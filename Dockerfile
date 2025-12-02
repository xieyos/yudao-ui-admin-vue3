# 运行阶段，使用nginx静态服务器
FROM nginx:stable-alpine as production-prod

# 复制构建产物到nginx默认目录
COPY dist-prod /usr/share/nginx/html

# 复制自定义nginx配置（可选）
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]