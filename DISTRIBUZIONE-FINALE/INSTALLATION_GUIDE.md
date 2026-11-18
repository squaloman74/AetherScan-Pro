# AetherScan-Pro v27-beta2.6 (Build 2.0.27+8) — Guida di Installazione

## Panoramica della Release
- **Versione:** `v27-beta2.6`
- **Build:** `2.0.27+8`
- **Novità e Risoluzioni:**
  1. **Modulo Vocale Custom "Real-Trigger" (Zero-AI, Zero-Random, Zero-Server):**
     - **Attivazione Energetica Reale:** Modulo spento di default. Si attiva ed emette parole unicamente quando i sensori superano le soglie metrologiche ($|Z| \ge 3.0\sigma$, $|\Delta\text{EMF}| \ge 1.5\,\mu\text{T}$) e persistono per almeno $150\text{ ms}$.
     - **Risonanza Lessicale Deterministica:** Nessun campionamento casuale. L'indice del dizionario italiano di 128 termini fisici è calcolato via Spatial Energy Hash delle grandezze reali ($Z$, $\Delta\text{EMF}$, $L_x$, frequenza).
     - **Sintesi Vocale Offline Nativa:** Audio TTS istantaneo e a consumo zero risorse tramite `AVSpeechSynthesizer` (iOS) e `android.speech.tts.TextToSpeech` (Android).
     - **Pillola HUD & Controlli:** Switch nel Drawer e pulsante rapido nell'AppBar per attivazione/disattivazione, con badge visivo `VOCAL ECHO` in verde fosforo.
  2. **Isolamento Totale dei Moduli:** Nessun loop residuo né audio spurio se i moduli (Sweep o Metrology) sono in pausa o standby.
  3. **Motore DSP Caotico di Lorenz (RK4):** AM/FM Sweep organico e non ripetitivo.
  4. **Aggiornamento Diretto Senza Cavo (OTA):** Dal popup "VERIFICA AGGIORNAMENTI", tocca **SCARICA ORA** per scaricare direttamente l'IPA/APK da Safari/browser.

---

## 1. Installazione Android (.apk)
File: `AetherScan-Pro-v27-beta2.6-Metrology.apk`
- Trasferisci o scarica l'APK sul dispositivo Android e aprilo per installare.

---

## 2. Installazione iOS (.ipa)
1. Apri AetherScan-Pro su iPhone.
2. Dal Drawer tocca **INFO E AGGIORNAMENTI** > **VERIFICA AGGIORNAMENTI**.
3. Tocca il tasto verde **SCARICA ORA**: si aprirà Safari con il download diretto dell'IPA.
4. In Safari, tocca il file scaricato > **Condividi** > **AltStore** (o Scarlet / TrollStore / Sideloadly con cavo) per aggiornare direttamente sul dispositivo.
