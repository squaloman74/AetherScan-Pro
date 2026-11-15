# ◈ Guida all'Installazione: AetherScan-Pro v2.0

Pacchetti finali pronti per il dispiegamento operativo sul campo.

---

## 📱 1. Installazione Android (.APK)
* **File:** `AetherScan-Pro-v2.0-Metrology.apk` (45.6 MB)
* **Compatibilità:** Android 8.0+ (Oreo, Pie, 10, 11, 12, 13, 14, 15+)
* **Procedura di installazione diretta:**
  1. Trasferisci il file `.apk` sullo smartphone (tramite cavo USB, WhatsApp, Telegram, Google Drive o browser).
  2. Apri il file manager del telefono e tocca l'APK.
  3. Se richiesto dal sistema, autorizza l'opzione **"Installa app sconosciute"** per quell'app/browser.
  4. Conferma l'installazione e avvia AetherScan-Pro.
  5. All'avvio, mantieni il dispositivo fermo per i primi **30 secondi** per consentire al motore Welford di calibrare la baseline ambientale.

---

## 🍏 2. Installazione iOS (.IPA)
* **File:** `AetherScan-Pro-v2.0-Metrology-unsigned.ipa` (8.89 MB)
* **Compatibilità:** iPhone iOS 14.0+ (inclusi iPhone 11, 12, 13, 14, 15, 16 Pro)
* **Metodi di Sideloading consigliati:**
  * **Metodo A (Sideloadly - Consigliato da PC/Mac):**
    1. Scarica e avvia [Sideloadly](https://sideloadly.io/) su PC Windows o Mac.
    2. Collega l'iPhone via cavo USB.
    3. Trascina il file `AetherScan-Pro-v2.0-Metrology-unsigned.ipa` nella finestra di Sideloadly.
    4. Inserisci il tuo Apple ID (gratuito) e clicca **Start**.
    5. Su iPhone, vai in *Impostazioni > Generali > Gestione VPN e dispositivo* e tocca **Autorizza** sul tuo profilo sviluppatore.
  * **Metodo B (AltStore / SideStore):**
    1. Apri AltStore o SideStore su iPhone.
    2. Tocca `+` (Aggiungi app) e seleziona `AetherScan-Pro-v2.0-Metrology-unsigned.ipa`.
  * **Metodo C (TrollStore - Dispositivi con iOS vulnerabile/Jailbreak):**
    1. Condividi l'IPA con l'app TrollStore e premi *Install*.

---

## 🔒 3. Verifica Integrità SHA-256
Prima dell'installazione peritali o indagini ufficiali, puoi verificare l'impronta crittografica con il comando:
```powershell
Get-FileHash .\AetherScan-Pro-v2.0-Metrology.apk -Algorithm SHA256
```
Impronte attese:
* **APK:** `27A89CE60F4697019035971E6BEB244990EC86C0383BA0C260E1DE575A6749C8`
* **IPA:** `5C309F2B35104E66080713B29EC9445EF9CC574378F656C6F44691969A42E050`
