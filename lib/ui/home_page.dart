import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';

import 'pages/diagnosis_mode_select.dart';
import 'pages/history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _seeding = true;
  bool _seedDone = false;

  @override
  void initState() {
    super.initState();
    // Jalankan seeding referensi sekali setelah login (non-blocking)
    Future(() async {
      try {
        await fs.seedFromAssetsOnce();
        if (!mounted) return;
        setState(() {
          _seedDone = true;
          _seeding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referensi siap digunakan.')),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _seeding = false);
        // Tidak memblok UI; hanya info
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seeding gagal/terlewati: $e')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Pakar Diagnosa'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => authService.signOut(),
            icon: const Icon(Icons.logout_rounded),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner status seeding (hanya terlihat saat awal)
          if (_seeding || !_seedDone)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withOpacity(.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.secondaryContainer.withOpacity(.5)),
              ),
              child: Row(
                children: [
                  if (_seeding)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _seeding
                          ? 'Menyiapkan referensi (sekali saja)…'
                          : 'Jika referensi belum terlihat, cek koneksi atau ulangi masuk.',
                    ),
                  ),
                ],
              ),
            ),

          _ActionCard(
            icon: Icons.local_hospital_outlined,
            title: 'Mulai Diagnosa',
            subtitle: 'Pilih mode Adaptif atau Ceklist',
            color: cs.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiagnosisModeSelectPage()),
            ),
          ),
          const SizedBox(height: 12),

          _ActionCard(
            icon: Icons.history_rounded,
            title: 'Riwayat',
            subtitle: 'Lihat hasil diagnosa sebelumnya',
            color: cs.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          const SizedBox(height: 12),

          _InfoCard(
            text:
                'Catatan: hasil aplikasi adalah dukungan keputusan (SPK), '
                'bukan diagnosis medis final. Konsultasikan dengan tenaga kesehatan.',
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(.14), cs.surface],
          ),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;
  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
