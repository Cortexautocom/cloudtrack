import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nova_venda.dart';
import 'dart:async';

// ==============================================================
//                PÁGINA DE PROGRAMAÇÃO DE VENDAS
// ==============================================================

class ProgramacaoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? filialId;
  final String? filialNome;
  final String? filialNomeDois;

  const ProgramacaoPage({
    super.key, 
    required this.onVoltar,
    this.filialId,
    this.filialNome,
    this.filialNomeDois,
  });

  @override
  State<ProgramacaoPage> createState() => _ProgramacaoPageState();
}

class _ProgramacaoPageState extends State<ProgramacaoPage> {
  bool carregando = true;
  List<Map<String, dynamic>> movimentacoes = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int grupoAtual = 0;
  bool _hoverGrupo1 = false;
  bool _hoverGrupo2 = false;
  
  DateTime _dataFiltro = DateTime.now();
  
  Map<String, Color> _coresOrdens = {};
  
  static const Map<String, Map<String, dynamic>> _mapaProdutosColuna = {
    '82c348c8-efa1-4d1a-953a-ee384d5780fc': {'grupo': 0, 'coluna': 0},
    '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': {'grupo': 0, 'coluna': 1},
    '58ce20cf-f252-4291-9ef6-f4821f22c29e': {'grupo': 0, 'coluna': 2},
    'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': {'grupo': 0, 'coluna': 3},
    '66ca957a-5698-4a02-8c9e-987770b6a151': {'grupo': 0, 'coluna': 4},
    'f8e95435-471a-424c-947f-def8809053a0': {'grupo': 1, 'coluna': 0},
    '4da89784-301f-4abe-b97e-c48729969e3d': {'grupo': 1, 'coluna': 1},
    '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': {'grupo': 1, 'coluna': 2},
    'cecab8eb-297a-4640-81ae-e88335b88d8b': {'grupo': 1, 'coluna': 3},
    'ecd91066-e763-42e3-8a0e-d982ea6da535': {'grupo': 1, 'coluna': 4},
  };
  
  static const List<Color> _paletaCoresOrdens = [
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00),
    Color(0xFF8E24AA), Color(0xFF0097A7), Color(0xFFF4511E), Color(0xFF3949AB),
    Color(0xFF7CB342), Color(0xFFD81B60), Color(0xFF5D4037), Color(0xFF546E7A),
    Color(0xFFC2185B), Color(0xFF00897B), Color(0xFF5E35B1), Color(0xFF00ACC1),
    Color(0xFFF57C00), Color(0xFF303F9F), Color(0xFF689F38), Color(0xFFAD1457),
  ];

  @override
  void initState() {
    super.initState();
    carregar();

    _horizontalHeaderController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset != _horizontalHeaderController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalBodyController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> carregar() async {
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;

      var query = supabase
          .from("movimentacoes")
          .select("*")
          .eq("tipo_op", "venda");

      if (widget.filialId != null && widget.filialId!.isNotEmpty) {
        query = query.eq("filial_id", widget.filialId!);
      }

      final dataFormatada = _dataFiltro.toIso8601String().split('T')[0];
      
      final dataInicio = '$dataFormatada 00:00:00';
      final dataFim = '$dataFormatada 23:59:59';
      
      // ALTERAÇÃO: ts_mov substituído por data_mov
      query = query
          .gte('data_mov', dataInicio)
          .lte('data_mov', dataFim);

      // ALTERAÇÃO: ts_mov substituído por data_mov
      final response = await query.order('data_mov', ascending: true);

      setState(() {
        movimentacoes = List<Map<String, dynamic>>.from(response);
        _gerarCoresParaOrdens();
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar movimentações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => carregando = false);
    }
  }

  void _gerarCoresParaOrdens() {
    _coresOrdens.clear();
    
    final ordemIdsSet = <String>{};
    for (var mov in movimentacoes) {
      final ordemId = mov['ordem_id']?.toString();
      if (ordemId != null && ordemId.isNotEmpty) {
        ordemIdsSet.add(ordemId);
      }
    }
    
    final listaOrdens = ordemIdsSet.toList()..sort();
    
    for (var i = 0; i < listaOrdens.length; i++) {
      final ordemId = listaOrdens[i];
      final indiceCor = i % _paletaCoresOrdens.length;
      _coresOrdens[ordemId] = _paletaCoresOrdens[indiceCor];
    }
  }

  Color? _obterCorParaOrdem(dynamic ordemId) {
    if (ordemId == null || ordemId.toString().isEmpty) {
      return null;
    }
    
    final idStr = ordemId.toString();
    
    if (_coresOrdens.containsKey(idStr)) {
      return _coresOrdens[idStr];
    }
    
    final hash = idStr.hashCode;
    final indiceCor = hash.abs() % _paletaCoresOrdens.length;
    final cor = _paletaCoresOrdens[indiceCor];
    
    _coresOrdens[idStr] = cor;
    
    return cor;
  }

  void _mostrarDialogNovaVenda() async {
    if (widget.filialId == null || widget.filialId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Filial não definida. Não é possível criar nova venda.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NovaVendaDialog(
        onSalvar: (sucesso, mensagem) {
          if (sucesso && mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.green,
              ),
            );
            carregar();
          } else if (mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        filialId: widget.filialId!,
        filialNome: widget.filialNome,
      ),
    );

    if (result == true) {
      await carregar();
    }
  }

  List<Map<String, dynamic>> get _movimentacoesFiltradas {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _obterDadosFiltrados(grupoAtual);

    return _obterDadosFiltrados(grupoAtual).where((t) {
      if ((t['cliente']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['placa']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['forma_pagamento']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['codigo']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['uf']?.toString().toLowerCase() ?? '').contains(query) ||
          (t['ordem_id']?.toString().toLowerCase() ?? '').contains(query)) {
        return true;
      }

      final quantidadeFormatada = _formatarQuantidadeParaBusca(t['saida_amb']?.toString() ?? '');
      if (quantidadeFormatada.contains(query)) {
        return true;
      }
      
      final apenasNumeros = (t['saida_amb']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.contains(query)) {
        return true;
      }

      return false;
    }).toList();
  }

  String _formatarQuantidadeParaBusca(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty || apenasNumeros == '0') return '';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
  }

  List<Map<String, dynamic>> _obterDadosFiltrados(int grupo) {
    return movimentacoes.where((l) {
      final qtd = double.tryParse(l['saida_amb']?.toString() ?? '0') ?? 0;
      if (qtd <= 0) return false;
      
      final produtoId = l['produto_id']?.toString();
      if (produtoId == null) return false;
      
      final produtoInfo = _mapaProdutosColuna[produtoId];
      if (produtoInfo == null) return false;
      
      return produtoInfo['grupo'] == grupo;
    }).toList();
  }  

  String _obterTextoStatus(dynamic statusCircuito) {
    if (statusCircuito == null) return "Programado";
    
    final statusNum = int.tryParse(statusCircuito.toString()) ?? 1;
    
    switch (statusNum) {
      case 1: return "Programado";
      case 2: return "Em check-list";
      case 3: return "Em operação";
      case 4: return "Aguardando NF";
      case 5: return "Expedido";
      default: return "Programado";
    }
  }

  Color _obterCorStatus(dynamic statusCircuito) {
    if (statusCircuito == null) return Colors.blue;
    
    final statusNum = int.tryParse(statusCircuito.toString()) ?? 1;
    
    switch (statusNum) {
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.grey;
      default: return Colors.blue;
    }
  }

  // ============================================================
  //          FUNÇÃO DE EDIÇÃO DE ORDEM (CORRIGIDA)
  // ============================================================
  Future<void> _editarOrdem(Map<String, dynamic> movimentacao) async {
    // Verificar status_circuito_orig
    final statusOrig = int.tryParse(movimentacao['status_circuito_orig']?.toString() ?? '1') ?? 1;
    
    if (statusOrig > 2) {
      await _mostrarDialogBloqueioEdicao();
      return;
    }

    // Verificar se tem ordem_id
    final ordemId = movimentacao['ordem_id']?.toString();
    if (ordemId == null || ordemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta movimentação não possui uma ordem associada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Buscar detalhes completos da movimentação (opcional, já temos)
    // Mas precisamos garantir que temos todos os campos necessários

    // Abrir diálogo de edição
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NovaVendaDialog(
        onSalvar: (sucesso, mensagem) {
          if (sucesso && mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.green,
              ),
            );
            carregar(); // Recarregar a lista
          } else if (mensagem != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        filialId: widget.filialId!,
        filialNome: widget.filialNome,
        // Passar dados da movimentação para edição
        movimentacaoParaEdicao: movimentacao,
        ordemId: ordemId,
      ),
    );

    if (result == true) {
      await carregar();
    }
  }

  // ============================================================
  //          DIÁLOGO DE BLOQUEIO PARA EDIÇÃO/EXCLUSÃO
  // ============================================================
  Future<void> _mostrarDialogBloqueioEdicao() async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.block_flipped, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Operação não permitida',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'A etapa do circuito não permite alteração da ordem. '
                  'Entre em contato com o supervisor da operação para reverter a etapa, '
                  'se ainda for possível.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Entendi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogBloqueioExclusao() async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.block_flipped, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Operação não permitida',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'A etapa do circuito não permite exclusão da ordem. '
                  'Entre em contato com o supervisor da operação para reverter a etapa, '
                  'se ainda for possível.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Entendi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //          FUNÇÃO DE EXCLUSÃO DE ORDEM
  // ============================================================
  Future<void> _excluirOrdem(Map<String, dynamic> movimentacao) async {
    // Verificar status_circuito_orig
    final statusOrig = int.tryParse(movimentacao['status_circuito_orig']?.toString() ?? '1') ?? 1;
    
    if (statusOrig > 2) {
      await _mostrarDialogBloqueioExclusao();
      return;
    }

    final ordemId = movimentacao['ordem_id']?.toString();
    
    if (ordemId == null || ordemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta movimentação não possui uma ordem associada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirmar exclusão
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
        ),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D47A1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirmar exclusão',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(
                        text: 'Tem certeza que quer excluir a programação?\n',
                      ),
                      TextSpan(
                        text: 'Atenção: a exclusão ocorrerá para todas os clientes do veículo. Esta ação é irreversível.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Sim, excluir',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmado != true) return;

    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('ordens')
          .delete()
          .eq('id', ordemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Programação excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        await carregar();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir programação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String tituloAppBar = "Programação de Vendas";
    if (widget.filialNomeDois != null && widget.filialNomeDois!.isNotEmpty) {
      tituloAppBar = "Programação ${widget.filialNomeDois}";
    } else if (widget.filialNome != null && widget.filialNome!.isNotEmpty) {
      tituloAppBar = "Programação ${widget.filialNome}";
    }
    
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
            ),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tituloAppBar,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSearchField(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: carregar,
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : _buildBodyContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogNovaVenda,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: const Icon(Icons.add_box, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBodyContent() {
    return Column(
      children: [
        _buildFixedPanel(),
        Expanded(
          child: _buildScrollableTable(),
        ),
      ],
    );
  }

  Widget _buildFixedPanel() {
    return Column(
      children: [
        Container(
          height: 40,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGrupoButton("Grupo 1 (Compostos)", 0),
                    const SizedBox(width: 16),
                    _buildGrupoButton("Grupo 2 (Puros)", 1),
                  ],
                ),
              ),
              _buildCampoDataFiltro(),
            ],
          ),
        ),
        
        Container(
          height: 32,
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: Text(
            '${_movimentacoesFiltradas.length} venda(s)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        if (_movimentacoesFiltradas.isNotEmpty)
          _buildFixedHeader(),
      ],
    );
  }

  Widget _buildFixedHeader() {
    final larguraTabela = _obterLarguraTabela();
    
    return Scrollbar(
      controller: _horizontalHeaderController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalHeaderController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: larguraTabela,
          child: Container(
            height: 40,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: _obterColunasCabecalho(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableTable() {
    return _movimentacoesFiltradas.isEmpty
        ? _buildEmptyState()
        : Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: Scrollbar(
                controller: _horizontalBodyController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalBodyController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _obterLarguraTabela(),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _movimentacoesFiltradas.length,
                      itemBuilder: (context, index) {
                        final t = _movimentacoesFiltradas[index];
                        final statusCircuito = t['status_circuito'];
                        final statusTexto = _obterTextoStatus(statusCircuito);
                        final corStatus = _obterCorStatus(statusCircuito);
                        
                        bool temProduto = false;
                        String codigo = "";
                        String uf = "";
                        String prazo = "";
                        
                        if (grupoAtual == 0) {
                          temProduto = [
                            'g_comum', 'g_aditivada', 'd_s10', 'd_s500', 'etanol'
                          ].any((k) => (double.tryParse(t[k]?.toString() ?? '0') ?? 0) > 0);
                        } else {
                          temProduto = [
                            'b100', 'gasolina_a', 's500_a', 's10_a', 'anidro'
                          ].any((k) => (double.tryParse(t[k]?.toString() ?? '0') ?? 0) > 0);
                        }
                        
                        if (temProduto) {
                          codigo = t["codigo"]?.toString() ?? "";
                          uf = t["uf"]?.toString() ?? "";
                          prazo = t["forma_pagamento"]?.toString() ?? "";
                        }
                        
                        return Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: _obterCelulasLinha(t, statusTexto, corStatus, codigo, uf, prazo),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhuma programação ainda.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tente alterar os termos da pesquisa',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildCampoDataFiltro() {
    final String textoData = '${_dataFiltro.day.toString().padLeft(2, '0')}/${_dataFiltro.month.toString().padLeft(2, '0')}/${_dataFiltro.year}';
    
    return InkWell(
      onTap: () async {
        final dataSelecionada = await showDatePicker(
          context: context,
          initialDate: _dataFiltro,
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Filtrar por data',
          cancelText: 'Cancelar',
          confirmText: 'Confirmar',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF0D47A1),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (dataSelecionada != null) {
          setState(() {
            _dataFiltro = DateTime(
              dataSelecionada.year,
              dataSelecionada.month,
              dataSelecionada.day,
            );
          });
          carregar();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Color(0xFF0D47A1),
            ),
            const SizedBox(width: 4),
            Text(
              textoData,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrupoButton(String texto, int grupo) {
    final bool selecionado = grupoAtual == grupo;
    bool isHovering = grupo == 0 ? _hoverGrupo1 : _hoverGrupo2;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          if (grupo == 0) {
            _hoverGrupo1 = true;
          } else {
            _hoverGrupo2 = true;
          }
        });
      },
      onExit: (_) {
        setState(() {
          if (grupo == 0) {
            _hoverGrupo1 = false;
          } else {
            _hoverGrupo2 = false;
          }
        });
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            grupoAtual = grupo;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado 
                ? Colors.blue.shade700 
                : (isHovering ? Colors.blue.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selecionado 
                  ? Colors.blue.shade700 
                  : Colors.grey.shade400,
              width: 1,
            ),
            boxShadow: isHovering && !selecionado
                ? [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: selecionado ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  //          MENU DE TRÊS PONTOS COM OPÇÕES
  // ============================================================
  Widget _buildMenuButton(BuildContext context, Map<String, dynamic> item) {
    return Container(
      width: 50,
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'editar_ordem',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('Editar ordem'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'excluir',
            child: Row(
              children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Excluir programação',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ],
        onSelected: (String value) {
          if (value == 'editar_ordem') {
            _editarOrdem(item);
          } else if (value == 'excluir') {
            _excluirOrdem(item);
          }
        },
        tooltip: 'Opções',
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
          child: const Icon(
            Icons.more_vert,
            size: 20,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  double _obterLarguraTabela() {
    double larguraFixa = 50 + 120 + 100 + 220 + 80 + 60 + 100;
    
    if (grupoAtual == 0) {
      return larguraFixa + (90 * 5);
    } else {
      return larguraFixa + (90 * 5);
    }
  }

  List<Widget> _obterColunasCabecalho() {
    final colunasFixas = [
      _th("", 50),
      _th("Placa", 120),
      _th("Status", 100),
      _th("Cliente", 220),
      _th("Cód.", 80),
      _th("UF", 60),
      _th("Prazo", 100),
    ];

    if (grupoAtual == 0) {
      return [
        ...colunasFixas,
        _th("G. Com.", 90),
        _th("G. Aditiv.", 90),
        _th("D. S10", 90),
        _th("D. S500", 90),
        _th("Etanol", 90),
      ];
    } else {
      return [
        ...colunasFixas,
        _th("G. A", 90),
        _th("S500 A", 90),
        _th("S10 A", 90),
        _th("Anidro", 90),
        _th("B100", 90),
      ];
    }
  }

  Widget _th(String texto, double largura) {
    return Container(
      width: largura,
      alignment: Alignment.center,
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<Widget> _obterCelulasLinha(
    Map<String, dynamic> t,
    String statusTexto,
    Color corStatus,
    String codigo,
    String uf,
    String prazo,
  ) {
    final placas = t["placa"];
    final placaText = placas is List && placas.isNotEmpty 
        ? placas.first.toString() 
        : placas?.toString() ?? "";

    final ordemId = t['ordem_id'];
    final corCliente = _obterCorParaOrdem(ordemId);

    final produtoId = t['produto_id']?.toString();
    final produtoInfo = produtoId != null ? _mapaProdutosColuna[produtoId] : null;
    final quantidadeSaidaAmb = _formatarQuantidade(t["saida_amb"]?.toString() ?? "0");

    final celulasFixas = [
      _buildMenuButton(context, t),
      _cell(placaText, 120),
      _statusCell(statusTexto, corStatus),
      _cellCliente(t["cliente"]?.toString() ?? "", 220, corCliente),
      _cell(codigo, 80),
      _cell(uf, 60),
      _cell(prazo, 100),
    ];

    final List<Widget> colunasQuantidade = [];
    final numColunas = 5;
    
    for (int i = 0; i < numColunas; i++) {
      if (produtoInfo != null && produtoInfo['coluna'] == i) {
        colunasQuantidade.add(_cell(quantidadeSaidaAmb, 90, isNumber: true));
      } else {
        colunasQuantidade.add(_cell("", 90, isNumber: true));
      }
    }

    return [...celulasFixas, ...colunasQuantidade];
  }

  Widget _cell(String texto, double largura, {bool isNumber = false}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
          fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _cellCliente(String texto, double largura, Color? cor) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusCell(String statusTexto, Color corStatus) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: corStatus.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: corStatus.withOpacity(0.3), width: 1),
        ),
        child: Text(
          statusTexto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: corStatus,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _formatarQuantidade(String quantidade) {
    try {
      final apenasNumeros = quantidade.replaceAll(RegExp(r'[^\d]'), '');
      if (apenasNumeros.isEmpty || apenasNumeros == '0') return '';
      
      final valor = int.parse(apenasNumeros);
      if (valor == 0) return '';
      
      if (valor > 999) {
        final parteMilhar = (valor ~/ 1000).toString();
        final parteCentena = (valor % 1000).toString().padLeft(3, '0');
        return '$parteMilhar.$parteCentena';
      }
      
      return valor.toString();
    } catch (e) {
      return quantidade;
    }
  }
}