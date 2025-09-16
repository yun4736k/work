import 'dart:math';
import 'package:flutter/material.dart';

import 'screens/loading_screen.dart'; // ✅ 이 줄 필수!
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _initialize() async {
    // 선택: 초기화 로직 (로딩은 최소 10초 보장됨)
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    // (선택) 랜덤 로고
    final logos = [
      const AssetImage('assets/canvus1.png'),
      const AssetImage('assets/canvus2.png'),
      const AssetImage('assets/canvus3.png'),
    ];
    final randomLogo = logos[Random().nextInt(logos.length)];

    return MaterialApp(
      title: 'Walk Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFA8D5BA),
      ),
      home: LoadingScreen(
        doInitialize: _initialize,
        nextPageBuilder: (_) => const LoginPage(),
        logo: randomLogo,
      ),
    );
  }
}
