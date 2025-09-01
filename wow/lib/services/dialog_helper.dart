import 'package:flutter/material.dart';

class DialogHelper {
  static void showMessage(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF8F4EC), // 베이지톤 배경
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "알림",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D), // 잉크 블랙
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "확인",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3CAEA3), // 포인트 민트
              ),
            ),
          ),
        ],
      ),
    );
  }
}
