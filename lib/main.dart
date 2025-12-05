import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // <<< TANPA LOGIN UI: sign-in anonim otomatis >>>
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (_) {
    // biar tidak menghambat start-up jika gagal, tapi log boleh ditambah
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildHealthTheme(),
      home: const HomePage(),  // langsung ke Home (tanpa AuthGate)
    );
  }
}
