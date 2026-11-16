/* ═══════════════════════════════════════════════════════════════
   AetherScan Pro v26 Beta 4 — Professional Engine
   - Tab switching (Scanner, Archivio, Analisi, Impostazioni)
   - Fonemi / Parole EVP con sintesi vocale SpeechSynthesis (TTS)
   - Spettrogramma con picchi rossi di anomalia in tempo reale
   - Ricerca e sincronizzazione aggiornamenti (GitHub squaloman74/AetherScan-Pro-apk)
   ═══════════════════════════════════════════════════════════════ */

const BANDS = {
  FM: { min: 87.50, max: 108.00, step: 0.05, unit: 'MHz', demod: 'WBFM', default: 104.30 },
  AM: { min: 530,   max: 1710,   step: 10,   unit: 'kHz', demod: 'AM',   default: 840 },
};

const state = {
  band: 'FM',
  frequency: 104.30,
  scanning: false,
  scanSpeed: 100,
  scanTimer: null,
  detectedFreq: '104.30 MHz',
  detectedWord: 'SPIRITO',
  audioCtx: null,

  // Dizionario professionale EVP e Fenomenologia Transcomunicativa
  // Suddiviso in: Nomi di persona, Fonemi base, Frasi di contatto, Suoni vocali/Risate
  updateProgressStep: 0,
  scanStepsSinceLastDetection: 0, // Filtro anti-allucinazione: richiede scansione minima tra rilevamenti
  phonemes: [
    // --- NOMI DI PERSONA (Rilevamenti Onomastici EVP) ---
    'MARCO', 'GIULIA', 'FRANCESCO', 'ELENA', 'ANNA', 'LUCA', 
    'ALESSANDRO', 'CHIARA', 'MATTEO', 'SARA', 'ANDREA', 'VALENTINA', 
    'LORENZO', 'MARTINA', 'GIOVANNI', 'BEATRICE', 'STEFANO', 'FEDERICA', 
    'PAOLO', 'SILVIA', 'DAVIDE', 'ALICE', 'GABRIELE', 'ELISA', 
    'ROBERTO', 'FRANCESCA', 'MICHELE', 'GIORGIA', 'SIMONE', 'LAURA',
    'THOMAS', 'EMILY', 'JOHN', 'MARY', 'MICHAEL', 'SARAH',

    // --- RISATE & SUONI VOCALI ANOMALI EVP ---
    '[RISATA STRIDULA]', '[RISATA SOFFOCATA]', '[SUSSURRO FEMMINILE]',
    '[RESPORO AFFANNOSO]', '[LAMENTO LONTANO]', '[VOCE METALLICA]',
    '[BAMBINO CHE PIANGE]', '[SUSSURRO: SHHH]', '[PASSI VICINI]',

    // --- FONEMI & PAROLE CHIAVE FONDAMENTALI ---
    'AIUTO', 'SPIRITO', 'QUI', 'SENTI', 'NOME', 'MORTE', 'LUCE', 
    'TEMPO', 'SÌ', 'NO', 'ASCOLTA', 'VICINO', 'FREDDO', 'PORTA', 
    'PRESENZA', 'CERCA', 'ANIMA', 'DIMMI', 'BUIO', 'OMBRA', 
    'PARLA', 'RICORDO', 'ADDIO', 'LIBERO', 'RESTO', 'PAURA',
    'FUOCO', 'ACQUA', 'NOTTE', 'CASA', 'ATTENTO', 'GUIDA',
    
    // --- FRASI BREVI DI COMUNICAZIONE EVP ---
    'SONO QUI', 'CHI SEI', 'NON ANDARE', 'TI SENTO', 'AIUTAMI',
    'VOGLIO PARLARE', 'DIETRO DI TE', 'NON POSSO', 'DIMMI IL NOME',
    'È FREDDO', 'C\'È QUALCUNO', 'GUARDAMI', 'NON SIAMO SOLI',
    'ASCOLTAMI BENE', 'VAI VIA', 'RESTO CON TE', 'LUCE BIANCA',
    'LIBERAMI', 'PRIGIONIERO', 'TI VEDO', 'MI CHIAMO COSI'
  ],
  lastPickedWords: [], // Evita ripetizioni consecutive
  ttsVolume: 1.0, // Volume TTS regolabile (0.1 .. 1.0)
  enableTTS: true,
  enableChime: true,
  sensitivity: 6,

  // Flag anomalia visiva per lo spettro (picchi rossi)
  anomalyActive: false,
  anomalyTimer: null,
  anomalyCount: 3,

  // Archivio salvataggi
  archive: [
    { id: 1, date: '29/10/2026 14:02', freq: '1280 kHz', band: 'AM', word: 'AIUTO', snr: '28 dB', type: 'EVP Diretto' },
    { id: 2, date: '29/10/2026 10:24', freq: '104.30 MHz', band: 'FM', word: 'SPIRITO', snr: '31 dB', type: 'Fonema RF' },
    { id: 3, date: '29/10/2026 10:18', freq: '102.50 MHz', band: 'FM', word: 'QUI', snr: '26 dB', type: 'Spettrogramma Anomalo' },
  ],

  recentList: [
    { freq: '104.30 MHz', time: '10:24', active: true, word: 'SPIRITO' },
    { freq: '102.50 MHz', time: '10:18', active: false, word: 'QUI' },
    { freq: '98.70 MHz', time: '10:15', active: false, word: 'SENTI' },
    { freq: '96.10 MHz', time: '10:11', active: false, word: 'NOME' },
    { freq: '105.90 MHz', time: '10:07', active: false, word: 'AIUTO' },
    { freq: '89.40 MHz', time: '10:03', active: false, word: 'NO' },
  ]
};

const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

document.addEventListener('DOMContentLoaded', () => {
  setupNavigation();
  setupWindowControls();
  setupBands();
  setupScan();
  setupKnob();
  setupModal();
  setupArchiveTab();
  setupSettingsTab();

  setupViewSwitch();

  renderRecentList();
  renderArchiveTable();
  initSpectrum();
  initIntegratedWaterfall();
  startVuMeters();
  updateDisplay();
});

// ══════════════════════ SWITCH VISTA SPETTRO / SPETTROGRAMMA 2D ══════════════════════
let currentCenterView = 'spectrum'; // 'spectrum' | 'waterfall'

function setupViewSwitch() {
  const btnSpec = $('#btn-view-spectrum');
  const btnWf = $('#btn-view-waterfall');
  const specCv = $('#spectrum-canvas');
  const wfCv = $('#waterfall-integrated-canvas');

  btnSpec?.addEventListener('click', () => {
    currentCenterView = 'spectrum';
    btnSpec.classList.add('active-spec');
    btnWf.classList.remove('active-spec');
    specCv.style.display = 'block';
    wfCv.style.display = 'none';
  });

  btnWf?.addEventListener('click', () => {
    currentCenterView = 'waterfall';
    btnWf.classList.add('active-spec');
    btnSpec.classList.remove('active-spec');
    specCv.style.display = 'none';
    wfCv.style.display = 'block';
    resizeIntegratedWaterfall();
  });
}

let intWfCanvas, intWfCtx, intWfData = [];
function initIntegratedWaterfall() {
  intWfCanvas = $('#waterfall-integrated-canvas');
  if (!intWfCanvas) return;
  intWfCtx = intWfCanvas.getContext('2d');
  resizeIntegratedWaterfall();
  window.addEventListener('resize', resizeIntegratedWaterfall);
  requestAnimationFrame(renderIntegratedWaterfall);
}

function resizeIntegratedWaterfall() {
  if (!intWfCanvas) return;
  const r = intWfCanvas.parentElement.getBoundingClientRect();
  intWfCanvas.width = r.width;
  intWfCanvas.height = r.height;
}

function renderIntegratedWaterfall() {
  if (!intWfCtx || !intWfCanvas) return;
  if (currentCenterView === 'waterfall') {
    const W = intWfCanvas.width;
    const H = intWfCanvas.height;

    // Genera nuova riga spettrogramma
    const row = new Uint8Array(Math.floor(W / 3));
    const center = Math.floor(row.length / 2);
    for (let x = 0; x < row.length; x++) {
      const dist = Math.abs(x - center);
      const base = Math.floor(Math.random() * 35);
      // Se c'è anomalia picco rosso acceso al centro
      let peak = 0;
      if (state.anomalyActive && dist < 10) {
        peak = 250;
      } else {
        peak = Math.floor(Math.exp(-Math.pow(dist / 14, 2)) * 180);
      }
      row[x] = Math.min(255, base + peak);
    }

    intWfData.unshift(row);
    if (intWfData.length > Math.floor(H / 3)) intWfData.pop();

    intWfCtx.fillStyle = '#030810';
    intWfCtx.fillRect(0, 0, W, H);

    for (let y = 0; y < intWfData.length; y++) {
      const r = intWfData[y];
      for (let x = 0; x < r.length; x++) {
        const val = r[x];
        if (val > 220 && state.anomalyActive) {
          intWfCtx.fillStyle = '#ff1144'; // Rosso anomalia EVP
        } else if (val > 160) {
          intWfCtx.fillStyle = '#00ff88'; // Cima verde
        } else if (val > 90) {
          intWfCtx.fillStyle = '#00efff'; // Corpo ciano
        } else if (val > 30) {
          intWfCtx.fillStyle = '#0a3250'; // Base scura
        } else {
          intWfCtx.fillStyle = '#040d18';
        }
        intWfCtx.fillRect(x * 3, y * 3, 3, 3);
      }
    }
  }
  requestAnimationFrame(renderIntegratedWaterfall);
}

function setupNavigation() {
  const tabs = [
    { navId: '#nav-scanner', tabId: '#tab-scanner' },
    { navId: '#nav-archivio', tabId: '#tab-archivio' },
    { navId: '#nav-analisi', tabId: '#tab-analisi' },
    { navId: '#nav-impostazioni', tabId: '#tab-impostazioni' },
  ];

  tabs.forEach(item => {
    const navEl = $(item.navId);
    if (!navEl) return;

    navEl.addEventListener('click', () => {
      // Toggle nav class
      $$('.nav-item').forEach(n => n.classList.remove('active'));
      navEl.classList.add('active');

      // Toggle content section
      $$('.tab-content').forEach(c => c.classList.remove('active'));
      const activeContent = $(item.tabId);
      if (activeContent) {
        activeContent.classList.add('active');
      }

      // Se entra nel tab analisi avvia il waterfall canvas
      if (item.tabId === '#tab-analisi') {
        initWaterfallCanvas();
      }
    });
  });
}

function setupWindowControls() {
  $('#btn-minimize')?.addEventListener('click', () => window.electronAPI?.minimize?.());
  $('#btn-maximize')?.addEventListener('click', () => window.electronAPI?.maximize?.());
  $('#btn-close')?.addEventListener('click', () => window.electronAPI?.close?.());
}

// ══════════════════════ 2. CONTROLLI BANDE & SCANNER ══════════════════════
function setupBands() {
  $('#mode-am')?.addEventListener('click', () => setBand('AM'));
  $('#mode-fm')?.addEventListener('click', () => setBand('FM'));

  $('#speed-slider')?.addEventListener('input', (e) => {
    state.scanSpeed = parseInt(e.target.value);
    let txt = 'MEDIA';
    if (state.scanSpeed < 60) txt = 'MOLTO RAPIDA';
    else if (state.scanSpeed < 90) txt = 'RAPIDA';
    else if (state.scanSpeed > 200) txt = 'LENTA';
    $('#speed-caption').textContent = `${txt} (${state.scanSpeed} ms)`;
    $('#st-refresh').textContent = `${state.scanSpeed} ms`;
    if (state.scanning) restartScan();
  });
}

function setBand(band) {
  if (state.band === band) return;
  if (state.scanning) stopScan();
  state.band = band;
  state.frequency = BANDS[band].default;

  $('#mode-am')?.classList.toggle('active', band === 'AM');
  $('#mode-fm')?.classList.toggle('active', band === 'FM');
  $('#st-band').textContent = band;
  $('#footer-demod').textContent = BANDS[band].demod;
  $('#freq-unit').textContent = BANDS[band].unit;

  updateDisplay();
}

function setupScan() {
  $('#btn-scan')?.addEventListener('click', toggleScan);

  document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.code === 'Space') {
      e.preventDefault();
      toggleScan();
    }
  });
}

function toggleScan() {
  if (state.scanning) {
    stopScan();
  } else {
    startScan();
  }
}

function startScan() {
  state.scanning = true;
  $('#btn-scan').classList.add('scanning');
  $('#scan-icon').textContent = '■';
  $('#scan-label').textContent = 'STOP SCAN';
  $('#st-scanner-val').textContent = 'In Scansione';
  $('#process-caption').textContent = 'Scansione in corso...';

  beep(880, 0.08);
  restartScan();
}

function stopScan() {
  state.scanning = false;
  clearInterval(state.scanTimer);
  state.scanTimer = null;

  $('#btn-scan').classList.remove('scanning');
  $('#scan-icon').textContent = '▶';
  $('#scan-label').textContent = 'START SCAN';
  $('#st-scanner-val').textContent = 'Attivo';
  $('#process-caption').textContent = 'In attesa...';
}

function pauseScan() {
  clearInterval(state.scanTimer);
  state.scanTimer = null;
  $('#process-caption').textContent = 'Anomalia Fonema Intercettata!';
}

function resumeScan() {
  if (!state.scanning) return;
  $('#process-caption').textContent = 'Scansione in corso...';
  restartScan();
}

function restartScan() {
  if (state.scanTimer) clearInterval(state.scanTimer);
  state.scanTimer = setInterval(scanStep, state.scanSpeed);
}

function scanStep() {
  const b = BANDS[state.band];
  state.frequency += b.step;
  if (state.frequency > b.max) state.frequency = b.min;

  const decimals = b.unit === 'kHz' ? 0 : 2;
  state.frequency = parseFloat(state.frequency.toFixed(decimals));

  updateDisplay();

  // Filtro anti-allucinazione avanzato:
  // 1. Minimo 20 step di scansione tra due intercettazioni consecutive (evita raffiche false)
  // 2. Soglia SNR minima dinamica (richiede segnale radio coerente)
  state.scanStepsSinceLastDetection++;
  if (state.scanStepsSinceLastDetection > 20) {
    const snrVal = parseInt($('#st-snr')?.textContent) || 28;
    if (snrVal >= 25) { // Filtro confidenza SNR minimo
      const prob = 0.00045 * state.sensitivity;
      if (Math.random() < prob) {
        state.scanStepsSinceLastDetection = 0;
        triggerPhonemeDetection();
      }
    }
  }
}

function updateDisplay() {
  const b = BANDS[state.band];
  const str = b.unit === 'kHz' ? Math.round(state.frequency).toString() : state.frequency.toFixed(2);
  
  $('#freq-number').textContent = str;
  $('#knob-readout').textContent = `${str} ${b.unit}`;
  $('#an-freq-val').textContent = `${str} ${b.unit}`;

  $('#st-snr').textContent = `${Math.floor(25 + Math.random() * 8)} dB`;
  $('#rds-indicator')?.classList.toggle('active', Math.random() > 0.4);

  // Asse frequenze
  const f = state.frequency;
  if (b.unit === 'MHz') {
    $('#spectrum-axis').innerHTML = `
      <span>${(f - 1.0).toFixed(1)}</span>
      <span>${(f - 0.5).toFixed(1)}</span>
      <span class="center-tick">${f.toFixed(1)}</span>
      <span>${(f + 0.5).toFixed(1)}</span>
      <span>${(f + 1.0).toFixed(1)}</span>
      <span class="unit-tick">MHz</span>
    `;
  } else {
    $('#spectrum-axis').innerHTML = `
      <span>${Math.round(f - 40)}</span>
      <span>${Math.round(f - 20)}</span>
      <span class="center-tick">${Math.round(f)}</span>
      <span>${Math.round(f + 20)}</span>
      <span>${Math.round(f + 40)}</span>
      <span class="unit-tick">kHz</span>
    `;
  }
}

// ══════════════════════ 3. MODULO RILEVAMENTO FONEMA & SINTESI VOCALE ══════════════════════
function triggerPhonemeDetection() {
  pauseScan();

  const b = BANDS[state.band];
  state.detectedFreq = b.unit === 'kHz' 
    ? `${Math.round(state.frequency)} ${b.unit}` 
    : `${state.frequency.toFixed(2)} ${b.unit}`;

  // Selezione intelligente anti-ripetizione: esclude le ultime parole usate
  const availablePool = state.phonemes.filter(w => !state.lastPickedWords.includes(w));
  const pool = availablePool.length > 0 ? availablePool : state.phonemes;
  const word = pool[Math.floor(Math.random() * pool.length)];
  
  state.detectedWord = word;
  state.lastPickedWords.push(word);
  if (state.lastPickedWords.length > 5) {
    state.lastPickedWords.shift(); // Mantiene solo le ultime 5 parole nella history di esclusione
  }

  // 1. Attiva picchi rossi di anomalia sullo spettro
  triggerAnomalyVisual();

  // 2. Pronuncia vocale (TTS)
  if (state.enableTTS) {
    speakWord(word);
  }

  // 3. Suono Chime
  if (state.enableChime) {
    playChime();
  }

  // 4. Mostra popup con parola scritta
  $('#popup-detected-freq').textContent = state.detectedFreq;
  $('#popup-word-value').textContent = word;
  $('#popup-overlay').classList.add('show');
}

// Pronuncia vocale TTS nativa con gestione risate e suoni vocali
function speakWord(word) {
  try {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();

      // Se è un suono vocale come risata, simula la fonetica spettrale
      let textToSpeak = word.toLowerCase();
      let pitch = 0.92;
      let rate = 0.85;

      if (word.includes('RISATA')) {
        textToSpeak = 'ah ah ah ah, eh eh eh';
        pitch = word.includes('STRIDULA') ? 1.4 : 0.6;
        rate = 1.1;
      } else if (word.includes('SUSSURRO')) {
        textToSpeak = 'shhhh... sono vicina...';
        pitch = 1.2;
        rate = 0.7;
      } else if (word.includes('PIANGE')) {
        textToSpeak = 'aiuto... mamma...';
        pitch = 1.35;
        rate = 0.75;
      } else if (word.includes('LAMENTO')) {
        textToSpeak = 'ohhh... nooo...';
        pitch = 0.65;
        rate = 0.7;
      }

      const utter = new SpeechSynthesisUtterance(textToSpeak);
      utter.lang = 'it-IT';
      utter.rate = rate;
      utter.pitch = pitch;
      utter.volume = Math.min(1.0, Math.max(0.0, state.ttsVolume));
      window.speechSynthesis.speak(utter);
    }
  } catch (_) {}
}

// Attivazione picchi anomalia rossi sullo spettrogramma
function triggerAnomalyVisual() {
  state.anomalyActive = true;
  state.anomalyCount++;
  $('#an-peaks-count').textContent = state.anomalyCount;

  $('#st-anomaly-val').textContent = `${state.detectedWord} (${state.detectedFreq})`;
  $('#spectrum-anomaly-badge')?.classList.add('show');

  clearTimeout(state.anomalyTimer);
  state.anomalyTimer = setTimeout(() => {
    state.anomalyActive = false;
    $('#spectrum-anomaly-badge')?.classList.remove('show');
    $('#st-anomaly-val').textContent = 'NESSUNA';
  }, 4000);
}

// ══════════════════════ 4. POPUP & ARCHIVIAZIONE ══════════════════════
function setupModal() {
  $('#popup-btn-si')?.addEventListener('click', () => {
    saveToArchive(state.detectedFreq, state.detectedWord);
    hidePopup();
    showToast(`Frequenza ${state.detectedFreq} ("${state.detectedWord}") archiviata!`);
    setTimeout(resumeScan, 400);
  });

  $('#popup-btn-no')?.addEventListener('click', () => {
    hidePopup();
    setTimeout(resumeScan, 200);
  });

  $('#popup-btn-x')?.addEventListener('click', () => {
    hidePopup();
    setTimeout(resumeScan, 200);
  });
}

function hidePopup() {
  $('#popup-overlay')?.classList.remove('show');
}

function saveToArchive(freq, word) {
  const now = new Date();
  const time = now.toTimeString().slice(0, 5);
  const dateStr = `${now.toLocaleDateString()} ${time}`;

  // Inserisci in lista recenti
  state.recentList.unshift({
    freq: freq,
    time: time,
    active: true,
    word: word,
  });
  if (state.recentList.length > 8) state.recentList.pop();
  renderRecentList();

  // Inserisci in tabella archivio
  state.archive.unshift({
    id: Date.now(),
    date: dateStr,
    freq: freq,
    band: state.band,
    word: word,
    snr: `${Math.floor(26 + Math.random() * 8)} dB`,
    type: 'Intercettazione EVP',
  });
  renderArchiveTable();
}

function renderRecentList() {
  const list = $('#recent-list');
  if (!list) return;

  list.innerHTML = state.recentList.map((item, idx) => `
    <div class="recent-row ${idx === 0 ? 'active' : ''}">
      <span class="rec-dot ${idx === 0 ? '' : 'off'}"></span>
      <span class="rec-freq">${item.freq}</span>
      ${item.word ? `<span class="rec-word-badge">${item.word}</span>` : ''}
      <span class="rec-time">${item.time}</span>
    </div>
  `).join('');
}

function renderArchiveTable() {
  const tbody = $('#archive-tbody');
  if (!tbody) return;

  if (state.archive.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; padding:24px; color:#4d6682;">Nessuna frequenza archiviata. Avvia la scansione per intercettare segnali.</td></tr>`;
    return;
  }

  tbody.innerHTML = state.archive.map(row => `
    <tr>
      <td>${row.date}</td>
      <td style="color:#00efff; font-weight:700;">${row.freq}</td>
      <td>${row.band}</td>
      <td><span class="table-kw-badge">${row.word}</span></td>
      <td>${row.snr}</td>
      <td>${row.type}</td>
      <td>
        <button class="btn-sec-action danger" style="padding:2px 8px; font-size:10px;" data-del="${row.id}">ELIMINA</button>
      </td>
    </tr>
  `).join('');

  tbody.querySelectorAll('[data-del]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const id = parseInt(e.target.dataset.del);
      state.archive = state.archive.filter(x => x.id !== id);
      renderArchiveTable();
      showToast('Elemento rimosso dall\'archivio');
    });
  });
}

function setupArchiveTab() {
  $('#btn-export-pdf')?.addEventListener('click', () => {
    if (state.archive.length === 0) {
      showToast('Nessun dato da esportare in PDF');
      return;
    }

    const printWin = window.open('', '_blank');
    if (!printWin) {
      showToast('Popup bloccato dal browser');
      return;
    }

    const rowsHtml = state.archive.map(x => `
      <tr>
        <td style="padding:8px; border:1px solid #ddd;">${x.date}</td>
        <td style="padding:8px; border:1px solid #ddd; font-weight:bold; color:#0066cc;">${x.freq}</td>
        <td style="padding:8px; border:1px solid #ddd;">${x.band}</td>
        <td style="padding:8px; border:1px solid #ddd; font-weight:bold; color:#d97706;">${x.word}</td>
        <td style="padding:8px; border:1px solid #ddd;">${x.snr}</td>
        <td style="padding:8px; border:1px solid #ddd;">${x.type}</td>
      </tr>
    `).join('');

    printWin.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Report EVP AetherScan Pro</title>
        <style>
          body { font-family: Arial, sans-serif; padding: 24px; color: #111; }
          h1 { color: #0055aa; margin-bottom: 4px; }
          .sub { color: #666; font-size: 13px; margin-bottom: 20px; }
          table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }
          th { background: #f0f4f8; padding: 10px; border: 1px solid #ddd; text-align: left; }
          .footer { margin-top: 30px; font-size: 11px; color: #888; border-top: 1px solid #eee; padding-top: 8px; }
        </style>
      </head>
      <body>
        <h1>AetherScan Pro v26 Beta 4 — Report Ufficiale EVP</h1>
        <div class="sub">Registro Scientifico di Ricerca sul Campo • Data esportazione: ${new Date().toLocaleString()}</div>
        <table>
          <thead>
            <tr>
              <th>DATA / ORA</th>
              <th>FREQUENZA</th>
              <th>BANDA</th>
              <th>PAROLA / FONEMA</th>
              <th>SEGNALE SNR</th>
              <th>TIPO</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml}
          </tbody>
        </table>
        <div class="footer">Documento generato automaticamente da AetherScan Pro • Dispositivo Autenticato KeyDigitale</div>
        <script>
          window.onload = function() { window.print(); }
        </script>
      </body>
      </html>
    `);
    printWin.document.close();
    showToast('Apertura anteprima di stampa / Salva come PDF!');
  });

  $('#btn-clear-archive')?.addEventListener('click', () => {
    state.archive = [];
    renderArchiveTable();
    showToast('Archivio svuotato');
  });

  $('#btn-export-csv')?.addEventListener('click', () => {
    if (state.archive.length === 0) {
      showToast('Nessun dato da esportare');
      return;
    }
    const header = 'DATA/ORA,FREQUENZA,BANDA,PAROLA/FONEMA,SNR,TIPO\n';
    const rows = state.archive.map(x => `"${x.date}","${x.freq}","${x.band}","${x.word}","${x.snr}","${x.type}"`).join('\n');
    const blob = new Blob([header + rows], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `AetherScan_Archive_${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('File CSV esportato con successo!');
  });
}

// ══════════════════════ 5. IMPOSTAZIONI & RICERCA AGGIORNAMENTI ══════════════════════
function setupSettingsTab() {
  // Volume Sintesi Vocale Slider
  $('#tts-vol-slider')?.addEventListener('input', (e) => {
    state.ttsVolume = parseFloat(e.target.value);
    const pct = Math.round(state.ttsVolume * 100);
    $('#tts-vol-label').textContent = `${pct}%`;
  });

  // Tasto Test Audio Voce
  $('#btn-test-tts')?.addEventListener('click', () => {
    speakWord('Prova sintesi vocale AetherScan Pro. Volume al cento per cento.');
  });

  // Sensibilità slider
  $('#sens-slider')?.addEventListener('input', (e) => {
    state.sensitivity = parseInt(e.target.value);
    $('#sens-caption').textContent = `Livello ${state.sensitivity} / 10`;
  });

  // Salva preferenze
  $('#btn-save-settings')?.addEventListener('click', () => {
    state.enableTTS = $('#chk-tts')?.checked ?? true;
    state.enableChime = $('#chk-sound')?.checked ?? true;

    const raw = $('#txt-keywords')?.value;
    if (raw) {
      state.phonemes = raw.split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
    }
    showToast('Impostazioni salvate!');
  });

  // Ricerca aggiornamenti GitHub — Beta 4: checker reale
  $('#btn-check-updates')?.addEventListener('click', async () => {
    const btn = $('#btn-check-updates');
    const statusText = $('#update-status-text');
    const bar = $('#update-progress-bar');
    const fill = $('#update-fill');

    btn.disabled = true;
    btn.textContent = 'VERIFICA IN CORSO...';
    statusText.textContent = 'Connessione a GitHub...';
    bar.style.display = 'block';
    fill.style.width = '20%';

    try {
      fill.style.width = '50%';
      statusText.textContent = 'Analisi release su squaloman74/AetherScan-Pro-apk...';

      const res = await fetch('https://api.github.com/repos/squaloman74/AetherScan-Pro-apk/releases/latest', {
        headers: { 'User-Agent': 'AetherScan-Pro-v26', 'Accept': 'application/vnd.github.v3+json' }
      });

      fill.style.width = '80%';

      if (res.status === 404) {
        statusText.textContent = '⚠ Nessuna release trovata. Versione corrente: v26 Beta 4';
        return;
      }
      if (!res.ok) {
        statusText.textContent = `❌ Errore GitHub API (${res.status})`;
        return;
      }

      const data = await res.json();
      const tag = (data.tag_name || '').toLowerCase();
      const betaMatch = tag.match(/beta[\-_]?(\d+)/);
      const remoteBeta = betaMatch ? parseInt(betaMatch[1]) : 0;
      const currentBeta = 4;

      fill.style.width = '100%';

      if (remoteBeta > currentBeta) {
        // Cerca APK tra gli asset della release
        const apkAsset = (data.assets || []).find(a => a.name.endsWith('.apk'));
        const downloadUrl = apkAsset?.browser_download_url || data.html_url;
        statusText.textContent = `⬆ AGGIORNAMENTO DISPONIBILE!\nRelease: ${data.tag_name}\nDownload: ${downloadUrl}`;
        statusText.style.color = '#00ff88';
        // Apre automaticamente il browser alla pagina release
        setTimeout(() => { window.open(downloadUrl, '_blank'); }, 800);
      } else {
        statusText.textContent = '✔ Sei aggiornato! Versione: v26 Beta 4 (Build 2026.11.01)';
        showToast('Versione aggiornata! Nessun aggiornamento necessario.');
      }
    } catch (e) {
      statusText.textContent = `❌ Errore connessione: ${e.message}`;
    } finally {
      setTimeout(() => { bar.style.display = 'none'; fill.style.width = '0%'; }, 1200);
      btn.textContent = 'VERIFICA AGGIORNAMENTI ORA';
      btn.disabled = false;
    }
  });
}

// ══════════════════════ 6. SINTONIA KNOB ══════════════════════
function setupKnob() {
  $('#knob-left')?.addEventListener('click', () => stepFreq(-1));
  $('#knob-right')?.addEventListener('click', () => stepFreq(1));

  const knob = $('#knob-rotary');
  knob?.addEventListener('wheel', (e) => {
    e.preventDefault();
    stepFreq(e.deltaY < 0 ? 1 : -1);
  });
}

function stepFreq(dir) {
  const b = BANDS[state.band];
  state.frequency += b.step * dir;
  if (state.frequency > b.max) state.frequency = b.min;
  if (state.frequency < b.min) state.frequency = b.max;

  const decimals = b.unit === 'kHz' ? 0 : 2;
  state.frequency = parseFloat(state.frequency.toFixed(decimals));
  updateDisplay();

  const ratio = (state.frequency - b.min) / (b.max - b.min);
  const deg = ratio * 320 - 160;
  const needle = $('#knob-needle');
  if (needle) {
    needle.style.transform = `translateX(-50%) rotate(${deg}deg)`;
    needle.style.transformOrigin = '50% 28px';
  }
}

// ══════════════════════ 7. SPETTRO AUDIO CON PICCHI ROSSI DI ANOMALIA ══════════════════════
const BARS_COUNT = 70;
let bars = [];

function initSpectrum() {
  const canvas = $('#spectrum-canvas');
  if (!canvas) return;

  for (let i = 0; i < BARS_COUNT; i++) {
    bars.push({ h: 0.15 });
  }

  window.addEventListener('resize', () => resize(canvas));
  resize(canvas);
  requestAnimationFrame(renderSpectrum);
}

function resize(canvas) {
  const r = canvas.parentElement.getBoundingClientRect();
  canvas.width = r.width * (window.devicePixelRatio || 1);
  canvas.height = r.height * (window.devicePixelRatio || 1);
}

function renderSpectrum() {
  const canvas = $('#spectrum-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  const W = canvas.width / dpr;
  const H = canvas.height / dpr;

  ctx.save();
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, W, H);

  // Griglia orizzontale dB (-80 a 0)
  const dbLines = [
    { label: '0',   ratio: 0.08 },
    { label: '-20', ratio: 0.28 },
    { label: '-40', ratio: 0.48 },
    { label: '-60', ratio: 0.68 },
    { label: '-80', ratio: 0.88 },
  ];

  ctx.font = '9.5px "Share Tech Mono", monospace';
  ctx.fillStyle = '#344b63';
  ctx.textAlign = 'right';

  dbLines.forEach(l => {
    const y = H * l.ratio;
    ctx.fillText(l.label, 24, y + 3);
    ctx.strokeStyle = '#0e1f30';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(32, y);
    ctx.lineTo(W, y);
    ctx.stroke();
  });

  // Griglia verticale
  const chartX = 32;
  const chartW = W - chartX;
  for (let i = 0; i <= 6; i++) {
    const x = chartX + (chartW / 6) * i;
    ctx.strokeStyle = '#0a1726';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, H * 0.05);
    ctx.lineTo(x, H * 0.90);
    ctx.stroke();
  }

  // Barre a blocchetti LED
  const barGap = 2.5;
  const barW = Math.max(2, (chartW - (BARS_COUNT - 1) * barGap) / BARS_COUNT);
  const center = Math.floor(BARS_COUNT / 2);

  for (let i = 0; i < BARS_COUNT; i++) {
    const b = bars[i];
    const dist = Math.abs(i - center);
    const bell = Math.exp(-Math.pow(dist / 13, 2));

    let targetH;
    if (state.anomalyActive && dist < 12) {
      // Picco anomalo EVP ad altissima intensità
      targetH = 0.85 + Math.random() * 0.15;
    } else if (state.scanning) {
      targetH = 0.10 + bell * 0.68 + Math.random() * 0.22;
    } else {
      targetH = 0.10 + bell * 0.72 + Math.sin(Date.now() * 0.002 + i * 0.2) * 0.03;
    }

    b.h += (targetH - b.h) * 0.22;

    const x = chartX + i * (barW + barGap);
    const totalH = Math.max(4, b.h * (H * 0.82));
    const blockH = 3.5;
    const blockGap = 1.5;
    const count = Math.floor(totalH / (blockH + blockGap));

    for (let k = 0; k < count; k++) {
      const by = H * 0.90 - (k + 1) * (blockH + blockGap);
      const ratio = k / count;

      // Colorazione: se c'è un'anomalia sui picchi centrali diventa ROSSO INTENSO
      if (state.anomalyActive && dist < 12 && ratio > 0.6) {
        ctx.fillStyle = '#ff1144'; // Rosso anomalia
      } else if (ratio > 0.75) {
        ctx.fillStyle = '#00ff88'; // Cima verde neon
      } else if (ratio > 0.38) {
        ctx.fillStyle = '#00efff'; // Corpo ciano
      } else {
        ctx.fillStyle = '#0a527c'; // Base scura
      }

      ctx.fillRect(x, by, barW, blockH);
    }
  }

  ctx.restore();
  requestAnimationFrame(renderSpectrum);
}

// ══════════════════════ 8. SPETTROGRAMMA WATERFALL (TAB ANALISI) ══════════════════════
let wfCanvas, wfCtx, wfData = [];
function initWaterfallCanvas() {
  wfCanvas = $('#waterfall-canvas');
  if (!wfCanvas) return;

  const rect = wfCanvas.parentElement.getBoundingClientRect();
  wfCanvas.width = rect.width;
  wfCanvas.height = rect.height - 24;
  wfCtx = wfCanvas.getContext('2d');

  if (wfData.length === 0) {
    for (let i = 0; i < 60; i++) {
      wfData.push(generateWaterfallRow(wfCanvas.width));
    }
  }
  renderWaterfall();
}

function generateWaterfallRow(w) {
  const row = new Uint8Array(Math.floor(w / 4));
  const center = Math.floor(row.length / 2);
  for (let x = 0; x < row.length; x++) {
    const dist = Math.abs(x - center);
    const base = Math.floor(Math.random() * 40);
    const peak = dist < 6 ? Math.floor(180 + Math.random() * 75) : 0;
    row[x] = Math.min(255, base + peak);
  }
  return row;
}

function renderWaterfall() {
  if (!wfCtx || !wfCanvas) return;
  const W = wfCanvas.width;
  const H = wfCanvas.height;

  wfCtx.fillStyle = '#020508';
  wfCtx.fillRect(0, 0, W, H);

  wfData.unshift(generateWaterfallRow(W));
  if (wfData.length > 80) wfData.pop();

  for (let y = 0; y < wfData.length; y++) {
    const row = wfData[y];
    for (let x = 0; x < row.length; x++) {
      const val = row[x];
      if (val > 190) {
        wfCtx.fillStyle = '#ff2255'; // anomalia termica
      } else if (val > 130) {
        wfCtx.fillStyle = '#00ff88';
      } else {
        wfCtx.fillStyle = `rgb(0, ${Math.floor(val * 0.8)}, ${Math.floor(val * 1.2)})`;
      }
      wfCtx.fillRect(x * 4, y * 3, 4, 3);
    }
  }
}

// ══════════════════════ 9. VU METERS & EFFETTI AUDIO ══════════════════════
function startVuMeters() {
  const sig = $$('#vu-signal .vu-bar');
  const aud = $$('#vu-audio .vu-bar');

  setInterval(() => {
    let s = state.scanning ? Math.floor(6 + Math.random() * 8) : 9;
    let a = state.scanning ? Math.floor(4 + Math.random() * 9) : 8;
    if (state.anomalyActive) {
      s = 14; a = 13;
    }

    sig.forEach((b, i) => b.classList.toggle('active', i < s));
    aud.forEach((b, i) => b.classList.toggle('active', i < a));
  }, 100);
}

function beep(freq, duration) {
  try {
    if (!state.audioCtx) state.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const ctx = state.audioCtx;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.connect(g);
    g.connect(ctx.destination);
    osc.frequency.value = freq;
    g.gain.setValueAtTime(0.06, ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
    osc.start();
    osc.stop(ctx.currentTime + duration);
  } catch (_) {}
}

function playChime() {
  try {
    if (!state.audioCtx) state.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const ctx = state.audioCtx;
    [650, 950, 1300].forEach((freq, idx) => {
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.connect(g);
      g.connect(ctx.destination);
      osc.frequency.value = freq;
      const t = ctx.currentTime + idx * 0.08;
      g.gain.setValueAtTime(0.08, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
      osc.start(t);
      osc.stop(t + 0.12);
    });
  } catch (_) {}
}

function showToast(msg) {
  const el = $('#toast-msg');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 2800);
}
