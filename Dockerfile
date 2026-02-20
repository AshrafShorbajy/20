FROM node:20-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl ca-certificates tar && rm -rf /var/lib/apt/lists/* \
  && curl -Ls https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz -o /tmp/supabase.tar.gz \
  && tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase \
  && chmod +x /usr/local/bin/supabase
COPY dist ./dist
COPY supabase ./supabase
COPY docker/server.js ./server.js
ENV PORT=80
EXPOSE 80
CMD ["node", "server.js"]
