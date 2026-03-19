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
    final terminalIdInicial =
        widget.terminalId ?? usuario?.terminalId ?? '';

    if (terminalIdInicial.isNotEmpty) {
      final encontrado = _terminaisDisponiveis.firstWhere(
        (t) => t['id'] == terminalIdInicial,
        orElse: () => <String, dynamic>{'id': '', 'nome': ''},
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
      orElse: () => <String, dynamic>{'id': '', 'nome': ''},
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
      final usuario = UsuarioAtual.instance;
      final nivelUsuario = usuario?.nivel ?? 0;
      final empresaIdEfetivo =
          (widget.empresaId ?? usuario?.empresaId ?? '').trim();
      List<Map<String, dynamic>> terminais = [];

      if (nivelUsuario == 4) {
        // Nível 4: terminal fixo do usuário, bloqueado para alteração
        final terminalId =
            (widget.terminalId ?? usuario?.terminalId ?? '').trim();
        if (terminalId.isNotEmpty) {
          final dados = await _supabase
              .from('terminais')
              .select('id, nome')
              .eq('id', terminalId)
              .limit(1);
          if (dados.isNotEmpty) {
            terminais = dados
                .map<Map<String, dynamic>>((t) => {
                      'id': t['id'].toString(),
                      'nome': t['nome'].toString(),
                    })
                .toList();
          }
        }
        setState(() {
          _terminaisDisponiveis = terminais.isNotEmpty
              ? terminais
              : <Map<String, dynamic>>[{'id': '', 'nome': '<selecione>'}];
        });
        return;
      }

      if (empresaIdEfetivo.isNotEmpty) {
        // Há empresa definida: exibe apenas os terminais em que ela atua,
        // buscando os vínculos na tabela relacoes_terminais.
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

          terminais = dados
              .map<Map<String, dynamic>>((t) => {
                    'id': t['id'].toString(),
                    'nome': t['nome'].toString(),
                  })
              .toList();
        }
      } else {
        // Sem empresa definida (administradores): todos os terminais.
        final dados = await _supabase
            .from('terminais')
            .select('id, nome')
            .order('nome');

        terminais = dados
            .map<Map<String, dynamic>>((t) => {
                  'id': t['id'].toString(),
                  'nome': t['nome'].toString(),
                })
            .toList();
      }

      setState(() {
        _terminaisDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _terminaisDisponiveis.addAll(terminais);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar terminais: $e');
      setState(() {
        _terminaisDisponiveis = <Map<String, dynamic>>[
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
      final nivelUsuario = usuario?.nivel ?? 0;
      
      // Verifica se o usuário TEM empresa fixa (níveis 1,2,3 com empresaId)
      final temEmpresaFixa = (nivelUsuario == 1 || nivelUsuario == 2 || nivelUsuario == 3) && 
                            usuario?.empresaId?.isNotEmpty == true;

      // Se tem empresa fixa, carrega apenas ela e bloqueia
      if (temEmpresaFixa) {
        final empresaId = usuario?.empresaId ?? '';
        
        final dados = await _supabase
            .from('empresas')
            .select('id, nome_dois')
            .eq('id', empresaId)
            .limit(1);

        if (dados.isNotEmpty) {
          final e = dados.first;
          final nome = (e['nome_dois'] ?? '').toString();
          setState(() {
            _empresasDisponiveis = <Map<String, dynamic>>[
              {'id': e['id'].toString(), 'nome': nome},
            ];
            _empresaSelecionadaId = e['id'].toString();
            _empresaSelecionadaNome = nome;
          });
        }
        return;
      }

      // Se não tem empresa fixa, carrega todas as empresas disponíveis
      List<Map<String, dynamic>> empresas = [];

      if (nivelUsuario == 4) {
        // Nível 4: empresas que atuam no terminal do usuário
        final terminalId = widget.terminalId ?? usuario?.terminalId ?? '';

        if (terminalId.isNotEmpty) {
          // Busca as empresas através da tabela relacoes_terminais
          final relacoes = await _supabase
              .from('relacoes_terminais')
              .select('empresa_id')
              .eq('terminal_id', terminalId);

          final empresasIds = relacoes
              .map((r) => r['empresa_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .toSet()
              .toList();

          if (empresasIds.isNotEmpty) {
            final dados = await _supabase
                .from('empresas')
                .select('id, nome_dois')
                .inFilter('id', empresasIds)
                .order('nome_dois');

            empresas = dados
                .map<Map<String, dynamic>>((e) => {
                      'id': e['id'].toString(),
                      'nome': (e['nome_dois'] ?? '').toString(),
                    })
                .toList();
          }
        }
      } else {
        // Outros níveis sem empresa fixa (ex: admin)
        final dados = await _supabase
            .from('empresas')
            .select('id, nome_dois')
            .order('nome_dois');

        empresas = dados
            .map<Map<String, dynamic>>((e) => {
                  'id': e['id'].toString(),
                  'nome': (e['nome_dois'] ?? '').toString(),
                })
            .toList();
      }

      setState(() {
        _empresasDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _empresasDisponiveis.addAll(empresas);
        
        // Se veio uma empresa selecionada via widget (de consulta anterior), seleciona ela
        if (widget.empresaId != null && widget.empresaId!.isNotEmpty) {
          final encontrada = empresas.firstWhere(
            (e) => e['id'] == widget.empresaId,
            orElse: () => <String, dynamic>{},
          );
          if (encontrada.isNotEmpty) {
            _empresaSelecionadaId = encontrada['id'];
            _empresaSelecionadaNome = encontrada['nome'];
          }
        }
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar empresas: $e');
      setState(() {
        _empresasDisponiveis = <Map<String, dynamic>>[
          {'id': '', 'nome': '<selecione>'}
        ];
        _empresaSelecionadaId = null;
        _empresaSelecionadaNome = null;
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
    }
  }

  Future<void> _selecionarMes(BuildContext context) async {
    DateTime tempDate = _mesSelecionado ?? DateTime.now();
    
    final DateTime? selecionado = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: const Color.fromARGB(255, 255, 128, 0),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Selecionar Mês',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromARGB(255, 255, 128, 0),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          color: Colors.grey.shade600,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Ano
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: const Color.fromARGB(255, 255, 128, 0),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year - 1,
                                  tempDate.month,
                                );
                              });
                            },
                          ),
                          Text(
                            '${tempDate.year}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 255, 128, 0),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              color: const Color.fromARGB(255, 255, 128, 0),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year + 1,
                                  tempDate.month,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Grid de meses
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      childAspectRatio: 1.8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = month == tempDate.month;
                        final isCurrentMonth = month == DateTime.now().month && 
                            tempDate.year == DateTime.now().year;
                        
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              tempDate = DateTime(tempDate.year, month);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color.fromARGB(255, 255, 128, 0)
                                  : isCurrentMonth
                                      ? const Color.fromARGB(30, 255, 128, 0)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _getMonthNameShort(month),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : isCurrentMonth
                                          ? const Color.fromARGB(255, 255, 128, 0)
                                          : Colors.black87,
                                  fontWeight: isSelected || isCurrentMonth
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Botões
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('CANCELAR'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempDate),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 255, 128, 0),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SELECIONAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _mesSelecionado = DateTime(selecionado.year, selecionado.month);
      });
    }
  }

  String _getMonthNameShort(int month) {
    const months = [
      'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
      'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'
    ];
    return months[month - 1];
  }

  Future<void> _selecionarDataIntraday(BuildContext context) async {
    DateTime tempDate = _dataSelecionada;
    
    final DateTime? selecionado = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: const Color.fromARGB(255, 255, 128, 0),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Selecionar Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromARGB(255, 255, 128, 0),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          color: Colors.grey.shade600,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Mês e Ano
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: const Color.fromARGB(255, 255, 128, 0),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month - 1,
                                  tempDate.day,
                                );
                              });
                            },
                          ),
                          Text(
                            '${_getMonthName(tempDate.month)} ${tempDate.year}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 255, 128, 0),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              color: const Color.fromARGB(255, 255, 128, 0),
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                tempDate = DateTime(
                                  tempDate.year,
                                  tempDate.month + 1,
                                  tempDate.day,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Dias da semana
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                        return Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: const Color.fromARGB(255, 255, 128, 0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    // Dias do mês
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && 
                            day == tempDate.day;
                        
                        final isToday = day != null && 
                            day == DateTime.now().day && 
                            tempDate.month == DateTime.now().month &&
                            tempDate.year == DateTime.now().year;
                        
                        return GestureDetector(
                          onTap: day != null ? () {
                            setStateDialog(() {
                              tempDate = DateTime(tempDate.year, tempDate.month, day);
                            });
                          } : null,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color.fromARGB(255, 255, 128, 0)
                                  : isToday
                                      ? const Color.fromARGB(30, 255, 128, 0)
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                day != null ? day.toString() : '',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : isToday
                                          ? const Color.fromARGB(255, 255, 128, 0)
                                          : Colors.black87,
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Botões
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('CANCELAR'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempDate),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 255, 128, 0),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'SELECIONAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _dataSelecionada = selecionado;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    
    List<int?> days = [];
    
    for (int i = 0; i < startOffset; i++) {
      days.add(null);
    }
    
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(i);
    }
    
    while (days.length < 42) {
      days.add(null);
    }
    
    return days;
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
    final usuario = UsuarioAtual.instance;
    final nivelUsuario = usuario?.nivel ?? 0;
    final temEmpresaFixa = (nivelUsuario == 1 || nivelUsuario == 2 || nivelUsuario == 3) && 
                          usuario?.empresaId?.isNotEmpty == true;
    final temTerminalFixo = nivelUsuario == 4;

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
            : _buildConteudo(temEmpresaFixa, temTerminalFixo),
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

  Widget _buildConteudo(bool temEmpresaFixa, bool temTerminalFixo) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(temEmpresaFixa, temTerminalFixo),
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

  Widget _buildCardFiltros(bool temEmpresaFixa, bool temTerminalFixo) {
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
                          color: temTerminalFixo
                              ? Colors.grey.shade100
                              : Colors.white,
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _terminalSelecionadoId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: temTerminalFixo
                                ? const Visibility(
                                    visible: false,
                                    child: Icon(Icons.arrow_drop_down),
                                  )
                                : const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
                            onChanged: temTerminalFixo
                                ? null
                                : (String? novoValor) {
                                    setState(() {
                                      _terminalSelecionadoId = novoValor;
                                      if (novoValor != null &&
                                          novoValor.isNotEmpty) {
                                        final terminal =
                                            _terminaisDisponiveis.firstWhere(
                                          (t) => t['id'] == novoValor,
                                          orElse: () =>
                                              <String, dynamic>{'id': '', 'nome': ''},
                                        );
                                        _terminalSelecionadoNome =
                                            terminal['nome'];
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
                          color: temEmpresaFixa
                              ? Colors.grey.shade100
                              : Colors.white,
                          border: Border.all(
                              color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _empresaSelecionadaId,
                            isExpanded: true,
                            itemHeight: 50,
                            icon: temEmpresaFixa
                                ? const Visibility(
                                    visible: false,
                                    child: Icon(Icons.arrow_drop_down),
                                  )
                                : const Icon(Icons.arrow_drop_down, size: 20),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black),
                            onChanged: temEmpresaFixa
                                ? null
                                : (String? novoValor) {
                                    setState(() {
                                      _empresaSelecionadaId = novoValor;
                                      if (novoValor != null &&
                                          novoValor.isNotEmpty) {
                                        final empresa =
                                            _empresasDisponiveis.firstWhere(
                                          (e) => e['id'] == novoValor,
                                          orElse: () => <String, dynamic>{'id': '', 'nome': ''},
                                        );
                                        _empresaSelecionadaNome =
                                            empresa['nome'];
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
                    color: const Color.fromARGB(255, 255, 128, 0),
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