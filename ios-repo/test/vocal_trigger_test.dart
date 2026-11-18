import 'package:flutter_test/flutter_test.dart';
import 'package:aetherscan_pro/vocal_trigger_engine.dart';
import 'package:aetherscan_pro/metrology_lexicon.dart';
import 'package:aetherscan_pro/investigative_lexicon.dart';
import 'package:aetherscan_pro/names_lexicon.dart';

void main() {
  group('VocalTriggerEngine — Test Multi-Bank e Risonanza Deterministica', () {
    late VocalTriggerEngine engine;

    setUp(() {
      engine = VocalTriggerEngine(
        isEnabled: false, // Spento di default
        currentBank: VocalLexiconBank.metrology,
        zScoreThreshold: 3.0,
        minDeltaEmf: 1.5,
        minPersistenceMs: 150,
        cooldownMs: 7000,
      );
    });

    test('Isolamento Totale: se disabilitato non genera MAI parole anche con forti anomalie', () {
      final now = DateTime.now();
      expect(engine.isEnabled, isFalse);

      final event = engine.evaluate(
        now: now,
        deltaEmf: 15.0,
        zScoreEmf: 5.2,
        dynamicAccel: 2.5,
        lorenzX: 12.3,
        currentFrequency: 104.5,
      );

      expect(event, isNull);
      expect(engine.lastTriggeredEvent, isNull);
    });

    test('Sotto soglia energetica: nessun trigger a riposo', () {
      engine.setEnabled(true);
      final now = DateTime.now();

      final event = engine.evaluate(
        now: now,
        deltaEmf: 0.3,
        zScoreEmf: 0.8,
        dynamicAccel: 0.04,
        lorenzX: 0.5,
        currentFrequency: 98.0,
      );

      expect(event, isNull);
    });

    test('Filtro di Persistenza: non emette prima di 150ms continui', () {
      engine.setEnabled(true);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);

      final e1 = engine.evaluate(
        now: t0,
        deltaEmf: 4.5,
        zScoreEmf: 3.8,
        dynamicAccel: 1.2,
        lorenzX: 5.0,
        currentFrequency: 92.5,
      );
      expect(e1, isNull);

      final t1 = t0.add(const Duration(milliseconds: 100));
      final e2 = engine.evaluate(
        now: t1,
        deltaEmf: 4.8,
        zScoreEmf: 3.9,
        dynamicAccel: 1.2,
        lorenzX: 5.2,
        currentFrequency: 92.5,
      );
      expect(e2, isNull);

      final t2 = t0.add(const Duration(milliseconds: 160));
      final e3 = engine.evaluate(
        now: t2,
        deltaEmf: 5.0,
        zScoreEmf: 4.0,
        dynamicAccel: 1.2,
        lorenzX: 5.5,
        currentFrequency: 92.5,
      );
      expect(e3, isNotNull);
      expect(e3!.word, isNotEmpty);
      expect(MetrologyLexicon.words.contains(e3.word), isTrue);
      expect(e3.bank, equals(VocalLexiconBank.metrology));
    });

    test('Multi-Bank: Bank B (Investigativo) emette vocaboli investigativi dedicati', () {
      engine.setEnabled(true);
      engine.setBank(VocalLexiconBank.investigative);

      final t0 = DateTime(2026, 1, 1, 14, 0, 0);
      final tPersist = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 5.5, zScoreEmf: 3.9, dynamicAccel: 1.0, lorenzX: 7.0, currentFrequency: 95.0);
      final event = engine.evaluate(now: tPersist, deltaEmf: 5.5, zScoreEmf: 3.9, dynamicAccel: 1.0, lorenzX: 7.0, currentFrequency: 95.0);

      expect(event, isNotNull);
      expect(event!.bank, equals(VocalLexiconBank.investigative));
      expect(InvestigativeLexicon.words.contains(event.word), isTrue);
    });

    test('Multi-Bank: Bank C (Anagrafico - Solo Nomi) emette solo nomi di battesimo validati', () {
      engine.setEnabled(true);
      engine.setBank(VocalLexiconBank.names);

      final t0 = DateTime(2026, 1, 1, 16, 0, 0);
      final tPersist = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 6.2, zScoreEmf: 4.1, dynamicAccel: 0.5, lorenzX: 3.2, currentFrequency: 101.2);
      final event = engine.evaluate(now: tPersist, deltaEmf: 6.2, zScoreEmf: 4.1, dynamicAccel: 0.5, lorenzX: 3.2, currentFrequency: 101.2);

      expect(event, isNotNull);
      expect(event!.bank, equals(VocalLexiconBank.names));
      expect(NamesLexicon.words.contains(event.word), isTrue);
      // Garanzia privacy: ogni elemento Ã¨ una singola parola di battesimo
      expect(event.word.contains(' '), isFalse);
    });

    test('Multi-Bank: Rotational Mode seleziona deterministicamente tra i banchi', () {
      engine.setEnabled(true);
      engine.setBank(VocalLexiconBank.rotational);

      final t0 = DateTime(2026, 1, 1, 18, 0, 0);
      final tPersist = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 7.0, zScoreEmf: 4.5, dynamicAccel: 1.5, lorenzX: 4.0, currentFrequency: 90.0);
      final event = engine.evaluate(now: tPersist, deltaEmf: 7.0, zScoreEmf: 4.5, dynamicAccel: 1.5, lorenzX: 4.0, currentFrequency: 90.0);

      expect(event, isNotNull);
      expect(event!.bank != VocalLexiconBank.rotational, isTrue); // risolto in uno dei banchi effettivi
      final allWords = [
        ...MetrologyLexicon.words,
        ...InvestigativeLexicon.words,
        ...NamesLexicon.words,
      ];
      expect(allWords.contains(event.word), isTrue);
    });

    test('Determinismo Assoluto: medesimi sensori generano sempre la stessa parola', () {
      engine.setEnabled(true);
      engine.setBank(VocalLexiconBank.investigative);

      final t0 = DateTime(2026, 1, 1, 20, 0, 0);
      final tPersist = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 8.0, zScoreEmf: 4.8, dynamicAccel: 1.1, lorenzX: 9.0, currentFrequency: 105.0);
      final e1 = engine.evaluate(now: tPersist, deltaEmf: 8.0, zScoreEmf: 4.8, dynamicAccel: 1.1, lorenzX: 9.0, currentFrequency: 105.0);

      final engineB = VocalTriggerEngine(isEnabled: true, currentBank: VocalLexiconBank.investigative);
      engineB.evaluate(now: t0, deltaEmf: 8.0, zScoreEmf: 4.8, dynamicAccel: 1.1, lorenzX: 9.0, currentFrequency: 105.0);
      final e2 = engineB.evaluate(now: tPersist, deltaEmf: 8.0, zScoreEmf: 4.8, dynamicAccel: 1.1, lorenzX: 9.0, currentFrequency: 105.0);

      expect(e1!.word, equals(e2!.word));
      expect(e1.bank, equals(e2.bank));
    });

    test('Cooldown Refrattario: blocca emissioni successive per 7 secondi', () {
      engine.setEnabled(true);
      final t0 = DateTime(2026, 1, 1, 10, 0, 0);
      final tTrigger = t0.add(const Duration(milliseconds: 200));

      engine.evaluate(now: t0, deltaEmf: 5.0, zScoreEmf: 3.5, dynamicAccel: 1.0, lorenzX: 2.0, currentFrequency: 95.0);
      final e1 = engine.evaluate(now: tTrigger, deltaEmf: 5.0, zScoreEmf: 3.5, dynamicAccel: 1.0, lorenzX: 2.0, currentFrequency: 95.0);
      expect(e1, isNotNull);

      final tCooldown = tTrigger.add(const Duration(seconds: 3));
      final e2 = engine.evaluate(now: tCooldown, deltaEmf: 8.0, zScoreEmf: 5.0, dynamicAccel: 2.0, lorenzX: 4.0, currentFrequency: 95.0);
      expect(e2, isNull);

      final tAfter = tTrigger.add(const Duration(milliseconds: 7500));
      final e3 = engine.evaluate(now: tAfter, deltaEmf: 8.0, zScoreEmf: 5.0, dynamicAccel: 2.0, lorenzX: 4.0, currentFrequency: 95.0);
      expect(e3, isNull);

      final tAfterPersist = tAfter.add(const Duration(milliseconds: 160));
      final e4 = engine.evaluate(now: tAfterPersist, deltaEmf: 8.0, zScoreEmf: 5.0, dynamicAccel: 2.0, lorenzX: 4.0, currentFrequency: 95.0);
      expect(e4, isNotNull);
    });
  });
}
