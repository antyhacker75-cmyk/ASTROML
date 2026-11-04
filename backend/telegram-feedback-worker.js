// Cloudflare Worker: stores the Telegram bot token as a Worker secret.
// Configure secrets with: npx wrangler secret put TELEGRAM_BOT_TOKEN
// Configure variable CHAT_ID in wrangler.toml or the Worker dashboard.

export default {
  async fetch(request, env) {
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: cors });

    try {
      const data = await request.json();
      const type = String(data.type || '').slice(0, 30);
      const message = String(data.message || '').trim().slice(0, 4000);
      if (!['Suggestion', 'Issue report'].includes(type) || message.length < 3) {
        return Response.json({ error: 'Invalid feedback' }, { status: 400, headers: cors });
      }
      if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) {
        return Response.json({ error: 'Feedback service is not configured' }, { status: 500, headers: cors });
      }
      const safe = (value) => String(value || 'Unknown').replace(/[<>]/g, '').slice(0, 120);
      const text = [
        'ASTROML — ' + type,
        '',
        'Device: ' + safe(data.device),
        'Android: ' + safe(data.android),
        'Chipset: ' + safe(data.chipset),
        'Manufacturer: ' + safe(data.manufacturer),
        'Model: ' + safe(data.model),
        'Date & time: ' + safe(data.submittedAt),
        '',
        'Message:',
        message,
      ].join('\n');
      const telegram = await fetch(`https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: env.TELEGRAM_CHAT_ID, text }),
      });
      if (!telegram.ok) return Response.json({ error: 'Telegram delivery failed' }, { status: 502, headers: cors });
      return Response.json({ ok: true }, { headers: cors });
    } catch (_) {
      return Response.json({ error: 'Invalid request' }, { status: 400, headers: cors });
    }
  },
};
