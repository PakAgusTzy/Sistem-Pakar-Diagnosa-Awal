// lib/services/firestore_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/disease.dart';
import '../models/symptom.dart';
import '../models/rule.dart';
import '../models/diagnosis.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ----------------- Referensi (read + fallback assets) -----------------
  Future<List<Disease>> getDiseases() async {
    try {
      final qs = await _db.collection('diseases').get();
      if (qs.docs.isNotEmpty) {
        return qs.docs.map((d) => Disease.fromJson(d.data(), d.id)).toList();
      }
    } catch (_) {}
    final text = await rootBundle.loadString('assets/seeds/diseases.json');
    final list = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
    return list.map((j) {
      final id = j['id'] as String;
      final data = Map<String, dynamic>.from(j)..remove('id');
      return Disease.fromJson(data, id);
    }).toList();
  }

  Future<List<Symptom>> getSymptoms() async {
    try {
      final qs = await _db.collection('symptoms').orderBy('code', descending: false).get();
      if (qs.docs.isNotEmpty) {
        return qs.docs.map((d) => Symptom.fromJson(d.data(), d.id)).toList();
      }
    } catch (_) {}
    final text = await rootBundle.loadString('assets/seeds/symptoms.json');
    final list = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
    return list.map((j) {
      final id = j['id'] as String;
      final data = Map<String, dynamic>.from(j)..remove('id');
      return Symptom.fromJson(data, id);
    }).toList();
  }

  Future<List<Rule>> getRules() async {
    try {
      final qs = await _db.collection('rules').get();
      if (qs.docs.isNotEmpty) {
        return qs.docs.map((d) => Rule.fromJson(d.data(), d.id)).toList();
      }
    } catch (_) {}
    final text = await rootBundle.loadString('assets/seeds/rules.json');
    final list = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
    return list.map((j) {
      final id = j['id'] as String;
      final data = Map<String, dynamic>.from(j)..remove('id');
      return Rule.fromJson(data, id);
    }).toList();
  }

  // ----------------- Riwayat -----------------
  Future<void> saveDiagnosis(DiagnosisModel m) async {
    final uid = _uid;
    if (uid == null) return;
    final doc = _db.collection('users').doc(uid).collection('diagnoses').doc();
    await doc.set(m.toJson());
  }

  Stream<List<DiagnosisModel>> watchDiagnoses() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    final col = _db
        .collection('users')
        .doc(uid)
        .collection('diagnoses')
        .orderBy('createdAt', descending: true);
    return col.snapshots().map(
          (qs) => qs.docs.map((d) => DiagnosisModel.fromJson(d.data(), d.id)).toList(),
        );
  }

  Future<DiagnosisModel?> getDiagnosis(String id) async {
    final uid = _uid;
    if (uid == null) return null;
    final doc =
        await _db.collection('users').doc(uid).collection('diagnoses').doc(id).get();
    if (!doc.exists) return null;
    return DiagnosisModel.fromJson(doc.data()!, doc.id);
  }

  // ----------------- SEED (dipanggil sekali setelah login) -----------------
  /// Import 3 koleksi referensi dari assets ke Firestore.
  Future<void> seedFromAssets() async {
    Future<void> _import(String asset, String collection) async {
      final text = await rootBundle.loadString(asset);
      final list = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
      final batch = _db.batch();
      for (final item in list) {
        final id = item['id'] as String;
        final data = Map<String, dynamic>.from(item)..remove('id');
        batch.set(_db.collection(collection).doc(id), data, SetOptions(merge: true));
      }
      await batch.commit();
    }

    await _import('assets/seeds/diseases.json', 'diseases');
    await _import('assets/seeds/symptoms.json', 'symptoms');
    await _import('assets/seeds/rules.json', 'rules');
  }

  /// Jalankan seeding hanya jika belum pernah (cek dokumen meta/seed_v1).
  Future<void> seedFromAssetsOnce() async {
    final meta = _db.collection('meta').doc('seed_v1');
    final snap = await meta.get();
    if (snap.exists) return; // sudah pernah seed
    await seedFromAssets();
    await meta.set({'seededAt': FieldValue.serverTimestamp()});
  }
}

// Instance global untuk di-import dari page mana pun
final fs = FirestoreService();
