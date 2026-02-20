const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

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

async function createAdmin(url, serviceRole, email, password) {
  try {
    const api = new URL('/auth/v1/admin/users', url).toString();
    const res = await fetch(api, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`
      },
      body: JSON.stringify({
        email,
        password,
        email_confirm: true,
        user_metadata: { role: 'admin', is_admin: true, ROLE: 'ADMIN' }
      })
    });
    if (!res.ok) return null;
    const json = await res.json();
    return json;
  } catch (_) {
    return null;
  }
}

async function listUsers(url, serviceRole) {
  try {
    const api = new URL('/auth/v1/admin/users?per_page=200', url).toString();
    const res = await fetch(api, {
      headers: {
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`
      }
    });
    if (!res.ok) return [];
    const json = await res.json();
    return Array.isArray(json) ? json : [];
  } catch (_) {
    return [];
  }
}

async function updateUser(url, serviceRole, id) {
  try {
    const api = new URL(`/auth/v1/admin/users/${id}`, url).toString();
    const res = await fetch(api, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`
      },
      body: JSON.stringify({
        email_confirm: true,
        user_metadata: { role: 'admin', is_admin: true, ROLE: 'ADMIN' }
      })
    });
    return res.ok;
  } catch (_) {
    return false;
  }
}

async function upsertProfile(url, serviceRole, id) {
  try {
    const rest = new URL('/rest/v1/profiles', url).toString();
    const res = await fetch(rest, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`,
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify({ id, role: 'admin' })
    });
    return res.ok;
  } catch (_) {
    return false;
  }
}

async function upsertAdminRole(url, serviceRole, userId) {
  try {
    const rest = new URL('/rest/v1/user_roles', url).toString();
    const res = await fetch(rest, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`,
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify({ user_id: userId, role: 'admin' })
    });
    return res.ok;
  } catch (_) {
    return false;
  }
}

function run(cmd, cwd, env) {
  return new Promise((resolve) => {
    const p = exec(cmd, { cwd, env });
    let out = '';
    let err = '';
    p.stdout.on('data', d => out += String(d));
    p.stderr.on('data', d => err += String(d));
    p.on('close', code => resolve({ ok: code === 0, out, err, code }));
  });
}

async function upsertSetting(url, serviceRole, key, value) {
  try {
    const rest = new URL('/rest/v1/site_settings', url).toString();
    const res = await fetch(rest, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`,
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify({ key, value })
    });
    return res.ok;
  } catch (_) {
    return false;
  }
}

async function createUploadsBucket(url, serviceRole) {
  try {
    const api = new URL('/storage/v1/bucket', url).toString();
    const res = await fetch(api, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRole,
        'Authorization': `Bearer ${serviceRole}`
      },
      body: JSON.stringify({ name: 'uploads', public: true })
    });
    return res.ok || res.status === 409;
  } catch (_) {
    return false;
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'POST' && url.pathname === '/install') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const json = JSON.parse(body || '{}');
        if (!json.SUPABASE_URL || !json.SUPABASE_ANON_KEY || !json.ADMIN_EMAIL || !json.ADMIN_PASSWORD || !json.SUPABASE_SERVICE_ROLE_KEY || !json.SUPABASE_ACCESS_TOKEN || !json.PROJECT_REF) {
          res.writeHead(400);
          return res.end('Missing values');
        }
        writeConfig(json);
        try {
          const installPath = path.join(__dirname, 'install.json');
          fs.writeFileSync(installPath, JSON.stringify({
            ADMIN_EMAIL: json.ADMIN_EMAIL,
            ADMIN_PASSWORD: json.ADMIN_PASSWORD,
            SUPABASE_ACCESS_TOKEN: json.SUPABASE_ACCESS_TOKEN,
            PROJECT_REF: json.PROJECT_REF
          }), 'utf-8');
        } catch (_) {}
        const env = {
          ...process.env,
          SUPABASE_ACCESS_TOKEN: json.SUPABASE_ACCESS_TOKEN,
          PROJECT_REF: json.PROJECT_REF,
          SUPABASE_URL: json.SUPABASE_URL,
          SUPABASE_SERVICE_ROLE_KEY: json.SUPABASE_SERVICE_ROLE_KEY
        };
        const steps = [];
        const cfg = path.join('/app', 'supabase', 'config.toml');
        if (!fs.existsSync(cfg)) {
          const s0 = await run(`npx supabase init --force`, '/app', env);
          steps.push({ step: 'init', ok: s0.ok, out: s0.out, err: s0.err });
          if (!s0.ok) return send(res, { ok: false, steps });
        }
        const s1 = await run(`npx supabase login --token "${json.SUPABASE_ACCESS_TOKEN}"`, '/app', env);
        steps.push({ step: 'login', ok: s1.ok, out: s1.out, err: s1.err });
        if (!s1.ok) return send(res, { ok: false, steps });
        const s2 = await run(`npx supabase link --project-ref "${json.PROJECT_REF}"`, '/app', env);
        steps.push({ step: 'link', ok: s2.ok, out: s2.out, err: s2.err });
        if (!s2.ok) return send(res, { ok: false, steps });
        const s3 = await run(`npx supabase db push`, '/app', env);
        steps.push({ step: 'db_push', ok: s3.ok, out: s3.out, err: s3.err });
        if (!s3.ok) return send(res, { ok: false, steps });
        const s4 = await run(`npx supabase secrets set SUPABASE_URL="${json.SUPABASE_URL}" SUPABASE_SERVICE_ROLE_KEY="${json.SUPABASE_SERVICE_ROLE_KEY}"`, '/app', env);
        steps.push({ step: 'secrets_base', ok: s4.ok, out: s4.out, err: s4.err });
        if (json.ZOOM_WEBHOOK_SECRET) {
          const s5 = await run(`npx supabase secrets set ZOOM_WEBHOOK_SECRET="${json.ZOOM_WEBHOOK_SECRET}"`, '/app', env);
          steps.push({ step: 'secrets_zoom', ok: s5.ok, out: s5.out, err: s5.err });
          await run(`npx supabase functions deploy zoom-webhook`, '/app', env);
        }
        await createUploadsBucket(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY);
        await upsertSetting(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, 'maintenance_mode', false);
        await upsertSetting(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, 'homepage_sections_order', ['announcements','promo_banners','lesson_types','offers']);
        await upsertSetting(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, 'site_name', 'New Deployment');
        await upsertSetting(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, 'offers', []);
        const created = await createAdmin(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, json.ADMIN_EMAIL, json.ADMIN_PASSWORD);
        let userId = created && created.id ? created.id : null;
        if (!userId) {
          const users = await listUsers(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY);
          const found = users.find(u => (u.email || '').toLowerCase() === json.ADMIN_EMAIL.toLowerCase());
          userId = found && found.id ? found.id : null;
        }
        if (userId) {
          await updateUser(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, userId);
          await upsertProfile(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, userId);
          await upsertAdminRole(json.SUPABASE_URL, json.SUPABASE_SERVICE_ROLE_KEY, userId);
        }
        send(res, { ok: true, steps });
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

function send(res, payload) {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}
