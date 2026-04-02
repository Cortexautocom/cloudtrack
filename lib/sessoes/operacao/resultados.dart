import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class ResultadosPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const ResultadosPage({super.key, this.onVoltar});

  @override
  State<ResultadosPage> createState() => _ResultadosPageState();
}

class _ResultadosPageState extends State<ResultadosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String? _selectedTerminalId;
  List<Map<String, dynamic>> _terminais = [];
  bool _carregandoTerminais = false;
  bool _isTerminalFixado = false;
  
  // Dados dos tanques
  List<Map<String, dynamic>> _tanques = [];
  bool _carregandoTanques = false;

  @override
  void initState() {
    super.initState();
    _carregarTerminais();
    
    // Verificar se o usuário tem terminal fixo
    if (UsuarioAtual.instance != null && UsuarioAtual.instance!.terminalId != null) {
      _selectedTerminalId = UsuarioAtual.instance!.terminalId;
      _isTerminalFixado = true;
    }
  }

  Future<void> _carregarTerminais() async {
    setState(() => _carregandoTerminais = true);
    try {
      final user = UsuarioAtual.instance;
      if (user == null) {
        setState(() => _carregandoTerminais = false);
        return;
      }

      // Se o usuário tem um terminal fixo, usamos apenas ele.
      if (user.terminalId != null && user.terminalId!.isNotEmpty) {
        final response = await _supabase
            .from('terminais')
            .select('id, nome')
            .eq('id', user.terminalId!)
            .maybeSingle();
        
        if (response != null) {
          setState(() {
            _terminais = [response];
            _selectedTerminalId = user.terminalId;
            _isTerminalFixado = true;
            _carregandoTerminais = false;
          });
          await _carregarTanques();
          return;
        }
      }

      // Caso contrário, buscamos todos os terminais da empresa através de relacoes_terminais
      final empresaIdEfetivo = (user.empresaId ?? '').trim();
      List<Map<String, dynamic>> listaTerminais = [];

      if (empresaIdEfetivo.isNotEmpty) {
        final relacoes = await _supabase
            .from('relacoes_terminais')
            .select('terminal_id')
            .eq('empresa_id', empresaIdEfetivo);

        final terminaisIds = relacoes
            .map((r) => r['terminal_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .toList();

        if (terminaisIds.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .inFilter('id', terminaisIds)
              .order('nome');

          listaTerminais = dados
              .map<Map<String, dynamic>>((t) => {
                    'id': t['id'].toString(),
                    'nome': t['nome'].toString(),
                  })
              .toList();
        }
      } else {
        final dados = await _supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');

        listaTerminais = dados
            .map<Map<String, dynamic>>((t) => {
                  'id': t['id'].toString(),
                  'nome': t['nome'].toString(),
                })
            .toList();
      }

      setState(() {
        _terminais = listaTerminais;
        _carregandoTerminais = false;
        _isTerminalFixado = false;
      });
      
      if (_selectedTerminalId != null) {
        await _carregarTanques();
      }
    } catch (e) {
      debugPrint('Erro ao carregar terminais: $e');
      setState(() => _carregandoTerminais = false);
    }
  }

  // Função para extrair o número da referência do tanque
  int _extractNumberFromReferencia(String referencia) {
    // Procura por padrões como TQ-01-JN, TQ-02-JN, etc.
    final regex = RegExp(r'TQ-(\d+)-');
    final match = regex.firstMatch(referencia);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> _carregarTanques() async {
    if (_selectedTerminalId == null || _selectedTerminalId!.isEmpty) {
      setState(() => _tanques = []);
      return;
    }
    
    setState(() => _carregandoTanques = true);
    try {
      final terminalId = _selectedTerminalId!;
      
      final dados = await _supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            id_produto,
            produtos (
              id,
              nome
            )
          ''')
          .eq('terminal_id', terminalId);
      
      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (var tanque in dados) {
        final produto = tanque['produtos'];
        tanquesFormatados.add({
          'id': tanque['id'].toString(),
          'referencia': tanque['referencia'].toString(),
          'produto_nome': produto != null ? produto['nome'].toString() : 'Sem Produto',
          'produto_id': tanque['id_produto']?.toString(),
        });
      }
      
      // Ordenar os tanques pelo número extraído da referência
      tanquesFormatados.sort((a, b) {
        final numA = _extractNumberFromReferencia(a['referencia']);
        final numB = _extractNumberFromReferencia(b['referencia']);
        return numA.compareTo(numB);
      });
      
      setState(() {
        _tanques = tanquesFormatados;
        _carregandoTanques = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar tanques: $e');
      setState(() => _carregandoTanques = false);
    }
  }

  Widget _buildAppBar() {
    return Container(
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
          const Expanded(
            child: Text(
              'Resultados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalSelector() {
    if (_carregandoTerminais) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (UsuarioAtual.instance == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            hint: const Text('Selecione um Terminal', style: TextStyle(fontSize: 14)),
            value: _selectedTerminalId,
            items: [
              if (!_isTerminalFixado)
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos os Terminais', style: TextStyle(fontSize: 14)),
                ),
              ..._terminais.map((t) {
                return DropdownMenuItem<String>(
                  value: t['id'].toString(),
                  child: Text(t['nome'].toString(), style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
            ],
            onChanged: _isTerminalFixado ? null : (val) {
              setState(() => _selectedTerminalId = val);
              _carregarTanques();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          Container(height: 1, color: Colors.grey.shade300),
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTerminalSelector(),
                      if (_carregandoTanques)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_tanques.isEmpty && _selectedTerminalId != null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('Nenhum tanque encontrado para este terminal.'),
                          ),
                        )
                      else if (_tanques.isNotEmpty) ...[
                        _buildControleEntradaSaidaTable(),
                        const SizedBox(height: 40),
                        _buildGanhoOperacionalTable(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControleEntradaSaidaTable() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, color: Color(0xFF1565C0), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'CONTROLE DE ENTRADA / SAÍDA DE PRODUTOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columnSpacing: 12,
              horizontalMargin: 20,
              dividerThickness: 0.5,
              columns: _buildColumns(),
              rows: _buildRows(),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    final columns = <DataColumn>[
      const DataColumn(
        label: SizedBox(
          width: 150,
          child: Center(
            child: Text(
              '',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
      ),
    ];
    
    for (var tanque in _tanques) {
      columns.add(
        DataColumn(
          label: SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tanque['referencia'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tanque['produto_nome'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 10,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return columns;
  }

  List<DataRow> _buildRows() {
    final List<DataRow> rows = [];
    
    // Linha: Abertura Mês
    rows.add(_buildDataRow('Abertura Mês', List.filled(_tanques.length, '0')));
    
    // Linha: Entrada
    rows.add(_buildDataRow('Entrada', List.filled(_tanques.length, '0')));
    
    // Linha: Saída
    rows.add(_buildDataRow('Saída', List.filled(_tanques.length, '0')));
    
    // Linha: Perda/Sobra
    rows.add(_buildDataRow('Perda/Sobra', List.filled(_tanques.length, '0')));
    
    // Linha: Diferença Amb/20ºC
    rows.add(_buildDataRow('Diferença Amb/20ºC', List.filled(_tanques.length, '0')));
    
    // Linha: Saldo Final (destacada)
    rows.add(_buildDataRow('Saldo Final', List.filled(_tanques.length, '0'), isHighlighted: true));
    
    return rows;
  }

  DataRow _buildDataRow(String label, List<String> values, {bool isHighlighted = false}) {
    return DataRow(
      color: isHighlighted ? WidgetStateProperty.all(Colors.blue.shade50.withOpacity(0.3)) : null,
      cells: [
        DataCell(
          SizedBox(
            width: 150,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: Colors.blue.shade900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        ...values.map((value) => DataCell(
          SizedBox(
            width: 120,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color: isHighlighted ? Colors.blue.shade900 : Colors.black87,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildGanhoOperacionalTable() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, color: Color(0xFF1565C0), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Variação Tanque / Volume 20ºC',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white),
              columnSpacing: 12,
              horizontalMargin: 20,
              dividerThickness: 0.5,
              columns: _buildGanhoColumns(),
              rows: [
                DataRow(
                  cells: [
                    const DataCell(
                      SizedBox(
                        width: 150,
                        child: SizedBox.shrink(),
                      ),
                    ),
                    ..._tanques.map((_) => DataCell(
                      SizedBox(
                        width: 120,
                        child: Center(
                          child: Text(
                            '0',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(
                      SizedBox(
                        width: 150,
                        child: SizedBox.shrink(),
                      ),
                    ),
                    ..._tanques.map((_) => DataCell(
                      SizedBox(
                        width: 120,
                        child: Center(
                          child: Text(
                            '0 %',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildGanhoColumns() {
    final columns = <DataColumn>[
      const DataColumn(
        label: SizedBox(
          width: 150,
          child: SizedBox.shrink(),
        ),
      ),
    ];
    
    for (var tanque in _tanques) {
      columns.add(
        DataColumn(
          label: SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tanque['referencia'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tanque['produto_nome'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 10,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return columns;
  }
}