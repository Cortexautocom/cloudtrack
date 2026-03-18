import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FiltroEstoqueFrascosPage extends StatefulWidget {
  final String? terminalId;
  final String? empresaId;
  final String nomeTerminal;
  final String? empresaNome;
  final Function({
    required String? terminalId,
    required String? empresaId,
    required String nomeTerminal,
    String? empresaNome,
    DateTime? mesFiltro,
    required String tipoRelatorio,
    required bool isIntraday,
    DateTime? dataIntraday,
  }) onConsultarEstoque;
  final VoidCallback onVoltar;

  const FiltroEstoqueFrascosPage({
    super.key,
    this.terminalId,
    this.empresaId,
    required this.nomeTerminal,
    this.empresaNome,
    required this.onConsultarEstoque,
    required this.onVoltar,
  });

  @override
  State<FiltroEstoqueFrascosPage> createState() =>
      _FiltroEstoqueFrascosPageState();
}

class _FiltroEstoqueFrascosPageState extends State<FiltroEstoqueFrascosPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime? _mesSelecionado;
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  String? _empresaSelecionadaId;
  String? _empresaSelecionadaNome;
  String _tipoRelatorio = 'sintetico';
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  List<Map<String, dynamic>> _empresasDisponiveis = [];
  bool _carregandoTerminais = false;
  bool _carregandoEmpresas = false;
  bool _carregando = false;
  bool _intraday = false;
  DateTime _dataSelecionada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mesSelecionado = DateTime.now();
    _inicializarFiltros();
  }

  Future<void> _inicializarFiltros() async {
    setState(() => _carregando = true);

    await _carregarTerminaisDisponiveis();

    final usuario = UsuarioAtual.instance;

    // Terminal: usar o do widget, ou o do usuário logado, ou o primeiro disponível
    final terminalIdInicial =
        widget.terminalId ?? usuario?.terminalId ?? '';

    if (terminalIdInicial.isNotEmpty) {
      final encontrado = _terminaisDisponiveis.firstWhere(
        (t) => t['id'] == terminalIdInicial,
        orElse: () => {'id': '', 'nome': ''},
      );
      if (encontrado['id'] != '') {
        _terminalSelecionadoId = encontrado['id'];
        _terminalSelecionadoNome = encontrado['nome'];
      } else {
        _selecionarPrimeiroTerminal();
      }
    } else {
      _selecionarPrimeiroTerminal();
    }

    await _carregarEmpresasDisponiveis();

    setState(() => _carregando = false);
  }

  void _selecionarPrimeiroTerminal() {
    final primeiro = _terminaisDisponiveis.firstWhere(
      (t) => t['id'] != '',
      orElse: () => {'id': '', 'nome': ''},
    );
    if (primeiro['id'] != '') {
      _terminalSelecionadoId = primeiro['id'];
      _terminalSelecionadoNome = primeiro['nome'];
    } else {
      _terminalSelecionadoId = '';
      _terminalSelecionadoNome = null;
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
    setState(() => _carregandoTerminais = true);

    try {
      final dados = await _supabase
          .from('terminais')
          .select('id, nome')
          .order('nome');

      final List<Map<String, dynamic>> terminais = [];
      for (var terminal in dados) {
        terminais.add({
          'id': terminal['id'].toString(),
          'nome': terminal['nome'].toString(),
        });
      }

      setState(() {
        _terminaisDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
        _terminaisDisponiveis.addAll(terminais);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _terminaisDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
      });
    } finally {
      setState(() => _carregandoTerminais = false);
    }
  }

  Future<void> _carregarEmpresasDisponiveis() async {
    setState(() => _carregandoEmpresas = true);

    try {
      final usuario = UsuarioAtual.instance;
      final empresaId = widget.empresaId ?? usuario?.empresaId ?? '';

      if (empresaId.isEmpty) {
        setState(() {
          _empresasDisponiveis = [];
          _empresaSelecionadaId = null;
          _empresaSelecionadaNome = null;
        });
        return;
      }

      final dados = await _supabase
          .from('empresas')
          .select('id, nome_dois')
          .eq('id', empresaId)
          .limit(1);

      if (dados.isNotEmpty) {
        final empresa = dados.first;
        final nome = (empresa['nome_dois'] ?? '').toString();
        setState(() {
          _empresasDisponiveis = [
            {'id': empresa['id'].toString(), 'nome': nome},
          ];
          _empresaSelecionadaId = empresa['id'].toString();
          _empresaSelecionadaNome = nome;
        });
      } else {
        setState(() {
          _empresasDisponiveis = [];
          _empresaSelecionadaId = null;
          _empresaSelecionadaNome = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar empresa: $e');
      setState(() {
        _empresasDisponiveis = [];
        _empresaSelecionadaId = null;
        _empresaSelecionadaNome = null;
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
    }
  }

  Future<void> _selecionarMes(BuildContext context) async {
    final DateTime? selecionado = await showDatePicker(
      context: context,
      initialDate: _mesSelecionado ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione o mês',
      fieldLabelText: 'Mês de referência',
      fieldHintText: 'MM/AAAA',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _mesSelecionado = DateTime(selecionado.year, selecionado.month);
      });
    }
  }

  Future<void> _selecionarDataIntraday(BuildContext context) async {
    final DateTime? selecionado = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecione a data',
      fieldLabelText: 'Data específica',
      fieldHintText: 'DD/MM/AAAA',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _dataSelecionada = selecionado;
      });
    }
  }

  void _consultarEstoque() {
    if (!_intraday && _mesSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um mês.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_terminalSelecionadoId == null || _terminalSelecionadoId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione um terminal.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_empresaSelecionadaId == null || _empresaSelecionadaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma empresa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onConsultarEstoque(
      terminalId: _terminalSelecionadoId,
      empresaId: _empresaSelecionadaId,
      nomeTerminal: _terminalSelecionadoNome ?? 'Terminal não selecionado',
      empresaNome: _empresaSelecionadaNome,
      mesFiltro: _intraday ? null : _mesSelecionado,
      tipoRelatorio: _tipoRelatorio,
      isIntraday: _intraday,
      dataIntraday: _intraday ? _dataSelecionada : null,
    );
  }

  void _resetarFiltros() {
    setState(() {
      _mesSelecionado = DateTime.now();
      _tipoRelatorio = 'sintetico';
      _intraday = false;
      _dataSelecionada = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de Estoque de Frascos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.nomeTerminal,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? _buildCarregando()
            : _buildConteudo(),
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando filtros...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(),
          const SizedBox(height: 20),
          _buildCardResumo(),
          const SizedBox(height: 20),
          _buildBotoes(),
          const SizedBox(height: 20),
          _buildNotas(),
        ],
      ),
    );
  }

  Widget _buildCardFiltros() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.filter_alt,
                    color: Color(0xFF0D47A1), size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Filtros de Consulta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Checkbox Intraday
          Row(
            children: [
              Checkbox(
                value: _intraday,
                onChanged: (value) {
                  setState(() {
                    _intraday = value ?? false;
                  });
                },
                activeColor: const Color(0xFF0D47A1),
              ),
              const Text(
                'Intraday (movimentações diárias)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Linha com os filtros
          Row(
            children: [
              // Campo Terminal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terminal *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_carregandoTerminais)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF0D47A1),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _terminalSelecionadoId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _terminalSelecionadoId = novoValor;
                                if (novoValor != null &&
                                    novoValor.isNotEmpty) {
                                  final terminal =
                                      _terminaisDisponiveis.firstWhere(
                                    (t) => t['id'] == novoValor,
                                    orElse: () => {'id': '', 'nome': ''},
                                  );
                                  _terminalSelecionadoNome = terminal['nome'];
                                } else {
                                  _terminalSelecionadoNome = null;
                                }
                              });
                            },
                            items: _terminaisDisponiveis
                                .map<DropdownMenuItem<String>>((terminal) {
                              return DropdownMenuItem<String>(
                                value: terminal['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    terminal['nome']!,
                                    style: TextStyle(
                                      color: terminal['id']!.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Empresa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Empresa *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_carregandoEmpresas)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF0D47A1),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _empresaSelecionadaId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
                            onChanged: (String? novoValor) {
                              setState(() {
                                _empresaSelecionadaId = novoValor;
                                if (novoValor != null &&
                                    novoValor.isNotEmpty) {
                                  final empresa =
                                      _empresasDisponiveis.firstWhere(
                                    (e) => e['id'] == novoValor,
                                    orElse: () => {'id': '', 'nome': ''},
                                  );
                                  _empresaSelecionadaNome = empresa['nome'];
                                } else {
                                  _empresaSelecionadaNome = null;
                                }
                              });
                            },
                            items: _empresasDisponiveis
                                .map<DropdownMenuItem<String>>((empresa) {
                              return DropdownMenuItem<String>(
                                value: empresa['id']!,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    empresa['nome']!,
                                    style: TextStyle(
                                      color: empresa['id']!.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Mês de Referência ou Data Específica
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _intraday ? 'Data específica *' : 'Mês de referência *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _intraday
                          ? () => _selecionarDataIntraday(context)
                          : () => _selecionarMes(context),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _intraday
                                  ? '${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}'
                                  : (_mesSelecionado != null
                                      ? '${_mesSelecionado!.month.toString().padLeft(2, '0')}/${_mesSelecionado!.year}'
                                      : 'Selecione o mês'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Campo Tipo de Relatório
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de relatório',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoRelatorio,
                          isExpanded: true,
                          itemHeight: 50,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          onChanged: (String? novoValor) {
                            setState(() {
                              _tipoRelatorio = novoValor!;
                            });
                          },
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'sintetico',
                              child: Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Sintético'),
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'analitico',
                              child: Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Analítico'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardResumo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize,
                  color: Color(0xFF0D47A1), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Resumo dos Filtros',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid de itens do resumo
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildItemResumo(
                icon: Icons.store,
                label: 'Terminal',
                value: _terminalSelecionadoNome ?? 'Não selecionado',
              ),
              _buildItemResumo(
                icon: Icons.business,
                label: 'Empresa',
                value: _empresaSelecionadaNome ?? 'Não selecionada',
              ),
              _buildItemResumo(
                icon: Icons.calendar_today,
                label: _intraday ? 'Data' : 'Mês',
                value: _intraday
                    ? '${_dataSelecionada.day.toString().padLeft(2, '0')}/${_dataSelecionada.month.toString().padLeft(2, '0')}/${_dataSelecionada.year}'
                    : (_mesSelecionado != null
                        ? '${_mesSelecionado!.month.toString().padLeft(2, '0')}/${_mesSelecionado!.year}'
                        : 'Não selecionado'),
              ),
              if (_intraday)
                _buildItemResumo(
                  icon: Icons.access_time,
                  label: 'Modo',
                  value: 'Intraday (diário)',
                ),
              _buildItemResumo(
                icon: Icons.assessment,
                label: 'Tipo de relatório',
                value:
                    _tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemResumo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoes() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botão Redefinir
          SizedBox(
            width: 140,
            height: 36,
            child: OutlinedButton(
              onPressed: _resetarFiltros,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: Colors.grey.shade400, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Redefinir',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 95, 95, 95),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Botão Consultar
          SizedBox(
            width: 140,
            height: 36,
            child: ElevatedButton(
              onPressed: _consultarEstoque,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Consultar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotas() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _intraday
                      ? 'Campos obrigatórios: Terminal, Empresa e Data específica'
                      : 'Campos obrigatórios: Terminal, Empresa e Mês de referência',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _intraday
                      ? 'Modo Intraday: mostra apenas movimentações da data selecionada.'
                      : 'O tipo de relatório determina o nível de detalhamento da consulta.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
