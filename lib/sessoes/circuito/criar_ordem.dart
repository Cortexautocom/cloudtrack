import 'package:flutter/material.dart';

class CriarOrdemPage extends StatelessWidget {
  const CriarOrdemPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE6DCCB), width: 1.2)),
          ),
          child: Row(
            children: const [
              Icon(Icons.add_circle_outline, color: Color(0xFF1B6A6F)),
              SizedBox(width: 8),
              Text(
                'Criar Ordem',
                style: TextStyle(
                  fontSize: 20,
                  color: Color(0xFF0E1C2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          fit: FlexFit.loose,
          child: Center(
            child: Text(
              'Em desenvolvimento',
              style: TextStyle(fontSize: 24, color: Color(0xFF5A6B7A)),
            ),
          ),
        ),
      ],
    );
  }
}
