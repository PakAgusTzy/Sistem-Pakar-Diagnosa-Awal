import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/diagnosis.dart';
import '../../models/disease.dart';
import '../../services/firestore_service.dart';
import 'history_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, Disease> _diseaseMap = const {};
  bool _loadingNames = true;

  @override
  void initState() {
    super.initState();
    _loadDiseaseNames();
  }

  Future<void> _loadDiseaseNames() async {
    final ds = await fs.getDiseases();
    setState(() {
      _diseaseMap = {for (final d in ds) d.id: d};
      _loadingNames = false;
    });
  }

  String _dName(String id) => _diseaseMap[id]?.name ?? id;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Diagnosa')),
      body: StreamBuilder<List<DiagnosisModel>>(
        stream: fs.watchDiagnoses(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <DiagnosisModel>[];
          if (items.isEmpty) {
            return _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => _loadDiseaseNames(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final m = items[i];
                final date = DateFormat('EEE, dd MMM yyyy • HH:mm').format(m.createdAt);
                final pct = NumberFormat.percentPattern().format(m.score.clamp(0, 1));
                final name = _dName(m.topDiseaseId);

                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HistoryDetailPage(id: m.id)),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.medical_services_rounded, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(date, style: TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(pct,
                                  style: TextStyle(
                                      color: cs.primary, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 6),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 64, color: cs.primary),
            const SizedBox(height: 12),
            const Text('Belum ada riwayat'),
            const SizedBox(height: 6),
            Text('Silakan lakukan diagnosa terlebih dahulu.',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
