import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'transferencias.dart'; // Importando para usar o AutocompleteField

// ==============================================================
//                DIALOG DE NOVA TRANSFERÊNCIA
// ==============================================================

class NovaTransferenciaDialog extends StatefulWidget {
  const NovaTransferenciaDialog({super.key});

  @override
  State<NovaTransferenciaDialog> createState() => _NovaTransferenciaDialogState();
}

class _NovaTransferenciaDialogState extends State<NovaTransferenciaDialog> {
  DateTime _dataSelecionada = DateTime.now();
  bool _salvando = false;
  
  // Controllers para os campos
  final TextEditingController _motoristaController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _transportadoraController = TextEditingController();
  final TextEditingController _cavaloController = TextEditingController();
  final TextEditingController _reboque1Controller = TextEditingController();
  final TextEditingController _reboque2Controller = TextEditingController();
  
  // IDs para salvar no banco
  String? _motoristaId;
  String? _produtoId;
  String? _transportadoraId;
  String? _origemId;
  String? _destinoId;
  String? _empresaId;
  String? _usuarioId;
  
  // Listas para dropdowns
  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _filiais = [];
  List<String> _datasFormatadas = [];
  List<DateTime> _datasDisponiveis = [];
  
  // Valores selecionados
  String? _produtoSelecionado;
  String? _origemSelecionada;
  String? _destinoSelecionado;
  
  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _carregarProdutos();
    _carregarFiliais();
    _gerarDatasDisponiveis();
  }

  void _gerarDatasDisponiveis() {
    final hoje = DateTime.now();
    _datasDisponiveis = [
      hoje,
      hoje.add(const Duration(days: 1)),
      hoje.add(const Duration(days: 2)),
      hoje.add(const Duration(days: 3)),
      hoje.add(const Duration(days: 4)),
    ];
    _datasFormatadas = _datasDisponiveis.map(_formatarData).toList();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        _usuarioId = user.id;
        
        // Buscar empresa_id do usuário
        final usuarioData = await supabase
            .from('usuarios')
            .select('empresa_id')
            .eq('id', user.id)
            .maybeSingle();
            
        if (usuarioData != null) {
          _empresaId = usuarioData['empresa_id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
    }
  }

  Future<void> _carregarProdutos() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('produtos')
          .select('id, nome');

      final produtos = List<Map<String, dynamic>>.from(response);

      // MESMA ORDEM USADA NO NovaVendaDialog
      const ordemPorId = {
        '82c348c8-efa1-4d1a-953a-ee384d5780fc': 1,  // Gasolina Comum
        '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 2,  // Gasolina Aditivada
        'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 3,  // Diesel S500
        '58ce20cf-f252-4291-9ef6-f4821f22c29e': 4,  // Diesel S10
        '66ca957a-5698-4a02-8c9e-987770b6a151': 5,  // Etanol
        'f8e95435-471a-424c-947f-def8809053a0': 6,  // Gasolina A
        '4da89784-301f-4abe-b97e-c48729969e3d': 7,  // S500 A
        '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 8,  // S10 A
        'cecab8eb-297a-4640-81ae-e88335b88d8b': 9,  // Anidro
        'ecd91066-e763-42e3-8a0e-d982ea6da535': 10, // B100
      };

      produtos.sort((a, b) {
        final idA = a['id'].toString().toLowerCase();
        final idB = b['id']?.toString().toLowerCase() ?? '';

        return (ordemPorId[idA] ?? 999)
            .compareTo(ordemPorId[idB] ?? 999);
      });

      setState(() {
        _produtos = produtos;
      });
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
      setState(() {
        _produtos = [];
      });
    }
  }

  Future<void> _carregarFiliais() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('filiais')
          .select('id, nome_dois')
          .order('nome_dois');
      
      setState(() {
        _filiais = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar filiais: $e');
    }
  }

  // Funções para buscar dados (apenas para autocomplete)
  Future<List<Map<String, dynamic>>> _buscarMotoristas(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('motoristas')
        .select('id, nome')
        .ilike('nome', '%$texto%')
        .order('nome')
        .limit(10);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _buscarTransportadoras(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('transportadoras')
        .select('id, nome_dois')
        .ilike('nome_dois', '%$texto%')
        .order('nome_dois')
        .limit(10);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<String>> _buscarPlacas(String texto) async {
    if (texto.length < 3) return [];
    
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('vw_placas')
        .select('placa')
        .ilike('placa', '$texto%')
        .order('placa')
        .limit(10);

    return response.map<String>((p) => p['placa'].toString()).toList();
  }

  // Formatar quantidade no formato "999.999"
  String _aplicarMascaraQuantidade(String texto) {
    // Remove tudo que não é número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    // Limita a 6 dígitos (999.999)
    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }

    if (apenasNumeros.isEmpty) return '';

    // Aplica máscara 999.999
    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }

    return apenasNumeros;
  }  

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

  Future<void> _salvar() async {
    if (_produtoId == null ||
        _origemId == null ||
        _destinoId == null ||
        _quantidadeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os campos obrigatórios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_origemId == _destinoId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Origem e destino não podem ser iguais'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_empresaId == null || _usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário ou empresa não identificados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;

      // Buscar empresa_id da filial de origem para a ordem
      final filialResponse = await supabase
          .from('filiais')
          .select('empresa_id')
          .eq('id', _origemId!)
          .single();

      final empresaIdOrdem = filialResponse['empresa_id'];

      // Criar ordem primeiro (mesmo padrão da NovaVendaDialog)
      final hoje = DateTime.now();
      final dataMov = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      final ordemResponse = await supabase
          .from('ordens')
          .insert({
            'empresa_id': empresaIdOrdem,
            'filial_id': _origemId,  // Filial de origem
            'usuario_id': _usuarioId,
            'tipo': 'transferencia',
            'data_ordem': dataMov,
          })
          .select('id')
          .single();

      final ordemId = ordemResponse['id'];

      final quantidade =
          int.parse(_quantidadeController.text.replaceAll('.', ''));
      
      // Buscar nomes das filiais para a descrição
      final origemNome = _filiais
        .firstWhere(
          (f) => f['id']?.toString() == _origemId,
          orElse: () => {'nome_dois': ''},
        )['nome_dois']
        ?.toString() ??
        '';
      
      final destinoNome = _filiais
        .firstWhere(
          (f) => f['id']?.toString() == _destinoId,
          orElse: () => {'nome_dois': ''},
        )['nome_dois']
        ?.toString() ??
        '';

      // Coluna do produto específica (baseado no UUID)
      final colunaProduto = _resolverColunaProduto(_produtoId!);

      // placas
      final placas = <String>[];
      if (_cavaloController.text.isNotEmpty) placas.add(_cavaloController.text);
      if (_reboque1Controller.text.isNotEmpty) placas.add(_reboque1Controller.text);
      if (_reboque2Controller.text.isNotEmpty) placas.add(_reboque2Controller.text);

      // Criar UMA ÚNICA LINHA com todos os dados da transferência
      final transferencia = {
        'ordem_id': ordemId,
        'tipo_op': 'transf',
        'produto_id': _produtoId,
        'quantidade': quantidade,
        'descricao': '$origemNome → $destinoNome',  // Descrição formatada
        'placa': placas.isNotEmpty ? placas : null,
        'usuario_id': _usuarioId,
        'empresa_id': _empresaId,
        'motorista_id': _motoristaId,
        'transportadora_id': _transportadoraId,
        'data_mov': _dataSelecionada.toIso8601String().split('T')[0],
        'filial_origem_id': _origemId,
        'filial_destino_id': _destinoId,
        'updated_at': DateTime.now().toIso8601String(),
        
        // NOVOS CAMPOS - APENAS 1 LINHA
        'filial_id': null,            // NULL pois não é específico de uma filial
        'tipo_mov': null,             // NULL pois não usamos mais
        'tipo_mov_orig': 'saida',     // Movimento na origem
        'tipo_mov_dest': 'entrada',   // Movimento no destino
        
        // COLUNAS DE PRODUTO INICIALIZADAS COM 0
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
      
      // Atribuir quantidade apenas na coluna correta do produto
      transferencia[colunaProduto] = quantidade;

      // INSERIR APENAS 1 LINHA
      await supabase.from('movimentacoes').insert([transferencia]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transferência registrada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Erro ao salvar transferência: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Nova Transferência',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            
            const Divider(),
            const SizedBox(height: 16),
            
            // Campos do formulário
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Primeira linha: Data e Produto
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Campo Data (dropdown simples)
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            initialValue: _formatarData(_dataSelecionada),
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _datasFormatadas.map((dataStr) {
                              return DropdownMenuItem<String>(
                                value: dataStr,
                                child: Text(dataStr),
                              );
                            }).toList(),
                            onChanged: (dataString) {
                              if (dataString != null) {
                                // Encontrar o DateTime correspondente à string selecionada
                                final index = _datasFormatadas.indexOf(dataString);
                                if (index >= 0) {
                                  setState(() => _dataSelecionada = _datasDisponiveis[index]);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Campo Produto (dropdown simples)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _produtoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Produto *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _produtos.map((produto) {
                              return DropdownMenuItem<String>(
                                value: produto['id']?.toString(),
                                child: Text(produto['nome']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _produtoSelecionado = id;
                                _produtoId = id;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Campo Quantidade
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: _quantidadeController,
                            keyboardType: TextInputType.number,
                            maxLength: 7,
                            onChanged: (value) {
                              final maskedValue = _aplicarMascaraQuantidade(value);
                              
                              if (maskedValue != value) {
                                final cursorPosition = _quantidadeController.selection.baseOffset;
                                _quantidadeController.value = TextEditingValue(
                                  text: maskedValue,
                                  selection: TextSelection.collapsed(
                                    offset: cursorPosition + (maskedValue.length - value.length),
                                  ),
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Quantidade *',
                              border: OutlineInputBorder(),
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              suffixText: 'litros',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Segunda linha: Motorista e Transportadora (autocomplete)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AutocompleteField<Map<String, dynamic>>(
                            controller: _motoristaController,
                            label: 'Motorista',
                            buscarItens: _buscarMotoristas,
                            obterTextoExibicao: (item) => item['nome']?.toString() ?? '',
                            obterId: (item) => item['id']?.toString() ?? '',
                            validarParaBusca: (texto) => texto.length >= 3,
                            onSelecionado: (motorista) {
                              _motoristaId = motorista['id']?.toString();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AutocompleteField<Map<String, dynamic>>(
                            controller: _transportadoraController,
                            label: 'Transportadora',
                            buscarItens: _buscarTransportadoras,
                            obterTextoExibicao: (item) => item['nome_dois']?.toString() ?? '',
                            obterId: (item) => item['id']?.toString() ?? '',
                            validarParaBusca: (texto) => texto.length >= 3,
                            onSelecionado: (transportadora) {
                              _transportadoraId = transportadora['id']?.toString();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Terceira linha: Cavalo, Reboque 1, Reboque 2 (autocomplete)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AutocompleteField<String>(
                            controller: _cavaloController,
                            label: 'Cavalo',
                            buscarItens: _buscarPlacas,
                            obterTextoExibicao: (item) => item,
                            obterId: (item) => item,
                            validarParaBusca: (texto) => texto.length >= 3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AutocompleteField<String>(
                            controller: _reboque1Controller,
                            label: 'Reboque 1',
                            buscarItens: _buscarPlacas,
                            obterTextoExibicao: (item) => item,
                            obterId: (item) => item,
                            validarParaBusca: (texto) => texto.length >= 3,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AutocompleteField<String>(
                            controller: _reboque2Controller,
                            label: 'Reboque 2',
                            buscarItens: _buscarPlacas,
                            obterTextoExibicao: (item) => item,
                            obterId: (item) => item,
                            validarParaBusca: (texto) => texto.length >= 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Quarta linha: Origem e Destino (dropdown simples)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _origemSelecionada,
                            decoration: const InputDecoration(
                              labelText: 'Origem *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _filiais.map((filial) {
                              return DropdownMenuItem<String>(
                                value: filial['id']?.toString(),
                                child: Text(filial['nome_dois']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _origemSelecionada = id;
                                _origemId = id;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _destinoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Destino *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _filiais.map((filial) {
                              return DropdownMenuItem<String>(
                                value: filial['id']?.toString(),
                                child: Text(filial['nome_dois']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _destinoSelecionado = id;
                                _destinoId = id;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Aviso de campos obrigatórios
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '* Campos obrigatórios: Produto, Quantidade, Origem e Destino',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
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
            
            const SizedBox(height: 24),
            
            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(_salvando ? 'Salvando...' : 'Criar Ordem'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}