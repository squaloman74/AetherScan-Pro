const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const os = require('os');
const fs = require('fs');

// Risoluzione definitiva dell'errore "cache_util_win.cc: Unable to move the cache: Accesso negato (0x5)"
// Disabilita la cache su disco di Chromium / GPU che causa conflitti di lock su Windows
app.commandLine.appendSwitch('disable-gpu-shader-disk-cache');
app.commandLine.appendSwitch('disable-http-cache');
app.commandLine.appendSwitch('no-sandbox');

// Usa una cartella isolata nei file temporanei dell'utente corrente con timestamp univoco per evitare lock
const uniqueCacheDir = path.join(os.tmpdir(), 'aetherscan_app_data');
if (!fs.existsSync(uniqueCacheDir)) {
  fs.mkdirSync(uniqueCacheDir, { recursive: true });
}
app.setPath('userData', uniqueCacheDir);

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 1024,
    minHeight: 700,
    frame: false,
    transparent: false,
    backgroundColor: '#060b12',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    icon: path.join(__dirname, '..', 'assets', 'icons', 'icon.ico'),
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

// Controlli finestra custom
ipcMain.on('window:minimize', () => mainWindow?.minimize());
ipcMain.on('window:maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow?.maximize();
  }
});
ipcMain.on('window:close', () => mainWindow?.close());
