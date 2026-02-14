import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaVendaDialog extends StatefulWidget {
  final Function(bool sucesso, String? mensagem)? onSalvar;
  final String? filialId;
  final String? filialNome;
  
  // Novos parâmetros para edição
  final Map<String, dynamic>? movimentacaoParaEdicao;
  final String? ordemId;

  const NovaVendaDialog({
    super.key,
    this.onSalvar,
    this.filialId,
    this.filialNome,
    this.movimentacaoParaEdicao,
    this.ordemId,
  });

  @override
  State<NovaVendaDialog> createState() => _NovaVendaDialogState();
}

class _NovaVendaDialogState extends State<NovaVendaDialog> {
  // =======================
  // MODELOS INTERNOS
  // =======================
  final List<_PlacaVenda> _placasVenda = [];
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _produtos = [];
  bool _carregandoProdutos = false;
  bool _salvando = false;
  
  // Controle da data para edição
  DateTime? _dataSelecionada;
  
  // Flag para modo edição
  bool get _modoEdicao => widget.movimentacaoParaEdicao != null;

  @override
  void initState() {
    super.initState();
    _carregarProdutos().then((_) {
      if (_modoEdicao) {
        _carregarDadosParaEdicao();
      } else {
        _adicionarPlaca();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final p in _placasVenda) {
      p.dispose();
    }
    super.dispose();
  }

  // =======================
  // FUNÇÃO PARA OBTER HORÁRIO BRASÍLIA (GMT-3)
  // =======================
  DateTime _getHorarioBrasilia() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 3));
  }

  // =======================
  // CARREGAR DADOS PARA EDIÇÃO
  // =======================
  void _carregarDadosParaEdicao() {
    final mov = widget.movimentacaoParaEdicao!;
    
    // Carregar a data do ts_mov
    if (mov['ts_mov'] != null) {
      try {
        _dataSelecionada = DateTime.parse(mov['ts_mov'].toString());
      } catch (e) {
        _dataSelecionada = _getHorarioBrasilia();
      }
    } else {
      _dataSelecionada = _getHorarioBrasilia();
    }
    
    // Criar uma placa
    final placa = _PlacaVenda();
    
    // Extrair placa (pode ser String ou List)
    final placasData = mov['placa'];
    if (placasData is List && placasData.isNotEmpty) {
      placa.controller.text = placasData.first.toString();
    } else if (placasData is String) {
      placa.controller.text = placasData;
    }
    
    // Criar um tanque com os dados da movimentação
    final tanque = _TanqueVenda(
      capacidade: _calcularCapacidade(mov['saida_amb']?.toString() ?? '0'),
    );
    
    tanque.produtoId = mov['produto_id']?.toString();
    tanque.clienteController.text = mov['cliente']?.toString() ?? '';
    tanque.pagamentoController.text = mov['forma_pagamento']?.toString() ?? '';
    
    placa.tanques.add(tanque);
    _placasVenda.add(placa);
    
    setState(() {});
  }

  String _calcularCapacidade(String quantidadeLitros) {
    try {
      final litros = double.tryParse(quantidadeLitros) ?? 0;
      final metrosCubicos = litros / 1000;
      return metrosCubicos.toStringAsFixed(0);
    } catch (e) {
      return '0';
    }
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregandoProdutos = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('produtos')
          .select('id, nome_dois');
      _produtos = ordenarProdutosPorClasse(
        List<Map<String, dynamic>>.from(response),
      );
    } catch (_) {
      _produtos = [];
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  // =======================
  // PLACAS
  // =======================
  void _adicionarPlaca() {
    setState(() {
      _placasVenda.add(_PlacaVenda());
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removerPlaca(int index) {
    if (index > 0 && index < _placasVenda.length) {
      setState(() {
        final placaRemovida = _placasVenda.removeAt(index);
        placaRemovida.dispose();
      });
    }
  }

  Future<void> _buscarPlacas(_PlacaVenda placa, String texto) async {
    if (texto.length < 3) {
      placa.placasEncontradas.clear();
      placa.mostrarSugestoes = false;
      setState(() {});
      return;
    }

    placa.carregandoPlacas = true;
    placa.mostrarSugestoes = true;
    setState(() {});

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('view_placas_tanques')
          .select('placas, tanques')
          .ilike('placas', '${texto.replaceAll('-', '').toUpperCase()}%')
          .order('placas')
          .limit(10);

      placa.placasEncontradas = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      placa.placasEncontradas.clear();
    } finally {
      placa.carregandoPlacas = false;
      setState(() {});
    }
  }

  void _selecionarPlaca(_PlacaVenda placa, Map<String, dynamic> item) {
    placa.controller.text = item['placas'];
    placa.mostrarSugestoes = false;

    final List<dynamic> tanques = item['tanques'] ?? [];

    placa.tanques.clear();
    for (final t in tanques) {
      placa.tanques.add(_TanqueVenda(capacidade: t.toString()));
    }

    setState(() {});
  }

  List<Map<String, dynamic>> ordenarProdutosPorClasse(
    List<Map<String, dynamic>> produtos,
  ) {
    const ordemPorId = {
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 1,
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 2,
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 3,
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 4,
      '66ca957a-5698-4a02-8c9e-987770b6a151': 5,
      'f8e95435-471a-424c-947f-def8809053a0': 6,
      '4da89784-301f-4abe-b97e-c48729969e3d': 7,
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 8,
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 9,
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 10,
    };

    produtos.sort((a, b) {
      final idA = a['id'].toString().toLowerCase();
      final idB = b['id'].toString().toLowerCase();

      return (ordemPorId[idA] ?? 999)
          .compareTo(ordemPorId[idB] ?? 999);
    });

    return produtos;
  }

  Future<void> _salvarVenda() async {
    if (widget.filialId == null || widget.filialId!.isEmpty) {
      _mostrarErro('Filial não informada');
      return;
    }

    final placasUnicas = <String>[];
    for (final placaVenda in _placasVenda) {
      final placa = placaVenda.controller.text.trim().toUpperCase();
      if (placa.isNotEmpty && !placasUnicas.contains(placa)) {
        placasUnicas.add(placa);
      }
    }

    if (placasUnicas.isEmpty) {
      _mostrarErro('Informe pelo menos uma placa');
      return;
    }

    bool existemCamposObrigatoriosVazios = false;

    for (final placaVenda in _placasVenda) {
      for (final tanque in placaVenda.tanques) {
        final produtoPreenchido =
            tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
        final clientePreenchido =
            tanque.clienteController.text.trim().isNotEmpty;
        final pagamentoPreenchido =
            tanque.pagamentoController.text.trim().isNotEmpty;

        final algumCampoPreenchido =
            produtoPreenchido || clientePreenchido || pagamentoPreenchido;

        if (algumCampoPreenchido &&
            !(produtoPreenchido &&
                clientePreenchido &&
                pagamentoPreenchido)) {
          existemCamposObrigatoriosVazios = true;
          break;
        }
      }
      if (existemCamposObrigatoriosVazios) break;
    }

    if (existemCamposObrigatoriosVazios) {
      setState(() {});
      return;
    }

    int totalTanques = 0;
    int tanquesCompletos = 0;
    int tanquesVazios = 0;
    int tanquesParciais = 0;

    for (final placaVenda in _placasVenda) {
      totalTanques += placaVenda.tanques.length;

      for (final tanque in placaVenda.tanques) {
        final produtoPreenchido =
            tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
        final clientePreenchido =
            tanque.clienteController.text.trim().isNotEmpty;
        final pagamentoPreenchido =
            tanque.pagamentoController.text.trim().isNotEmpty;

        final isCompleto = produtoPreenchido && clientePreenchido && pagamentoPreenchido;
        final isVazio = !produtoPreenchido && !clientePreenchido && !pagamentoPreenchido;
        final isParcial = !isCompleto && !isVazio;

        if (isCompleto) {
          tanquesCompletos++;
        } else if (isParcial) {
          tanquesParciais++;
        } else {
          tanquesVazios++;
        }
      }
    }

    if (tanquesCompletos == 0) {
      _mostrarErro('Preencha pelo menos um tanque completo');
      return;
    }

    if (tanquesParciais > 0) {
      setState(() {});
      return;
    }

    // Se for edição, não perguntar sobre carregamento parcial
    if (!_modoEdicao && tanquesVazios > 0 && tanquesCompletos < totalTanques) {
      final bool? resultado = await _mostrarDialogCarregamentoParcial(
        tanquesCompletos,
        totalTanques,
      );

      if (resultado == null || !resultado) {
        return;
      }
    }

    if (_modoEdicao) {
      await _processarEdicaoVenda();
    } else {
      await _processarSalvamentoVenda();
    }
  }

  Future<bool?> _mostrarDialogCarregamentoParcial(
    int preenchidos,
    int total,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (intent) {
                  Navigator.of(context).pop(false);
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Dialog(
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
                      // HEADER
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
                              'Carregamento parcial',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CONTENT
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nem todos os tanques foram preenchidos.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _infoLinha('Tanques disponíveis', total.toString()),
                            const SizedBox(height: 6),
                            _infoLinha(
                              'Tanques preenchidos',
                              preenchidos.toString(),
                              destaque: true,
                            ),

                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade300, height: 1),
                            const SizedBox(height: 14),

                            Text(
                              'Deseja continuar com carregamento parcial?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ACTIONS
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(9),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 140,
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
                                  'Voltar e completar',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            SizedBox(
                              width: 140,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Seguir parcial',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _infoLinha(String label, String valor, {bool destaque = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: valor,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: destaque ? const Color.fromARGB(255, 255, 0, 0) : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // =======================
  // PROCESSAMENTO DO SALVAMENTO (NOVA VENDA)
  // =======================
  Future<void> _processarSalvamentoVenda() async {
    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;

      final filialResponse = await supabase
          .from('filiais')
          .select('empresa_id')
          .eq('id', widget.filialId!)
          .single();

      final empresaId = filialResponse['empresa_id'];

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Garante que use o horário de Brasília (GMT -3)
      final hoje = _getHorarioBrasilia();
      final dataMov =
          '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      final ordemResponse = await supabase
          .from('ordens')
          .insert({
            'empresa_id': empresaId,
            'filial_id': widget.filialId!,
            'usuario_id': user.id,
            'tipo': 'venda',
            'data_ordem': dataMov,
          })
          .select('id')
          .single();

      final ordemId = ordemResponse['id'];

      int tanquesProcessados = 0;
      
      for (final placaVenda in _placasVenda) {
        for (final tanque in placaVenda.tanques) {
          final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
          final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
          final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
          
          if (!(produtoPreenchido && clientePreenchido && pagamentoPreenchido)) {
            continue;
          }

          final capacidadeMCubicos =
              double.tryParse(tanque.capacidade) ?? 0.0;
          final capacidadeLitros = capacidadeMCubicos * 1000.0;

          final Map<String, dynamic> movimentacao = {
            'ordem_id': ordemId,
            'filial_id': widget.filialId!,
            'filial_origem_id': widget.filialId!,
            'empresa_id': empresaId,
            'usuario_id': user.id,
            'produto_id': tanque.produtoId,
            'placa': [placaVenda.controller.text.trim().toUpperCase()],
            'cliente': tanque.clienteController.text.trim(),
            'forma_pagamento': tanque.pagamentoController.text.trim(),
            'tipo_op': 'venda',
            'tipo_mov': 'saida',
            'tipo_mov_orig': 'saida',
            'descricao': 'Venda Comum',
            'data_mov': dataMov,
            'ts_mov': hoje.toIso8601String(),
            'quantidade': capacidadeLitros,
            'anp': false,
            'status_circuito_orig': 1,
            'entrada_amb': 0,
            'entrada_vinte': 0,
            'saida_amb': capacidadeLitros,
            'saida_vinte': 0,
          };

          await supabase.from('movimentacoes').insert(movimentacao);
          tanquesProcessados++;
        }
      }

      if (tanquesProcessados == 0) {
        throw Exception('Nenhum tanque completo para processar');
      }

      widget.onSalvar?.call(true, 'Venda registrada com sucesso! ($tanquesProcessados tanque(s) processado(s))');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _mostrarErro('Erro ao salvar venda: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }
  
  Future<void> _processarEdicaoVenda() async {
    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Só deve haver uma placa e um tanque na edição
      if (_placasVenda.isEmpty || _placasVenda.first.tanques.isEmpty) {
        throw Exception('Dados inválidos para edição');
      }

      final placaVenda = _placasVenda.first;
      final tanque = placaVenda.tanques.first;

      final capacidadeMCubicos = double.tryParse(tanque.capacidade) ?? 0.0;
      final capacidadeLitros = capacidadeMCubicos * 1000.0;

      // Obter o ordem_id da movimentação que está sendo editada
      final ordemId = widget.movimentacaoParaEdicao!['ordem_id']?.toString();
      
      if (ordemId == null || ordemId.isEmpty) {
        throw Exception('Ordem ID não encontrado para esta movimentação');
      }

      // Determinar o timestamp a ser usado (data selecionada ou atual)
      DateTime timestampParaSalvar;
      
      if (_dataSelecionada != null) {
        // Usar a data selecionada, mantendo o horário como 00:00:00 para consistência
        timestampParaSalvar = DateTime(
          _dataSelecionada!.year,
          _dataSelecionada!.month,
          _dataSelecionada!.day,
          0, 0, 0, // Hora zero
        );
      } else {
        // Se não selecionou data, usar o horário atual (GMT-3)
        timestampParaSalvar = _getHorarioBrasilia();
      }

      // Formatar a data para data_mov e data_ordem (apenas a data)
      final dataMov = 
          '${timestampParaSalvar.year}-${timestampParaSalvar.month.toString().padLeft(2, '0')}-${timestampParaSalvar.day.toString().padLeft(2, '0')}';

      // 1. ATUALIZAR A ORDEM (tabela ordens)
      await supabase
          .from('ordens')
          .update({'data_ordem': dataMov})
          .eq('id', ordemId);

      // 2. ATUALIZAR TODAS AS MOVIMENTAÇÕES COM ESTE ordem_id
      // Preparar dados base para update das movimentações
      final Map<String, dynamic> dadosBaseMovimentacao = {
        'data_mov': dataMov,
        'ts_mov': timestampParaSalvar.toIso8601String(),
        'updated_at': _getHorarioBrasilia().toIso8601String(),
      };

      // Atualizar todas as movimentações com o mesmo ordem_id
      await supabase
          .from('movimentacoes')
          .update(dadosBaseMovimentacao)
          .eq('ordem_id', ordemId);

      // 3. ATUALIZAR A MOVIMENTAÇÃO ESPECÍFICA (com os dados do formulário)
      final Map<String, dynamic> dadosMovimentacaoEspecifica = {
        'produto_id': tanque.produtoId,
        'placa': [placaVenda.controller.text.trim().toUpperCase()],
        'cliente': tanque.clienteController.text.trim(),
        'forma_pagamento': tanque.pagamentoController.text.trim(),
        'quantidade': capacidadeLitros,
        'saida_amb': capacidadeLitros,
      };

      await supabase
          .from('movimentacoes')
          .update(dadosMovimentacaoEspecifica)
          .eq('id', widget.movimentacaoParaEdicao!['id']);

      widget.onSalvar?.call(true, 'Programação atualizada!');
      if (mounted) Navigator.of(context).pop(true);
      
    } catch (e) {
      _mostrarErro('Erro ao atualizar venda: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
    print('ERRO: $mensagem');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    setState(() => _salvando = false);
  }

  // =======================
  // UI
  // =======================
  Widget _buildTanqueLinha(_TanqueVenda tanque) {
    final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
    final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
    final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
    final incompleto = (produtoPreenchido || clientePreenchido || pagamentoPreenchido) &&
        !(produtoPreenchido && clientePreenchido && pagamentoPreenchido);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: incompleto ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: incompleto ? Colors.orange.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tanque • ${tanque.capacidade}.000 L',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: incompleto ? Colors.orange.shade800 : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: tanque.produtoId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('', style: TextStyle(fontSize: 13)),
                ),
                ..._produtos
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(
                          p['nome_dois'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => tanque.produtoId = v),
              decoration: _inputDecoration('Produto*', incompleto: incompleto && !produtoPreenchido),
            ),
          ),
          
          const SizedBox(width: 12),
          
          SizedBox(
            width: 230,
            child: TextFormField(
              controller: tanque.clienteController,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration('Cliente*', incompleto: incompleto && !clientePreenchido),
            ),
          ),
          
          const SizedBox(width: 12),
          
          SizedBox(
            width: 180,
            child: TextFormField(
              controller: tanque.pagamentoController,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration('Forma de pagamento*', incompleto: incompleto && !pagamentoPreenchido),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              tooltip: 'Limpar linha',
              icon: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.backspace, size: 18, color: Colors.black54),
              ),
              onPressed: () {
                tanque.produtoId = null;
                tanque.clienteController.clear();
                tanque.pagamentoController.clear();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoData() {
    if (!_modoEdicao) return const SizedBox.shrink();
    
    final dataFormatada = _dataSelecionada != null
        ? '${_dataSelecionada!.day.toString().padLeft(2, '0')}/${_dataSelecionada!.month.toString().padLeft(2, '0')}/${_dataSelecionada!.year}'
        : 'Selecionar data';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 180,
            child: Text(
              'Data da programação',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              final dataSelecionada = await showDatePicker(
                context: context,
                initialDate: _dataSelecionada ?? DateTime.now(),
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                helpText: 'Selecionar data da programação',
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
                  _dataSelecionada = DateTime(
                    dataSelecionada.year,
                    dataSelecionada.month,
                    dataSelecionada.day,
                  );
                });
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dataFormatada,
                    style: TextStyle(
                      fontSize: 13,
                      color: _dataSelecionada != null ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Color(0xFF0D47A1),
                  ),
                ],
              ),
            ),
          ),
          if (_dataSelecionada != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              onPressed: () {
                setState(() {
                  _dataSelecionada = null;
                });
              },
              tooltip: 'Limpar data',
            ),
        ],
      ),
    );
  }

  Widget _buildPlaca(_PlacaVenda placa, {bool primeira = false}) {
    final index = _placasVenda.indexOf(placa);
    final mostrarRemover = !primeira && !_modoEdicao; // Não mostrar remover no modo edição
    
    return Container(
      key: ValueKey<int>(index),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Placa ${index + 1}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: placa.controller,
                      onChanged: (v) => _buscarPlacas(placa, v),
                      style: const TextStyle(fontSize: 13),
                      enabled: !_modoEdicao, // Desabilitar edição de placa no modo edição
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: _modoEdicao ? Colors.grey.shade200 : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.5,
                          ),
                        ),
                        suffixIcon: placa.carregandoPlacas && !_modoEdicao
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.search, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              if (primeira && !_modoEdicao)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    tooltip: 'Adicionar outra placa',
                    icon: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: _adicionarPlaca,
                  ),
                )
              else if (mostrarRemover)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    tooltip: 'Remover esta placa',
                    icon: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: () => _removerPlaca(index),
                  ),
                ),
            ],
          ),

          if (placa.mostrarSugestoes && !_modoEdicao)
            Container(
              margin: const EdgeInsets.only(top: 4, left: 0),
              width: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: placa.placasEncontradas.map((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(
                      item['placas'],
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _selecionarPlaca(placa, item),
                  );
                }).toList(),
              ),
            ),

          if (placa.tanques.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (_carregandoProdutos)
              const Center(child: CircularProgressIndicator()),
            ...placa.tanques.map(_buildTanqueLinha),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {bool incompleto = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 13,
        color: incompleto ? Colors.orange.shade700 : null,
      ),
      filled: true,
      fillColor: incompleto ? Colors.orange.shade50 : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: incompleto ? Colors.orange.shade400 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: incompleto ? Colors.orange.shade400 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: incompleto ? Colors.orange.shade600 : Colors.blue,
          width: 1.2,
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  // =======================
  // BUILD
  // =======================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
      ),
      child: SizedBox(
        width: 900,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: Row(
                children: [
                  Text(
                    _modoEdicao ? 'Editar Venda' : 'Nova Venda',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // CONTEÚDO
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    // Campo de data (aparece apenas no modo edição)
                    _buildCampoData(),
                    // Lista de placas
                    ...List.generate(
                      _placasVenda.length,
                      (i) => _buildPlaca(
                        _placasVenda[i],
                        primeira: i == 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FOOTER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BOTÃO CANCELAR
                  SizedBox(
                    width: 150,
                    child: OutlinedButton(
                      onPressed: _salvando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Cancelar',
                              style: TextStyle(fontSize: 13),
                            ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // BOTÃO SALVAR (texto dinâmico)
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _salvando ? null : _salvarVenda,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _salvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _modoEdicao ? 'Salvar alterações' : 'Emitir ordem',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================
// CLASSES AUXILIARES
// =======================
class _PlacaVenda {
  final TextEditingController controller = TextEditingController();

  bool mostrarSugestoes = false;
  bool carregandoPlacas = false;
  List<Map<String, dynamic>> placasEncontradas = [];

  final List<_TanqueVenda> tanques = [];

  void dispose() {
    controller.dispose();
    for (final t in tanques) {
      t.dispose();
    }
  }
}

class _TanqueVenda {
  final String capacidade;
  String? produtoId;
  final TextEditingController clienteController = TextEditingController();
  final TextEditingController pagamentoController = TextEditingController();

  _TanqueVenda({required this.capacidade});

  void reset() {
    produtoId = '';
    clienteController.clear();
    pagamentoController.clear();
  }

  void dispose() {
    clienteController.dispose();
    pagamentoController.dispose();
  }
}