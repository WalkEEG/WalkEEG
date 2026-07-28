/* ===========================================
   WalkEEG - Data Portal Application
   SPA with auth, upload, visualization
   =========================================== */

// ===== State =====
let state = {
  user: null,
  signals: [],
  currentView: null,
};

// ===== DOM Cache =====
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// ===== Toast =====
function toast(msg, type = 'info') {
  const container = $('#toastContainer');
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.textContent = msg;
  container.appendChild(el);
  setTimeout(() => {
    el.classList.add('toast-removing');
    setTimeout(() => el.remove(), 300);
  }, 4000);
}

// ===== Modal =====
function showModal(html) {
  const overlay = $('#modalOverlay');
  overlay.innerHTML = `<div class="modal">${html}</div>`;
  overlay.classList.add('open');
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) hideModal();
  });
}

function hideModal() {
  $('#modalOverlay').classList.remove('open');
}

// ===== Router =====
function navigate(page, data) {
  // Handle special routes
  if (page === 'logout') {
    logout();
    return;
  }

  // Show app layout (hide auth)
  if (state.user) {
    $('#authPage').style.display = 'none';
    $('#appLayout').style.display = 'flex';
  }

  // Hide all pages
  $$('.app-page').forEach(p => p.classList.remove('active'));
  $$('.app-nav-item').forEach(n => n.classList.remove('active'));

  // Activate target page
  const pageEl = $(`#page-${page}`);
  if (pageEl) {
    pageEl.classList.add('active');
    const navItem = $(`.app-nav-item[data-page="${page}"]`);
    if (navItem) navItem.classList.add('active');
  }

  // Route-specific logic
  switch(page) {
    case 'dashboard': loadDashboard(); break;
    case 'signals': loadSignals(); break;
    case 'signal-view': loadSignalView(data); break;
    case 'profile': loadProfile(); break;
  }
}

// ===== Auth =====
function isAuthenticated() {
  return !!localStorage.getItem('walkeeg_token');
}

function getToken() {
  return localStorage.getItem('walkeeg_token');
}

// DEMO MODE: Use localStorage mock when backend is not available
const USE_DEMO = true;

async function login(email, password) {
  if (USE_DEMO) {
    // Demo mode - simulate auth
    const user = { name: email.split('@')[0], email, id: 'demo_' + Date.now() };
    localStorage.setItem('walkeeg_token', 'demo_token_' + Date.now());
    localStorage.setItem('walkeeg_user', JSON.stringify(user));
    state.user = user;
    return user;
  }
  return API.post('/auth/login', { email, password });
}

async function register(name, email, password) {
  if (USE_DEMO) {
    const user = { name, email, id: 'demo_' + Date.now() };
    localStorage.setItem('walkeeg_token', 'demo_token_' + Date.now());
    localStorage.setItem('walkeeg_user', JSON.stringify(user));
    state.user = user;
    return user;
  }
  return API.post('/auth/register', { name, email, password });
}

function logout() {
  localStorage.removeItem('walkeeg_token');
  localStorage.removeItem('walkeeg_user');
  state.user = null;
  state.signals = [];
  $('#authPage').style.display = 'flex';
  $('#appLayout').style.display = 'none';
  showAuthForm('login');
}

// ===== Auth Form =====
function showAuthForm(form) {
  $('#loginForm').style.display = form === 'login' ? 'block' : 'none';
  $('#registerForm').style.display = form === 'register' ? 'block' : 'none';
}

// ===== Dashboard =====
async function loadDashboard() {
  if (USE_DEMO) {
    const signals = getDemoSignals();
    const total = signals.length;

    $('#totalRecordings').textContent = total;
    $('#monthRecordings').textContent = signals.filter(s => {
      const d = new Date(s.createdAt);
      const now = new Date();
      return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
    }).length;

    const totalBytes = signals.reduce((a, s) => a + (s.fileSize || 0), 0);
    $('#storageUsed').textContent = formatBytes(totalBytes);

    $('#lastUpload').textContent = signals.length > 0
      ? new Date(signals[signals.length-1].createdAt).toLocaleDateString()
      : '—';

    renderRecentSignals(signals);
  }
}

function renderRecentSignals(signals) {
  const container = $('#recentRecordings');
  if (signals.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">🧠</div>
        <h3>No Recordings Yet</h3>
        <p>Upload your first EEG signal to start building your data library.</p>
        <a href="#upload" class="btn btn-primary" data-page="upload">Upload Your First Signal</a>
      </div>`;
    return;
  }

  const rows = signals.slice().reverse().slice(0, 10).map(s => `
    <tr>
      <td style="font-weight:600;">${escapeHtml(s.name)}</td>
      <td>${new Date(s.createdAt).toLocaleDateString()}</td>
      <td>${formatBytes(s.fileSize || 0)}</td>
      <td><span class="status-badge ${s.status}">${s.status}</span></td>
      <td>
        <a href="#signal-view/${s.id}" class="btn btn-sm btn-outline" data-nav="signal-view" data-id="${s.id}">View</a>
      </td>
    </tr>
  `).join('');

  container.innerHTML = `
    <table class="data-table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Date</th>
          <th>Size</th>
          <th>Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

// ===== Upload =====
function initUpload() {
  const uploadArea = $('#uploadArea');
  const fileInput = $('#fileInput');

  uploadArea.addEventListener('click', () => fileInput.click());

  uploadArea.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadArea.classList.add('dragover');
  });

  uploadArea.addEventListener('dragleave', () => {
    uploadArea.classList.remove('dragover');
  });

  uploadArea.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadArea.classList.remove('dragover');
    if (e.dataTransfer.files.length) handleFileSelect(e.dataTransfer.files[0]);
  });

  fileInput.addEventListener('change', () => {
    if (fileInput.files.length) handleFileSelect(fileInput.files[0]);
  });

  $('#removeFile').addEventListener('click', () => {
    $('#selectedFile').style.display = 'none';
    $('#uploadArea').style.display = 'block';
    fileInput.value = '';
  });

  $('#uploadForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = $('#signalName').value.trim();
    const desc = $('#signalDescription').value.trim();
    const file = fileInput.files[0];
    if (!name || !file) { toast('Please fill in all required fields.', 'error'); return; }
    await uploadSignal(name, desc, file);
  });
}

function handleFileSelect(file) {
  $('#fileName').textContent = file.name;
  $('#fileSize').textContent = formatBytes(file.size);
  $('#selectedFile').style.display = 'block';
  $('#uploadArea').style.display = 'none';
}

async function uploadSignal(name, desc, file) {
  const progress = $('#uploadProgress');
  const fill = $('#progressFill');
  const ptext = $('#progressText');
  const ppercent = $('#progressPercent');
  const btn = $('#uploadBtn');
  const btnText = $('#uploadBtnText');

  progress.classList.add('active');
  btn.disabled = true;
  btnText.textContent = 'Uploading...';

  if (USE_DEMO) {
    // Simulate upload progress
    for (let i = 0; i <= 100; i += 10) {
      await new Promise(r => setTimeout(r, 150));
      fill.style.width = i + '%';
      ptext.textContent = i < 100 ? 'Uploading...' : 'Processing...';
      ppercent.textContent = i + '%';
    }

    const newSignal = {
      id: 'sig_' + Date.now(),
      name,
      description: desc,
      fileName: file.name,
      fileSize: file.size,
      status: 'processed',
      createdAt: new Date().toISOString(),
      duration: '—',
      channels: '—',
      sampleRate: '—',
    };

    const signals = getDemoSignals();
    signals.push(newSignal);
    localStorage.setItem('walkeeg_demo_signals', JSON.stringify(signals));
    state.signals = signals;

    toast('Signal uploaded successfully!', 'success');
    setTimeout(() => navigate('signals'), 1000);
  }

  progress.classList.remove('active');
  fill.style.width = '0';
  btn.disabled = false;
  btnText.textContent = 'Upload Signal';
}

// ===== Signals List =====
async function loadSignals() {
  if (USE_DEMO) {
    const signals = getDemoSignals();
    renderSignalsTable(signals);
  }
}

function renderSignalsTable(signals) {
  const container = $('#signalsList');
  if (signals.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">📊</div>
        <h3>No Recordings</h3>
        <p>When you upload EEG signals, they will appear here.</p>
        <a href="#upload" class="btn btn-primary" data-page="upload">Upload Now</a>
      </div>`;
    return;
  }

  const rows = signals.slice().reverse().map(s => `
    <tr>
      <td style="font-weight:600;">${escapeHtml(s.name)}</td>
      <td>${new Date(s.createdAt).toLocaleDateString()}</td>
      <td>${s.duration || '—'}</td>
      <td>${s.channels || '—'}</td>
      <td>${formatBytes(s.fileSize || 0)}</td>
      <td><span class="status-badge ${s.status}">${s.status}</span></td>
      <td>
        <a href="#signal-view/${s.id}" class="btn btn-sm btn-outline" data-nav="signal-view" data-id="${s.id}">View</a>
      </td>
    </tr>
  `).join('');

  container.innerHTML = `
    <table class="data-table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Date</th>
          <th>Duration</th>
          <th>Channels</th>
          <th>Size</th>
          <th>Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`;
}

// ===== Signal Viewer =====
let signalChart = null;
let fftChart = null;

function loadSignalView(signalId) {
  const signals = getDemoSignals();
  const signal = signals.find(s => s.id === signalId);
  if (!signal) { navigate('signals'); return; }

  state.currentView = signal;

  $('#viewSignalName').textContent = signal.name;
  $('#viewSignalMeta').textContent = `Uploaded ${new Date(signal.createdAt).toLocaleString()} · ${formatBytes(signal.fileSize || 0)}`;

  // Simulate signal metadata
  const duration = signal.duration || '30s';
  const channels = signal.channels || '8';
  const sampleRate = signal.sampleRate || '256 Hz';
  const fileSize = formatBytes(signal.fileSize || 0);

  $('#signalDuration').textContent = duration;
  $('#signalChannels').textContent = channels;
  $('#signalSampleRate').textContent = sampleRate;
  $('#signalFileSize').textContent = fileSize;

  renderSignalChart();
  renderFFTChart();

  // Download handler
  $('#downloadSignalBtn').onclick = () => {
    if (USE_DEMO) {
      toast('Demo mode: download would generate a CSV file.', 'info');
      downloadDemoCSV(signal);
    }
  };

  // Delete handler
  $('#deleteSignalBtn').onclick = () => {
    showModal(`
      <h2>Delete Recording</h2>
      <p>Are you sure you want to delete "${escapeHtml(signal.name)}"? This cannot be undone.</p>
      <div class="confirm-actions">
        <button class="btn btn-secondary" onclick="hideModal()">Cancel</button>
        <button class="btn btn-primary" style="background:var(--danger);" onclick="deleteSignal('${signal.id}')">Delete</button>
      </div>
    `);
  };
}

function renderSignalChart() {
  const canvas = $('#signalChart');
  const parent = canvas.parentElement;

  if (signalChart) signalChart.destroy();

  const ctx = canvas.getContext('2d');
  const width = parent.clientWidth;
  const height = parent.clientHeight;
  canvas.width = width * 2;
  canvas.height = height * 2;
  canvas.style.width = width + 'px';
  canvas.style.height = height + 'px';

  // Generate realistic-looking EEG data
  const points = 1000;
  const data = generateEEGSignal(points);

  signalChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: Array.from({ length: points }, (_, i) => (i / points * 10).toFixed(1)),
      datasets: [{
        label: 'Channel 1',
        data: data,
        borderColor: '#6366f1',
        backgroundColor: 'rgba(99, 102, 241, 0.05)',
        borderWidth: 1.5,
        pointRadius: 0,
        tension: 0.4,
        fill: true,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 300 },
      plugins: {
        legend: { display: false },
        tooltip: { enabled: false },
      },
      scales: {
        x: {
          grid: { color: 'rgba(255,255,255,0.03)', drawTicks: false },
          ticks: { color: '#64748b', maxTicksLimit: 8, font: { size: 11 } },
          title: { display: true, text: 'Time (s)', color: '#64748b', font: { size: 11 } },
        },
        y: {
          grid: { color: 'rgba(255,255,255,0.03)' },
          ticks: { color: '#64748b', font: { size: 11 } },
          title: { display: true, text: 'Amplitude (µV)', color: '#64748b', font: { size: 11 } },
        },
      },
      interaction: { mode: 'nearest', axis: 'x', intersect: false },
    }
  });

  // Zoom controls
  $('#zoomInBtn').onclick = () => {
    if (signalChart) {
      const min = signalChart.scales.x.min || 0;
      const max = signalChart.scales.x.max || 10;
      const range = max - min;
      signalChart.options.scales.x.min = min + range * 0.1;
      signalChart.options.scales.x.max = max - range * 0.1;
      signalChart.update();
    }
  };

  $('#zoomOutBtn').onclick = () => {
    if (signalChart) {
      signalChart.options.scales.x.min = undefined;
      signalChart.options.scales.x.max = undefined;
      signalChart.update();
    }
  };

  $('#resetViewBtn').onclick = () => {
    if (signalChart) {
      signalChart.options.scales.x.min = undefined;
      signalChart.options.scales.x.max = undefined;
      signalChart.update();
    }
  };
}

function renderFFTChart() {
  const canvas = $('#fftChart');
  if (fftChart) fftChart.destroy();

  const ctx = canvas.getContext('2d');

  // Generate frequency spectrum data
  const bands = ['Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'];
  const freqs = ['1-4 Hz', '4-8 Hz', '8-13 Hz', '13-30 Hz', '30-50 Hz'];
  const values = bands.map(() => Math.random() * 0.8 + 0.2);

  fftChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: bands.map((b, i) => `${b}\n${freqs[i]}`),
      datasets: [{
        label: 'Power',
        data: values,
        backgroundColor: [
          'rgba(99, 102, 241, 0.7)',
          'rgba(6, 182, 212, 0.7)',
          'rgba(34, 197, 94, 0.7)',
          'rgba(245, 158, 11, 0.7)',
          'rgba(239, 68, 68, 0.7)',
        ],
        borderColor: [
          '#6366f1', '#06b6d4', '#22c55e', '#f59e0b', '#ef4444',
        ],
        borderWidth: 1,
        borderRadius: 4,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 500 },
      plugins: {
        legend: { display: false },
      },
      scales: {
        x: {
          grid: { display: false },
          ticks: { color: '#64748b', font: { size: 10 } },
        },
        y: {
          grid: { color: 'rgba(255,255,255,0.03)' },
          beginAtZero: true,
          max: 1.0,
          ticks: { color: '#64748b', font: { size: 11 } },
          title: { display: true, text: 'Relative Power', color: '#64748b', font: { size: 11 } },
        },
      },
    }
  });
}

// ===== Profile =====
function loadProfile() {
  const user = state.user || JSON.parse(localStorage.getItem('walkeeg_user') || '{}');
  const avatar = $('#profileAvatar');
  avatar.textContent = (user.name || 'U')[0].toUpperCase();
  $('#profileName').value = user.name || '';
  $('#profileEmail').value = user.email || '';

  $('#profileForm').onsubmit = (e) => {
    e.preventDefault();
    const name = $('#profileName').value.trim();
    if (!name) { toast('Name cannot be empty.', 'error'); return; }
    user.name = name;
    localStorage.setItem('walkeeg_user', JSON.stringify(user));
    state.user = user;
    updateUserUI();
    toast('Profile updated!', 'success');
  };
}

// ===== Delete Signal =====
window.deleteSignal = function(id) {
  let signals = getDemoSignals();
  signals = signals.filter(s => s.id !== id);
  localStorage.setItem('walkeeg_demo_signals', JSON.stringify(signals));
  state.signals = signals;
  hideModal();
  toast('Recording deleted.', 'info');
  navigate('signals');
};

// ===== Demo Data =====
function getDemoSignals() {
  let signals = JSON.parse(localStorage.getItem('walkeeg_demo_signals') || '[]');
  // Seed demo data if empty
  if (signals.length === 0) {
    signals = [
      {
        id: 'sig_demo_1',
        name: 'Resting State - Eyes Open',
        description: 'Baseline recording with eyes open',
        fileName: 'resting_eyes_open.csv',
        fileSize: 2457600,
        status: 'processed',
        createdAt: new Date(Date.now() - 86400000 * 3).toISOString(),
        duration: '120s',
        channels: '8',
        sampleRate: '256 Hz',
      },
      {
        id: 'sig_demo_2',
        name: 'Resting State - Eyes Closed',
        description: 'Baseline recording with eyes closed',
        fileName: 'resting_eyes_closed.csv',
        fileSize: 2457600,
        status: 'processed',
        createdAt: new Date(Date.now() - 86400000 * 2).toISOString(),
        duration: '120s',
        channels: '8',
        sampleRate: '256 Hz',
      },
      {
        id: 'sig_demo_3',
        name: 'Motor Imagery - Right Hand',
        description: 'Subject imagined right hand movement',
        fileName: 'motor_right.csv',
        fileSize: 5120000,
        status: 'processed',
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        duration: '300s',
        channels: '8',
        sampleRate: '256 Hz',
      },
    ];
    localStorage.setItem('walkeeg_demo_signals', JSON.stringify(signals));
  }
  return signals;
}

function generateEEGSignal(n) {
  const data = [];
  for (let i = 0; i < n; i++) {
    // Simulate EEG: alpha rhythm (~10 Hz) + noise + occasional artifacts
    const alpha = Math.sin(i * 0.063) * 30;   // ~10 Hz at 256Hz sample rate
    const theta = Math.sin(i * 0.025) * 15;    // ~4 Hz
    const beta = Math.sin(i * 0.12) * 10;      // ~20 Hz
    const noise = (Math.random() - 0.5) * 15;
    const artifact = Math.random() < 0.01 ? (Math.random() - 0.5) * 80 : 0;
    data.push(alpha + theta + beta + noise + artifact);
  }
  return data;
}

function downloadDemoCSV(signal) {
  const header = 'Time(s),Ch1(uV),Ch2(uV),Ch3(uV),Ch4(uV),Ch5(uV),Ch6(uV),Ch7(uV),Ch8(uV)\n';
  let rows = '';
  for (let t = 0; t < 300; t++) {
    const time = (t / 256).toFixed(3);
    const chs = Array.from({length: 8}, () => (Math.random() - 0.5) * 100 + Math.sin(t * 0.063) * 30);
    rows += `${time},${chs.join(',')}\n`;
  }
  const blob = new Blob([header + rows], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${signal.name.replace(/\s+/g, '_')}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

// ===== Utilities =====
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function updateUserUI() {
  const user = state.user || JSON.parse(localStorage.getItem('walkeeg_user') || '{}');
  $('#userAvatar').textContent = (user.name || 'U')[0].toUpperCase();
  $('#userName').textContent = user.name || 'User';
  $('#userEmail').textContent = user.email || '';
}

// ===== Hash Router =====
function handleHashChange() {
  const hash = window.location.hash.slice(1) || 'dashboard';

  if (!isAuthenticated() && hash !== 'login' && hash !== 'register') {
    window.location.hash = 'login';
    return;
  }

  if (!isAuthenticated()) {
    showAuthForm(hash === 'register' ? 'register' : 'login');
    return;
  }

  // Parse hash routes
  if (hash.startsWith('signal-view/')) {
    const id = hash.split('/')[1];
    navigate('signal-view', id);
  } else {
    navigate(hash);
  }
}

// ===== Init =====
document.addEventListener('DOMContentLoaded', () => {
  // Auth form handlers
  $('#loginFormElement').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = $('#loginEmail').value;
    const password = $('#loginPassword').value;
    const errorEl = $('#loginError');
    try {
      await login(email, password);
      updateUserUI();
      window.location.hash = 'dashboard';
      toast('Welcome back!', 'success');
    } catch (err) {
      errorEl.textContent = err.message || 'Invalid credentials.';
      errorEl.classList.add('visible');
    }
  });

  $('#registerFormElement').addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = $('#regName').value;
    const email = $('#regEmail').value;
    const password = $('#regPassword').value;
    const errorEl = $('#registerError');
    try {
      await register(name, email, password);
      updateUserUI();
      window.location.hash = 'dashboard';
      toast('Account created! Welcome to WalkEEG.', 'success');
    } catch (err) {
      errorEl.textContent = err.message || 'Registration failed.';
      errorEl.classList.add('visible');
    }
  });

  $('#showRegister').addEventListener('click', (e) => {
    e.preventDefault();
    window.location.hash = 'register';
  });

  $('#showLogin').addEventListener('click', (e) => {
    e.preventDefault();
    window.location.hash = 'login';
  });

  $('#logoutBtn').addEventListener('click', logout);

  // Navigation click delegation
  document.addEventListener('click', (e) => {
    const navLink = e.target.closest('[data-page], [data-nav]');
    if (navLink) {
      e.preventDefault();
      const page = navLink.dataset.page || navLink.dataset.nav;
      const id = navLink.dataset.id;
      if (id) {
        window.location.hash = `${page}/${id}`;
      } else if (page === 'logout') {
        logout();
      } else {
        window.location.hash = page;
      }
    }
  });

  // Search filter
  $('#signalSearch')?.addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase();
    const signals = getDemoSignals().filter(s =>
      s.name.toLowerCase().includes(q) || s.description?.toLowerCase().includes(q)
    );
    renderSignalsTable(signals);
  });

  // Init upload
  initUpload();

  // Hash router
  window.addEventListener('hashchange', handleHashChange);

  // Restore session
  if (isAuthenticated()) {
    const userData = localStorage.getItem('walkeeg_user');
    if (userData) {
      state.user = JSON.parse(userData);
      updateUserUI();
    }
  }

  // Bootstrap routing
  handleHashChange();
});
