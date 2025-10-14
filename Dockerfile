# Use uma imagem mínima de servidor web
FROM nginx:alpine

# Remove os arquivos default do nginx
RUN rm -rf /usr/share/nginx/html/*

# Copia apenas os arquivos necessários
COPY index.html /usr/share/nginx/html/index.html

# Expõe a porta padrão do nginx
EXPOSE 80

# Inicia o nginx em foreground
CMD ["nginx", "-g", "daemon off;"]
