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

  @override
  void initState() {
    super.initState();
    _carregarTerminais();
    // Inicializar o terminal selecionado com o do usuário, se houver
    if (UsuarioAtual.instance != null && UsuarioAtual.instance!.terminalId != null) {
      _selectedTerminalId = UsuarioAtual.instance!.terminalId;
    }
  }

  Future<void> _carregarTerminais() async {
    setState(() => _carregandoTerminais = true);
    try {
      final response = await _supabase
          .from('terminais')
          .select('id, nome')
          .order('nome');
      
      setState(() {
        _terminais = List<Map<String, dynamic>>.from(response);
        _carregandoTerminais = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar terminais: $e');
      setState(() => _carregandoTerminais = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom AppBar
          _buildAppBar(),
          
          // Divider
          Container(height: 1, color: Colors.grey.shade300),
          
          // Content
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 1000,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildControleEntradaSaidaTable(),
                        const SizedBox(height: 40),
                        _buildGanhoOperacionalTable(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          _buildTerminalSelector(),
        ],
      ),
    );
  }

  Widget _buildTerminalSelector() {
    if (_carregandoTerminais) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Se o nível for alto o suficiente, mostra dropdown. Caso contrário, mostra apenas o nome do terminal.
    if (UsuarioAtual.instance != null && UsuarioAtual.instance!.nivel >= 3) {
      return Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            hint: const Text('Selecione um Terminal'),
            value: _selectedTerminalId,
            items: _terminais.map((t) {
              return DropdownMenuItem<String>(
                value: t['id'].toString(),
                child: Text(t['nome'].toString()),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedTerminalId = val);
            },
          ),
        ),
      );
    } else if (UsuarioAtual.instance?.terminalNome != null) {
      return Container(
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
          SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white),
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columnSpacing: 12,
              horizontalMargin: 20,
              dividerThickness: 0.5,
              columns: [
                DataColumn(label: _headerText('CONCEITO')),
                DataColumn(label: _headerText('DIESEL-S500 A', isProduct: true)),
                DataColumn(label: _headerText('GASOLINA C', isProduct: true)),
                DataColumn(label: _headerText('ANIDRO', isProduct: true)),
                DataColumn(label: _headerText('AEHC', isProduct: true)),
                DataColumn(label: _headerText('B - 100', isProduct: true)),
                DataColumn(label: _headerText('DIESEL S-10 B', isProduct: true)),
                DataColumn(label: _headerText('GERAL', isTotal: true, isProduct: true)),
              ],
              rows: [
                _dataRow('Abertura Mês', ['367.078', '965.788', '789.434', '187.304', '212.711', '716.118', '3.238.433']),
                _dataRow('Entrada', ['99.410', '149.936', '0', '0', '0', '114.779', '364.125']),
                _dataRow('Saída', ['19.430', '73.033', '31.296', '125.996', '10.288', '38.873', '298.916']),
                _dataRow('Perda/Sobra', ['174', '1.050', '836', '171', '35', '471', '2.737']),
                _dataRow('Percentual', ['0,90%', '1,44%', '2,67%', '0,14%', '0,34%', '1,21%', '0,75%']),
                _dataRow('Saldo Final', ['447.232', '1.043.741', '758.974', '61.479', '202.458', '792.495', '2.513.884'], isHighlighted: true),
              ],
            ),
          ),
        ],
      ),
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
                    'GANHO OPERACIONAL',
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
          SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white),
              columnSpacing: 12,
              horizontalMargin: 20,
              dividerThickness: 0.5,
              columns: [
                DataColumn(label: _headerText('DIESEL-S500 A', isProduct: true)),
                DataColumn(label: _headerText('GASOLINA C', isProduct: true)),
                DataColumn(label: _headerText('ANIDRO', isProduct: true)),
                DataColumn(label: _headerText('AEHC', isProduct: true)),
                DataColumn(label: _headerText('B - 100', isProduct: true)),
                DataColumn(label: _headerText('DIESEL S-10 B', isProduct: true)),
                DataColumn(label: _headerText('GERAL', isTotal: true, isProduct: true)),
              ],
              rows: [
                DataRow(
                  cells: [
                    _dataCell('366', isBold: true),
                    _dataCell('1.474', isBold: true),
                    _dataCell('1.040', isBold: true),
                    _dataCell('171', isBold: true),
                    _dataCell('97', isBold: true),
                    _dataCell('532', isBold: true),
                    _dataCell('3.680', isBold: true, textColor: Colors.blue.shade800),
                  ],
                ),
                DataRow(
                  cells: [
                    _dataCell('1,8836 %', isSmall: true),
                    _dataCell('2,0182 %', isSmall: true),
                    _dataCell('3,3231 %', isSmall: true),
                    _dataCell('0,1357 %', isSmall: true),
                    _dataCell('0,9428 %', isSmall: true),
                    _dataCell('1,3685 %', isSmall: true),
                    _dataCell('1,2311 %', isSmall: true, textColor: Colors.blue.shade700),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String label, {bool isTotal = false, bool isProduct = false}) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isProduct ? FontWeight.bold : FontWeight.bold,
            color: isTotal ? Colors.blue.shade900 : Colors.blue.shade700,
            fontSize: isProduct ? 12 : 11,
          ),
        ),
      ),
    );
  }

  DataRow _dataRow(String label, List<String> values, {bool isHighlighted = false, bool addPercent = false}) {
    return DataRow(
      color: isHighlighted ? WidgetStateProperty.all(Colors.blue.shade50.withOpacity(0.3)) : null,
      cells: [
        DataCell(
          Center(
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
        ...values.asMap().entries.map((entry) {
          bool isLast = entry.key == values.length - 1;
          String value = entry.value;
          if (addPercent) {
            value = '$value %';
          }
          
          return _dataCell(
            value,
            isBold: isHighlighted || isLast,
            textColor: isLast
                ? Colors.blue.shade900
                : (isHighlighted ? Colors.blue.shade700 : Colors.black87),
          );
        }).toList(),
      ],
    );
  }

  DataCell _dataCell(String text, {bool isBold = false, Color? textColor, bool isSmall = false}) {
    return DataCell(
      Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor ?? Colors.black87,
            fontSize: isSmall ? 10 : 12,
          ),
        ),
      ),
    );
  }
}
