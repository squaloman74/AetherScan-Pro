# AetherScan-Pro v27-beta2.6 (Build 2.0.27+8) — Guida di Installazione

## Panoramica della Release
- **Versione:** `v27-beta2.6`
- **Build:** `2.0.27+8`
- **Novità e Risoluzioni:**
  1. **Modulo Vocale Custom "Real-Trigger" Multi-Bank (Zero-AI, Zero-Random, Zero-Server):**
     - **Separazione Modulare dei Banchi Lessicali:**
       - **Bank A (Metrologico):** 128 termini a matrice fisica/ambientale (`PRESENZA`, `ENERGIA`, `SOGLIA`, `FLUSSO`, `ONDA`, ecc.).
       - **Bank B (Investigativo Classico):** 128 termini mirati per indagini ambientali sul campo (`ASCOLTO`, `CHI`, `DOVE`, `PORTA`, `VOCE`, `LUCE`, ecc.).
       - **Bank C (Anagrafico - Solo Nomi):** 128 soli nomi di battesimo tradizionali italiani, categoricamente privi di cognomi a totale tutela della privacy (`MARCO`, `ANNA`, `LUCA`, `GIULIA`, ecc.).
       - **Modalità Rotational (Multi-Bank Auto):** Rotazione deterministica sui 3 banchi pilotata dall'hash energetico dei sensori.
     - **Selezione Rapida Banco (HUD & Drawer):** Tocco immediato sulla pillola HUD per ciclare tra `METR`, `INV`, `NOMI`, `AUTO` oppure chip dedicati nel menu laterale.
     - **Attivazione Energetica Reale:** Modulo spento di default. Si attiva ed emette parole unicamente quando i sensori superano le soglie metrologiche ($|Z| \ge 3.0\sigma$, $|\Delta\text{EMF}| \ge 1.5\,\mu\text{T}$) e persistono per almeno $150\text{ ms}$.
     - **Risonanza Lessicale Deterministica:** Nessun campionamento casuale. L'accesso al dizionario avviene tramite Spatial Energy Hash a 31-bit sulle grandezze fisiche reali ($Z$, $\Delta\text{EMF}$, $L_x$, frequenza, accelerometro).
     - **Sintesi Vocale Offline Nativa:** Audio TTS istantaneo a zero consumo risorse tramite `AVSpeechSynthesizer` (iOS) e `android.speech.tts.TextToSpeech` (Android).
  2. **Isolamento Totale dei Moduli:** Nessun loop residuo né audio spurio se i moduli (Sweep o Metrology) sono in pausa o standby.
  3. **Motore DSP Caotico di Lorenz (RK4):** AM/FM Sweep organico e non ripetitivo.
  4. **Aggiornamento Diretto Senza Cavo (OTA):** Dal popup "VERIFICA AGGIORNAMENTI", tocca **SCARICA ORA** per scaricare direttamente l'IPA/APK da Safari/browser.

---

## 1. Installazione Android (.apk)
File: `AetherScan-Pro-v27-beta2.6-Metrology.apk`
- Percorso: `D:\AetherScan-Pro\DISTRIBUZIONE-FINALE\AetherScan-Pro-v27-beta2.6-Metrology.apk`
- SHA-256: `24C8258C1324D8D6666BBBEF379AC47DF759064675F883022855E2FC6119AA32`
- Trasferisci o scarica l'APK sul dispositivo Android e aprilo per installare.

---

## 2. Installazione iOS (.ipa)
1. Esegui `git push origin main` dal tuo terminale per avviare la compilazione automatica con Xcode su macOS (GitHub Actions).
2. Appena pronta, puoi installare l'IPA via Sideloadly (con cavo) o tramite AltStore / Safari (senza cavo).
