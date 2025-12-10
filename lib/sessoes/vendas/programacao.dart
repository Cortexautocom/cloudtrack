// vendas/programacao.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalhes_lancamento.dart';
import 'nova_venda.dart';

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;  

  const ProgramacaoPage({
    super.key,
    required this.onVoltar, // Mantém esta para voltar ao menu principal
  });

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  int _selectedTab = 0;
  final List<Map<String, dynamic>> _vendas = [];
  bool _carregando = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarVendas();
  }

  Future<void> _carregarVendas() async {
    if (!mounted) return;
    
    setState(() => _carregando = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Busca vendas com join para trazer nome do produto
      final response = await supabase
          .from('vendas')
          .select('''
            *,
            produtos (nome, codigo)
          ''')
          .order('data_criacao', ascending: false);

      if (mounted) {
        setState(() {
          _vendas.clear();
          _vendas.addAll(List<Map<String, dynamic>>.from(response));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vendas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _abrirNovaVenda() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovaVendaPage(
          onVoltar: () {
            Navigator.pop(context); // Fecha a página de nova venda
            _carregarVendas(); // Recarrega a lista quando voltar
          },
          onSalvar: (sucesso) {
            if (sucesso) {
              Navigator.pop(context); // Fecha a página de nova venda
              _carregarVendas(); // Recarrega a lista
            }
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getVendasFiltradas() {
    final termo = _searchController.text.toLowerCase();
    if (termo.isEmpty) return _vendas;

    return _vendas.where((venda) {
      final cliente = (venda['cliente'] ?? '').toString().toLowerCase();
      final placa = (venda['placa'] ?? '').toString().toLowerCase();
      final produtoNome = _getProdutoNome(venda).toLowerCase();
      
      return cliente.contains(termo) || 
             placa.contains(termo) || 
             produtoNome.contains(termo);
    }).toList();
  }

  String _formatarData(String dataISO) {
    try {
      final data = DateTime.parse(dataISO).toLocal();
      return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  String _formatarDataCompleta(String dataISO) {
    try {
      final data = DateTime.parse(dataISO).toLocal();
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Data inválida';
    }
  }

  String _getProdutoNome(Map<String, dynamic> venda) {
    if (venda['produtos'] != null && venda['produtos'] is Map) {
      return venda['produtos']['nome'] ?? 'Produto não identificado';
    }
    return 'Produto não identificado';
  }

  String _getProdutoCodigo(Map<String, dynamic> venda) {
    if (venda['produtos'] != null && venda['produtos'] is Map) {
      return venda['produtos']['codigo']?.toString() ?? '';
    }
    return '';
  }

  Widget _buildListaLancamentos() {
    final vendasFiltradas = _getVendasFiltradas();

    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    if (vendasFiltradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Nenhuma venda registrada'
                  : 'Nenhuma venda encontrada',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Clique no botão + para adicionar a primeira venda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarVendas,
      child: ListView.builder(
        itemCount: vendasFiltradas.length,
        itemBuilder: (context, index) {
          final venda = vendasFiltradas[index];
          final produtoCodigo = _getProdutoCodigo(venda);
          final produtoInfo = produtoCodigo.isNotEmpty 
              ? '${_getProdutoNome(venda)} (Cód: $produtoCodigo)'
              : _getProdutoNome(venda);
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 1,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_gas_station,
                  color: const Color(0xFF0D47A1),
                  size: 24,
                ),
              ),
              title: Text(
                venda['cliente'] ?? 'Cliente não informado',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Placa: ${venda['placa']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    '${venda['quantidade']}L - $produtoInfo',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    '${venda['forma_pagamento']} • ${_formatarDataCompleta(venda['data_criacao'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(venda),
                  const SizedBox(height: 4),
                  Text(
                    _formatarData(venda['data_criacao']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalhesLancamentoPage(
                      venda: venda,
                      onVoltar: () {
                        Navigator.pop(context); // Volta para a lista de vendas
                      },
                      onVendaEditada: () {
                        Navigator.pop(context); // Fecha detalhes
                        _carregarVendas(); // Recarrega a lista
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> venda) {
    final anp = venda['anp'] ?? false;
    Color backgroundColor = anp ? Colors.green : Colors.orange;
    String texto = anp ? 'ANP OK' : 'PENDENTE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildResumoDia() {
    final hoje = DateTime.now();
    final vendasHoje = _vendas.where((venda) {
      try {
        final dataVenda = DateTime.parse(venda['data_criacao']).toLocal();
        return dataVenda.year == hoje.year &&
               dataVenda.month == hoje.month &&
               dataVenda.day == hoje.day;
      } catch (e) {
        return false;
      }
    }).toList();

    final totalLitros = vendasHoje.fold<double>(0, (sum, venda) {
      final quantidade = venda['quantidade'] is num 
          ? (venda['quantidade'] as num).toDouble()
          : double.tryParse(venda['quantidade'].toString()) ?? 0;
      return sum + quantidade;
    });

    final produtosMap = <String, double>{};
    for (var venda in vendasHoje) {
      final produto = _getProdutoNome(venda);
      final quantidade = venda['quantidade'] is num 
          ? (venda['quantidade'] as num).toDouble()
          : double.tryParse(venda['quantidade'].toString()) ?? 0;
      produtosMap[produto] = (produtosMap[produto] ?? 0) + quantidade;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card de totais
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resumo de Hoje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${vendasHoje.length} ${vendasHoje.length == 1 ? 'venda' : 'vendas'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Volume Total:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${totalLitros.toStringAsFixed(2)}L',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Média por Venda:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        vendasHoje.isNotEmpty 
                            ? '${(totalLitros / vendasHoje.length).toStringAsFixed(2)}L'
                            : '0.00L',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resumo por produto
          Text(
            'Distribuição por Produto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),

          if (produtosMap.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhuma venda hoje',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...produtosMap.entries.map((entry) {
              final percentual = totalLitros > 0 
                  ? (entry.value / totalLitros) * 100 
                  : 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.local_gas_station, color: Colors.blue),
                  title: Text(entry.key),
                  subtitle: Text('${entry.value.toStringAsFixed(2)} litros'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${percentual.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '${(entry.value / vendasHoje.length).toStringAsFixed(1)}L/média',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programação de Vendas'),
        backgroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onVoltar,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabItem('Lançamentos', 0),
                _buildTabItem('Resumo do Dia', 1),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Barra de pesquisa (apenas na aba de lançamentos)
          if (_selectedTab == 0) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar por cliente, placa ou produto...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (_) {
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
          ],
          
          // Conteúdo da aba selecionada
          Expanded(
            child: _selectedTab == 0 ? _buildListaLancamentos() : _buildResumoDia(),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              onPressed: _abrirNovaVenda,
              backgroundColor: const Color(0xFF0D47A1),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabItem(String title, int index) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mounted) {
            setState(() => _selectedTab = index);
          }
        },
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}