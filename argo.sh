#!/bin/bash

set -e

NAMESPACE="argocd"
RELEASE_NAME="argocd"
PORT_LOCAL=8080
PORT_TARGET=80

echo "[1/6] Verificando ferramentas necessárias..."
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl não encontrado. Instale antes de continuar."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo >&2 "helm não encontrado. Instale antes de continuar."; exit 1; }

echo "[2/6] Adicionando repositório Helm do ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "[3/6] Obtendo arquivo padrão de valores do ArgoCD..."
helm show values argo/argo-cd > argocd-values.yaml

# Aqui você pode editar programaticamente o argocd-values.yaml se desejar

echo "[4/6] Instalando ArgoCD no cluster..."
helm install "$RELEASE_NAME" argo/argo-cd -f argocd.yaml -n "$NAMESPACE" --create-namespace

echo "[5/6] Aguardando pods do ArgoCD ficarem prontos..."
kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=300s

echo "[6/6] Fazendo port-forward do serviço argocd-server para localhost:$PORT_LOCAL..."
kubectl port-forward service/argocd-server "$PORT_LOCAL":"$PORT_TARGET" -n "$NAMESPACE"

