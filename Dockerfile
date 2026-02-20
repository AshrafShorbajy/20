FROM node:20-slim
WORKDIR /app
COPY package.json ./package.json
RUN npm install --no-audit --no-fund
COPY dist ./dist
COPY supabase ./supabase
COPY docker/server.js ./server.js
COPY ["sql apply.txt","./sql-apply.sql"]
ENV PORT=80
EXPOSE 80
CMD ["node", "server.js"]
