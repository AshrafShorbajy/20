FROM node:20-slim
WORKDIR /app
RUN npm i -g supabase@latest
COPY dist ./dist
COPY supabase ./supabase
COPY docker/server.js ./server.js
ENV PORT=80
EXPOSE 80
CMD ["node", "server.js"]
