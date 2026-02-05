import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'dart:convert';

class TemperaturaDensidadeMediaPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const TemperaturaDensidadeMediaPage({super.key, this.onVoltar});

  @override
  State<TemperaturaDensidadeMediaPage> createState() =>
      _TemperaturaDensidadeMediaPageState();
}

class _TemperaturaDensidadeMediaPageState
    extends State<TemperaturaDensidadeMediaPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _registros = [];
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Larguras base (mínimas)
  static const double baseHorario = 110;
  static const double baseTq = 95; // 🆕 TQ operação
  static const double basePlacas = 200;
  static const double baseProduto = 180;
  static const double baseEditavel = 85;

  static const double margemLateral = 50;
  
  int _paginaAtual = 0;
  final int _limitePorPagina = 50;
  bool _temMaisPaginas = true;
  bool _carregandoMais = false;

  @override
  void initState() {
    super.initState();

    _horizontalHeaderController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset !=
              _horizontalHeaderController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset !=
              _horizontalBodyController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
      }
    });

    _carregarDados();
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    _verticalScrollController.dispose();
    _dataController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados({bool carregarMais = false}) async {
    if (carregarMais) {
      if (!_temMaisPaginas || _carregandoMais) return;
      setState(() => _carregandoMais = true);
    } else {
      setState(() {
        _carregando = true;
        _erro = false;
        _paginaAtual = 0;
        _temMaisPaginas = true;
        if (!carregarMais) {
          _registros = []; // Limpa registros ao recarregar
        }
      });
    }

    try {
      // Obter usuário atual da instância global
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        throw Exception('Usuário não autenticado. Faça login novamente.');
      }

      final filialId = usuario.filialId;
      final empresaId = usuario.empresaId;

      if (filialId == null || filialId.isEmpty || empresaId == null || empresaId.isEmpty) {
        throw Exception('Filial ou empresa não configurada para o usuário');
      }

      debugPrint('🔍 Consultando para filial: $filialId, empresa: $empresaId');

      // Converter filtro de data
      DateTime? dataFiltro;
      if (_dataController.text.trim().isNotEmpty) {
        try {
          final partes = _dataController.text.trim().split('/');
          if (partes.length == 3) {
            dataFiltro = DateTime(
              int.parse(partes[2]),
              int.parse(partes[1]),
              int.parse(partes[0]),
            );
          } else if (_dataController.text.trim().contains('-')) {
            dataFiltro = DateTime.parse(_dataController.text.trim());
          }
        } catch (e) {
          debugPrint("Erro ao converter data: $e");
        }
      }
      
      // Se não houver filtro de data, usa data atual
      dataFiltro ??= DateTime.now();
      final dataInicio = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day);
      final dataFim = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day, 23, 59, 59);

      debugPrint('📅 Data consulta: ${dataInicio.toIso8601String()} até ${dataFim.toIso8601String()}');

      // Consulta movimentações - ADICIONAR DEBUG
      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_carga,
            placa,
            produto_id,
            tipo_mov_orig,
            status_circuito,
            produtos!inner(nome)
          ''')
          .eq('filial_origem_id', filialId)
          .eq('tipo_mov_orig', 'saida')
          .eq('empresa_id', empresaId)
          .inFilter('status_circuito', ['4', '5'])
          .gte('data_carga', dataInicio.toIso8601String())
          .lte('data_carga', dataFim.toIso8601String())
          .order('data_carga', ascending: true)
          .range(
            _paginaAtual * _limitePorPagina,
            (_paginaAtual * _limitePorPagina) + _limitePorPagina - 1,
          );

      debugPrint('📋 Query SQL: $query');
      
      final response = await query;

      debugPrint('📊 Resposta recebida: ${response.length} registros');
      debugPrint('📊 Dados brutos: ${response.toString()}');

      final List<Map<String, dynamic>> lista = List<Map<String, dynamic>>.from(response);

      // Verificar se há mais páginas
      final temMais = lista.length >= _limitePorPagina;

      // Transformar os dados para o formato da página
      final registrosTransformados = lista.map((mov) {
        final dataCarga = mov['data_carga'] is String
            ? DateTime.parse(mov['data_carga'])
            : mov['data_carga'] as DateTime? ?? DateTime.now();
        
        debugPrint('📝 Processando movimentação: ${mov['id']}, data: $dataCarga');
        
        // Processar placas - COMO É ARRAY DE TEXTO, JÁ VEM COMO LIST
        List<String> placas = [];
        
        if (mov['placa'] != null) {
          debugPrint('🚗 Placa bruta: ${mov['placa']}, tipo: ${mov['placa'].runtimeType}');
          
          if (mov['placa'] is List) {
            // Já é uma lista (array de texto do PostgreSQL)
            final listaPlacas = mov['placa'] as List;
            placas = listaPlacas
                .where((placa) => placa.toString().isNotEmpty)
                .map((placa) => placa.toString())
                .toList();
          } else if (mov['placa'] is String) {
            // Pode ser uma string JSON (fallback)
            final placaString = mov['placa'] as String;
            try {
              if (placaString.startsWith('[')) {
                final dynamic parsed = jsonDecode(placaString);
                if (parsed is List) {
                  placas = parsed
                      .where((placa) => placa.toString().isNotEmpty)
                      .map((placa) => placa.toString())
                      .toList();
                }
              } else {
                if (placaString.isNotEmpty) {
                  placas = [placaString];
                }
              }
            } catch (e) {
              if (placaString.isNotEmpty) {
                placas = [placaString];
              }
            }
          }
        }

        // Garantir que temos pelo menos uma string vazia se não houver placas
        if (placas.isEmpty) {
          placas = [''];
        }

        final produtoNome = mov['produtos']?['nome']?.toString() ?? 'Produto não identificado';
        debugPrint('✅ Registro processado: ${dataCarga.hour}:${dataCarga.minute}, placas: $placas, produto: $produtoNome');

        return {
          'data_carga': dataCarga,
          'placas': placas,
          'produto': produtoNome,
          'tanque_operacao': '', // Inicialmente vazio para usuário preencher
          'movimentacao_id': mov['id'], // Guardar ID para referência futura
        };
      }).toList();

      debugPrint('🎯 Total registros transformados: ${registrosTransformados.length}');

      setState(() {
        if (carregarMais) {
          _registros.addAll(registrosTransformados);
        } else {
          _registros = registrosTransformados;
        }
        
        _temMaisPaginas = temMais;
        if (temMais && registrosTransformados.isNotEmpty) {
          _paginaAtual++;
        }
        
        _carregando = false;
        _carregandoMais = false;
      });

      debugPrint('📊 Estado final: ${_registros.length} registros na memória');

    } catch (e, stackTrace) {
      debugPrint("❌ Erro ao carregar temperatura e densidade média: $e");
      debugPrint("📝 Stack trace: $stackTrace");
      
      setState(() {
        _erro = true;
        _mensagemErro = e.toString();
        _carregando = false;
        _carregandoMais = false;
      });
      
      if (!carregarMais && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ----------------- FILTRO -----------------

  List<Map<String, dynamic>> get _registrosFiltrados {
    final placaFiltro = _placaController.text.trim().toLowerCase();
    final dataFiltro = _dataController.text.trim();

    return _registros.where((r) {
      bool ok = true;

      if (placaFiltro.isNotEmpty) {
        final placas = (r['placas'] as List<String>? ?? []).join(' ').toLowerCase();
        ok = placas.contains(placaFiltro);
      }

      if (ok && dataFiltro.isNotEmpty) {
        final dt = r['data_carga'] as DateTime?;
        if (dt == null) return false;

        final s1 =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        final s2 =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

        ok = s1.contains(dataFiltro) || s2.contains(dataFiltro);
      }

      return ok;
    }).toList();
  }

  // ----------------- CÁLCULO DINÂMICO DE LARGURAS -----------------

  Map<String, double> _calcularLarguras(double larguraDisponivel) {
    final larguraMinima =
        baseHorario + baseTq + basePlacas + baseProduto + (baseEditavel * 4);

    double horario = baseHorario;
    double tq = baseTq;
    double placas = basePlacas;
    double produto = baseProduto;
    double editavel = baseEditavel;

    if (larguraDisponivel > larguraMinima) {
      final sobra = larguraDisponivel - larguraMinima;

      placas += sobra * 0.22;
      produto += sobra * 0.18;
      tq += sobra * 0.10;
      editavel += (sobra * 0.50) / 4;
    }

    return {
      'horario': horario,
      'tq': tq,
      'placas': placas,
      'produto': produto,
      'editavel': editavel,
      'total': horario + tq + placas + produto + (editavel * 4),
    };
  }

  // ----------------- AGRUPAMENTO -----------------

  Map<String, List<Map<String, dynamic>>> _agruparPorHora(
      List<Map<String, dynamic>> itens) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    
    // Períodos fixos das 7:00 às 21:00
    final periodos = [
      '07:00 - 08:00',
      '08:00 - 09:00',
      '09:00 - 10:00',
      '10:00 - 11:00',
      '11:00 - 12:00',
      '12:00 - 13:00',
      '13:00 - 14:00',
      '14:00 - 15:00',
      '15:00 - 16:00',
      '16:00 - 17:00',
      '17:00 - 18:00',
      '18:00 - 19:00',
      '19:00 - 20:00',
      '20:00 - 21:00',
    ];

    // Inicializar todos os períodos
    for (final periodo in periodos) {
      grupos[periodo] = [];
    }

    // Distribuir itens pelos períodos
    for (final r in itens) {
      final dt = r['data_carga'] as DateTime?;
      if (dt == null) continue;

      final hora = dt.hour;
      
      // Encontrar período correspondente
      String? periodoEncontrado;
      for (final periodo in periodos) {
        final horaIni = int.parse(periodo.substring(0, 2));
        if (hora == horaIni) {
          periodoEncontrado = periodo;
          break;
        }
      }
      
      if (periodoEncontrado != null) {
        grupos[periodoEncontrado]!.add(r);
      }
    }

    // Ordenar itens dentro de cada período pela data_carga
    for (final periodo in periodos) {
      grupos[periodo]!.sort((a, b) {
        final dtA = a['data_carga'] as DateTime;
        final dtB = b['data_carga'] as DateTime;
        return dtA.compareTo(dtB);
      });
    }

    // Remover períodos vazios
    final gruposFiltrados = Map<String, List<Map<String, dynamic>>>.fromEntries(
      grupos.entries.where((entry) => entry.value.isNotEmpty)
    );

    return gruposFiltrados;
  }

  // ----------------- UI HELPERS -----------------

  Widget _th(String texto, double largura) {
    return SizedBox(
      width: largura,
      child: Center(
        child: Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _cell(String texto, double largura) {
    return SizedBox(
      width: largura,
      child: Center(
        child: Text(texto, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _editableCell(double largura, String campo, int index, String faixa) {
    return SizedBox(
      width: largura,
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SizedBox(
            width: largura,
            height: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade700, width: 1.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextField(
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onChanged: (value) {
                  // Aqui será implementada a lógica para salvar no banco
                  // quando a integração dos campos editáveis for feita
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Carregando temperatura e densidade...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _carregarDados(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.thermostat_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma movimentação encontrada',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 119, 119, 119),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dataController.text.isEmpty
                ? 'Para hoje'
                : 'Para a data ${_dataController.text}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------- WIDGET DE PESQUISA (IGUAL AO DA PROGRAMAÇÃO) -----------------

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
          Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _dataController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'DD/MM/AAAA',
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
          if (_dataController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _dataController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildPlacaSearchField() {
    return Container(
      width: 200,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.directions_car, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _placaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Placa',
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
          if (_placaController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _placaController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _registros.isEmpty) {
      return _buildCarregando();
    }

    if (_erro && _registros.isEmpty) {
      return _buildErro();
    }

    final registros = _registrosFiltrados;
    final grupos = _agruparPorHora(registros);
    final chavesOrdenadas = grupos.keys.toList()..sort();

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // AppBar personalizada FIXA (igual à da Programação)
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
                // Título alinhado à esquerda
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Temperatura e Densidade Média',
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
                // Campos de busca
                Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSearchField(),
                ),
                Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildPlacaSearchField(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: () => _carregarDados(),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          // Linha divisória opcional
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          // Resto do conteúdo
          Expanded(
            child: registros.isEmpty
                ? _buildVazio()
                : _buildBodyContent(grupos, chavesOrdenadas),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    Map<String, List<Map<String, dynamic>>> grupos,
    List<String> chavesOrdenadas,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraDisponivel = constraints.maxWidth - (margemLateral * 2);
        final larguras = _calcularLarguras(larguraDisponivel);

        final colHorario = larguras['horario']!;
        final colTq = larguras['tq']!;
        final colPlacas = larguras['placas']!;
        final colProduto = larguras['produto']!;
        final colEditavel = larguras['editavel']!;
        final larguraTabela = larguras['total']!;

        return Column(
          children: [
            // Cabeçalho da tabela - FIXO
            _buildFixedHeader(larguraTabela, colHorario, colTq, colPlacas, colProduto, colEditavel),
            
            // Corpo rolável da tabela
            Expanded(
              child: _buildScrollableTable(
                grupos,
                chavesOrdenadas,
                larguraTabela,
                colHorario,
                colTq,
                colPlacas,
                colProduto,
                colEditavel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFixedHeader(
    double larguraTabela,
    double colHorario,
    double colTq,
    double colPlacas,
    double colProduto,
    double colEditavel,
  ) {
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
            color: Colors.blue.shade900,
            child: Row(
              children: [
                _th('Horário', colHorario),
                _th('TQ operação', colTq),
                _th('Placas', colPlacas),
                _th('Produto', colProduto),
                _th('Temp. CT', colEditavel),
                _th('Dens. Amostra', colEditavel),
                _th('Temp. Amostra', colEditavel),
                _th('Dens. Amostra', colEditavel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableTable(
    Map<String, List<Map<String, dynamic>>> grupos,
    List<String> chavesOrdenadas,
    double larguraTabela,
    double colHorario,
    double colTq,
    double colPlacas,
    double colProduto,
    double colEditavel,
  ) {
    return Scrollbar(
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
              width: larguraTabela,
              child: Column(
                children: [
                  ...chavesOrdenadas.expand((faixa) {
                    final itens = grupos[faixa]!;
                    return [
                      Container(
                        height: 34,
                        width: larguraTabela,
                        color: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faixa,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ...List.generate(itens.length, (i) {
                        final r = itens[i];
                        final dt = r['data_carga'] as DateTime;
                        return Container(
                          height: 46,
                          color: Colors.white,
                          child: Row(
                            children: [
                              _cell(
                                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                colHorario,
                              ),
                              SizedBox(
                                width: colTq,
                                child: Center(
                                  child: TextField(
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: '',
                                    ),
                                    onChanged: (value) {
                                      // Salvar TQ operação quando implementado
                                    },
                                  ),
                                ),
                              ),
                              _cell(
                                (r['placas'] as List<String>)
                                    .join(' / '),
                                colPlacas,
                              ),
                              _cell(
                                r['produto'],
                                colProduto,
                              ),
                              _editableCell(colEditavel, 'Temp. Tanque', i, faixa),
                              _editableCell(colEditavel, 'Dens. Tanque', i, faixa),
                              _editableCell(colEditavel, 'Temp. Amostra', i, faixa),
                              _editableCell(colEditavel, 'Dens. Amostra', i, faixa),
                            ],
                          ),
                        );
                      }),
                    ];
                  }).toList(),
                  if (_carregandoMais)
                    Container(
                      height: 60,
                      color: Colors.white,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (!_temMaisPaginas && _registrosFiltrados.isNotEmpty)
                    Container(
                      height: 40,
                      color: Colors.grey.shade50,
                      alignment: Alignment.center,
                      child: Text(
                        'Fim dos registros (${_registrosFiltrados.length} total)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}