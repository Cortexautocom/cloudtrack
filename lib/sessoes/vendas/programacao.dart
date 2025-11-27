// vendas/vendas_page.dart
import 'package:flutter/material.dart';
import 'nova_venda.dart';
import 'detalhes_lancamento.dart';

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});

  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  int _selectedTab = 0;
  final List<Map<String, dynamic>> _vendas = [];

  @override
  void initState() {
    super.initState();
    _carregarVendas();
  }

  Future<void> _carregarVendas() async {
    // Implementar carregamento das vendas do Supabase
    setState(() {
      // Dados mock para exemplo
      _vendas.addAll([
        {
          'id': '1',
          'cliente': 'João Silva Transportes',
          'placa': 'ABC-1234',
          'quantidade': 250.0,
          'produto': 'Diesel S10',
          'pagamento': 'Cartão',
          'data': DateTime.now(),
        },
        {
          'id': '2',
          'cliente': 'Maria Santos',
          'placa': 'XYZ-5678',
          'quantidade': 150.0,
          'produto': 'Gasolina Comum',
          'pagamento': 'Dinheiro',
          'data': DateTime.now().subtract(const Duration(hours: 2)),
        },
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _buildTabItem('Lançamentos', 0),
              _buildTabItem('Resumo do Dia', 1),
            ],
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildListaLancamentos() : _buildResumoDia(),
      floatingActionButton: _selectedTab == 0 
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NovaVendaPage(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTabItem(String title, int index) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _selectedTab == index 
                    ? const Color(0xFF0D47A1) 
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: _selectedTab == index 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                color: _selectedTab == index 
                    ? const Color(0xFF0D47A1) 
                    : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaLancamentos() {
    return ListView.builder(
      itemCount: _vendas.length,
      itemBuilder: (context, index) {
        final venda = _vendas[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.local_gas_station, color: Colors.green),
            title: Text(
              venda['cliente'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Placa: ${venda['placa']}'),
                Text('${venda['quantidade']}L - ${venda['produto']}'),
                Text('Pagamento: ${venda['pagamento']}'),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetalhesVendaPage(venda: venda),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildResumoDia() {
    return const Center(
      child: Text(
        'Resumo do dia em construção...',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}