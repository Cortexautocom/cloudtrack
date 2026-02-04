import 'package:flutter/material.dart';

// =============================================================
//  PÁGINA: TEMPERATURA E DENSIDADE MÉDIA
//  - Coluna extra: "TQ operação" após Horário
//  - Margem lateral de 50px
//  - Largura total da tabela ocupa a área útil (sem sobra no final)
//  - Inputs não vazam da célula
//  - Redistribuição de espaço entre colunas
//  - Filtro funcional por PLACA ou DATA
// =============================================================

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

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Larguras base (mínimas)
  static const double baseHorario = 110;
  static const double baseTq = 95;        // 🆕 TQ operação
  static const double basePlacas = 200;
  static const double baseProduto = 180;
  static const double baseEditavel = 85;

  static const double margemLateral = 50;

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
        _horizontalHeaderController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    // MOCK
    _registros = List.generate(12, (i) {
      return {
        'data_carga':
            DateTime.now().subtract(Duration(minutes: 20 * i)),
        'placas': ['ABC1D23', 'EFG4H56', 'IJK7L89'],
        'produto': i.isEven ? 'Diesel S10' : 'Gasolina Comum',
        'tanque_operacao': i % 11, // 0 a 10
      };
    });
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
    final dataFiltro = _dataController.text.trim();

    return _registros.where((r) {
      bool ok = true;

      if (placaFiltro.isNotEmpty) {
        final placas = (r['placas'] as List<String>? ?? [])
            .join(' ')
            .toLowerCase();
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
      'total':
          horario + tq + placas + produto + (editavel * 4),
    };
  }

  // ----------------- AGRUPAMENTO -----------------

  Map<String, List<Map<String, dynamic>>> _agruparPorHora(
      List<Map<String, dynamic>> itens) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final r in itens) {
      final dt = r['data_carga'] as DateTime?;
      if (dt == null) continue;

      final hIni = dt.hour.toString().padLeft(2, '0');
      final hFim = (dt.hour + 1).toString().padLeft(2, '0');
      final chave = '$hIni:00 - $hFim:00';

      grupos.putIfAbsent(chave, () => []);
      grupos[chave]!.add(r);
    }
    return grupos;
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
        child: Text(texto, style: const TextStyle(fontSize: 12)),
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
    final grupos = _agruparPorHora(registros);
    final chavesOrdenadas = grupos.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraDisponivel =
            constraints.maxWidth - (margemLateral * 2);

        final larguras = _calcularLarguras(larguraDisponivel);

        final colHorario = larguras['horario']!;
        final colTq = larguras['tq']!;
        final colPlacas = larguras['placas']!;
        final colProduto = larguras['produto']!;
        final colEditavel = larguras['editavel']!;
        final larguraTabela = larguras['total']!;

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
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _dataController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Data',
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
                          onChanged: (_) => setState(() {}),
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

                // TABELA
                Expanded(
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        controller: _horizontalHeaderController,
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          height: 40,
                          width: larguraTabela,
                          color: Colors.blue.shade900,
                          child: Row(
                            children: [
                              _th('Horário', colHorario),
                              _th('TQ operação', colTq), // 🆕
                              _th('Placas', colPlacas),
                              _th('Produto', colProduto),
                              _th('Temp. Tanque', colEditavel),
                              _th('Dens. Tanque', colEditavel),
                              _th('Temp. Amostra', colEditavel),
                              _th('Dens. Amostra', colEditavel),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: SingleChildScrollView(
                            controller: _horizontalBodyController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: larguraTabela,
                              child: Column(
                                children: chavesOrdenadas.expand((faixa) {
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
                                            fontSize: 12),
                                      ),
                                    ),
                                    ...List.generate(itens.length, (i) {
                                      final r = itens[i];
                                      final dt = r['data_carga'] as DateTime;
                                      return Container(
                                        height: 46,
                                        color: i.isEven
                                            ? Colors.grey.shade50
                                            : Colors.white,
                                        child: Row(
                                          children: [
                                            _cell(
                                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                              colHorario,
                                            ),
                                            _cell(
                                              '${r['tanque_operacao']}',
                                              colTq,
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
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
