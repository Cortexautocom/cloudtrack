/*// C:\Users\Public\Desenvolvimento\cloudtrack\lib\sessoes\almoxerifado\frascos_amostras.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class FrascosAmostraPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const FrascosAmostraPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<FrascosAmostraPage> createState() => _FrascosAmostraPageState();
}

class _FrascosAmostraPageState extends State<FrascosAmostraPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Controles de filtro
  String? _terminalSelecionadoId;
  String? _terminalSelecionadoNome;
  String? _empresaSelecionadaId;
  String? _empresaSelecionadaNome;
  
  // Listas para dropdowns
  List<Map<String, dynamic>> _terminaisDisponiveis = [];
  List<Map<String, dynamic>> _empresasDisponiveis = [];
  
  // Flags de carregamento
  bool _carregandoTerminais = false;
  bool _carregandoEmpresas = false;
  bool _carregandoDados = false;
  
  // Dados da tabela
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  
  // Controles de scroll (igual ao EstoqueTanquePage)
  final ScrollController _vertical = ScrollController();
  final ScrollController _hHeader = ScrollController();
  final ScrollController _hBody = ScrollController();
  
  // Dimensões da tabela (igual ao EstoqueTanquePage)
  static const double _hCab = 40;
  static const double _hRow = 40;
  static const double _hFoot = 32;
  
  static const double _wData = 120;
  static const double _wPlaca = 180;
  static const double _wNum = 130;
  
  double get _wTable => _wData + _wPlaca + (_wNum * 3);
  
  // Ordenação
  String _coluna = 'data_mov';
  bool _asc = true;
  
  // Totais
  int _totalEntradas = 0;
  int _totalSaidas = 0;
  int _saldoFinal = 0;

  @override
  void initState() {
    super.initState();
    _syncScroll();
    _inicializarFiltros();
  }

  void _syncScroll() {
    _hHeader.addListener(() {
      if (_hBody.hasClients && _hBody.offset != _hHeader.offset) {
        _hBody.jumpTo(_hHeader.offset);
      }
    });
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
        _hHeader.jumpTo(_hBody.offset);
      }
    });
  }

  @override
  void dispose() {
    _vertical.dispose();
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  Future<void> _inicializarFiltros() async {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    // 1. Carregar terminais disponíveis
    await _carregarTerminaisDisponiveis();

    // 2. Verificar se usuário tem terminal no widget
    if (usuario.terminalId != null && usuario.terminalId!.isNotEmpty) {
      // Usuário tem terminal: campo bloqueado
      final terminalId = usuario.terminalId;
      _terminalSelecionadoId = terminalId;
      
      // Buscar nome do terminal
      final terminal = _terminaisDisponiveis.firstWhere(
        (t) => t['id'] == terminalId,
        orElse: () => {'id': '', 'nome': ''},
      );
      _terminalSelecionadoNome = terminal['nome'];

      // Carregar empresas deste terminal
      await _carregarEmpresasDoTerminal(terminalId!);
    } else {
      // Usuário não tem terminal: campo livre com primeiro terminal
      if (_terminaisDisponiveis.isNotEmpty) {
        final primeiroTerminal = _terminaisDisponiveis.firstWhere(
          (t) => t['id'] != '',
          orElse: () => _terminaisDisponiveis.isNotEmpty ? _terminaisDisponiveis.first : {'id': '', 'nome': ''},
        );
        
        if (primeiroTerminal['id'] != '') {
          _terminalSelecionadoId = primeiroTerminal['id'];
          _terminalSelecionadoNome = primeiroTerminal['nome'];
          
          // Carregar empresas do primeiro terminal
          await _carregarEmpresasDoTerminal(primeiroTerminal['id']);
        }
      }
    }

    // 3. Verificar empresa do usuário
    if (usuario.empresaId != null && usuario.empresaId!.isNotEmpty) {
      // Usuário tem empresa: campo bloqueado
      final empresaId = usuario.empresaId;
      _empresaSelecionadaId = empresaId;
      
      // Buscar nome da empresa
      final empresa = _empresasDisponiveis.firstWhere(
        (e) => e['id'] == empresaId,
        orElse: () => {'id': '', 'nome': ''},
      );
      _empresaSelecionadaNome = empresa['nome'];
    } else {
      // Usuário não tem empresa: selecionar primeira disponível
      if (_empresasDisponiveis.isNotEmpty) {
        final primeiraEmpresa = _empresasDisponiveis.firstWhere(
          (e) => e['id'] != '',
          orElse: () => _empresasDisponiveis.isNotEmpty ? _empresasDisponiveis.first : {'id': '', 'nome': ''},
        );
        
        if (primeiraEmpresa['id'] != '') {
          _empresaSelecionadaId = primeiraEmpresa['id'];
          _empresaSelecionadaNome = primeiraEmpresa['nome'];
        }
      }
    }

    // 4. Carregar dados do mês atual
    final terminalId = _terminalSelecionadoId;
    final empresaId = _empresaSelecionadaId;
    
    if (terminalId != null && terminalId.isNotEmpty && 
        empresaId != null && empresaId.isNotEmpty) {
      await _carregarDados();
    }
  }

  Future<void> _carregarTerminaisDisponiveis() async {
    setState(() => _carregandoTerminais = true);

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      // Lógica igual ao filtro_movimentacoes: buscar todos os terminais
      final dados = await _supabase
          .from('terminais')
          .select('id, nome')
          .order('nome');

      final List<Map<String, dynamic>> terminais = [];
      
      // Adicionar opção "selecione" apenas se usuário não tiver terminal fixo
      if (usuario.terminalId == null || usuario.terminalId!.isEmpty) {
        terminais.add({'id': '', 'nome': '<selecione>'});
      }
      
      for (var terminal in dados) {
        terminais.add({
          'id': terminal['id'].toString(),
          'nome': terminal['nome'].toString(),
        });
      }

      setState(() {
        _terminaisDisponiveis = terminais;
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

  Future<void> _carregarEmpresasDoTerminal(String terminalId) async {
    if (terminalId.isEmpty) {
      setState(() {
        _empresasDisponiveis = [];
        _empresaSelecionadaId = null;
        _empresaSelecionadaNome = null;
      });
      return;
    }

    setState(() => _carregandoEmpresas = true);

    try {
      // Buscar empresas que operam neste terminal
      final dados = await _supabase
          .from('empresas')
          .select('id, nome, nome_abrev')
          .eq('terminal_orig_id', terminalId)
          .order('nome');

      final List<Map<String, dynamic>> empresas = [];
      
      final usuario = UsuarioAtual.instance;
      
      // Adicionar opção "selecione" apenas se usuário não tiver empresa fixa
      if (usuario?.empresaId == null || usuario!.empresaId!.isEmpty) {
        empresas.add({'id': '', 'nome': '<selecione>'});
      }
      
      for (var empresa in dados) {
        empresas.add({
          'id': empresa['id'].toString(),
          'nome': empresa['nome_abrev'] ?? empresa['nome'] ?? '',
        });
      }

      setState(() {
        _empresasDisponiveis = empresas;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar empresas do terminal: $e');
      setState(() {
        _empresasDisponiveis = [
          {'id': '', 'nome': '<selecione>'}
        ];
      });
    } finally {
      setState(() => _carregandoEmpresas = false);
    }
  }

  Future<void> _carregarDados() async {
    final terminalId = _terminalSelecionadoId;
    final empresaId = _empresaSelecionadaId;
    
    if (terminalId == null || terminalId.isEmpty ||
        empresaId == null || empresaId.isEmpty) {
      return;
    }

    setState(() {
      _carregandoDados = true;
      _movimentacoes = [];
      _movimentacoesOrdenadas = [];
      _totalEntradas = 0;
      _totalSaidas = 0;
      _saldoFinal = 0;
    });

    try {
      // Definir período: mês atual (01 até último dia)
      final now = DateTime.now();
      final primeiroDia = DateTime(now.year, now.month, 1);
      final ultimoDia = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final primeiroDiaStr = primeiroDia.toIso8601String().split('T')[0];
      final ultimoDiaStr = ultimoDia.toIso8601String().split('T')[0];

      // Buscar movimentações de saída do período
      final dados = await _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_mov,
            placa,
            quantidade,
            tipo_op
          ''')
          .eq('terminal_orig_id', terminalId)
          .eq('empresa_id', empresaId)
          .gte('data_mov', '$primeiroDiaStr 00:00:00')
          .lte('data_mov', '$ultimoDiaStr 23:59:59')
          .neq('tipo_op', 'ENTRADA') // Apenas saídas
          .order('data_mov');

      // Agrupar por dia e placa
      final Map<String, Map<String, dynamic>> movimentacoesAgrupadas = {};

      for (var mov in dados) {
        final data = DateTime.parse(mov['data_mov']);
        final dataStr = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
        
        // Extrair placa do array ou usar valor padrão
        String placa = 'SEM PLACA';
        if (mov['placa'] != null) {
          if (mov['placa'] is List) {
            final List placas = mov['placa'] as List;
            if (placas.isNotEmpty) {
              placa = placas.first.toString();
            }
          } else if (mov['placa'] is String) {
            placa = mov['placa'] as String;
          }
        }
        
        final key = '$dataStr|$placa';

        if (!movimentacoesAgrupadas.containsKey(key)) {
          movimentacoesAgrupadas[key] = {
            'data': dataStr,
            'placa': placa,
            'entradas': 0,
            'saidas': 0,
            'movimentacoes': [],
          };
        }

        // Cada movimentação de saída = 1 frasco
        final saidasAtual = movimentacoesAgrupadas[key]!['saidas'] as int;
        movimentacoesAgrupadas[key]!['saidas'] = saidasAtual + 1;
        movimentacoesAgrupadas[key]!['movimentacoes'].add(mov);
      }

      // Calcular saldo acumulado (iniciando em zero)
      int saldoAcumulado = 0;
      final List<Map<String, dynamic>> listaComSaldo = [];

      // Ordenar por data
      final keysOrdenadas = movimentacoesAgrupadas.keys.toList()..sort();

      for (final key in keysOrdenadas) {
        final item = movimentacoesAgrupadas[key]!;
        
        final entradas = item['entradas'] as int;
        final saidas = item['saidas'] as int;
        
        saldoAcumulado = saldoAcumulado + entradas - saidas;
        
        listaComSaldo.add({
          'data': item['data'],
          'placa': item['placa'],
          'entradas': entradas,
          'saidas': saidas,
          'saldo': saldoAcumulado,
        });
      }

      // Calcular totais
      int totalEntradas = 0;
      int totalSaidas = 0;
      for (var item in listaComSaldo) {
        totalEntradas += item['entradas'] as int;
        totalSaidas += item['saidas'] as int;
      }
      final saldoFinal = listaComSaldo.isNotEmpty ? listaComSaldo.last['saldo'] as int : 0;

      setState(() {
        _movimentacoes = listaComSaldo;
        _movimentacoesOrdenadas = List.from(listaComSaldo);
        _totalEntradas = totalEntradas;
        _totalSaidas = totalSaidas;
        _saldoFinal = saldoFinal;
        _carregandoDados = false;
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
      setState(() {
        _carregandoDados = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _ordenar(String col, bool asc) {
    final ord = List<Map<String, dynamic>>.from(_movimentacoes);
    ord.sort((a, b) {
      dynamic va, vb;
      switch (col) {
        case 'data':
          va = a['data'] as String;
          vb = b['data'] as String;
          break;
        case 'placa':
          va = (a['placa'] as String? ?? '').toLowerCase();
          vb = (b['placa'] as String? ?? '').toLowerCase();
          break;
        case 'entradas':
        case 'saidas':
        case 'saldo':
          va = a[col] as int? ?? 0;
          vb = b[col] as int? ?? 0;
          break;
        default:
          return 0;
      }
      if (va is String && vb is String) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      if (va is int && vb is int) {
        return asc ? va.compareTo(vb) : vb.compareTo(va);
      }
      return 0;
    });

    setState(() {
      _movimentacoesOrdenadas = ord;
      _coluna = col;
      _asc = asc;
    });
  }

  void _onSort(String col) {
    final asc = _coluna == col ? !_asc : true;
    _ordenar(col, asc);
  }

  String _fmtNum(int? v) {
    if (v == null) return '-';
    return v.toString();
  }

  String _fmtData(String dataStr) {
    final partes = dataStr.split('-');
    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }
    return dataStr;
  }

  Color _bgEntrada() => Colors.green.shade50.withOpacity(0.3);
  Color _bgSaida() => Colors.red.shade50.withOpacity(0.3);

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;
    final bool terminalBloqueado = usuario?.terminalId != null && usuario!.terminalId!.isNotEmpty;
    final bool empresaBloqueada = usuario?.empresaId != null && usuario!.empresaId!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: const Text(
          'Frascos de Amostra Testemunha',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtros
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  // Campo Terminal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Terminal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_carregandoTerminais)
                          Container(
                            height: 40,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: terminalBloqueado ? Colors.grey.shade100 : Colors.white,
                              border: Border.all(
                                color: terminalBloqueado ? Colors.grey.shade400 : Colors.grey.shade400,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _terminalSelecionadoId,
                                isExpanded: true,
                                itemHeight: 50,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                style: const TextStyle(fontSize: 13, color: Colors.black),
                                onChanged: terminalBloqueado
                                    ? null
                                    : (String? novoValor) {
                                        setState(() {
                                          _terminalSelecionadoId = novoValor;
                                          final terminal = _terminaisDisponiveis.firstWhere(
                                            (t) => t['id'] == novoValor,
                                            orElse: () => {'id': '', 'nome': ''},
                                          );
                                          _terminalSelecionadoNome = terminal['nome'];
                                          
                                          // Recarregar empresas do novo terminal
                                          if (novoValor != null && novoValor.isNotEmpty) {
                                            _carregarEmpresasDoTerminal(novoValor);
                                          }
                                          
                                          // Limpar empresa selecionada
                                          _empresaSelecionadaId = null;
                                          _empresaSelecionadaNome = null;
                                        });
                                      },
                                items: _terminaisDisponiveis.map<DropdownMenuItem<String>>((terminal) {
                                  return DropdownMenuItem<String>(
                                    value: terminal['id']!,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          'Empresa',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_carregandoEmpresas)
                          Container(
                            height: 40,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: empresaBloqueada ? Colors.grey.shade100 : Colors.white,
                              border: Border.all(
                                color: empresaBloqueada ? Colors.grey.shade400 : Colors.grey.shade400,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _empresaSelecionadaId,
                                isExpanded: true,
                                itemHeight: 50,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                style: const TextStyle(fontSize: 13, color: Colors.black),
                                onChanged: empresaBloqueada
                                    ? null
                                    : (String? novoValor) {
                                        setState(() {
                                          _empresaSelecionadaId = novoValor;
                                          final empresa = _empresasDisponiveis.firstWhere(
                                            (e) => e['id'] == novoValor,
                                            orElse: () => {'id': '', 'nome': ''},
                                          );
                                          _empresaSelecionadaNome = empresa['nome'];
                                          
                                          // Recarregar dados
                                          final terminalId = _terminalSelecionadoId;
                                          if (terminalId != null && terminalId.isNotEmpty &&
                                              novoValor != null && novoValor.isNotEmpty) {
                                            _carregarDados();
                                          }
                                        });
                                      },
                                items: _empresasDisponiveis.map<DropdownMenuItem<String>>((empresa) {
                                  return DropdownMenuItem<String>(
                                    value: empresa['id']!,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  
                  // Botão Consultar
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        final terminalId = _terminalSelecionadoId;
                        final empresaId = _empresaSelecionadaId;
                        
                        if (terminalId != null && terminalId.isNotEmpty &&
                            empresaId != null && empresaId.isNotEmpty) {
                          _carregarDados();
                        }
                      },
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
                          SizedBox(width: 4),
                          Text(
                            'Consultar',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tabela
            Expanded(
              child: _carregandoDados
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                  : _movimentacoes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma movimentação encontrada',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Selecione um terminal e empresa para consultar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildTabela(),
            ),
            
            // Rodapé com resumo
            if (_movimentacoes.isNotEmpty) _buildRodape(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabela() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _cabecalho(),
          Expanded(
            child: Scrollbar(
              controller: _vertical,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _vertical,
                child: _corpo(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Scrollbar(
      controller: _hHeader,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hHeader,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wTable,
          child: Container(
            height: _hCab,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: [
                _th('Data', _wData, () => _onSort('data')),
                _th('Placa', _wPlaca, () => _onSort('placa')),
                _th('Qtd entrada', _wNum, () => _onSort('entradas')),
                _th('Qtd saída', _wNum, () => _onSort('saidas')),
                _th('Saldo', _wNum, () => _onSort('saldo')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String titulo, double largura, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largura,
        alignment: Alignment.center,
        child: Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _corpo() {
    return Scrollbar(
      controller: _hBody,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hBody,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wTable,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movimentacoesOrdenadas.length,
            itemBuilder: (context, index) {
              final item = _movimentacoesOrdenadas[index];
              return Container(
                height: _hRow,
                color: index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                child: Row(
                  children: [
                    _cell(_fmtData(item['data'] as String), _wData),
                    _cell(item['placa'] as String? ?? '-', _wPlaca),
                    _cell(_fmtNum(item['entradas'] as int?), _wNum, bg: _bgEntrada()),
                    _cell(_fmtNum(item['saidas'] as int?), _wNum, bg: _bgSaida()),
                    _cell(
                      _fmtNum(item['saldo'] as int?),
                      _wNum,
                      cor: (item['saldo'] as int? ?? 0) < 0 ? Colors.red : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(String texto, double largura, {Color? bg, Color? cor}) {
    return Container(
      width: largura,
      alignment: Alignment.center,
      color: bg,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildRodape() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItemRodape(
            'Total de entradas',
            _fmtNum(_totalEntradas),
            Colors.green.shade700,
          ),
          _buildItemRodape(
            'Total de saídas',
            _fmtNum(_totalSaidas),
            Colors.red.shade700,
          ),
          _buildItemRodape(
            'Saldo atual',
            _fmtNum(_saldoFinal),
            const Color(0xFF0D47A1),
            negrito: true,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRodape(String label, String valor, Color cor, {bool negrito = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: negrito ? 18 : 16,
            fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
            color: cor,
          ),
        ),
      ],
    );
  }
}*/