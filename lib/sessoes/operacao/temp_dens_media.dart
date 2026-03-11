import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> _terminais = [];
  String? _selectedTerminalId;
  bool _carregandoTerminais = true;
  
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();

  final ScrollController _verticalScrollController = ScrollController();

  // apenas o controlador vertical é necessário para a nova tabela

  @override
  void initState() {
    super.initState();

    // Preencher campo de data com a data atual
    final now = DateTime.now();
    _dataController.text = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // não são necessários listeners horizontais para a tabela simples

    // carregar lista de terminais para o dropdown
    _carregarTerminais();
  }

  @override
  void dispose() {
    // apenas dispose do controlador vertical
    _verticalScrollController.dispose();
    _dataController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _carregarTerminais() async {
    setState(() {
      _carregandoTerminais = true;
    });

    try {
      final resp = await _supabase
          .from('terminais')
          .select('id,nome')
          .order('nome', ascending: true)
          .limit(1000);

      final List<dynamic> lista = resp;

      setState(() {
        _terminais = lista.map<Map<String, dynamic>>((t) {
          return {
            'id': t['id']?.toString() ?? '',
            'nome': t['nome']?.toString() ?? '',
          };
        }).toList();

        // Selecionar automaticamente o primeiro terminal, se houver
        if (_terminais.isNotEmpty) {
          _selectedTerminalId = _terminais.first['id']?.toString();
        }

        _carregandoTerminais = false;
      });

      // Carregar dados usando o terminal selecionado (ou sem filtro se nenhum)
      _carregarDados();
    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _carregandoTerminais = false;
      });
    }
  }

  Future<void> _carregarDados({bool carregarMais = false}) async {
    if (carregarMais) return;

    setState(() {
      _carregando = true;
      _erro = false;
      _registros = [];
    });

    try {


      var query = _supabase
          .from('ordens_analises')
          .select('''
            id,
            terminal_id,
            data_criacao,
            densidade_observada,
            temperatura_amostra,
            temperatura_ct,
            produto_nome,
            placa_cavalo,
            terminais(nome),
            movimentacoes(cliente)
          ''');

      // Aplicar filtro por data (se preenchido). O campo `data_criacao` é timestamp
      // no formato YYYY-MM-DD HH:MI:SS, então filtramos pela faixa do dia
      // convertendo o texto 'DD/MM/YYYY' para DateTime e usando gte/lt.
      if (_dataController.text.isNotEmpty) {
        try {
          final parts = _dataController.text.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            final start = DateTime(year, month, day);
            final end = start.add(const Duration(days: 1));

            // usar ISO strings para comparação com timestamp
            query = query.gte('data_criacao', start.toIso8601String());
            query = query.lt('data_criacao', end.toIso8601String());
          }
        } catch (e) {
          debugPrint('Erro ao parsear data de filtro: ${_dataController.text} -> $e');
        }
      }

      final resp = await query.order('data_criacao', ascending: false).limit(1000);

      final List<dynamic> lista = resp;

      final registrosTransformados =
          lista.map<Map<String, dynamic>>((row) {

        String descricao = '';
        String placa = row['placa_cavalo']?.toString() ?? '';

        // ===== CORREÇÃO AQUI =====
        final movs = row['movimentacoes'];

        if (movs is List && movs.isNotEmpty) {
          descricao = movs.first['cliente']?.toString() ?? '';
        } 
        else if (movs is Map<String, dynamic>) {
          descricao = movs['cliente']?.toString() ?? '';
        }

        String terminalNome = '';
        final term = row['terminais'];

        if (term is Map<String, dynamic>) {
          terminalNome = term['nome']?.toString() ?? '';
        }

        return {
          'descricao': descricao,
          'placa': placa,
          'produto': row['produto_nome'],
          'densidade': row['densidade_observada'],
          'temp_amostra': row['temperatura_amostra'],
          'temp_ct': row['temperatura_ct'],
          'terminal': terminalNome,
          'terminal_id': row['terminal_id'],
        };
      }).toList();

      setState(() {
        _registros = registrosTransformados;
        _carregando = false;
      });

    } catch (e, stackTrace) {
      debugPrint('❌ ERRO NA CONSULTA');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      setState(() {
        _erro = true;
        _mensagemErro = e.toString();
        _carregando = false;
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
    final terminalFiltro = _selectedTerminalId;

    return _registros.where((r) {
      if (placaFiltro.isNotEmpty) {
        final placa = r['placa']?.toString().toLowerCase() ?? '';
        if (!placa.contains(placaFiltro)) return false;
      }

      if (terminalFiltro != null && terminalFiltro.isNotEmpty) {
        final recTerminalId = r['terminal_id']?.toString() ?? '';
        if (recTerminalId != terminalFiltro) return false;
      }

      return true;
    }).toList();
  }

  // removed layout helpers no longer used by the simplified list view

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
    return SizedBox(
      height: 40,
      child: Builder(builder: (context) {
        final textoData = _dataController.text.isNotEmpty
            ? _dataController.text
            : 'Data';

        return InkWell(
            onTap: () async {
            final now = DateTime.now();
            final data = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2000),
              lastDate: DateTime(now.year + 1),
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

            if (data != null) {
              setState(() {
                _dataController.text = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
              });
              _carregarDados();
            }
          },
          borderRadius: BorderRadius.circular(4),
            child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Center(
              child: Text(
                textoData,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }),
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

  Widget _buildTerminalDropdown() {
    return Container(
      width: 200,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Icon(Icons.store, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: _carregandoTerminais
                ? const SizedBox(
                    height: 20,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _selectedTerminalId,
                      hint: const Text('Terminal', style: TextStyle(fontSize: 13)),
                      items: _terminais.map((t) {
                        return DropdownMenuItem<String?>(
                          value: t['id']?.toString(),
                          child: Text(
                            t['nome']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedTerminalId = v;
                        });
                        _carregarDados();
                      },
                    ),
                  ),
          ),
          if (_selectedTerminalId != null && _selectedTerminalId!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                setState(() {
                  _selectedTerminalId = null;
                });
                _carregarDados();
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
                Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildTerminalDropdown(),
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
                : _buildTable(registros),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> registros) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 0),
          child: Column(
            children: [
            // Cabeçalho da tabela (mesmo estilo de estoque_tanques_geral)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF222B45),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Descrição',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Placa',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Produto',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Densidade Obs.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Temp. da amostra',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Temp. do CT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Linhas
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Column(
                  children: List.generate(registros.length, (index) {
                    final r = registros[index];
                    final isEven = index.isEven;
                    return Container(
                      color: isEven ? const Color(0xFFF0F1F6) : const Color(0xFFF8F9FA),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Text(
                                r['descricao']?.toString() ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF222B45),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['placa']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['produto']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['densidade']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['temp_amostra']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['temp_ct']?.toString() ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  // funções de agrupamento e tabela antiga removidas — mantemos apenas a tabela simples
}