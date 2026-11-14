# ◈ AetherScan Pro

> Modern Digital Radio Scanner & Spirit Box — Electron Desktop Application

![Version](https://img.shields.io/badge/version-1.0.0-00f0ff)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Mac-333)
![License](https://img.shields.io/badge/license-MIT-green)

## 🔧 Quick Start

```bash
# Install dependencies
npm install

# Launch the app
npm start

# Launch in dev mode (with DevTools)
npm run dev
```

## 📁 Project Structure

```
AetherScan-Pro/
├── src/
│   ├── main.js              # Electron main process
│   ├── preload.js            # Context bridge (IPC)
│   └── renderer/
│       ├── index.html        # Application UI
│       ├── styles.css         # Cyber/tech dark theme
│       └── app.js            # Scanning logic & controls
├── assets/
│   ├── fonts/                # Custom fonts
│   ├── sounds/               # Audio assets
│   └── icons/                # App icons
├── package.json
└── README.md
```

## 🎛️ Features

- **4-Band Scanner**: FM, AM, SW, Digital
- **7-Segment LED Display**: Authentic DSEG7 font with glow effects
- **Real-time Spectrum Visualizer**: Animated frequency spectrum
- **Keyword Detection System**: Configurable keywords trigger alerts
- **Save & Export**: Log detected frequencies, export as CSV
- **Sound Effects**: Web Audio API beeps and alerts
- **Keyboard Shortcuts**: Space/Enter (scan), P (pause), Esc (dismiss)

## ⌨️ Keyboard Shortcuts

| Key       | Action                |
|-----------|-----------------------|
| `Space`   | Start / Stop Scan     |
| `P`       | Pause / Resume        |
| `Esc`     | Dismiss detection popup |

## 📱 Mobile Porting (Phase 2)

The frontend is built with vanilla HTML/CSS/JS, making it portable to:
- **Capacitor** — wrap the web app in a native Android/iOS shell
- **Cordova** — similar approach with plugin ecosystem
- **PWA** — Progressive Web App for browser-based mobile use

## License

MIT
