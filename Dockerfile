FROM node:20-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/* \
  && curl -sL https://github.com/supabase/cli/releases/download/v1.176.10/supabase_1.176.10_linux_amd64.tar.gz -o /tmp/supabase.tar.gz \
  && tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase \
  && chmod +x /usr/local/bin/supabase
COPY dist ./dist
COPY supabase ./supabase
COPY docker/server.js ./server.js
ENV PORT=80
EXPOSE 80
CMD ["node", "server.js"]
