const http = require('http');
const fs = require('fs');
const path = require('path');

const APP_DIR = path.join(__dirname, 'dist');
const CONFIG_PATH = path.join(APP_DIR, 'config.js');
const PORT = process.env.PORT || 80;

function writeConfig({ SUPABASE_URL = '', SUPABASE_ANON_KEY = '', ZOOM_WEBHOOK_URL = '' }) {
  const content = `window.__APP_CONFIG__ = {
  SUPABASE_URL: "${SUPABASE_URL}",
  SUPABASE_ANON_KEY: "${SUPABASE_ANON_KEY}",
  ZOOM_WEBHOOK_URL: "${ZOOM_WEBHOOK_URL}"
};\n`;
  fs.writeFileSync(CONFIG_PATH, content, 'utf-8');
}

// Initialize from env if provided
try {
  const envConfig = {
    SUPABASE_URL: process.env.SUPABASE_URL || '',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || '',
    ZOOM_WEBHOOK_URL: process.env.ZOOM_WEBHOOK_URL || ''
  };
  writeConfig(envConfig);
} catch (_) {}

function serveFile(req, res, filePath) {
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('Not found');
    }
    const ext = path.extname(filePath).toLowerCase();
    const type =
      ext === '.html' ? 'text/html' :
      ext === '.js' ? 'application/javascript' :
      ext === '.css' ? 'text/css' :
      ext === '.svg' ? 'image/svg+xml' :
      ext === '.ico' ? 'image/x-icon' : 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type });
    res.end(data);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'POST' && url.pathname === '/install') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const json = JSON.parse(body || '{}');
        if (!json.SUPABASE_URL || !json.SUPABASE_ANON_KEY || !json.ADMIN_EMAIL || !json.ADMIN_PASSWORD) {
          res.writeHead(400);
          return res.end('Missing values');
        }
        writeConfig(json);
        try {
          const installPath = path.join(__dirname, 'install.json');
          fs.writeFileSync(installPath, JSON.stringify({
            ADMIN_EMAIL: json.ADMIN_EMAIL,
            ADMIN_PASSWORD: json.ADMIN_PASSWORD
          }), 'utf-8');
        } catch (_) {}
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(500);
        res.end('Error');
      }
    });
    return;
  }

  if (req.method === 'GET' && url.pathname === '/config.js') {
    return serveFile(req, res, CONFIG_PATH);
  }

  let filePath = path.join(APP_DIR, url.pathname.replace(/\/+$/, ''));
  if (url.pathname === '/' || !path.extname(filePath)) {
    filePath = path.join(APP_DIR, 'index.html');
  }
  serveFile(req, res, filePath);
});

server.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});
