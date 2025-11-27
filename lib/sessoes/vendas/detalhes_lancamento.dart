// vendas/detalhes_lancamento.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetalhesLancamentoPage extends StatefulWidget {
  final Map<String, dynamic> venda;
  final VoidCallback onVoltar;
  final Function()? onVendaEditada;

  const DetalhesLancamentoPage({
    super.key,
    required this.venda,
    required this.onVoltar,
    this.onVendaEditada,
  });

  @override
  State<DetalhesLancamentoPage> createState() => _DetalhesLancamentoPageState();
}

class _DetalhesLancamentoPageState extends State<DetalhesLancamentoPage> {
  bool _carregando = false;

  Future<void> _excluirVenda() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir esta venda? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _carregando = true);
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('vendas')
            .delete()
            .eq('id', widget.venda['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Venda excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          
          widget.onVoltar();
          if (widget.onVendaEditada != null) {
            widget.onVendaEditada!();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir venda: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _carregando = false);
        }
      }
    }
  }

  String _formatarData(String dataISO) {
    try {
      final data = DateTime.parse(dataISO).toLocal();
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Data inválida';
    }
  }

  String _getProdutoNome() {
    if (widget.venda['produtos'] != null && widget.venda['produtos'] is Map) {
      return widget.venda['produtos']['nome'] ?? 'Produto não identificado';
    }
    return 'Produto não identificado';
  }

  String _getProdutoCodigo() {
    if (widget.venda['produtos'] != null && widget.venda['produtos'] is Map) {
      return widget.venda['produtos']['codigo']?.toString() ?? '';
    }
    return '';
  }

  Widget _buildInfoCard(String titulo, String valor, {IconData? icon}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: icon != null 
            ? Icon(icon, color: const Color(0xFF0D47A1))
            : null,
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          valor,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final anp = widget.venda['anp'] ?? false;
    Color backgroundColor = anp ? Colors.green : Colors.orange;
    String texto = anp ? 'ANP CONFIRMADA' : 'ANP PENDENTE';

    return Chip(
      label: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final produtoCodigo = _getProdutoCodigo();
    final produtoInfo = produtoCodigo.isNotEmpty 
        ? '${_getProdutoNome()} (Cód: $produtoCodigo)'
        : _getProdutoNome();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Detalhes do Lançamento',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _carregando ? null : widget.onVoltar,
        ),
        actions: [
          if (!_carregando)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'excluir') {
                  _excluirVenda();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'excluir',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir Venda'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com status
                  Card(
                    elevation: 3,
                    color: const Color(0xFF0D47A1),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Venda #${widget.venda['id']?.toString().substring(0, 8) ?? 'N/A'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusChip(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Informações do Cliente e Veículo
                  Text(
                    'INFORMAÇÕES PRINCIPAIS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Cliente',
                    widget.venda['cliente'] ?? 'Não informado',
                    icon: Icons.person,
                  ),
                  _buildInfoCard(
                    'Placa do Veículo',
                    widget.venda['placa'] ?? 'Não informada',
                    icon: Icons.directions_car,
                  ),
                  const SizedBox(height: 20),

                  // Informações do Produto
                  Text(
                    'DADOS DO PRODUTO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Produto',
                    produtoInfo,
                    icon: Icons.local_gas_station,
                  ),
                  _buildInfoCard(
                    'Quantidade',
                    '${widget.venda['quantidade']?.toString() ?? '0'} litros',
                    icon: Icons.speed,
                  ),
                  const SizedBox(height: 20),

                  // Informações de Pagamento
                  Text(
                    'PAGAMENTO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Forma de Pagamento',
                    widget.venda['forma_pagamento'] ?? 'Não informada',
                    icon: Icons.payment,
                  ),
                  if (widget.venda['codigo'] != null)
                    _buildInfoCard(
                      'Código',
                      widget.venda['codigo'].toString(),
                      icon: Icons.tag,
                    ),
                  const SizedBox(height: 20),

                  // Informações Adicionais
                  Text(
                    'INFORMAÇÕES ADICIONAIS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Data e Hora',
                    _formatarData(widget.venda['data_criacao'] ?? ''),
                    icon: Icons.calendar_today,
                  ),
                  _buildInfoCard(
                    'Declaração ANP',
                    widget.venda['anp'] == true ? 'Confirmada' : 'Não confirmada',
                    icon: Icons.verified,
                  ),
                  
                  // Observações (se houver)
                  if (widget.venda['observacoes'] != null && 
                      widget.venda['observacoes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'OBSERVAÇÕES',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Observações',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.venda['observacoes'].toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Botão de ação
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _excluirVenda,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'EXCLUIR VENDA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}