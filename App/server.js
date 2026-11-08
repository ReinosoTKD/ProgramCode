const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
// Respaldo local: solo se usa si Supabase no esta disponible.
const CONFIG = require('./models.config.js');
const SUPABASE = require('./supabase.config.js');

const SB_URL = SUPABASE.url;
const SB_ANON_KEY = SUPABASE.publishableKey;
const SB_SERVICE_KEY = SUPABASE.serviceKey || SUPABASE.publishableKey;
const SB_KEY = SUPABASE.serviceKey || SUPABASE.publishableKey;
const SB_HAS_SERVICE_KEY = !!SUPABASE.serviceKey;
const SESSION_DAYS = 30;

// Tiempo maximo que puede tardar un modelo concreto (algunos necesitan 10-20s).
const PROVIDER_TIMEOUT_MS = 45000;
// Ventana de espera de la carrera en "Automatico".
const AUTO_RACE_TIMEOUT_MS = 20000;

// Orden inicial de los modelos usados por "Automatico" (solo para la siembra).
const AUTO_SEED = ['laguna-xs', 'nemotron-super-vl', 'minimax-m3-flash', 'gemma-4', 'muse-glimmer-30b'];

// Modelos en memoria: se cargan desde Supabase al arrancar.
let MODELS = CONFIG.slice();

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

// ---------------------------------------------------------------------------
// Supabase (REST + Auth). La clave service_role solo existe en el servidor.
// ---------------------------------------------------------------------------
function sbHeaders(extra) {
  return Object.assign({
    apikey: SB_KEY,
    Authorization: 'Bearer ' + SB_KEY,
    'Content-Type': 'application/json'
  }, extra || {});
}

async function supabaseFetch(pathname, options) {
  const opts = options || {};
  const key = opts.key || SB_KEY;
  const res = await fetch(SB_URL + pathname, {
    method: opts.method || 'GET',
    headers: Object.assign({
      apikey: key,
      Authorization: 'Bearer ' + key,
      'Content-Type': 'application/json'
    }, opts.headers || {}),
    body: opts.body
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (e) { data = text; }
  if (!res.ok) {
    let detail = data && (data.message || data.msg || data.error_description || data.hint || data.details);
    if (!detail && data && typeof data.error === 'string') detail = data.error;
    if (!detail && data && data.error && typeof data.error === 'object') detail = data.error.message;
    const err = new Error(detail || ('Supabase HTTP ' + res.status));
    err.status = res.status;
    throw err;
  }
  return data;
}

async function sbRequest(pathname, options) {
  return supabaseFetch('/rest/v1/' + pathname, Object.assign({ key: SB_KEY }, options || {}));
}

function sbAuthRequest(pathname, options) {
  return supabaseFetch(pathname, Object.assign({ key: SB_ANON_KEY }, options || {}));
}

function sbAdminRequest(pathname, options) {
  return supabaseFetch(pathname, Object.assign({ key: SB_SERVICE_KEY }, options || {}));
}

// ---------------------------------------------------------------------------
// Sesiones (cookie httpOnly + tabla sessions en Supabase)
// ---------------------------------------------------------------------------
function parseCookies(req) {
  const header = req.headers.cookie || '';
  const out = {};
  header.split(';').forEach((part) => {
    const i = part.indexOf('=');
    if (i < 0) return;
    const name = part.slice(0, i).trim();
    if (!name) return;
    try { out[name] = decodeURIComponent(part.slice(i + 1).trim()); } catch (e) { out[name] = part.slice(i + 1).trim(); }
  });
  return out;
}

function setSessionCookie(res, sessionId, maxAgeSeconds) {
  const parts = [
    'pc_session=' + encodeURIComponent(sessionId),
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=' + maxAgeSeconds
  ];
  if (process.env.NODE_ENV === 'production') parts.push('Secure');
  res.setHeader('Set-Cookie', parts.join('; '));
}

function clearSessionCookie(res) {
  const parts = ['pc_session=', 'Path=/', 'HttpOnly', 'SameSite=Lax', 'Max-Age=0'];
  if (process.env.NODE_ENV === 'production') parts.push('Secure');
  res.setHeader('Set-Cookie', parts.join('; '));
}

function decodeJwt(token) {
  try {
    const payload = String(token).split('.')[1];

    return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch (e) {
    return null;
  }
}

function userFromToken(token, fallbackUser) {
  const payload = decodeJwt(token) || {};
  const meta = payload.user_metadata || {};
  const fallbackMeta = (fallbackUser && fallbackUser.user_metadata) || {};
  return {
    id: (fallbackUser && fallbackUser.id) || payload.sub || '',
    email: payload.email || (fallbackUser && fallbackUser.email) || '',
    name: meta.name || fallbackMeta.name || ''
  };
}

async function createSession(res, tokenData) {
  const access = tokenData && tokenData.access_token;
  const refresh = tokenData && tokenData.refresh_token;
  if (!access || !refresh) throw new Error('Sesion invalida');
  const user = userFromToken(access, tokenData.user);
  if (!user.id) throw new Error('Usuario invalido');
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const rows = await sbRequest('sessions', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      user_id: user.id,
      access_token: access,
      refresh_token: refresh,
      expires_at: expiresAt
    })
  });
  const session = Array.isArray(rows) ? rows[0] : rows;
  if (!session || !session.id) throw new Error('No se pudo crear la sesion');
  setSessionCookie(res, session.id, SESSION_DAYS * 24 * 60 * 60);
  return user;
}

async function getAuthUser(req, res) {
  const cookies = parseCookies(req);
  const sessionId = cookies.pc_session;
  if (!isUuid(sessionId)) return null;
  const rows = await sbRequest('sessions?select=*&id=eq.' + sessionId + '&limit=1');
  const session = Array.isArray(rows) ? rows[0] : null;
  if (!session) return null;
  if (new Date(session.expires_at).getTime() < Date.now()) {
    await sbRequest('sessions?id=eq.' + sessionId, { method: 'DELETE', headers: { Prefer: 'return=minimal' } }).catch(() => {});
    if (res) clearSessionCookie(res);
    return null;
  }

  let payload = decodeJwt(session.access_token);
  const expMs = payload && payload.exp ? payload.exp * 1000 : 0;
  if (!payload || expMs < Date.now() + 60000) {
    try {
      const refreshed = await sbAuthRequest('/auth/v1/token?grant_type=refresh_token', {
        method: 'POST',
        body: JSON.stringify({ refresh_token: session.refresh_token })
      });
      const access = refreshed && refreshed.access_token;
      if (!access) throw new Error('Sin token');
      payload = decodeJwt(access) || payload;
      await sbRequest('sessions?id=eq.' + sessionId, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({
          access_token: access,
          refresh_token: (refreshed && refreshed.refresh_token) || session.refresh_token
        })
      });
    } catch (e) {
      await sbRequest('sessions?id=eq.' + sessionId, { method: 'DELETE', headers: { Prefer: 'return=minimal' } }).catch(() => {});
      if (res) clearSessionCookie(res);
