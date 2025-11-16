import 'package:flutter/material.dart';

class FormCalcPage extends StatefulWidget {
  final void Function(Map<String, dynamic>) onGerar;

  const FormCalcPage({super.key, required this.onGerar});

  @override
  State<FormCalcPage> createState() => _FormCalcPageState();
}

class _FormCalcPageState extends State<FormCalcPage> {
  final baseController = TextEditingController();
  final produtoController = TextEditingController();
  final tanqueController = TextEditingController();
  final dataController = TextEditingController();
  final horaController = TextEditingController();
  final responsavelController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Gerar Certificado de Arqueação (CALC)",
            style: TextStyle(
              fontSize: 20,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),

          // ===== FORMULÁRIO =====
          Row(
            children: [
              _campo("Base", baseController),
              const SizedBox(width: 20),
              _campo("Produto", produtoController),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _campo("Tanque nº", tanqueController),
              const SizedBox(width: 20),
              _campo("Data", dataController),
              const SizedBox(width: 20),
              _campo("Hora", horaController),
            ],
          ),

          const SizedBox(height: 20),

          _campo("Responsável pela medição", responsavelController),

          const SizedBox(height: 40),

          // BOTÃO GERAR
          SizedBox(
            width: 200,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {
                widget.onGerar({
                  "base": baseController.text,
                  "produto": produtoController.text,
                  "tanque": tanqueController.text,
                  "data": dataController.text,
                  "hora": horaController.text,
                  "responsavel": responsavelController.text,
                });
              },
              child: const Text(
                "Gerar",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== CAMPO PADRÃO =====
  Widget _campo(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
