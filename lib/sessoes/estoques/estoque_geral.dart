import 'package:flutter/material.dart';

/// ===============================
/// MODELO DE DADOS DO ESTOQUE
/// ===============================
class EstoqueProduto {
  final String nome;
  final double abertura;
  final double entradaDescarga;
  final double entradaBombeio;
  final double saida;
  final double transito;
  final double capacidadeTotal;

  EstoqueProduto({
    required this.nome,
    required this.abertura,
    required this.entradaDescarga,
    required this.entradaBombeio,
    required this.saida,
    required this.transito,
    required this.capacidadeTotal,
  });

  double get entradasTotais => entradaDescarga + entradaBombeio;
  double get tanque => abertura + entradasTotais - saida;
  double get finalDoDia => tanque + transito;
  double get espaco => capacidadeTotal - finalDoDia;
}

/// ===============================
/// LINHA COMPACTA DE ESTOQUE
/// ===============================
class EstoqueLinha extends StatelessWidget {
  final EstoqueProduto produto;

  const EstoqueLinha({super.key, required this.produto});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          // PRODUTO
          SizedBox(
            width: 180,
            child: Text(
              produto.nome,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),

          _miniBox("Abert.", produto.abertura, Colors.blue),
          _miniBox("Entr.", produto.entradasTotais, Colors.indigo),
          _miniBox("Saída", produto.saida, Colors.red),
          _miniBox("Tanque", produto.tanque, Colors.green),
          _miniBox("Trans.", produto.transito, Colors.orange),
          _miniBox("Final", produto.finalDoDia, Colors.teal),
          _miniBox(
            "Espaço",
            produto.espaco,
            produto.espaco >= 0 ? Colors.grey.shade800 : Colors.red.shade900,
          ),
        ],
      ),
    );
  }

  Widget _miniBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// PÁGINA DE ESTOQUE GERAL (COMPACTA)
/// ===============================
class EstoqueGeralPage extends StatelessWidget {
  const EstoqueGeralPage({super.key});

  @override
  Widget build(BuildContext context) {
    final produtos = [
      EstoqueProduto(
        nome: 'Diesel S10',
        abertura: 120000,
        entradaDescarga: 30000,
        entradaBombeio: 10000,
        saida: 45000,
        transito: 8000,
        capacidadeTotal: 200000,
      ),
      EstoqueProduto(
        nome: 'Gasolina Comum',
        abertura: 90000,
        entradaDescarga: 20000,
        entradaBombeio: 5000,
        saida: 38000,
        transito: 6000,
        capacidadeTotal: 150000,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Estoque Geral',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // LISTA SEM SCROLL
            Column(
              children: produtos
                  .map((p) => EstoqueLinha(produto: p))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
