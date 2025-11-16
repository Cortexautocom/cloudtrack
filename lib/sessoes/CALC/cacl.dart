import 'package:flutter/material.dart';

class CalcPage extends StatelessWidget {
  const CalcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== CABEÇALHO =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: const Center(
                child: Text(
                  "CERTIFICADO DE ARQUEAÇÃO DE CARGAS LÍQUIDAS",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ===== DATA =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "10/2025",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ===== BASE =====
            _secaoTitulo("BASE:"),
            _linhaValor("POLO DE COMBUSTÍVEL DE CANDEIAS"),

            const SizedBox(height: 20),

            // ===== PRODUTO =====
            _secaoTitulo("DESCARGA/RECEBIMENTO DE:"),
            _linhaValor("DIESEL S10 A"),

            const SizedBox(height: 20),

            // ===== TANQUE =====
            _secaoTitulo("PARA O TANQUE Nº:"),
            _linhaValor("05"),

            const SizedBox(height: 30),

            // ===== TABELA COM MEDIÇÕES =====
            _subtitulo("CARGA RECEBIDA NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
            const SizedBox(height: 20),

            _tabela([
              ["Altura média do líquido (1ª medição)", "783,4"],
              ["Altura média do líquido (2ª medição)", "780,3"],
              ["Temperatura média no tanque", "28 °C   /   27,5 °C"],
              ["Volume (altura verificada)", "679.020 L   /   676.337 L"],
              ["Densidade observada", "0,823 g/ml"],
              ["Temperatura da amostra", "24,5 °C"],
              ["Densidade a 20 °C", "0,9940"],
              ["Volume convertido a 20 °C", "674.699 L   /   672.300 L"],
            ]),

            const SizedBox(height: 35),

            // ===== RESULTADOS =====
            _subtitulo("COMPARAÇÃO DOS RESULTADOS"),
            const SizedBox(height: 10),

            _tabela([
              ["Litros a Ambiente", "2.683"],
              ["Litros a 20 °C", "2.399"],
            ]),

            const SizedBox(height: 40),

            // ===== MANIFESTAÇÃO =====
            _subtitulo("MANIFESTAÇÃO"),
            const SizedBox(height: 10),

            _tabela([
              ["Recebido", ""],
              ["Diferença", ""],
              ["Percentual", ""],
            ]),

            const SizedBox(height: 40),

            // ===== ABERTURA / SALDO =====
            _subtitulo("ABERTURA / ENTRADA / SAÍDA / SALDO"),
            const SizedBox(height: 10),

            _tabela([
              ["Abertura", "674.699 L"],
              ["Entrada", "0 L"],
              ["Saída", "0 L"],
              ["Saldo Final", "674.699 L"],
            ]),

            const SizedBox(height: 50),

            Center(
              child: Text(
                "Página demonstrativa — valores ilustrativos",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ===========================================
  // WIDGETS DE FORMATAÇÃO
  // ===========================================

  Widget _secaoTitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _linhaValor(String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        valor,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _tabela(List<List<String>> linhas) {
    return Table(
      border: TableBorder.all(color: Colors.black54),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
      },
      children: linhas.map((l) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l[0], style: const TextStyle(fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l[1], style: const TextStyle(fontSize: 13)),
            ),
          ],
        );
      }).toList(),
    );
  }
}
