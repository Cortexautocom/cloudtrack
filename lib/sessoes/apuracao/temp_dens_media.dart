import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_page.dart';

class TemperaturaDensidadeMediaPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const TemperaturaDensidadeMediaPage({super.key, this.onVoltar});

  @override
  State<TemperaturaDensidadeMediaPage> createState() =>
      _TemperaturaDensidadeMediaPageState();
}

class _TemperaturaDensidadeMediaPageState
    extends State<TemperaturaDensidadeMediaPage> {
  List<Map<String, dynamic>> _registros = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  final int _pageSize = 50;
  int _totalCount = 0;

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Larguras base (mínimas)
  static const double baseHorario = 110;
  static const double baseTq = 95;
  static const double basePlacas = 200;
  static const double baseProduto = 180;
  static const double baseEditavel = 85;

  static const double margemLateral = 50;

  // Períodos fixos das 7:00 às 21:00
  final List<String> _periodosFixos = [
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

    // Definir data inicial como hoje
    final hoje = DateTime.now();
    _dataController.text =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';

    // Carregar dados inicialmente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDados();
    });
  }

  Future<void> _carregarDados({bool resetPage = true}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final usuario = UsuarioAtual.instance;

      if (usuario == null || usuario.filialId == null || usuario.empresaId == null) {
        throw Exception('Usuário não autenticado ou sem filial/empresa definida');
      }

      // Parse data do filtro
      DateTime? dataFiltro;
      if (_dataController.text.isNotEmpty) {
        final parts = _dataController.text.split('/');
        if (parts.length == 3) {
          dataFiltro = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }

      // Calcular offset para paginação
      final from = (_currentPage - 1) * _pageSize;
      final to = from + _pageSize - 1;

      // Construir query base usando a sintaxe correta
      var query = _supabase
          .from('movimentacoes')
          .select('''
          id,
          data_carga,
          placa,
          produto_id,
          produtos!inner(nome),
          filial_origem_id,
          tipo_mov_orig,
          status_circuito,
          empresa_id
        ''');

      // Aplicar filtros - mesma sintaxe do exemplo fornecido
      query = query.eq('filial_origem_id', usuario.filialId!);
      query = query.eq('empresa_id', usuario.empresaId!);
      query = query.eq('tipo_mov_orig', 'saida');
      
      // Para filtrar status_circuito = 4 ou 5, usamos .or() com filtros
      query = query.or('status_circuito.eq.4,status_circuito.eq.5');

      // Aplicar filtro de data se existir
      if (dataFiltro != null) {
        final dataInicio = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day, 0, 0, 0);
        final dataFim = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day, 23, 59, 59);
        
        // Converter para UTC para o Supabase
        final dataInicioUtc = dataInicio.toUtc().toIso8601String();
        final dataFimUtc = dataFim.toUtc().toIso8601String();
        
        // Usar .gte() e .lte() diretamente
        query = query.gte('data_carga', dataInicioUtc);
        query = query.lte('data_carga', dataFimUtc);
      }

      // Aplicar filtro de placa
      final placaFiltro = _placaController.text.trim();
      if (placaFiltro.isNotEmpty) {
        // Para filtrar em array, usamos .cs() (contains) para verificar se o array contém o valor
        query = query.contains('placa', [placaFiltro.toUpperCase()]);
      }

      // Ordenar e aplicar paginação
      query = query.order('data_carga', ascending: true);
      query = query.range(from, to);

      final response = await query;

      // Para obter o total de registros, fazer uma consulta de contagem separada
      var countQuery = _supabase
          .from('movimentacoes')
          .select('*', const FetchOptions(count: CountOption.exact));

      // Aplicar os mesmos filtros da consulta principal
      countQuery = countQuery.eq('filial_origem_id', usuario.filialId!);
      countQuery = countQuery.eq('empresa_id', usuario.empresaId!);
      countQuery = countQuery.eq('tipo_mov_orig', 'saida');
      countQuery = countQuery.or('status_circuito.eq.4,status_circuito.eq.5');

      if (dataFiltro != null) {
        final dataInicio = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day, 0, 0, 0);
        final dataFim = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day, 23, 59, 59);
        final dataInicioUtc = dataInicio.toUtc().toIso8601String();
        final dataFimUtc = dataFim.toUtc().toIso8601String();
        
        countQuery = countQuery.gte('data_carga', dataInicioUtc);
        countQuery = countQuery.lte('data_carga', dataFimUtc);
      }

      if (placaFiltro.isNotEmpty) {
        countQuery = countQuery.contains('placa', [placaFiltro.toUpperCase()]);
      }

      final countResponse = await countQuery;
      final count = countResponse.length;
      _totalCount = count;
      _totalPages = (count / _pageSize).ceil();
      if (_totalPages == 0) _totalPages = 1;

      // Processar resultados
      final dados = response as List<dynamic>;
      final registros = <Map<String, dynamic>>[];

      for (final item in dados) {
        final map = Map<String, dynamic>.from(item as Map);
        
        // Formatar placas
        final placasArray = map['placa'] as List<dynamic>? ?? [];
        final placasFormatadas = placasArray.map((p) => p.toString()).toList();
        
        // Extrair nome do produto
        final produto = map['produtos'] as Map<String, dynamic>?;
        final nomeProduto = produto?['nome']?.toString() ?? '';

        // Converter data_carga para DateTime local
        DateTime? dataCarga;
        try {
          if (map['data_carga'] != null) {
            dataCarga = DateTime.parse(map['data_carga']).toLocal();
          }
        } catch (e) {
          debugPrint('Erro ao parse data_carga: $e');
        }

        registros.add({
          'id': map['id'],
          'data_carga': dataCarga,
          'placas': placasFormatadas,
          'produto': nomeProduto,
          'tanque_operacao': '', // Campo para o usuário preencher
        });
      }

      setState(() {
        _registros = registros;
        _isLoading = false;
      });

    } catch (error) {
      debugPrint('❌ Erro ao carregar dados: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
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

  // ----------------- FILTRO -----------------

  List<Map<String, dynamic>> get _registrosFiltrados {
    final placaFiltro = _placaController.text.trim().toLowerCase();

    return _registros.where((r) {
      if (placaFiltro.isNotEmpty) {
        final placas = (r['placas'] as List<String>)
            .join(' ')
            .toLowerCase();
        return placas.contains(placaFiltro);
      }
      return true;
    }).toList();
  }

  // ----------------- CÁLCULO DINÂMICO DE LARGURAS -----------------

  Map<String, double> _calcularLarguras(double larguraDisponivel) {
    final larguraMinima = baseHorario +
        baseTq +
        basePlacas +
        baseProduto +
        (baseEditavel * 4);

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

  // ----------------- AGRUPAMENTO POR PERÍODO -----------------

  Map<String, List<Map<String, dynamic>>> _agruparPorPeriodo(
      List<Map<String, dynamic>> itens) {
    final grupos = <String, List<Map<String, dynamic>>>{};

    // Inicializar todos os períodos
    for (final periodo in _periodosFixos) {
      grupos[periodo] = [];
    }

    // Agrupar movimentações por período
    for (final r in itens) {
      final dt = r['data_carga'] as DateTime?;
      if (dt == null) continue;

      final hora = dt.hour;
      final minuto = dt.minute;

      // Encontrar período correto
      String? periodoEncontrado;
      for (final periodo in _periodosFixos) {
        final partes = periodo.split(' - ');
        if (partes.length != 2) continue;

        final horaInicio = int.parse(partes[0].split(':')[0]);
        final horaFim = int.parse(partes[1].split(':')[0]);

        // Verificar se está dentro do período
        if (hora >= horaInicio && hora < horaFim) {
          periodoEncontrado = periodo;
          break;
        }
        // Para último período (20:00-21:00), incluir 21:00 também
        else if (hora == 21 && horaInicio == 20 && minuto == 0) {
          periodoEncontrado = periodo;
          break;
        }
      }

      if (periodoEncontrado != null) {
        grupos[periodoEncontrado]!.add(r);
      }
    }

    return grupos;
  }

  // ----------------- PAGINAÇÃO -----------------

  Widget _buildPaginacao() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1
              ? () {
                  _currentPage--;
                  _carregarDados(resetPage: false);
                }
              : null,
        ),
        Text(
          '$_currentPage de $_totalPages (${_totalCount} registros)',
          style: const TextStyle(fontSize: 14),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages
              ? () {
                  _currentPage++;
                  _carregarDados(resetPage: false);
                }
              : null,
        ),
      ],
    );
  }

  // ----------------- UI HELPERS -----------------

  Widget _th(String texto, double largura) {
    return SizedBox(
      width: largura,
      child: Center(
        child: Text(
          texto,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _cell(String texto, double largura) {
    return SizedBox(
      width: largura,
      child: Center(
        child: Text(
          texto,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }

  Widget _editableCell(double largura) {
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registros = _registrosFiltrados;
    final grupos = _agruparPorPeriodo(registros);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: margemLateral),
        child: Column(
          children: [
            // TOPO
            Container(
              height: kToolbarHeight + MediaQuery.of(context).padding.top,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
              ),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onVoltar,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Temperatura e Densidade Média',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Botão de refresh
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : () => _carregarDados(),
                    tooltip: 'Recarregar dados',
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _dataController,
                      onChanged: (_) => _carregarDados(),
                      decoration: const InputDecoration(
                        hintText: 'DD/MM/AAAA',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _placaController,
                      onChanged: (_) => _carregarDados(),
                      decoration: const InputDecoration(
                        hintText: 'Placa',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.shade300),

            // PAGINAÇÃO
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildPaginacao(),
            ),

            // TABELA
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final larguraDisponivel = constraints.maxWidth.toDouble();
                            final larguras = _calcularLarguras(larguraDisponivel);
                            final colHorario = larguras['horario']!;
                            final colTq = larguras['tq']!;
                            final colPlacas = larguras['placas']!;
                            final colProduto = larguras['produto']!;
                            final colEditavel = larguras['editavel']!;
                            final larguraTabela = larguras['total']!;

                            return SingleChildScrollView(
                              controller: _horizontalHeaderController,
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                height: 40,
                                width: larguraTabela,
                                color: Colors.blue.shade900,
                                child: Row(
                                  children: [
                                    _th('Horário', colHorario),
                                    _th('TQ operação', colTq),
                                    _th('Placas', colPlacas),
                                    _th('Produto', colProduto),
                                    _th('Temp. Tanque', colEditavel),
                                    _th('Dens. Tanque', colEditavel),
                                    _th('Temp. Amostra', colEditavel),
                                    _th('Dens. Amostra', colEditavel),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final larguraDisponivel = constraints.maxWidth.toDouble();
                              final larguras = _calcularLarguras(larguraDisponivel);
                              final colHorario = larguras['horario']!;
                              final colTq = larguras['tq']!;
                              final colPlacas = larguras['placas']!;
                              final colProduto = larguras['produto']!;
                              final colEditavel = larguras['editavel']!;
                              final larguraTabela = larguras['total']!;

                              return SingleChildScrollView(
                                controller: _verticalScrollController,
                                child: SingleChildScrollView(
                                  controller: _horizontalBodyController,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: larguraTabela,
                                    child: Column(
                                      children: _periodosFixos.expand((periodo) {
                                        final itens = grupos[periodo] ?? [];
                                        
                                        // Ordenar itens dentro do período
                                        itens.sort((a, b) {
                                          final dtA = a['data_carga'] as DateTime?;
                                          final dtB = b['data_carga'] as DateTime?;
                                          if (dtA == null && dtB == null) return 0;
                                          if (dtA == null) return -1;
                                          if (dtB == null) return 1;
                                          return dtA.compareTo(dtB);
                                        });

                                        return [
                                          Container(
                                            height: 34,
                                            width: larguraTabela,
                                            color: Colors.grey.shade300,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              periodo,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12),
                                            ),
                                          ),
                                          if (itens.isEmpty)
                                            Container(
                                              height: 40,
                                              color: Colors.white,
                                              child: Center(
                                                child: Text(
                                                  'Nenhuma movimentação neste período',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            ...List.generate(itens.length, (i) {
                                              final r = itens[i];
                                              final dt = r['data_carga'] as DateTime?;
                                              return Container(
                                                height: 46,
                                                color: i.isEven
                                                    ? Colors.grey.shade50
                                                    : Colors.white,
                                                child: Row(
                                                  children: [
                                                    _cell(
                                                      dt != null
                                                          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                                          : '--:--',
                                                      colHorario,
                                                    ),
                                                    _cell(
                                                      r['tanque_operacao']?.toString() ?? '',
                                                      colTq,
                                                    ),
                                                    _cell(
                                                      (r['placas'] as List<String>)
                                                          .join(' / '),
                                                      colPlacas,
                                                    ),
                                                    _cell(
                                                      r['produto'].toString(),
                                                      colProduto,
                                                    ),
                                                    _editableCell(colEditavel),
                                                    _editableCell(colEditavel),
                                                    _editableCell(colEditavel),
                                                    _editableCell(colEditavel),
                                                  ],
                                                ),
                                              );
                                            }),
                                        ];
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
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