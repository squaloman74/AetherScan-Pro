# AetherScan-Pro v27-beta2.5 (Build 2.0.27+7) — Guida di Installazione

## Panoramica della Release
- **Versione:** `v27-beta2.5`
- **Build:** `2.0.27+7`
- **Novità e Risoluzioni:**
  1. **Evoluzione Motore DSP Audio (AM/FM Spectral Sweep Reale e Organico):**
     - **Eliminazione Rumore Piatto:** Abolito qualsiasi loop statico o rumore bianco ripetitivo.
     - **Oscillatore Caotico di Lorenz (RK4):** Sintesi fisica continua basata sul sistema attrattore di Lorenz ($\sigma=10, \rho=28, \beta=8/3$) con Runge-Kutta al 4° ordine campione-per-campione, senza generatori pseudo-casuali (PRNG) né campioni preregistrati.
     - **Modulazione Caotica Eterodina (EMF + Accelerometro):** La deviazione magnetica $\Delta\text{EMF}$ perturba direttamente la divergenza $\rho$ e produce uno shift di frequenza eterodina, mentre le sollecitazioni dell'accelerometro introducono tremolo d'ampiezza non lineare.
     - **Filtraggio Dinamico Passabanda IIR Biquad (Squelch Reale):** Frequenza di taglio ($200 - 3000\text{ Hz}$) e risonanza $Q$ ($0.5 - 8.0$) inseguono in tempo reale l'energia ambientale misurata dai sensori, simulando la sintonizzazione spettrale eterea.
  2. **Accelerometro Reale iPhone in m/s²:** Flusso continuo in unità metriche standard CoreMotion $\text{m/s}^2$ uniforme ad Android.
  3. **Feedback Acustico Urto Fisico:** Ogni colpo o urto sul telaio ($|A_{\text{dyn}}| \ge 3.2\text{ m/s}^2$) genera feedback acustico immediato e indicatore visivo `URTO RILEVATO`.
  4. **Aggiornamento Diretto Senza Cavo (OTA):** Dal popup "VERIFICA AGGIORNAMENTI", se è presente una nuova release, compare il tasto **SCARICA ORA** che apre Safari su iPhone per scaricare l'IPA e installarlo via AltStore / Scarlet / TrollStore senza cavo USB.
  5. **Doppio Trigger Concomitante:** L'allarme acustico forense scatta solo con la coincidenza simultanea di urto fisico e anomalia statistica ($Z \ge 3.5\sigma$).

---

## 1. Installazione Android (.apk)
File: `AetherScan-Pro-v27-beta2.5-Metrology.apk`
- Trasferisci o scarica l'APK sul dispositivo.
- Tocca il file APK per installare/aggiornare.

---

## 2. Installazione iOS Senza Cavo (.ipa)
1. Apri AetherScan-Pro su iPhone.
2. Apri il Drawer laterale e tocca **INFO E AGGIORNAMENTI**.
3. Tocca **VERIFICA AGGIORNAMENTI**.
4. Tocca il tasto verde **SCARICA ORA**: si aprirà Safari con il download diretto dell'IPA.
5. In Safari, tocca il file scaricato > **Condividi** > **AltStore** (o Scarlet / TrollStore / Sideloadly) per aggiornare direttamente sul dispositivo.
