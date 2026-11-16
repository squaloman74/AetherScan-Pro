# AetherScan-Pro v27-beta2.3 (Build 2.0.27+5) — Guida di Installazione

## Panoramica della Release
- **Versione:** `v27-beta2.3`
- **Build:** `2.0.27+5`
- **Novità Principali:**
  1. **UI Header Compatto & Pulito:** Risolto l'overlap visivo nell'AppBar tra il badge `CAL/UNCAL` e la titolazione dell'app.
  2. **Interfaccia Pulita:** Rimozione di qualsiasi stringa/identificativo personale di repository dalla visualizzazione utente ("Canale Ufficiale: Release Certificata e Sicura").
  3. **Verifica Aggiornamenti Live:** Tasto "VERIFICA AGGIORNAMENTI" integrato che interroga in tempo reale l'endpoint ufficiale e notifica istantaneamente la disponibilità di nuove release.
  4. **Esportazione Forense Certificata:** Esportazione diretta di file fisici su disco `CSV RFC 4180` e `JSON Forense` tramite Share Sheet di sistema, con fallback automatico e sicuro negli appunti del dispositivo.
  5. **Controlli Indipendenti:** Spectral Sweep AM/FM e Metrology Pro partono spenti (STANDBY) e sono attivabili on-demand dall'operatore.

---

## 1. Installazione Android (.apk)
File: `AetherScan-Pro-v27-beta2.3-Metrology.apk`

1. Trasferisci l'APK sul dispositivo (via USB, Drive, Telegram o browser).
2. Se necessario, abilita l'opzione "Installa da origini sconosciute" per il file manager utilizzato.
3. Tocca il file APK e seleziona **Installa** (o **Aggiorna** per sovrascrivere senza perdere configurazioni).
4. All'avvio, concedi il permesso del **Microfono** per l'analisi spettrale FFT ambientale live.

---

## 2. Installazione iOS (.ipa Sideloading)
File: `AetherScan-Pro-v27-beta2.3-Metrology-unsigned.ipa`

### Procedura con Sideloadly / AltStore / Scarlet:
1. Connetti l'iPhone/iPad al computer via cavo Lightning/USB-C.
2. Apri **Sideloadly** o **AltStore**.
3. Trascina il file `AetherScan-Pro-v27-beta2.3-Metrology-unsigned.ipa` nell'applicazione.
4. Inserisci il tuo Apple ID per la firma con certificato sviluppatore gratuito (7 giorni) o profilo enterprise/developer pagato.
5. Clicca su **Start** / **Installa**.
6. Sul dispositivo iOS, vai in:
   * **Impostazioni > Generali > VPN e gestione dispositivo**
   * Tocca il profilo associato al tuo Apple ID e seleziona **Autorizza / Attendibile**.
7. All'apertura, concedi il permesso di accesso al **Microfono**.

---

## 3. Checksum di Sicurezza (SHA-256)
Consulta `SHA256_CHECKSUMS.txt` per verificare l'integrità crittografica di ogni singolo file prima dell'installazione.
