FROM node:20-alpine
WORKDIR /app
COPY dist ./dist
COPY docker/server.js ./server.js
ENV PORT=80
EXPOSE 80
CMD ["node", "server.js"]
