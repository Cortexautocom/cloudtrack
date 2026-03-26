import 'package:flutter/material.dart';

class OrdemBombeioPage extends StatelessWidget {
  final VoidCallback onVoltar;

  const OrdemBombeioPage({super.key, required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add_check, size: 64, color: Color(0xFF00BCD4)),
          SizedBox(height: 16),
          Text(
            'Ordem de Bombeio',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Em desenvolvimento.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
