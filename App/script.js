(function () {
  'use strict';

  const chat = document.getElementById('chat');
  const input = document.getElementById('promptInput');
  const sendBtn = document.getElementById('sendBtn');
  const modelSelect = document.getElementById('modelSelect');
  const modelPickerBtn = document.getElementById('modelPickerBtn');
  const modelPickerLabel = document.getElementById('modelPickerLabel');
  const modelMenu = document.getElementById('modelMenu');
  const atMenu = document.getElementById('atMenu');
  const functionChip = document.getElementById('functionChip');
  const statusText = document.getElementById('statusText');
  const composer = document.querySelector('.composer');
  const appEl = document.querySelector('.app');

  const sidebar = document.getElementById('sidebar');
  const sidebarToggle = document.getElementById('sidebarToggle');
  const sidebarClose = document.getElementById('sidebarClose');
  const sidebarBackdrop = document.getElementById('sidebarBackdrop');
  const newChatBtn = document.getElementById('newChatBtn');
  const chatList = document.getElementById('chatList');
  const guestModal = document.getElementById('guestModal');
  const guestContinue = document.getElementById('guestContinue');
  const guestCancel = document.getElementById('guestCancel');

  const signupBtn = document.getElementById('signupBtn');
  const userChip = document.getElementById('userChip');
  const userChipName = document.getElementById('userChipName');
  const logoutBtn = document.getElementById('logoutBtn');
  const authModal = document.getElementById('authModal');
  const authForm = document.getElementById('authForm');
  const authEmail = document.getElementById('authEmail');
  const authPassword = document.getElementById('authPassword');
  const togglePassword = document.getElementById('togglePassword');
  const authName = document.getElementById('authName');
  const authNameField = document.getElementById('authNameField');
  const authTitle = document.getElementById('authTitle');
  const authSub = document.getElementById('authSub');
  const authSubmit = document.getElementById('authSubmit');
  const authError = document.getElementById('authError');
  const authSwitchText = document.getElementById('authSwitchText');
  const authSwitchBtn = document.getElementById('authSwitchBtn');
  const authClose = document.getElementById('authClose');

  const aboutBtn = document.getElementById('aboutBtn');
  const aboutView = document.getElementById('aboutView');
  const aboutClose = document.getElementById('aboutClose');
  const aboutScroll = document.getElementById('aboutScroll');

  let sending = false;
  const history = [];
  const availability = {};
  const capacities = {};
  let selectedFunction = null;
  let chats = [];
  let currentChatId = null;
  let currentUser = null;
  let authMode = 'signup';

  // El texto de estado fue retirado de la interfaz; se conserva la funcion
  // para no romper las llamadas existentes.
  function setStatus(text) {
    if (statusText) statusText.textContent = text;
  }

  // ---------- Historial de chats (Supabase via API) ----------
  async function apiJson(url, options) {
    const res = await fetch(url, options);
    let data = null;
    try { data = await res.json(); } catch (e) { data = null; }
    if (!res.ok) throw new Error((data && data.error) || ('Error ' + res.status));
    return data;
  }

  async function loadChats() {
    if (!currentUser) {
      chats = [];
      renderChatList();
      return;
    }
    try {
      const rows = await apiJson('/api/chats');
      chats = (Array.isArray(rows) ? rows : []).map(r => ({
        id: r.id,
        title: r.title || 'Chat',
        updatedAt: r.updated_at || r.updatedAt || Date.now()
      }));
    } catch (e) {

      chats = [];
    }
    renderChatList();
  }

  // Sube una sola vez los chats que quedaron guardados en el navegador.
  async function migrateLocalChats() {
    if (!currentUser) return;
    try {
      if (localStorage.getItem('pc_chats_migrated')) return;
      const raw = localStorage.getItem('pc_chats');
      if (!raw) return;
      const stored = JSON.parse(raw);
      if (Array.isArray(stored) && stored.length) {
        await apiJson('/api/chats/import', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chats: stored })
        });
      }
      localStorage.removeItem('pc_chats');
      localStorage.setItem('pc_chats_migrated', '1');
    } catch (e) { /* si falla, se reintenta en la proxima carga */ }
  }

  async function ensureChat() {
    if (!currentUser) return null;
    if (currentChatId) return currentChatId;
    const created = await apiJson('/api/chats', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: 'Nuevo chat' })
    });
    if (created && created.id) {
      currentChatId = created.id;
      chats.unshift({
        id: created.id,
        title: created.title || 'Nuevo chat',
        updatedAt: created.updated_at || Date.now()
      });
      renderChatList();
    }
    return currentChatId;
  }

  function formatChatDate(ts) {
    const d = new Date(ts || Date.now());
    const now = new Date();
    if (d.toDateString() === now.toDateString()) {
      return d.toLocaleTimeString('es', { hour: '2-digit', minute: '2-digit' });
    }
    return d.toLocaleDateString('es', { day: 'numeric', month: 'short' });
  }

  function renderChatList() {
    if (!chatList) return;
    chatList.innerHTML = '';
    if (!chats.length) {
      const empty = document.createElement('div');
      empty.className = 'chat-list-empty';
      empty.textContent = 'Aun no hay chats guardados.';
