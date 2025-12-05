import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/diagnosis.dart';
import '../../models/disease.dart';
import '../../models/symptom.dart';
import '../../models/rule.dart';
import '../../services/firestore_service.dart';

class HistoryDetailPage extends StatefulWidget {
  final String id; // document id di users/{uid}/diagnoses/{id}
  const HistoryDetailPage({super.key, required this.id});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool loading = true;
  DiagnosisModel? model;
  List<Disease> diseases = [];
  List<Symptom> symptoms = [];
  List<Rule> rules = [];

  Map<String, Symptom> get _symptomMap =>
      {for (final s in symptoms) s.id: s};

  String _diseaseName(String id) {
    final d = diseases.where((e) => e.id == id);
    return d.isEmpty ? id : d.first.name;
  }

  Future<void> _load() async {
    try {
      model = await fs.getDiagnosis(widget.id);
      diseases = await fs.getDiseases();
      symptoms = await fs.getSymptoms();
      rules = await fs.getRules();
    } catch (e) {
      debugPrint('DETAIL LOAD ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat detail: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // === Menemukan aturan paling mendekati berdasarkan jawaban pengguna ===
  Map<String, dynamic>? _nearestRule(Map<String, dynamic> answers) {
    if (rules.isEmpty) return null;

    int bestHit = -1;
    Rule? bestRule;
    List<String> missing = [];

    for (final r in rules) {
      int hit = 0;
      final List<String> notMet = [];
      for (final c in r.conditions) {
        final v = answers[c.symptomId];
        bool ok;
        switch (c.op) {
          case 'present':
            ok = (v == true) || (v is num && v > 0);
            break;
          case '==':
            ok = v == c.value;
            break;
          case '>=':
            ok = (v is num) && v >= (c.value as num);
            break;
          case '<=':
            ok = (v is num) && v <= (c.value as num);
            break;
          case '>':
            ok = (v is num) && v > (c.value as num);
            break;
          case '<':
            ok = (v is num) && v < (c.value as num);
            break;
          default:
            ok = false;
        }
        if (ok) hit++;
        else notMet.add(c.symptomId);
      }
      if (hit > bestHit) {
        bestHit = hit;
        bestRule = r;
        missing = notMet;
      }
    }

    if (bestRule == null) return null;
    return {
      'rule': bestRule,
      'hit': bestHit,
      'total': bestRule.conditions.length,
      'missing': missing,
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Diagnosa')),
        body: const Center(child: Text('Data tidak ditemukan.')),
      );
    }

    final m = model!;
    final dateStr =
        DateFormat('EEE, dd MMM yyyy • HH:mm').format(m.createdAt);
    final topName = _diseaseName(m.topDiseaseId);
    final pct =
        NumberFormat.percentPattern().format(m.score.clamp(0.0, 1.0));

    // Cari rule terdekat (kalau keyakinan < 50%)
    final near = (m.score < 0.5) ? _nearestRule(m.answers) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Diagnosa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== HEADER =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Waktu',
                        style: TextStyle(
                            color: cs.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(dateStr),
                    const SizedBox(height: 12),
                    Text('Kesimpulan',
                        style: TextStyle(
                            color: cs.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      topName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Keyakinan: $pct'),
                  ],
                ),
              ),
            ),
          ),

          // ===== RULE PALING MENDEKATI =====
          if (near != null) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.surfaceVariant.withOpacity(.4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aturan Paling Mendekati',
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        'Kemungkinan paling dekat: ${_diseaseName((near['rule'] as Rule).diseaseId)}'),
                    const SizedBox(height: 4),
                    Text(
                        'Kecocokan ${(near['hit'])}/${(near['total'])} gejala'),
                    const SizedBox(height: 8),
                    if ((near['missing'] as List).isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gejala belum terpenuhi:',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          ...((near['missing'] as List<String>)
                              .map((id) => _symptomMap[id]?.name ?? id)
                              .map((name) => Padding(
                                    padding: const EdgeInsets.only(left: 8, top: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.circle, size: 6),
                                        const SizedBox(width: 6),
                                        Text(name),
                                      ],
                                    ),
                                  ))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],

          // ===== LIST JAWABAN =====
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.rule),
                  title: Text('Jawaban Gejala'),
                ),
                const Divider(height: 1),
                ...m.answers.entries.map((e) {
                  final sym = _symptomMap[e.key];
                  final title = sym?.name ?? e.key;
                  final val = e.value;
                  String trailing;
                  if (val is bool) {
                    trailing = val ? 'Ya' : 'Tidak';
                  } else if (val is num) {
                    trailing = val.toString();
                    if ((sym?.unit ?? '').isNotEmpty) {
                      trailing = '$trailing ${sym!.unit}';
                    }
                  } else {
                    trailing = '$val';
                  }
                  return ListTile(
                    dense: true,
                    title: Text(title),
                    trailing: Text(trailing),
                  );
                }).toList(),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Catatan: hasil merupakan dukungan keputusan, bukan diagnosis medis final.',
            style: TextStyle(color: cs.primary.withOpacity(.7)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
