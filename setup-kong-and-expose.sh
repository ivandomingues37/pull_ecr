#!/bin/bash
set -e

NAMESPACE_KONG="kong"
RELEASE_NAME="kong"
INGRESS_CLASS_NAME="kong"

echo "[1/8] Verificando ferramentas necessárias..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl não encontrado. Instale antes."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm não encontrado. Instale antes."; exit 1; }

echo "[2/8] Criando namespace '$NAMESPACE_KONG' (se não existir)..."
kubectl create namespace "$NAMESPACE_KONG" --dry-run=client -o yaml | kubectl apply -f -

echo "[3/8] Adicionando repositório Helm do Kong..."
helm repo add kong https://charts.konghq.com
helm repo update

echo "[4/8] Instalando Kong (modo DB-less)..."
helm install "$RELEASE_NAME" kong/kong \
  --namespace "$NAMESPACE_KONG" \
  --skip-crds \
  --set ingressController.ingressClass="$INGRESS_CLASS_NAME" \
  --set proxy.type=ClusterIP \
  --set admin.enabled=true

echo "[5/8] Aguardando pods do Kong estarem prontos..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=$RELEASE_NAME -n "$NAMESPACE_KONG" --timeout=300s

echo "[6/8] Criando IngressClass (se não existir)..."
kubectl get ingressclass "$INGRESS_CLASS_NAME" >/dev/null 2>&1 || cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: $INGRESS_CLASS_NAME
spec:
  controller: konghq.com/ingress-controller
EOF

echo "[7/8] Listando serviços disponíveis para expor..."
read -p "Digite o namespace onde estão suas aplicações (default): " APP_NAMESPACE
APP_NAMESPACE=${APP_NAMESPACE:-default}
kubectl get svc -n "$APP_NAMESPACE"

read -p "Digite os nomes dos serviços que deseja expor (separados por espaço): " -a SERVICES

for SERVICE in "${SERVICES[@]}"; do
  PORT=$(kubectl get svc "$SERVICE" -n "$APP_NAMESPACE" -o jsonpath="{.spec.ports[0].port}")
  echo "Criando Ingress para $SERVICE na porta $PORT"
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-$SERVICE
  namespace: $APP_NAMESPACE
  annotations:
    konghq.com/strip-path: "true"
spec:
  ingressClassName: $INGRESS_CLASS_NAME
  rules:
  - http:
      paths:
      - path: /$SERVICE
        pathType: Prefix
        backend:
          service:
            name: $SERVICE
            port:
              number: $PORT
EOF
done

echo "[8/8] Fazendo port-forward do Kong (proxy: 8000, admin: 8001)..."
echo "Use: curl http://localhost:8000/<nome-do-serviço>"

kubectl port-forward -n "$NAMESPACE_KONG" svc/kong-proxy 8000:80 &
kubectl port-forward -n "$NAMESPACE_KONG" svc/kong-admin 8001:8001 &

