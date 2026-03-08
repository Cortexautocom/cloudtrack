import 'package:flutter/material.dart';

class EstoqueProdutoPage extends StatelessWidget {
  final VoidCallback onVoltar;

  const EstoqueProdutoPage({
    super.key,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Estoque por produto',
          style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
          onPressed: onVoltar,
        ),
      ),
      body: const Center(
        child: Text(
          'Em desenvolvimento',
          style: TextStyle(
            fontSize: 20,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
