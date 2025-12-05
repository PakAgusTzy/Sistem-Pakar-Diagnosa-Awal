import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/symptom.dart';
import '../../models/rule.dart';
import '../../models/disease.dart';
import '../../models/diagnosis.dart';
import '../../services/firestore_service.dart';
import '../../services/inference_engine.dart';

class DiagnosisAdaptivePage extends StatefulWidget {
  const DiagnosisAdaptivePage({super.key});
  @override
  State<DiagnosisAdaptivePage> createState() => _DiagnosisAdaptivePageState();
}

class _DiagnosisAdaptivePageState extends State<DiagnosisAdaptivePage> {
  bool loading = true;
  bool running = false;

  List<Symptom> symptoms = [];
  List<Rule> rules = [];
  List<Disease> diseases = [];
  Map<String, dynamic> answers = {};
  Set<String> asked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      symptoms = await fs.getSymptoms();
      rules = await fs.getRules();
      diseases = await fs.getDiseases();
      for (final s in symptoms) {
        answers[s.id] = (s.kind == SymptomKind.boolean) ? null : (s.min ?? 0);
      }
    } finally { setState(() => loading = false); }
  }

  String _name(String diseaseId) => diseases.firstWhere(
    (d) => d.id == diseaseId, orElse: () => Disease(id: diseaseId, name: diseaseId)
  ).name;

  Symptom? _sym(String id) => symptoms.firstWhere((s) => s.id == id, orElse: () => Symptom(
    id: id, code: id, name: id, kind: SymptomKind.boolean
  ));

  // ====== ADAPTIVE SELECTOR ======
  List<Rule> get remaining {
    // aturan yang belum terbantahkan oleh jawaban pasti
    return rules.where((r) {
      for (final c in r.conditions) {
        final v = answers[c.symptomId];
        if (v == null) continue; // unknown -> jangan gugurkan
        if (!_match(c, v)) return false;
      }
      return true;
    }).toList();
  }

  bool _match(RuleCondition c, dynamic v) {
    switch (c.op) {
      case 'present': return v == true || (v is num && v > 0);
      case '==': return v == c.value;
      case '>=': return v is num && v >= (c.value as num);
      case '<=': return v is num && v <= (c.value as num);
      case '>':  return v is num && v >  (c.value as num);
      case '<':  return v is num && v <  (c.value as num);
      default: return false;
    }
  }

  String? _nextQuestion() {
    // jika ada rule yang semua kondisinya sudah terpenuhi -> stop
    for (final r in remaining) {
      if (r.conditions.every((c) => answers[c.symptomId] != null && _match(c, answers[c.symptomId]))) {
        return null;
      }
    }
    // ranking gejala berdasarkan kemunculan di remaining, exclude yang sudah ditanya
    final freq = <String, int>{};
    for (final r in remaining) {
      for (final c in r.conditions) {
        if (answers[c.symptomId] != null) continue;
        freq[c.symptomId] = (freq[c.symptomId] ?? 0) + 1;
      }
    }
    if (freq.isEmpty) return null;
    final sorted = freq.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    for (final e in sorted) {
      if (!asked.contains(e.key)) return e.key;
    }
    return sorted.first.key;
  }

  double _progress() {
    final totalToAsk = symptoms.where((s) => s.kind == SymptomKind.boolean).length;
    final answered = answers.values.where((v) => v != null).length;
    if (totalToAsk == 0) return 0;
    return (answered / totalToAsk).clamp(0, 1).toDouble();
  }

  Future<void> _finish() async {
  setState(()=>running=true);
  try {
    final res = runInference(rules: rules, answers: answers);

    if (res.ranked.isEmpty) {
      // sangat jarang (rules kosong). Tampilkan info aman.
      if (!mounted) return;
      showDialog(context: context, builder: (_)=> const AlertDialog(
        title: Text('Referensi belum siap'),
        content: Text('Rules kosong. Pastikan seeding berhasil.'),
      ));
      return;
    }

    // Ambil kandidat teratas SELALU (tidak ada "no result")
    final top = res.ranked.first;
    final topDiseaseId = top['diseaseId'] as String;
    final score = (top['score'] as num).toDouble().clamp(0, 1);
    final matched = top['matched'] as int;
    final total = top['total'] as int;
    final missing = (top['missing'] as List).cast<String>();

    // simpan ke riwayat
    final model = DiagnosisModel(
      id: 'tmp',
      createdAt: DateTime.now(),
      topDiseaseId: topDiseaseId,
      score: score.toDouble(),
      answers: Map<String,dynamic>.from(answers),
      ranked: res.ranked,
    );
    await fs.saveDiagnosis(model);

    if (!mounted) return;
    final pct = NumberFormat.percentPattern().format(score);
    showDialog(
      context: context,
      builder: (_)=> AlertDialog(
        title: const Text('Hasil Diagnosa'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_name(topDiseaseId), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Kecocokan: $matched dari $total gejala'),
          Text('Keyakinan: $pct'),
          if (missing.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Belum terpenuhi:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...missing.map((id){
              final s = _sym(id);
              return ListTile(
                dense: true,
                leading: const Icon(Icons.info_outline, size: 18),
                title: Text(s?.name ?? id),
              );
            }),
          ]
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Tutup'))
        ],
      ),
    );
  } finally {
    if(mounted) setState(()=>running=false);
  }
}


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nextId = _nextQuestion(); // null -> boleh finish
    final nextSym = nextId == null ? null : _sym(nextId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Adaptif'),
        actions: [
          IconButton(
            tooltip: 'Lihat semua gejala',
            icon: const Icon(Icons.view_list_rounded),
            onPressed: ()=>Navigator.pushReplacementNamed(context, '/checklist'),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _progress()),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: nextSym == null
              ? _FinishCard(onFinish: running?null:_finish, running: running)
              : _QuestionCard(
                  key: ValueKey(nextSym.id),
                  symptom: nextSym,
                  value: answers[nextSym.id],
                  onAnswer: (v){
                    setState(() {
                      asked.add(nextSym.id);
                      answers[nextSym.id] = v;
                    });
                  },
                ),
        ),
      ),
      floatingActionButton: (nextSym==null)
          ? null
          : FloatingActionButton.extended(
              onPressed: (){
                // skip / tidak tahu -> set null & lanjut
                setState(() { asked.add(nextSym.id); answers[nextSym.id] = answers[nextSym.id]; });
              },
              label: const Text('Lewati'),
              icon: const Icon(Icons.skip_next),
            ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Symptom symptom;
  final dynamic value;
  final ValueChanged<dynamic> onAnswer;
  const _QuestionCard({super.key, required this.symptom, required this.value, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final isBool = symptom.kind == SymptomKind.boolean;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(symptom.askText ?? symptom.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (isBool)
            Row(children: [
              ChoiceChip(label: const Text('Tidak'), selected: value==false, onSelected: (_)=>onAnswer(false)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Ya'), selected: value==true, onSelected: (_)=>onAnswer(true)),
            ])
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Slider(
                value: ((value as num?) ?? (symptom.min ?? 0)).toDouble(),
                min: (symptom.min ?? 0).toDouble(),
                max: (symptom.max ?? 100).toDouble(),
                divisions: 100,
                label: '${(value as num?)?.toStringAsFixed(0) ?? symptom.min ?? 0} ${symptom.unit ?? ''}',
                onChanged: (v)=>onAnswer(v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${((value as num?) ?? (symptom.min ?? 0)).toStringAsFixed(0)} ${symptom.unit ?? ''}'),
              )
            ]),
        ]),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  final VoidCallback? onFinish;
  final bool running;
  const _FinishCard({required this.onFinish, required this.running});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: 44, color: cs.primary),
          const SizedBox(height: 8),
          const Text('Cukup untuk simpulan. Lanjutkan proses diagnosa.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton.icon(
              onPressed: onFinish,
              icon: running
                ? const SizedBox(width:18,height:18,child: CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Icon(Icons.check_circle),
              label: Text(running ? 'Memproses…' : 'Proses Diagnosa'),
            ),
          ),
        ]),
      ),
    );
  }
}
