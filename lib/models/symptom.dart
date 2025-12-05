// lib/models/symptom.dart
enum SymptomKind { boolean, number }

class Symptom {
  final String id;
  final String code;
  final String name;
  final SymptomKind kind;
  final String? unit;
  final String? askText;
  final num? min;
  final num? max;

  Symptom({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    this.unit,
    this.askText,
    this.min,
    this.max,
  });

  /// TAHAN FORMAT LENGKAP & RINGKAS:
  /// - lengkap: {code, name, kind, ...}
  /// - ringkas: {name} saja -> code=id, kind=boolean, askText=pertanyaan default
  factory Symptom.fromJson(Map<String, dynamic> j, String id) {
    final code = (j['code'] as String?) ?? id;
    final name = (j['name'] as String?) ?? id;
    final kindStr = (j['kind'] as String?) ?? 'boolean';
    final kind =
        (kindStr == 'number') ? SymptomKind.number : SymptomKind.boolean;
    final ask = (j['askText'] as String?) ?? _defaultAsk(name);

    return Symptom(
      id: id,
      code: code,
      name: name,
      kind: kind,
      unit: j['unit'] as String?,
      askText: ask,
      min: (j['min'] as num?) ?? (kind == SymptomKind.number ? 0 : null),
      max: (j['max'] as num?) ?? (kind == SymptomKind.number ? 100 : null),
    );
  }

  static String _defaultAsk(String name) {
    // “mual” -> “Apakah mual?”
    final n = name.trim();
    final capital = n.isEmpty ? n : n[0].toUpperCase() + n.substring(1);
    return 'Apakah $capital?';
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'kind': kind.name,
        'unit': unit,
        'askText': askText,
        'min': min,
        'max': max,
      };
}
