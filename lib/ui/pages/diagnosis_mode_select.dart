import 'package:flutter/material.dart';
import 'diagnosis_adaptive_page.dart';
import 'diagnosis_checklist_page.dart';

class DiagnosisModeSelectPage extends StatelessWidget {
  const DiagnosisModeSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Mode Diagnosa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModeCard(
            icon: Icons.smart_toy_outlined,
            title: 'Mode Adaptif',
            subtitle: 'Pertanyaan satu-per-satu, lebih cepat & fokus',
            badge: 'Direkomendasikan',
            color: cs.primary,
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const DiagnosisAdaptivePage()),
            ),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.view_list_rounded,
            title: 'Mode Ceklist',
            subtitle: 'Lihat semua gejala, centang yang sesuai',
            color: cs.secondary,
            onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const DiagnosisChecklistPage()),
            ),
          ),
          const SizedBox(height: 20),
          _Tip(),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color color;
  final VoidCallback onTap;
  const _ModeCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withOpacity(.15), cs.surface],
          ),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(width: 8),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(badge!, style: TextStyle(color: color, fontSize: 11)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('Kapan pun kamu bisa beralih mode dari menu ⋯ di kanan atas.')),
        ],
      ),
    );
  }
}
