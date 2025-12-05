// lib/models/rule.dart
class RuleCondition {
  final String symptomId;
  final String op; // 'present'|'=='|'>='|'<='|'>'|'<'
  final dynamic value; // bool/num/null

  RuleCondition({required this.symptomId, required this.op, this.value});

  factory RuleCondition.fromJson(Map<String, dynamic> j) => RuleCondition(
        symptomId: j['symptom'] as String,
        op: (j['op'] as String?) ?? 'present',
        value: j['value'],
      );

  Map<String, dynamic> toJson() => {
        'symptom': symptomId,
        'op': op,
        'value': value,
      };
}

class Rule {
  final String id;
  final String diseaseId;
  final List<RuleCondition> conditions;
  final double cf; // optional, default 1.0
  final String? source;

  Rule({
    required this.id,
    required this.diseaseId,
    required this.conditions,
    required this.cf,
    this.source,
  });

  /// TAHAN DUA FORMAT:
  /// 1) lengkap:
  ///    { "if": [ {"symptom":"G01","op":"present"}, ... ], "cf":0.8 }
  /// 2) ringkas:
  ///    { "if": ["G01","G02",... ] }  -> otomatis jadi op="present", cf=1.0
  factory Rule.fromJson(Map<String, dynamic> j, String id) {
    final diseaseId = j['diseaseId'] as String;

    final raw = j['if'];
    final List<RuleCondition> conds;
    if (raw is List && raw.isNotEmpty) {
      if (raw.first is String) {
        // format ringkas: list of symptomId
        conds = raw.map((e) => RuleCondition(symptomId: e as String, op: 'present')).toList();
      } else {
        // format lengkap: list of objects
        conds = raw.map((e) => RuleCondition.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } else {
      conds = const [];
    }

    final cf = ((j['cf'] as num?) ?? 1.0).toDouble();
    final source = j['source'] as String?;
    return Rule(id: id, diseaseId: diseaseId, conditions: conds, cf: cf, source: source);
  }

  Map<String, dynamic> toJson() => {
        'diseaseId': diseaseId,
        'if': conditions.map((e) => e.toJson()).toList(),
        'cf': cf,
        'source': source,
      };
}
