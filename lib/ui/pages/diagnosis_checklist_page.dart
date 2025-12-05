import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/symptom.dart';
import '../../models/rule.dart';
import '../../models/disease.dart';
import '../../models/diagnosis.dart';
import '../../services/firestore_service.dart';
import '../../services/inference_engine.dart';

class DiagnosisChecklistPage extends StatefulWidget {
  const DiagnosisChecklistPage({super.key});
  @override
  State<DiagnosisChecklistPage> createState() => _DiagnosisChecklistPageState();
}

class _DiagnosisChecklistPageState extends State<DiagnosisChecklistPage> {
  bool loading = true;
  bool running = false;

  List<Symptom> symptoms = [];
  List<Rule> rules = [];
  List<Disease> diseases = [];
  Map<String, dynamic> answers = {};
  String query = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      symptoms = await fs.getSymptoms();
      rules = await fs.getRules();
      diseases = await fs.getDiseases();
      for (final s in symptoms) {
        answers[s.id] = (s.kind == SymptomKind.boolean) ? false : (s.min ?? 0);
      }
    } finally { setState(()=>loading=false); }
  }

  String _name(String diseaseId) => diseases.firstWhere(
    (d) => d.id == diseaseId, orElse: () => Disease(id: diseaseId, name: diseaseId)
  ).name;

  Future<void> _run() async {
  if (running) return;
  setState(()=>running=true);
  try {
    final res = runInference(rules: rules, answers: answers);

    if (res.ranked.isEmpty) {
      if (!mounted) return;
      showDialog(context: context, builder: (_)=> const AlertDialog(
        title: Text('Referensi belum siap'),
        content: Text('Rules kosong. Pastikan seeding berhasil.'),
      ));
      return;
    }

    final top = res.ranked.first;
    final topDiseaseId = top['diseaseId'] as String;
    final score = (top['score'] as num).toDouble().clamp(0, 1);
    final matched = top['matched'] as int;
    final total = top['total'] as int;
    final missing = (top['missing'] as List).cast<String>();

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
              final s = symptoms.firstWhere(
                (x) => x.id == id,
                orElse: ()=> Symptom(id:id, code:id, name:id, kind: SymptomKind.boolean),
              );
              return ListTile(
                dense: true,
                leading: const Icon(Icons.info_outline, size: 18),
                title: Text(s.name),
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

    final filtered = symptoms.where((s) =>
      s.name.toLowerCase().contains(query.toLowerCase())
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Ceklist'),
        actions: [
          IconButton(
            tooltip: 'Mode adaptif',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: ()=>Navigator.pushReplacementNamed(context, '/adaptive'),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16,0,16,12),
            child: TextField(
              onChanged: (v)=>setState(()=>query=v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cari gejala…',
                filled: true, fillColor: cs.surfaceVariant.withOpacity(.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: filtered.length,
        itemBuilder: (_, i) {
          final s = filtered[i];
          final isBool = s.kind == SymptomKind.boolean;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isBool
                ? SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.name),
                    subtitle: Text(s.askText ?? ''),
                    value: (answers[s.id] as bool?) ?? false,
                    onChanged: (v)=>setState(()=>answers[s.id]=v),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Row(children: [
                        Expanded(child: Slider(
                          value: ((answers[s.id] as num?) ?? (s.min ?? 0)).toDouble(),
                          min: (s.min ?? 0).toDouble(),
                          max: (s.max ?? 100).toDouble(),
                          divisions: 100,
                          onChanged: (v)=>setState(()=>answers[s.id]=v),
                        )),
                        const SizedBox(width: 8),
                        Text('${((answers[s.id] as num?) ?? (s.min ?? 0)).toStringAsFixed(0)} ${s.unit ?? ''}'),
                      ]),
                    ],
                  ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 56, width: double.infinity,
            child: FilledButton.icon(
              onPressed: running ? null : _run,
              icon: running
                ? const SizedBox(width:20,height:20,child: CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Icon(Icons.check_circle),
              label: Text(running ? 'Memproses…' : 'Proses Diagnosa'),
            ),
          ),
        ),
      ),
    );
  }
}
