import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';  

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
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Preencher campo de data com a data atual
    final now = DateTime.now();
    _dataController.text = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Carregar dados diretamente usando o terminal do usuário
    _carregarDados();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _dataController.dispose();
    _placaController.dispose();
    super.dispose();
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
            movimentacoes!inner(cliente, descricao, tipo_mov)
          ''');

      // Aplicar filtro por terminal baseado no usuário logado
      // Se o usuário for admin (nivel >= 3), não aplica filtro de terminal
      if (UsuarioAtual.instance != null && 
          UsuarioAtual.instance!.nivel < 3 && 
          UsuarioAtual.instance!.terminalId != null) {
        query = query.eq('terminal_id', UsuarioAtual.instance!.terminalId!);
      }

      // Aplicar filtro por data (se preenchido)
      if (_dataController.text.isNotEmpty) {
        try {
          final parts = _dataController.text.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            final start = DateTime(year, month, day);
            final end = start.add(const Duration(days: 1));

            query = query.gte('data_criacao', start.toIso8601String());
            query = query.lt('data_criacao', end.toIso8601String());
          }
        } catch (e) {
          debugPrint('Erro ao parsear data de filtro: ${_dataController.text} -> $e');
        }
      }

      // Adicionar filtro para tipo_mov = 'saida'
      query = query.filter('movimentacoes.tipo_mov', 'eq', 'saida');

      final resp = await query.order('data_criacao', ascending: false).limit(1000);

      final List<dynamic> lista = resp;

      final registrosTransformados =
          lista.map<Map<String, dynamic>>((row) {

        String descricao = '';
        String placa = row['placa_cavalo']?.toString() ?? '';

        final movs = row['movimentacoes'];

        if (movs is List && movs.isNotEmpty) {
          final primeiroMov = movs.first;
          descricao = primeiroMov['cliente']?.toString() ?? '';
          if (descricao.isEmpty) {
            descricao = primeiroMov['descricao']?.toString() ?? '';
          }
        } 
        else if (movs is Map<String, dynamic>) {
          descricao = movs['cliente']?.toString() ?? '';
          if (descricao.isEmpty) {
            descricao = movs['descricao']?.toString() ?? '';
          }
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

  // Filtro apenas por placa (terminal já está filtrado na consulta)
  List<Map<String, dynamic>> get _registrosFiltrados {
    final placaFiltro = _placaController.text.trim().toLowerCase();

    return _registros.where((r) {
      if (placaFiltro.isNotEmpty) {
        final placa = r['placa']?.toString().toLowerCase() ?? '';
        if (!placa.contains(placaFiltro)) return false;
      }

      return true;
    }).toList();
  }

  // Função para calcular as médias
  Map<String, double> _calcularMedias(List<Map<String, dynamic>> registros) {
    if (registros.isEmpty) {
      return {
        'densidade': 0,
        'temp_amostra': 0,
        'temp_ct': 0,
      };
    }

    double somaDensidade = 0;
    double somaTempAmostra = 0;
    double somaTempCt = 0;
    int countDensidade = 0;
    int countTempAmostra = 0;
    int countTempCt = 0;

    for (var r in registros) {
      // Densidade
      final densidade = r['densidade'];
      if (densidade != null) {
        final valor = double.tryParse(densidade.toString());
        if (valor != null) {
          somaDensidade += valor;
          countDensidade++;
        }
      }

      // Temperatura da amostra
      final tempAmostra = r['temp_amostra'];
      if (tempAmostra != null) {
        final valor = double.tryParse(tempAmostra.toString());
        if (valor != null) {
          somaTempAmostra += valor;
          countTempAmostra++;
        }
      }

      // Temperatura do CT
      final tempCt = r['temp_ct'];
      if (tempCt != null) {
        final valor = double.tryParse(tempCt.toString());
        if (valor != null) {
          somaTempCt += valor;
          countTempCt++;
        }
      }
    }

    return {
      'densidade': countDensidade > 0 ? somaDensidade / countDensidade : 0,
      'temp_amostra': countTempAmostra > 0 ? somaTempAmostra / countTempAmostra : 0,
      'temp_ct': countTempCt > 0 ? somaTempCt / countTempCt : 0,
    };
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

  // Widget de pesquisa de data
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

  // Widget de pesquisa de placa
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
    final medias = _calcularMedias(registros);

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // AppBar personalizada
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
                // Exibir terminal atual para usuários não-admin
                if (UsuarioAtual.instance != null && 
                    UsuarioAtual.instance!.nivel < 3 && 
                    UsuarioAtual.instance!.terminalNome != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          UsuarioAtual.instance!.terminalNome!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Linha divisória
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          // Conteúdo principal
          Expanded(
            child: registros.isEmpty
                ? _buildVazio()
                : _buildTable(registros, medias),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> registros, Map<String, double> medias) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 10, 30, 0),
          child: Column(
            children: [
              // Cabeçalho da tabela
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

              // Linhas de dados
              Expanded(
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  child: Column(
                    children: [
                      ...List.generate(registros.length, (index) {
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
                      
                      // Linha de médias
                      if (registros.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    'MÉDIAS',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    medias['densidade']?.toStringAsFixed(3) ?? '0.000',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    medias['temp_amostra']?.toStringAsFixed(1) ?? '0.0',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    medias['temp_ct']?.toStringAsFixed(1) ?? '0.0',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}