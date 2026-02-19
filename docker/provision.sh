#!/bin/bash
set -euo pipefail
supabase link --project-ref "${PROJECT_REF}" --access-token "${SUPABASE_ACCESS_TOKEN}"
supabase db push
supabase secrets set SUPABASE_URL="${SUPABASE_URL}" SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}" ZOOM_WEBHOOK_SECRET="${ZOOM_WEBHOOK_SECRET}"
supabase functions deploy zoom-webhook
curl -s -X POST "${SUPABASE_URL}/storage/v1/bucket" -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" -H "Content-Type: application/json" -d '{"name":"uploads","public":true}' || true
node - <<'NODE'
const { createClient } = require('@supabase/supabase-js');
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const adminEmail = process.env.ADMIN_EMAIL;
const adminPassword = process.env.ADMIN_PASSWORD;
const supabase = createClient(url, key);
async function upsert(key, value) {
  const { data } = await supabase.from('site_settings').select('id').eq('key', key).maybeSingle();
  if (data) { await supabase.from('site_settings').update({ value }).eq('key', key); }
  else { await supabase.from('site_settings').insert({ key, value }); }
}
async function run() {
  await upsert('maintenance_mode', false);
  await upsert('homepage_sections_order', ['announcements','promo_banners','lesson_types','offers']);
  await upsert('site_name', 'New Deployment');
  await upsert('offers', []);
  const { data: user, error } = await supabase.auth.admin.createUser({ email: adminEmail, password: adminPassword, email_confirm: true, user_metadata: { role: 'admin' } });
  if (error && !String(error.message||'').includes('already exists')) throw error;
  const adminUserId = user?.user?.id || null;
  if (adminUserId) {
    const { data: prof } = await supabase.from('profiles').select('user_id').eq('user_id', adminUserId).maybeSingle();
    if (!prof) { await supabase.from('profiles').insert({ user_id: adminUserId, full_name: 'Administrator', role: 'admin' }); }
    else { await supabase.from('profiles').update({ role: 'admin' }).eq('user_id', adminUserId); }
  }
}
run().then(()=>console.log('Seeding complete')).catch(e=>{ console.error(e); process.exit(1); });
NODE
echo "Provisioning complete."
