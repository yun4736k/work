import 'package:flutter/material.dart';
import 'screens/login_screen.dart';  // 로그인 화면을 가져오기 위한 import

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk Canvas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Color(0xFFA8D5BA),//배경색
      ),
      home: LoginPage(),
    );
  }
}
