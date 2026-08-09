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

/** True only when Cognito config is missing — evaluated at call time. */
function useDemo() {
  return !window.WalkEEGAuth?.isConfigured?.();
}

function clearAuthStorage() {
  [
    'walkeeg_token',
    'walkeeg_user',
    'walkeeg_id_token',
    'walkeeg_access_token',
    'walkeeg_refresh_token',
    'walkeeg_identity_id',
  ].forEach((k) => localStorage.removeItem(k));
}

function isJwt(token) {
  return typeof token === 'string' && token.split('.').length === 3;
}

function isAuthenticated() {
  const token = localStorage.getItem('walkeeg_token');
  if (!token) return false;
  // In real mode, only Cognito JWTs count — demo tokens cannot enter the app.
  if (!useDemo() && !isJwt(token)) {
    clearAuthStorage();
    return false;
  }
  return true;
}

function getToken() {
  return localStorage.getItem('walkeeg_token');
}

// Purge leftover demo tokens when Cognito is configured
(function purgeInvalidSession() {
  if (useDemo()) return;
  const token = localStorage.getItem('walkeeg_token') || '';
  if (token && !isJwt(token)) clearAuthStorage();
})();

async function login(email, password) {
  if (useDemo()) {
    const user = { name: email.split('@')[0], email, id: 'demo_' + Date.now() };
    localStorage.setItem('walkeeg_token', 'demo_token_' + Date.now());
    localStorage.setItem('walkeeg_user', JSON.stringify(user));
    state.user = user;
    return user;
  }
  const user = await WalkEEGAuth.login(email, password);
  state.user = user;
  return user;
}

/** Pending signup — kept in memory for auto-login after email confirm. */
let pendingSignup = null;

async function register(name, email, password) {
  if (useDemo()) {
    const user = { name, email, id: 'demo_' + Date.now() };
    localStorage.setItem('walkeeg_token', 'demo_token_' + Date.now());
    localStorage.setItem('walkeeg_user', JSON.stringify(user));
    state.user = user;
    return { user, needsConfirmation: false };
  }
  try {
    await WalkEEGAuth.register(name, email, password);
  } catch (err) {
    // Account already exists but not confirmed — send them to verify UI.
    if (/UsernameExistsException|already exists|exists/i.test(err.message || '')) {
      pendingSignup = { name, email, password };
      return { user: null, needsConfirmation: true, email, alreadyRegistered: true };
    }
    throw err;
  }
  // Production path: ALWAYS show email verification (never auto-login after SignUp).
  pendingSignup = { name, email, password };
  return { user: null, needsConfirmation: true, email };
}

async function confirmEmail(email, code) {
  await WalkEEGAuth.confirmSignUp(email, code);
  const password = pendingSignup?.password || $('#loginPassword')?.value;
  if (!password) {
    pendingSignup = null;
    throw new Error('Account verified. Please sign in with your password.');
  }
  const user = await WalkEEGAuth.login(email, password);
  state.user = user;
  pendingSignup = null;
  return user;
}

function logout() {
  if (!useDemo()) WalkEEGAuth.logout();
  localStorage.removeItem('walkeeg_token');
  localStorage.removeItem('walkeeg_user');
  state.user = null;
  state.signals = [];
  pendingSignup = null;
  $('#authPage').style.display = 'flex';
  $('#appLayout').style.display = 'none';
  showAuthForm('login');
}

// ===== Auth Form =====
function showAuthForm(form) {
  $('#loginForm').style.display = form === 'login' ? 'block' : 'none';
  $('#registerForm').style.display = form === 'register' ? 'block' : 'none';
  $('#confirmForm').style.display = form === 'confirm' ? 'block' : 'none';
  if (form === 'confirm' && pendingSignup?.email) {
    $('#confirmEmailLabel').textContent = pendingSignup.email;
  }
}

function goToConfirm(email) {
  pendingSignup = pendingSignup || { email };
  if (email) pendingSignup.email = email;
  showAuthForm('confirm');
  window.location.hash = 'confirm';
}

// ===== Dashboard =====
async function loadDashboard() {
  const signals = await fetchSignals();
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
    ? new Date(signals[signals.length - 1].createdAt).toLocaleDateString()
    : '—';

  renderRecentSignals(signals);
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

  try {
    if (useDemo()) {
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
    } else {
      const cfg = window.WALKEEG_CONFIG;
      const idToken = WalkEEGAuth.getIdToken();
      const { identityId, credentials } = await WalkEEGAuth.getCredentials(idToken);
      const date = new Date().toISOString().slice(0, 10);
      const safeName = name.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 40);
      const fileName = `${date}_${safeName}.csv`;
      const s3Key = `${identityId}/signals/${fileName}`;

      ptext.textContent = 'Uploading to S3...';
      await window.WalkEEGS3.uploadFile(
        credentials,
        cfg.region,
        cfg.dataBucket,
        s3Key,
        file,
        (pct) => {
          fill.style.width = pct + '%';
          ppercent.textContent = pct + '%';
        },
      );

      ptext.textContent = 'Saving metadata...';
      fill.style.width = '100%';
      ppercent.textContent = '100%';

      let channels = '8';
      let sampleRate = '2000 Hz';
      let duration = '—';
      try {
        const text = await file.text();
        const parsed = parseWalkEegCsv(text, 2000);
        channels = String(parsed.channels.length);
        sampleRate = `${parsed.sampleRateHz} Hz`;
        const n = parsed.times.length;
        const dur = n > 1
          ? parsed.times[n - 1] - parsed.times[0]
          : n / parsed.sampleRateHz;
        duration = `${dur.toFixed(1)}s`;
      } catch (_) { /* non-WalkEEG CSV: keep defaults */ }

      await API.post('/signals', {
        name,
        description: desc,
        s3Key,
        identityId,
        fileName,
        fileSize: file.size,
        channels,
        sampleRate,
        duration,
        status: 'uploaded',
      });
    }

    toast('Signal uploaded successfully!', 'success');
    setTimeout(() => navigate('signals'), 1000);
  } catch (err) {
    toast(err.message || 'Upload failed.', 'error');
  }

  progress.classList.remove('active');
  fill.style.width = '0';
  btn.disabled = false;
  btnText.textContent = 'Upload Signal';
}

// ===== Signals List =====
async function fetchSignals() {
  if (useDemo()) return getDemoSignals();
  if (state.signals.length) return state.signals;
  const data = await API.get('/signals');
  state.signals = data.signals || [];
  return state.signals;
}

async function loadSignals() {
  const signals = await fetchSignals();
  renderSignalsTable(signals);
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
/** @type {{ times: number[], channels: number[][], sampleRateHz: number } | null} */
let loadedEeg = null;
let selectedChannel = 0;

async function loadSignalView(signalId) {
  let signal;
  if (useDemo()) {
    signal = getDemoSignals().find(s => s.id === signalId);
  } else {
    signal = await API.get(`/signals/${signalId}`);
  }
  if (!signal) { navigate('signals'); return; }

  state.currentView = signal;
  loadedEeg = null;
  selectedChannel = 0;

  $('#viewSignalName').textContent = signal.name;
  $('#viewSignalMeta').textContent = `Uploaded ${new Date(signal.createdAt).toLocaleString()} · ${formatBytes(signal.fileSize || 0)}`;

  const duration = signal.duration || '—';
  const channels = signal.channels || '8';
  const sampleRate = signal.sampleRate || '2000 Hz';
  const fileSize = formatBytes(signal.fileSize || 0);

  $('#signalDuration').textContent = duration;
  $('#signalChannels').textContent = channels;
  $('#signalSampleRate').textContent = sampleRate;
  $('#signalFileSize').textContent = fileSize;

  const statusEl = $('#signalLoadStatus');
  statusEl.textContent = 'Loading recording data…';

  try {
    if (useDemo()) {
      loadedEeg = buildDemoEegTrace(parseSampleRateHz(sampleRate) || 256);
      statusEl.textContent = 'Demo waveform (synthetic).';
    } else {
      const csvText = await fetchSignalCsv(signal);
      loadedEeg = parseWalkEegCsv(csvText, parseSampleRateHz(sampleRate) || 2000);
      const n = loadedEeg.times.length;
      const dur = n > 1 ? loadedEeg.times[n - 1] - loadedEeg.times[0] : n / loadedEeg.sampleRateHz;
      $('#signalDuration').textContent = `${dur.toFixed(1)}s`;
      $('#signalChannels').textContent = String(loadedEeg.channels.length);
      $('#signalSampleRate').textContent = `${loadedEeg.sampleRateHz} Hz`;
      statusEl.textContent = `Loaded ${n.toLocaleString()} samples · ${loadedEeg.channels.length} channels (real CSV).`;
    }
    populateChannelSelect(loadedEeg.channels.length);
    renderSignalChart();
    renderFFTChart();
  } catch (err) {
    console.error(err);
    statusEl.textContent = `Could not load CSV for plotting: ${err.message || err}. Charts show placeholder.`;
    loadedEeg = null;
    populateChannelSelect(8);
    renderSignalChart();
    renderFFTChart();
  }

  $('#downloadSignalBtn').onclick = async () => {
    if (useDemo()) {
      downloadDemoCSV(signal);
    } else if (signal.downloadUrl) {
      window.open(signal.downloadUrl, '_blank');
    }
  };

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

async function fetchSignalCsv(signal) {
  const urls = [];
  if (Array.isArray(signal.segmentUrls) && signal.segmentUrls.length) {
    const sorted = [...signal.segmentUrls].sort(
      (a, b) => (a.partIndex ?? 0) - (b.partIndex ?? 0),
    );
    for (const seg of sorted) {
      if (seg.downloadUrl) urls.push(seg.downloadUrl);
    }
  }
  if (!urls.length && signal.downloadUrl) urls.push(signal.downloadUrl);
  if (!urls.length) throw new Error('No download URL for this signal');

  const parts = [];
  for (let i = 0; i < urls.length; i++) {
    const res = await fetch(urls[i]);
    if (!res.ok) throw new Error(`Failed to fetch CSV segment (${res.status})`);
    let text = await res.text();
    if (i > 0) {
      // Drop repeated header lines when stitching multi-part recordings.
      const nl = text.indexOf('\n');
      if (nl >= 0 && /time/i.test(text.slice(0, nl))) text = text.slice(nl + 1);
    }
    parts.push(text);
  }
  return parts.join('\n');
}

function parseSampleRateHz(sampleRate) {
  if (typeof sampleRate === 'number') return sampleRate;
  const m = String(sampleRate || '').match(/([\d.]+)/);
  return m ? Number(m[1]) : null;
}

/** Parse WalkEEG CSV: Time(s),Ch1,...,Ch8 */
function parseWalkEegCsv(text, fallbackSampleRateHz) {
  const lines = text.split(/\r?\n/).filter((l) => l.trim().length);
  if (lines.length < 2) throw new Error('CSV has no data rows');

  let start = 0;
  if (/time/i.test(lines[0]) || /ch\d/i.test(lines[0])) start = 1;

  const times = [];
  const channelCols = [];
  let numChannels = 0;

  for (let i = start; i < lines.length; i++) {
    const cols = lines[i].split(',');
    if (cols.length < 2) continue;
    const t = Number(cols[0]);
    if (!Number.isFinite(t)) continue;
    if (!numChannels) {
      numChannels = cols.length - 1;
      for (let c = 0; c < numChannels; c++) channelCols.push([]);
    }
    times.push(t);
    for (let c = 0; c < numChannels; c++) {
      channelCols[c].push(Number(cols[c + 1]) || 0);
    }
  }

  if (!times.length) throw new Error('No numeric samples in CSV');

  let sampleRateHz = fallbackSampleRateHz;
  if (times.length > 1) {
    const dt = (times[times.length - 1] - times[0]) / (times.length - 1);
    if (dt > 0) sampleRateHz = Math.round(1 / dt);
  }

  return { times, channels: channelCols, sampleRateHz };
}

function buildDemoEegTrace(sampleRateHz) {
  const n = sampleRateHz * 10;
  const times = [];
  const ch = [];
  for (let i = 0; i < n; i++) times.push(i / sampleRateHz);
  for (let c = 0; c < 8; c++) {
    const series = [];
    for (let i = 0; i < n; i++) {
      const alpha = Math.sin(i * ((2 * Math.PI * 10) / sampleRateHz) + c) * 30;
      const noise = (Math.random() - 0.5) * 12;
      series.push(alpha + noise);
    }
    ch.push(series);
  }
  return { times, channels: ch, sampleRateHz };
}

function populateChannelSelect(n) {
  const sel = $('#channelSelect');
  if (!sel) return;
  sel.innerHTML = '';
  for (let i = 0; i < n; i++) {
    const opt = document.createElement('option');
    opt.value = String(i);
    opt.textContent = `Ch${i + 1}`;
    sel.appendChild(opt);
  }
  sel.value = String(Math.min(selectedChannel, n - 1));
  sel.onchange = () => {
    selectedChannel = Number(sel.value) || 0;
    renderSignalChart();
    renderFFTChart();
  };
}

/** Downsample for Chart.js performance (keep first/last). */
function downsampleSeries(times, values, maxPoints) {
  const n = values.length;
  if (n <= maxPoints) {
    return {
      labels: times.map((t) => t.toFixed(3)),
      data: values.slice(),
    };
  }
  const step = n / maxPoints;
  const labels = [];
  const data = [];
  for (let i = 0; i < maxPoints; i++) {
    const idx = Math.min(n - 1, Math.floor(i * step));
    labels.push(times[idx].toFixed(3));
    data.push(values[idx]);
  }
  return { labels, data };
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

  let labels;
  let data;
  let yTitle = 'Amplitude';

  if (loadedEeg) {
    const ch = Math.min(selectedChannel, loadedEeg.channels.length - 1);
    const series = loadedEeg.channels[ch];
    const ds = downsampleSeries(loadedEeg.times, series, 4000);
    labels = ds.labels;
    data = ds.data;
    yTitle = 'Amplitude (raw / µV)';
  } else {
    const points = 1000;
    labels = Array.from({ length: points }, (_, i) => (i / points * 10).toFixed(1));
    data = generateEEGSignal(points);
    yTitle = 'Amplitude (µV)';
  }

  signalChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels,
      datasets: [{
        label: `Channel ${selectedChannel + 1}`,
        data,
        borderColor: '#22c55e',
        backgroundColor: 'rgba(34, 197, 94, 0.05)',
        borderWidth: 1.2,
        pointRadius: 0,
        tension: 0,
        fill: false,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 200 },
      plugins: {
        legend: { display: false },
        tooltip: { enabled: true, mode: 'index', intersect: false },
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
          title: { display: true, text: yTitle, color: '#64748b', font: { size: 11 } },
        },
      },
      interaction: { mode: 'nearest', axis: 'x', intersect: false },
    }
  });

  $('#zoomInBtn').onclick = () => {
    if (signalChart) {
      const min = signalChart.scales.x.min ?? 0;
      const max = signalChart.scales.x.max ?? labels.length - 1;
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

/** Relative band power from a channel window (naive DFT magnitude). */
function computeBandPowers(samples, sampleRateHz) {
  const bands = [
    { name: 'Delta', lo: 1, hi: 4 },
    { name: 'Theta', lo: 4, hi: 8 },
    { name: 'Alpha', lo: 8, hi: 13 },
    { name: 'Beta', lo: 13, hi: 30 },
    { name: 'Gamma', lo: 30, hi: 50 },
  ];
  const n = Math.min(samples.length, 4096);
  if (n < 64) return bands.map(() => 0.2);

  // Mean-center window
  let mean = 0;
  for (let i = 0; i < n; i++) mean += samples[i];
  mean /= n;

  const powers = bands.map(() => 0);
  // Coarse frequency scan (enough for band ratios)
  for (let k = 1; k < n / 2; k++) {
    const freq = (k * sampleRateHz) / n;
    if (freq < 1 || freq > 50) continue;
    let re = 0;
    let im = 0;
    for (let t = 0; t < n; t++) {
      const x = samples[t] - mean;
      const ang = (2 * Math.PI * k * t) / n;
      re += x * Math.cos(ang);
      im -= x * Math.sin(ang);
    }
    const p = (re * re + im * im) / (n * n);
    for (let b = 0; b < bands.length; b++) {
      if (freq >= bands[b].lo && freq < bands[b].hi) powers[b] += p;
    }
  }
  const total = powers.reduce((a, b) => a + b, 0) || 1;
  return powers.map((p) => p / total);
}

function renderFFTChart() {
  const canvas = $('#fftChart');
  if (fftChart) fftChart.destroy();

  const ctx = canvas.getContext('2d');
  const bands = ['Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'];
  const freqs = ['1-4 Hz', '4-8 Hz', '8-13 Hz', '13-30 Hz', '30-50 Hz'];

  let values;
  if (loadedEeg) {
    const ch = Math.min(selectedChannel, loadedEeg.channels.length - 1);
    const series = loadedEeg.channels[ch];
    // Use a mid-recording window for a more stable spectrum.
    const win = Math.min(series.length, loadedEeg.sampleRateHz * 4);
    const start = Math.max(0, Math.floor((series.length - win) / 2));
    values = computeBandPowers(series.slice(start, start + win), loadedEeg.sampleRateHz);
  } else {
    values = bands.map(() => Math.random() * 0.8 + 0.2);
  }

  const maxVal = Math.max(...values, 0.01);

  fftChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: bands.map((b, i) => `${b}\n${freqs[i]}`),
      datasets: [{
        label: 'Relative Power',
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
      animation: { duration: 400 },
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
          max: Math.min(1, maxVal * 1.25),
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
window.deleteSignal = async function(id) {
  if (useDemo()) {
    let signals = getDemoSignals();
    signals = signals.filter(s => s.id !== id);
    localStorage.setItem('walkeeg_demo_signals', JSON.stringify(signals));
    state.signals = signals;
  } else {
    await API.delete(`/signals/${id}`);
    state.signals = state.signals.filter(s => s.id !== id);
  }
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

  const authPages = ['login', 'register', 'confirm'];
  if (!isAuthenticated() && !authPages.includes(hash)) {
    window.location.hash = 'login';
    return;
  }

  if (!isAuthenticated()) {
    if (hash === 'confirm') showAuthForm('confirm');
    else if (hash === 'register') showAuthForm('register');
    else showAuthForm('login');
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
  // Make it obvious if the site fell back to local demo auth (no Cognito).
  if (useDemo()) {
    console.warn('[WalkEEG] DEMO MODE — Cognito config missing. Registration will not send email codes.');
    ['#loginForm .subtitle', '#registerForm .subtitle'].forEach((sel) => {
      const el = $(sel);
      if (el) {
        el.textContent = 'Demo mode (cloud not configured). Sign-in is local only — no email code.';
        el.style.color = '#f59e0b';
      }
    });
  } else {
    console.info('[WalkEEG] Cognito mode active — registration requires email verification.');
  }

  // Auth form handlers
  $('#loginFormElement').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = $('#loginEmail').value;
    const password = $('#loginPassword').value;
    const errorEl = $('#loginError');
    errorEl.classList.remove('visible');
    try {
      await login(email, password);
      updateUserUI();
      window.location.hash = 'dashboard';
      toast('Welcome back!', 'success');
    } catch (err) {
      if (!useDemo() && WalkEEGAuth.isUserNotConfirmedError(err)) {
        pendingSignup = { email, password };
        goToConfirm(email);
        toast('Please enter the verification code sent to your email.', 'info');
        return;
      }
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
    errorEl.classList.remove('visible');
    try {
      const result = await register(name, email, password);
      if (result.needsConfirmation) {
        goToConfirm(result.email);
        if (result.alreadyRegistered) {
          try {
            await WalkEEGAuth.resendConfirmationCode(result.email);
          } catch (_) { /* ignore resend errors */ }
          toast('Account already registered. We resent a verification code.', 'info');
        } else {
          toast('Check your email (and spam) for a verification code.', 'success');
        }
        return;
      }
      updateUserUI();
      window.location.hash = 'dashboard';
      toast('Account created! Welcome to WalkEEG.', 'success');
    } catch (err) {
      errorEl.textContent = err.message || 'Registration failed.';
      errorEl.classList.add('visible');
    }
  });

  $('#confirmFormElement')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = pendingSignup?.email || $('#regEmail')?.value || $('#loginEmail')?.value;
    const code = $('#confirmCode').value;
    const errorEl = $('#confirmError');
    errorEl.classList.remove('visible');
    if (!email) {
      errorEl.textContent = 'Missing email. Please register or sign in again.';
      errorEl.classList.add('visible');
      return;
    }
    try {
      await confirmEmail(email, code);
      updateUserUI();
      window.location.hash = 'dashboard';
      toast('Email verified. Welcome to WalkEEG!', 'success');
    } catch (err) {
      if (/Please sign in/i.test(err.message || '')) {
        toast(err.message, 'info');
        window.location.hash = 'login';
        return;
      }
      errorEl.textContent = err.message || 'Invalid code.';
      errorEl.classList.add('visible');
    }
  });

  $('#resendCode')?.addEventListener('click', async (e) => {
    e.preventDefault();
    const email = pendingSignup?.email;
    if (!email) {
      toast('Missing email. Please register again.', 'error');
      return;
    }
    try {
      await WalkEEGAuth.resendConfirmationCode(email);
      toast('A new code was sent to your email.', 'success');
    } catch (err) {
      toast(err.message || 'Could not resend code.', 'error');
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

  $('#showLoginFromConfirm')?.addEventListener('click', (e) => {
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
  $('#signalSearch')?.addEventListener('input', async (e) => {
    const q = e.target.value.toLowerCase();
    const signals = (await fetchSignals()).filter(s =>
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
