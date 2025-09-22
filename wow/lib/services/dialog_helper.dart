// lib/services/dialog_helper.dart

import 'package:flutter/material.dart';

class DialogHelper {
  // 기존의 showMessage 메서드
  static void showMessage(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF8F4EC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "알림",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
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
                color: Color(0xFF3CAEA3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ⚠️ 새로 추가할 showConfirmation 메서드
  static Future<bool?> showConfirmation(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8F4EC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // '취소' 버튼을 누르면 false 반환
              child: const Text(
                '취소',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF577590),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // '확인' 버튼을 누르면 true 반환
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CAEA3),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}