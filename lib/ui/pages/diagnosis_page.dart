// lib/ui/pages/diagnosis_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/symptom.dart';
import '../../models/rule.dart';
import '../../models/disease.dart';
import '../../models/diagnosis.dart';
import '../../services/firestore_service.dart';
import '../../services/inference_engine.dart';

class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({super.key});
  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  bool loading = true;
  bool running = false;

  List<Symptom> symptoms = [];
  List<Rule> rules = [];
  List<Disease> diseases = [];

  // jawaban: symptomId -> value (bool | num)
  final Map<String, dynamic> answers = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      symptoms = await fs.getSymptoms();
      rules = await fs.getRules();
      diseases = await fs.getDiseases();
      // inisialisasi jawaban default
      for (final s in symptoms) {
        answers[s.id] = (s.kind == SymptomKind.boolean)
            ? false
            : (s.min ?? 0);
      }
    } catch (e) {
      debugPrint('LOAD ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat referensi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _diseaseName(String id) {
    final d = diseases.where((e) => e.id == id);
    return d.isEmpty ? id : d.first.name;
  }

  // Hitung rule terdekat jika tidak ada yang match (untuk explainability)
  Map<String, dynamic>? _nearestRule() {
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
        if (ok) {
          hit++;
        } else {
          notMet.add(c.symptomId);
        }
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

  Future<void> _run() async {
    if (running) return;
    setState(() => running = true);

    try {
      // jalankan engine
      final res = runInference(rules: rules, answers: answers);

      if (res.ranked.isEmpty) {
        // tidak ada aturan terpenuhi → tampilkan near-match
        final near = _nearestRule();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Belum ada kesimpulan'),
            content: near == null
                ? const Text(
                    'Tidak ada aturan yang mendekati. Cek kembali referensi rules.')
                : _NearMatchExplain(
                    diseaseName: _diseaseName((near['rule'] as Rule).diseaseId),
                    hit: near['hit'] as int,
                    total: near['total'] as int,
                    missingNames: (near['missing'] as List<String>)
                        .map((id) =>
                            symptoms.firstWhere(
                                (s) => s.id == id,
                                orElse: () => Symptom(
                                    id: id,
                                    code: id,
                                    name: id,
                                    kind: SymptomKind.boolean))
                            .name)
                        .toList(),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              )
            ],
          ),
        );
        return;
      }

      // simpan hasil teratas ke riwayat
      final top = res.ranked.first;
      final model = DiagnosisModel(
        id: 'tmp',
        createdAt: DateTime.now(),
        topDiseaseId: top['diseaseId'] as String,
        score: top['score'] as double,
        answers: Map<String, dynamic>.from(answers),
        ranked: res.ranked,
      );
      await fs.saveDiagnosis(model);

      if (!mounted) return;
      final pct =
          NumberFormat.percentPattern().format(model.score.clamp(0.0, 1.0));
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hasil Diagnosa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _diseaseName(model.topDiseaseId),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Keyakinan: $pct'),
              const Divider(height: 20),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Peringkat Lainnya:')),
              const SizedBox(height: 6),
              ...res.ranked.skip(1).take(4).map((e) {
                final p = NumberFormat.percentPattern()
                    .format((e['score'] as double).clamp(0, 1));
                return ListTile(
                  dense: true,
                  title: Text(_diseaseName(e['diseaseId'] as String)),
                  trailing: Text(p),
                );
              })
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            )
          ],
        ),
      );
    } catch (e) {
      debugPrint('RUN ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasData = symptoms.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Kuesioner Gejala')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasData)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Referensi gejala kosong. Jalankan seeding atau cek Firestore.',
                  style: TextStyle(color: cs.primary),
                ),
              ),
            ),
          ...symptoms.map((s) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: s.kind == SymptomKind.boolean
                      ? SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.askText ?? s.name),
                          value: (answers[s.id] as bool?) ?? false,
                          onChanged: (v) => setState(() => answers[s.id] = v),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.askText ?? s.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: ((answers[s.id] as num?) ??
                                            (s.min ?? 0))
                                        .toDouble(),
                                    min: (s.min ?? 0).toDouble(),
                                    max: (s.max ?? 100).toDouble(),
                                    divisions: 100,
                                    label:
                                        '${(answers[s.id] as num?)?.toStringAsFixed(0) ?? s.min ?? 0} ${s.unit ?? ''}',
                                    onChanged: (v) =>
                                        setState(() => answers[s.id] = v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${((answers[s.id] as num?) ?? (s.min ?? 0)).toStringAsFixed(0)} ${s.unit ?? ''}',
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              icon: running
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(running ? 'Memproses...' : 'Proses Diagnosa'),
              onPressed: (running || !hasData) ? null : _run,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Catatan: hasil adalah dukungan keputusan, bukan diagnosis medis final.',
            style: TextStyle(color: cs.primary.withOpacity(.7)),
          ),
        ],
      ),
    );
  }
}

class _NearMatchExplain extends StatelessWidget {
  final String diseaseName;
  final int hit;
  final int total;
  final List<String> missingNames;
  const _NearMatchExplain({
    required this.diseaseName,
    required this.hit,
    required this.total,
    required this.missingNames,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aturan paling mendekati: $diseaseName'),
        const SizedBox(height: 6),
        Text('Kecocokan $hit dari $total gejala.'),
        if (missingNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Belum terpenuhi:'),
          const SizedBox(height: 6),
          ...missingNames.map((n) => ListTile(
                dense: true,
                leading: const Icon(Icons.info_outline, size: 18),
                title: Text(n),
              )),
        ],
      ],
    );
  }
}
