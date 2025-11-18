import 'package:flutter/material.dart';

class CalcPage extends StatelessWidget {
  final Map<String, dynamic> dadosFormulario;

  const CalcPage({
    super.key,
    required this.dadosFormulario,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Certificado de Arqueação'),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _imprimir(context),
            tooltip: 'Imprimir',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _fazerDownload(context),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.symmetric(vertical: 20),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== CABEÇALHO DO DOCUMENTO =====
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

                const SizedBox(height: 20),

                // ===== INFORMAÇÕES EM LINHA (4 CAMPOS) =====
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DATA
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _secaoTitulo("DATA:"),
                            _linhaValor(dadosFormulario['data'] ?? "10/2025"),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      
                      // BASE
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _secaoTitulo("BASE:"),
                            _linhaValor(dadosFormulario['base'] ?? "POLO DE COMBUSTÍVEL DE CANDEIAS"),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      
                      // PRODUTO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _secaoTitulo("Produto:"),
                            _linhaValor(dadosFormulario['produto'] ?? "DIESEL S10 A"),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      
                      // TANQUE
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _secaoTitulo("Tanque Nº:"),
                            _linhaValor(dadosFormulario['tanque']?.toString() ?? "05"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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

                // ===== RESPONSÁVEL =====
                if (dadosFormulario['responsavel'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      _subtitulo("RESPONSÁVEL PELA MEDIÇÃO"),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                        ),
                        child: Text(
                          dadosFormulario['responsavel']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),

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
        fontSize: 12,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        valor,
        style: const TextStyle(fontSize: 12),
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
              child: Text(
                l[0], 
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l[1], 
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ===========================================
  // FUNÇÕES DE IMPRESSÃO E DOWNLOAD SIMPLIFICADAS
  // ===========================================

  void _imprimir(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imprimir Documento'),
        content: const Text('Use Ctrl+P para imprimir esta página ou clique no botão de impressão do seu navegador.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _fazerDownload(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download PDF'),
        content: const Text('Para gerar PDF, use a função de imprimir do navegador e selecione "Salvar como PDF" como destino.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}