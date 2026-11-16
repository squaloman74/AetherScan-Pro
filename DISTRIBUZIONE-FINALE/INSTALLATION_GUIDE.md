# AetherScan-Pro v27-beta2.4 (Build 2.0.27+6) — Guida di Installazione

## Panoramica della Release
- **Versione:** `v27-beta2.4`
- **Build:** `2.0.27+6`
- **Novità e Risoluzioni:**
  1. **Motore Audio Sweep Reale su iOS:** Risolto il silenzio su iPhone. Riproduzione reale e continua del fruscio statico radio AM/FM filtrato sull'altoparlante principale (`.defaultToSpeaker`).
  2. **Accelerometro Reale iPhone in m/s²:** Risolta l'assenza di risposta agli urti. Il sensore hardware CoreMotion ora trasmette un flusso continuo in unità metriche standard $m/s^2$ uniformi ad Android.
  3. **Feedback Acustico Urto Fisico:** Ogni colpo o urto sul telaio (`|A_dyn| >= 3.2 m/s²`) genera ora un feedback acustico immediato e la dicitura visiva `URTO RILEVATO` in arancione sulla plancia.
  4. **Aggiornamento Diretto Senza Cavo (OTA):** Dal popup "VERIFICA AGGIORNAMENTI", se è presente una nuova release, compare il tasto **SCARICA ORA** che apre direttamente Safari su iPhone per scaricare l'IPA e installarlo via AltStore / Scarlet / TrollStore senza cavo USB.
  5. **Doppio Trigger Concomitante:** L'allarme acustico forense scatta solo con la coincidenza simultanea di urto fisico e anomalia statistica ($Z \ge 3.5\sigma$).

---

## 1. Installazione Android (.apk)
File: `AetherScan-Pro-v27-beta2.4-Metrology.apk`
- Trasferisci o scarica l'APK sul dispositivo.
- Tocca il file APK per installare/aggiornare.

---

## 2. Installazione iOS Senza Cavo (.ipa)
1. Apri AetherScan-Pro su iPhone.
2. Apri il Drawer laterale e tocca **INFO E AGGIORNAMENTI**.
3. Tocca **VERIFICA AGGIORNAMENTI**.
4. Tocca il tasto verde **SCARICA ORA**: si aprirà Safari con il download diretto dell'IPA.
5. In Safari, tocca il file scaricato > **Condividi** > **AltStore** (o Scarlet / TrollStore) per aggiornare direttamente sul dispositivo senza cavo PC.
