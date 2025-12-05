// models/diagnosis.dart
import 'package:cloud_firestore/cloud_firestore.dart';
class DiagnosisModel {
  final String id;
  final DateTime createdAt;
  final String topDiseaseId;
  final double score; // 0..1
  final Map<String, dynamic> answers; // symptomId -> value
  final List<Map<String, dynamic>> ranked; // {diseaseId, score}

  DiagnosisModel({
    required this.id,
    required this.createdAt,
    required this.topDiseaseId,
    required this.score,
    required this.answers,
    required this.ranked,
  });

  factory DiagnosisModel.fromJson(Map<String, dynamic> j, String id) => DiagnosisModel(
    id: id,
    createdAt: (j['createdAt'] as Timestamp).toDate(),
    topDiseaseId: j['topDiseaseId'],
    score: (j['score'] as num).toDouble(),
    answers: Map<String, dynamic>.from(j['answers'] ?? {}),
    ranked: (j['ranked'] as List).map((e) => Map<String, dynamic>.from(e)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'createdAt': Timestamp.fromDate(createdAt),
    'topDiseaseId': topDiseaseId,
    'score': score,
    'answers': answers,
    'ranked': ranked,
  };
}
