import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TestPostPage extends StatelessWidget {
  const TestPostPage({super.key});

  Future<void> testarPost() async {
    final url = Uri.parse('https://ikaxzlpaihdkqyjqrxyw.supabase.co/functions/v1/redefinir-senha');
    print('🚀 Enviando POST de teste...');
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": "teste@teste.com"}),
    );
    print('📡 Status: ${resp.statusCode}');
    print('📦 Body: ${resp.body}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: testarPost,
          child: const Text("Testar POST"),
        ),
      ),
    );
  }
}
