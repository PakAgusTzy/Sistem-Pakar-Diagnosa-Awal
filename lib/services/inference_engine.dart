// lib/services/inference_engine.dart
import '../models/rule.dart';

class InferenceResult {
  /// item: { diseaseId, score, matched, total, ruleId, missing(List<String>) }
  final List<Map<String, dynamic>> ranked;
  InferenceResult(this.ranked);
}

/// Cocokkan satu kondisi terhadap jawaban
bool _match(RuleCondition c, dynamic v) {
  switch (c.op) {
    case 'present':
      return v == true || (v is num && v > 0);
    case '==':
      return v == c.value;
    case '>=':
      return (v is num) && v >= (c.value as num);
    case '<=':
      return (v is num) && v <= (c.value as num);
    case '>':
      return (v is num) && v > (c.value as num);
    case '<':
      return (v is num) && v < (c.value as num);
    default:
      return false;
  }
}

/// Engine soft-scoring:
/// - Skor aturan = (matched / total) * cf
/// - Skor penyakit = MAX skor aturan-aturan miliknya (ambil rule terbaik)
/// - Selalu mengembalikan kandidat terurut menurun skor
InferenceResult runInference({
  required List<Rule> rules,
  required Map<String, dynamic> answers,
}) {
  if (rules.isEmpty) return InferenceResult(const []);

  // pilih rule terbaik per penyakit
  final bestByDisease = <String, Map<String, dynamic>>{}; // diseaseId -> detail

  for (final r in rules) {
    final total = r.conditions.length;
    if (total == 0) continue;

    int matched = 0;
    final missing = <String>[];

    for (final c in r.conditions) {
      final v = answers[c.symptomId];
      // jawaban null (unknown) dianggap belum terpenuhi
      final ok = (v == null) ? false : _match(c, v);
      if (ok) matched++; else missing.add(c.symptomId);
    }

    final ruleScore = (matched / total) * (r.cf);
    final cur = bestByDisease[r.diseaseId];
    if (cur == null || ruleScore > (cur['score'] as double)) {
      bestByDisease[r.diseaseId] = {
        'diseaseId': r.diseaseId,
        'score': ruleScore,           // 0..1
        'matched': matched,
        'total': total,
        'ruleId': r.id,
        'missing': missing,
      };
    }
  }

  // rangking
  final ranked = bestByDisease.values.toList()
    ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

  // jaga-jaga: kalau semua 0, tetap kembalikan urutan apa adanya (tetap ada "yang paling mendekati")
  return InferenceResult(ranked.cast<Map<String, dynamic>>());
}
