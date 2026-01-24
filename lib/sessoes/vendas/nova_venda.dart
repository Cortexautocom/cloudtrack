import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaVendaDialog extends StatefulWidget {
  final Function(bool sucesso, String? mensagem)? onSalvar;
  final String? filialId;
  final String? filialNome;

  const NovaVendaDialog({
    super.key,
    this.onSalvar,
    this.filialId,
    this.filialNome,
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

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    _adicionarPlaca(); // primeira placa já nasce aberta
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final p in _placasVenda) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregandoProdutos = true);
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('produtos').select('id, nome').order('nome');
      _produtos = List<Map<String, dynamic>>.from(response);
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
    
    // Desliza para o final após a reconstrução do widget
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

  // =======================
  // MAPEAMENTO DE PRODUTOS (MESMO DA TRANSFERÊNCIA)
  // =======================
  String _resolverColunaProduto(String produtoId) {
    const mapaProdutoColuna = {
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',
      '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',
      '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada',
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 'd_s500',
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',
      'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a',
    };

    // Normalizar UUID (remover espaços, converter para minúsculas)
    final uuidNormalizado = produtoId.trim().toLowerCase();
    
    final coluna = mapaProdutoColuna[uuidNormalizado];

    if (coluna == null) {
      throw Exception('Produto (UUID: $produtoId) sem coluna de movimentação configurada');
    }

    return coluna;
  }

  // =======================
  // VALIDAÇÃO E DIALOG DE CARREGAMENTO PARCIAL
  // =======================
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

    // Verificar se há tanques com campos obrigatórios não preenchidos
    bool existemCamposObrigatoriosVazios = false;
    for (final placaVenda in _placasVenda) {
      for (final tanque in placaVenda.tanques) {
        final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
        final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
        final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
        
        // Verificar se algum campo foi preenchido (para indicar que o usuário começou a preencher)
        final algumCampoPreenchido = produtoPreenchido || clientePreenchido || pagamentoPreenchido;
        
        // Se algum campo foi preenchido mas não todos, temos campos obrigatórios vazios
        if (algumCampoPreenchido && !(produtoPreenchido && clientePreenchido && pagamentoPreenchido)) {
          existemCamposObrigatoriosVazios = true;
          break;
        }
      }
      if (existemCamposObrigatoriosVazios) break;
    }

    // Bloquear se há campos obrigatórios não preenchidos em tanques que foram iniciados
    if (existemCamposObrigatoriosVazios) {
      await _mostrarDialogCamposIncompletos();
      return;
    }

    // Agora contar tanques completamente preenchidos vs tanques vazios
    int totalTanques = 0;
    int tanquesPreenchidos = 0;
    int tanquesVazios = 0;

    for (final placaVenda in _placasVenda) {
      totalTanques += placaVenda.tanques.length;
      
      for (final tanque in placaVenda.tanques) {
        final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
        final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
        final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
        
        if (produtoPreenchido && clientePreenchido && pagamentoPreenchido) {
          tanquesPreenchidos++;
        } else {
          tanquesVazios++;
        }
      }
    }

    // Verificar se há pelo menos um tanque preenchido
    if (tanquesPreenchidos == 0) {
      _mostrarErro('Preencha pelo menos um tanque completo');
      return;
    }

    // Se houver tanques vazios (carregamento parcial), mostrar dialog de confirmação
    if (tanquesVazios > 0 && tanquesPreenchidos < totalTanques) {
      final bool? resultado = await _mostrarDialogCarregamentoParcial(tanquesPreenchidos, totalTanques);
      if (resultado == null || !resultado) {
        return; // Usuário escolheu "Não, vou completar" ou fechou o dialog
      }
      // Se resultado for true, prosseguir com carregamento parcial
    }

    await _processarSalvamentoVenda();
  }

  Future<void> _mostrarDialogCamposIncompletos() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DialogPersonalizado(
        titulo: 'Campos obrigatórios',
        conteudo: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preencha todos os campos obrigatórios nos tanques que foram iniciados.'),
            SizedBox(height: 8),
            Text('Os tanques com campos incompletos estão destacados em laranja.'),
          ],
        ),
        temBotoesAcao: false,
        textoBotaoPositivo: 'OK',
        onPressedPositivo: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<bool?> _mostrarDialogCarregamentoParcial(int preenchidos, int total) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DialogPersonalizado(
        titulo: 'Carregamento parcial',
        conteudo: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanques disponíveis: $total'),
            Text('Tanques preenchidos: $preenchidos'),
            const SizedBox(height: 12),
            const Text('Seguir com carregamento parcial?'),
          ],
        ),
        textoBotaoNegativo: 'Não, vou completar',
        textoBotaoPositivo: 'Sim, parcial',
        onPressedNegativo: () => Navigator.of(context).pop(false),
        onPressedPositivo: () => Navigator.of(context).pop(true),
      ),
    );
  }

  // =======================
  // PROCESSAMENTO DO SALVAMENTO
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

      final hoje = DateTime.now();
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
          // Verificar se o tanque está completamente preenchido
          final produtoPreenchido = tanque.produtoId != null && tanque.produtoId!.isNotEmpty;
          final clientePreenchido = tanque.clienteController.text.trim().isNotEmpty;
          final pagamentoPreenchido = tanque.pagamentoController.text.trim().isNotEmpty;
          
          // Pular tanques vazios (carregamento parcial)
          if (!(produtoPreenchido && clientePreenchido && pagamentoPreenchido)) {
            continue;
          }

          final colunaProduto = _resolverColunaProduto(tanque.produtoId!);
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
            'quantidade': capacidadeLitros,
            'anp': false,
            'status_circuito': 1,
            'entrada_amb': 0,
            'entrada_vinte': 0,
            'saida_amb': 0,
            'saida_vinte': 0,
            'g_comum': 0,
            'g_aditivada': 0,
            'd_s10': 0,
            'd_s500': 0,
            'etanol': 0,
            'anidro': 0,
            'b100': 0,
            'gasolina_a': 0,
            's500_a': 0,
            's10_a': 0,
          };

          movimentacao[colunaProduto] = capacidadeLitros;

          await supabase.from('movimentacoes').insert(movimentacao);
          tanquesProcessados++;
        }
      }

      if (tanquesProcessados == 0) {
        throw Exception('Nenhum tanque completo para processar');
      }

      widget.onSalvar?.call(true, 'Venda registrada com sucesso! (${tanquesProcessados} tanque(s) processado(s))');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _mostrarErro('Erro ao salvar venda: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
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
    // Verificar se o tanque está incompleto (pelo menos um campo preenchido mas não todos)
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
          // TÍTULO DO TANQUE (centralizado verticalmente)
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
                if (incompleto)
                  const SizedBox(height: 2),
                if (incompleto)
                  Text(
                    'Campos obrigatórios não preenchidos',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // PRODUTO (200px)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: tanque.produtoId,
              isExpanded: true,
              items: _produtos
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text(
                        p['nome'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => tanque.produtoId = v,
              decoration: _inputDecoration('Produto*', incompleto: incompleto && !produtoPreenchido),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // CLIENTE (250px)
          SizedBox(
            width: 250,
            child: TextFormField(
              controller: tanque.clienteController,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration('Cliente*', incompleto: incompleto && !clientePreenchido),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // FORMA DE PAGAMENTO (200px)
          SizedBox(
            width: 200,
            child: TextFormField(
              controller: tanque.pagamentoController,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration('Forma de pagamento*', incompleto: incompleto && !pagamentoPreenchido),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaca(_PlacaVenda placa, {bool primeira = false}) {
    final index = _placasVenda.indexOf(placa);
    final mostrarRemover = !primeira; // Não mostrar no primeiro
    
    return Container(
      key: ValueKey<int>(index), // Key para ajudar no scroll
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LINHA DA PLACA + "+" + "X"
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CAMPO DA PLACA
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
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
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
                        suffixIcon: placa.carregandoPlacas
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
              
              // BOTÕES: ADICIONAR (apenas primeira) ou REMOVER (apenas das demais)
              const SizedBox(width: 8),
              
              if (primeira)
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

          if (placa.mostrarSugestoes)
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Nova Venda',
                    style: TextStyle(
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
                  children: List.generate(
                    _placasVenda.length,
                    (i) => _buildPlaca(
                      _placasVenda[i],
                      primeira: i == 0,
                    ),
                  ),
                ),
              ),
            ),

            // FOOTER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BOTÃO CANCELAR (150px)
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
                  
                  // BOTÃO EMITIR ORDEM (150px)
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
                          : const Text(
                              'Emitir ordem',
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
    );
  }
}

// =======================
// DIALOG PERSONALIZADO
// =======================
class _DialogPersonalizado extends StatelessWidget {
  final String titulo;
  final Widget conteudo;
  final String? textoBotaoNegativo;
  final String? textoBotaoPositivo;
  final VoidCallback? onPressedNegativo;
  final VoidCallback? onPressedPositivo;
  final bool temBotoesAcao;

  const _DialogPersonalizado({
    required this.titulo,
    required this.conteudo,
    this.textoBotaoNegativo,
    this.textoBotaoPositivo,
    this.onPressedNegativo,
    this.onPressedPositivo,
    this.temBotoesAcao = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // CONTEÚDO
            Container(
              padding: const EdgeInsets.all(20),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
                child: conteudo,
              ),
            ),

            // BOTÕES
            if (temBotoesAcao)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (textoBotaoNegativo != null)
                      SizedBox(
                        width: textoBotaoNegativo!.length * 8.0 + 32, // Ajusta largura pelo conteúdo
                        child: OutlinedButton(
                          onPressed: onPressedNegativo,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: BorderSide(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Text(
                            textoBotaoNegativo!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    
                    if (textoBotaoNegativo != null && textoBotaoPositivo != null)
                      const SizedBox(width: 12),
                    
                    if (textoBotaoPositivo != null)
                      SizedBox(
                        width: textoBotaoPositivo!.length * 8.0 + 32, // Ajusta largura pelo conteúdo
                        child: ElevatedButton(
                          onPressed: onPressedPositivo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            textoBotaoPositivo!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 80, // Largura fixa para o botão OK
                      child: ElevatedButton(
                        onPressed: onPressedPositivo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'OK',
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

  void dispose() {
    clienteController.dispose();
    pagamentoController.dispose();
  }
}