// vendas/detalhes_venda_page.dart
import 'package:flutter/material.dart';

class DetalhesVendaPage extends StatelessWidget {
  final Map<String, dynamic> venda;

  const DetalhesVendaPage({super.key, required this.venda});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Venda'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildInfoCard('Cliente', venda['cliente']),
            _buildInfoCard('Placa', venda['placa']),
            _buildInfoCard('Produto', venda['produto']),
            _buildInfoCard('Quantidade', '${venda['quantidade']}L'),
            _buildInfoCard('Forma de Pagamento', venda['pagamento']),
            _buildInfoCard('Data', 
                '${venda['data'].hour}:${venda['data'].minute.toString().padLeft(2, '0')}'),
            // Adicione mais campos conforme necessário
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String titulo, String valor) {
    return Card(
      child: ListTile(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(valor),
      ),
    );
  }
}