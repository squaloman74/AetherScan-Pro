# ◈ Guida all'Installazione: AetherScan-Pro v27-beta2.2 (Metrology Suite)

Pacchetti ufficiali compilati per il rilascio e dispiegamento operativo sul campo.
Architettura blindata: controllo manuale dei flussi (AM/FM e Metrology Pro spenti all'avvio, attivabili a comando), dialog informazioni release e verifica aggiornamenti, calibrazione Welford 30s su richiesta, doppio trigger rigoroso (3.5σ + 3.2 m/s²), audio AM/FM Spectral Sweep modulato in tempo reale e salvataggio nativo CSV/JSON con Share Sheet.

---

## 📱 1. Installazione Android (.APK)
* **File:** `AetherScan-Pro-v27-beta2.2-Metrology.apk` (47.3 MB)
* **Compatibilità:** Android 8.0+ (Oreo, Pie, 10, 11, 12, 13, 14, 15+)
* **Procedura di installazione diretta:**
  1. Trasferisci il file `AetherScan-Pro-v27-beta2.2-Metrology.apk` sullo smartphone (tramite cavo USB, WhatsApp, Telegram, Google Drive o browser).
  2. Apri il file manager del telefono e tocca l'APK.
  3. Se richiesto dal sistema, autorizza l'opzione **"Installa app sconosciute"** per quell'app/browser.
  4. Conferma l'installazione e avvia AetherScan-Pro.
  5. **Flussi Spenti di Default:** All'avvio né la radio né il trigger metrologico partono da soli; sei tu ad attivarli con i pulsanti dedicati.
  6. **Info Versione & Aggiornamenti:** Tocca l'icona ℹ️ nella barra in alto o "Verifica Aggiornamenti" nel menu laterale per visualizzare lo stato della versione.
  7. **Condivisione Forense:** Toccando "CSV RFC 4180" o "JSON FORENSE" si apre direttamente il foglio di condivisione nativo di Android.

---

## 🍏 2. Installazione iOS (.IPA)
* **File:** `AetherScan-Pro-v27-beta2.2-Metrology-unsigned.ipa` (8.12 MB)
* **Compatibilità:** iPhone iOS 14.0+ (inclusi iPhone 11, 12, 13, 14, 15, 16 Pro)
* **Metodi di Sideloading consigliati:**
  * **Metodo A (Sideloadly - Consigliato da PC/Mac):**
    1. Scarica e avvia [Sideloadly](https://sideloadly.io/) su PC Windows o Mac.
    2. Collega l'iPhone via cavo USB.
    3. Trascina il file `AetherScan-Pro-v27-beta2.2-Metrology-unsigned.ipa` nella finestra di Sideloadly.
    4. Inserisci il tuo Apple ID (gratuito) e clicca **Start**.
    5. Su iPhone, vai in *Impostazioni > Generali > Gestione VPN e dispositivo* e tocca **Autorizza** sul tuo profilo sviluppatore.
  * **Metodo B (AltStore / SideStore):**
    1. Apri AltStore o SideStore su iPhone.
    2. Tocca `+` (Aggiungi app) e seleziona `AetherScan-Pro-v27-beta2.2-Metrology-unsigned.ipa`.
  * **Metodo C (TrollStore - Dispositivi con iOS vulnerabile/Jailbreak):**
    1. Condividi l'IPA con l'app TrollStore e premi *Install*.

---

## 🔒 3. Verifica Integrità SHA-256
Prima dell'installazione peritale o indagini ufficiali, puoi verificare l'impronta crittografica con il comando PowerShell:
```powershell
Get-FileHash .\AetherScan-Pro-v27-beta2.2-Metrology.apk -Algorithm SHA256
```
Impronte certificate ufficiali v27-beta2.2:
* **APK (Android):** `10A79F1AC7CD984671D64EEE305A1F19A5D04EF9997132E3D04006C6AD1BBCEE`
* **IPA (iOS):** `FF44A523311C61142E84502755F01D8483BA8484E8CCF0BCDD6F0B3022EF535F`
