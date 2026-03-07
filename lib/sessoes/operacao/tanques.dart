import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'emitir_cacl.dart';
import 'cacl_historico.dart';
import 'estoque_tanque.dart';
import 'estoque_tanque_mensal.dart';
import 'editar_cacl.dart';

class GerenciamentoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? filialSelecionadaId;
  final Function(String filialId)? onAbrirCACL;

  const GerenciamentoTanquesPage({
    super.key, 
    required this.onVoltar,
    this.filialSelecionadaId,
    this.onAbrirCACL,
  });

  @override
  State<GerenciamentoTanquesPage> createState() => _GerenciamentoTanquesPageState();
}

class _GerenciamentoTanquesPageState extends State<GerenciamentoTanquesPage> {
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _accent = Color(0xFF1B6A6F);
  static const Color _line = Color(0xFFE6DCCB);
  static const Color _muted = Color(0xFF5A6B7A);
  static const Color _warn = Color(0xFFC17D2D);

  List<Map<String, dynamic>> tanques = [];
  List<Map<String, dynamic>> produtos = [];
  bool _carregando = true;
  bool _editando = false;
  bool _mostrandoCardsAcoes = false;
  Map<String, dynamic>? _tanqueEditando;
  Map<String, dynamic>? _tanqueSelecionadoParaAcoes;
  String? _nomeFilial;
  bool _carregandoCacls = false;
  List<Map<String, dynamic>> _caclesTanque = [];
  int? _hoverCaclIndex;
  bool _mostrandoEstoqueTanque = false;
  String? _estoqueTanqueId;
  String? _estoqueTanqueReferencia;
  String? _estoqueFilialId;
  String? _estoqueNomeFilial;
  bool _filialEmiteCacl = false;

  final List<String> _statusOptions = ['Em operação', 'Operação suspensa'];
  
  final TextEditingController _referenciaController = TextEditingController();
  final TextEditingController _capacidadeController = TextEditingController();
  final TextEditingController _lastroController = TextEditingController();
  String? _produtoSelecionado;
  String? _statusSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  int _extrairNumeroTanque(String referencia) {
    final match = RegExp(r'TQ[^0-9]*([0-9]+)', caseSensitive: false).firstMatch(referencia);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  Future<void> _carregarDados() async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;

      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      setState(() {
        produtos = List<Map<String, dynamic>>.from(produtosResponse);
      });

      String? terminalId;
      String? nomeTerminal;

      if (widget.filialSelecionadaId != null) {
        terminalId = widget.filialSelecionadaId!;
        try {
          final terminalCheck = await supabase
              .from('terminais')
              .select('id, nome')
              .eq('id', widget.filialSelecionadaId!)
              .maybeSingle();
          if (terminalCheck != null) {
            nomeTerminal = terminalCheck['nome']?.toString();
          }
        } catch (_) {
          nomeTerminal = null;
        }
      }
      else if (usuario.terminalId != null) {
        terminalId = usuario.terminalId;
        
        try {
          final terminalData = await supabase
              .from('terminais')
              .select('nome')
              .eq('id', usuario.terminalId!)
              .maybeSingle();
          if (terminalData != null) {
            nomeTerminal = terminalData['nome'];
          }
        } catch (_) {
          nomeTerminal = null;
        }
      }

      if (terminalId == null) {
        print("ERRO: Não foi possível determinar o terminal para buscar tanques");
        setState(() {
          _carregando = false;
          tanques = [];
          _nomeFilial = null;
        });
        return;
      }

      final query = supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            capacidade,
            lastro,
            status,
            id_produto,
            produtos (nome),
            terminais!inner (nome)
          ''')
          .eq('terminal_id', terminalId)
          .order('referencia');

      final tanquesResponse = await query;

      bool filialEmite = false;
      final String? usuarioFilialId = usuario.filialId;
      if (usuarioFilialId != null) {
        try {
          final filialResp = await supabase
              .from('filiais')
              .select('emite_cacl_mov')
              .eq('id', usuarioFilialId)
              .maybeSingle();

          if (filialResp != null) {
            filialEmite = filialResp['emite_cacl_mov'] == true;
          }
        } catch (_) {
          filialEmite = false;
        }
      }

      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (final tanque in tanquesResponse) {
        tanquesFormatados.add({
          'id': tanque['id'],
          'referencia': tanque['referencia']?.toString() ?? 'SEM REFERÊNCIA',
          'produto': tanque['produtos']?['nome']?.toString() ?? 'PRODUTO NÃO INFORMADO',
          'capacidade': tanque['capacidade']?.toString() ?? '0',
          'lastro': tanque['lastro']?.toString(),
          'status': tanque['status']?.toString() ?? 'Em operação',
          'id_produto': tanque['id_produto'],
          'terminal_nome': tanque['terminais']?['nome']?.toString() ?? nomeTerminal,
        });
      }

      tanquesFormatados.sort((a, b) {
        final numA = _extrairNumeroTanque(a['referencia']?.toString() ?? '');
        final numB = _extrairNumeroTanque(b['referencia']?.toString() ?? '');
        if (numA != numB) {
          return numA.compareTo(numB);
        }
        return (a['referencia']?.toString() ?? '').compareTo(b['referencia']?.toString() ?? '');
      });

      setState(() {
        tanques = tanquesFormatados;
        _carregando = false;
        _nomeFilial = nomeTerminal;
        _filialEmiteCacl = filialEmite;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _nomeFilial = null;
      });
      print('Erro ao carregar dados: $e');
    }
  }

  void _editarTanque(Map<String, dynamic> tanque) {
    setState(() {
      _editando = true;
      _tanqueEditando = tanque;
      _referenciaController.text = tanque['referencia'];
      
      final capacidade = tanque['capacidade'];
      if (capacidade != null && capacidade.isNotEmpty) {
        _capacidadeController.text = _formatarMilhar(capacidade);
      } else {
        _capacidadeController.clear();
      }
      
      _produtoSelecionado = tanque['id_produto']?.toString();
      _statusSelecionado = tanque['status'];
      _lastroController.text = _formatarMilhar(tanque['lastro']);
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editando = false;
      _tanqueEditando = null;
      _referenciaController.clear();
      _capacidadeController.clear();
      _lastroController.clear();
      _produtoSelecionado = null;
      _statusSelecionado = null;
      _mostrandoCardsAcoes = true;
    });
  }

  void _mostrarCardsAcoesDoTanque(Map<String, dynamic> tanque) {
    setState(() {
      _mostrandoCardsAcoes = true;
      _tanqueSelecionadoParaAcoes = tanque;
    });
    final tanqueId = tanque['id']?.toString();
    if (tanqueId != null && tanqueId.isNotEmpty) {
      _carregarCaclsDoTanque(tanqueId);
    }
  }

  Future<void> _carregarCaclsDoTanque(String tanqueId) async {
    setState(() {
      _carregandoCacls = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final hoje = DateTime.now();
      final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
      final fimDoDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

      final response = await supabase
          .from('cacl')
          .select('''
            id,
            data,
            produto,
            tanque_id,
            status,
            solicita_canc,
            horario_inicial,
            horario_final,
            tanques:tanque_id (referencia)
          ''')
          .eq('tanque_id', tanqueId)
          .order('data', ascending: false)
          .order('created_at', ascending: false);

      if (mounted) {
        final caclesFiltrados = List<Map<String, dynamic>>.from(response).where((cacl) {
          final status = cacl['status']?.toString().toLowerCase();
          final dataCacl = cacl['data'] != null 
              ? DateTime.parse(cacl['data'].toString())
              : null;
          
          if (status == 'pendente') {
            return true;
          }
          
          if (dataCacl != null) {
            return !dataCacl.isBefore(inicioDoDia) && !dataCacl.isAfter(fimDoDia);
          }
          
          return false;
        }).toList();

        setState(() {
          _caclesTanque = caclesFiltrados;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar CACLs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregandoCacls = false;
        });
      }
    }
  }

  String _formatarInicio(dynamic data, dynamic horarioInicial) {
    if (data == null) return 'Início: -';

    try {
      final d = DateTime.parse(data.toString());

      final dataFmt =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

      String horaFmt = '';
      if (horarioInicial != null) {
        final h = horarioInicial.toString();
        if (h.contains('T')) {
          final dh = DateTime.parse(h);
          horaFmt =
              '${dh.hour.toString().padLeft(2, '0')}:${dh.minute.toString().padLeft(2, '0')}';
        } else {
          horaFmt = h.substring(0, 5);
        }
      } else {
        horaFmt =
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }

      return 'Início: $dataFmt, $horaFmt h';
    } catch (_) {
      return 'Início: -';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green;
      case 'pendente':
      case 'aguardando':
        return Colors.orange;
      case 'cancelado':
        return const Color.fromARGB(255, 192, 43, 43);
      default:
        return const Color.fromARGB(255, 128, 128, 128);
    }
  }

  Color _getCardColor(String? status, bool? solicitaCanc) {
    if (status?.toLowerCase() == 'cancelado') {
      return Colors.grey.shade50;
    }

    if (solicitaCanc == true) {
      return Colors.red.shade50;
    }

    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade50;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade50;
      case 'cancelado':
        return Colors.grey.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBorderColor(String? status, bool? solicitaCanc) {
    if (status?.toLowerCase() == 'cancelado') {
      return Colors.grey.shade300;
    }

    if (solicitaCanc == true) {
      return Colors.red.shade300;
    }

    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade300;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade300;
      case 'cancelado':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return 'Emitido';
      case 'pendente':
      case 'aguardando':
        return 'Pendente';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Sem status';
    }
  }

  Future<void> _abrirCACL() async {
    final filialId = _tanqueSelecionadoParaAcoes?['id_filial']?.toString() ?? widget.filialSelecionadaId ?? UsuarioAtual.instance!.filialId;
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    bool caclFinalizado = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicaoTanquesPage(
          onVoltar: () => Navigator.pop(context),
          filialSelecionadaId: filialId,
          tanqueSelecionadoId: tanqueId,
          onFinalizarCACL: () {
            caclFinalizado = true;
          },
        ),
      ),
    );

    if (!mounted) return;

    if (caclFinalizado) {
      await _carregarDados();
    }
    
    if (tanqueId != null && tanqueId.isNotEmpty) {
      await _carregarCaclsDoTanque(tanqueId);
    }
  }

  void _abrirEdicaoTanque() {
    if (_tanqueSelecionadoParaAcoes != null) {
      final tanqueId = _tanqueSelecionadoParaAcoes?['id'];
      final tanqueAtualizado = tanques.firstWhere(
        (t) => t['id'] == tanqueId,
        orElse: () => _tanqueSelecionadoParaAcoes!,
      );
      _editarTanque(tanqueAtualizado);
      setState(() {
        _mostrandoCardsAcoes = false;
      });
    }
  }

  void _abrirEstoqueTanque() {
    final usuario = UsuarioAtual.instance;
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    final referencia = _tanqueSelecionadoParaAcoes?['referencia']?.toString();

    if (usuario == null || tanqueId == null || tanqueId.isEmpty) {
      return;
    }

    final filialId = _tanqueSelecionadoParaAcoes?['id_filial']?.toString() ?? 
                     widget.filialSelecionadaId ?? 
                     usuario.filialId;
    if (filialId == null || filialId.isEmpty) {
      return;
    }

    final nomeFilial = _tanqueSelecionadoParaAcoes?['filial']?.toString() ??
        _nomeFilial ??
        '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelecaoTipoVisualizacaoBottomSheet(
        tanqueId: tanqueId,
        referenciaTanque: referencia ?? 'Tanque',
        filialId: filialId,
        nomeFilial: nomeFilial,
        onVoltar: () {
          setState(() {
            _mostrandoEstoqueTanque = false;
          });
          _carregarDados();
          if (tanqueId.isNotEmpty) {
            _carregarCaclsDoTanque(tanqueId);
          }
        },
      ),
    );
  }

  void _voltarDoEstoqueTanque() {
    setState(() {
      _mostrandoEstoqueTanque = false;
    });

    _carregarDados();

    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString() ?? _estoqueTanqueId;
    if (tanqueId != null && tanqueId.isNotEmpty) {
      _carregarCaclsDoTanque(tanqueId);
    }
  }

  void _aplicarMascaraCapacidade(String valor) {
    final digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      _capacidadeController.clear();
      return;
    }
    final novoTexto = _formatarMilhar(digitsOnly);
    if (_capacidadeController.text != novoTexto) {
      _capacidadeController.text = novoTexto;
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: novoTexto.length),
      );
    }
  }

  void _aplicarMascaraLastro(String valor) {
    final digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      _lastroController.clear();
      return;
    }

    final novoTexto = _formatarMilhar(digitsOnly);
    if (_lastroController.text != novoTexto) {
      _lastroController.text = novoTexto;
      _lastroController.selection = TextSelection.fromPosition(
        TextPosition(offset: novoTexto.length),
      );
    }
  }

  Future<void> _salvarTanque() async {
    final capacidadeTexto = _capacidadeController.text.trim();
    final valorNumerico = int.tryParse(capacidadeTexto.replaceAll('.', '')) ?? 0;
    final lastroTexto = _lastroController.text.trim();
    final lastroValor = lastroTexto.isEmpty
      ? null
      : int.tryParse(lastroTexto.replaceAll('.', ''));
    
    if (valorNumerico < 1000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('A capacidade deve ser de no mínimo 1.000 litros'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;
      
      String? idFilial;
      if (usuario.nivel == 3) {
        idFilial = widget.filialSelecionadaId;
      } else {
        idFilial = usuario.filialId;
      }

      if (idFilial == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro: Não foi possível determinar a filial'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final Map<String, dynamic> dadosAtualizados = {
        'referencia': _referenciaController.text.trim(),
        'capacidade': capacidadeTexto,
        'lastro': lastroValor,
        'status': _statusSelecionado,
        'id_produto': _produtoSelecionado,
        'id_filial': idFilial,
      };

      if (_tanqueEditando != null) {
        await supabase
            .from('tanques')
            .update(dadosAtualizados)
            .eq('id', _tanqueEditando!['id']);
      }

      await _carregarDados();
      
      _cancelarEdicao();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tanque ${_tanqueEditando != null ? 'atualizado' : 'criado'} com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar tanque: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _referenciaController.dispose();
    _capacidadeController.dispose();
    _lastroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrandoEstoqueTanque) {
      return EstoqueTanquePage(
        tanqueId: _estoqueTanqueId ?? '',
        referenciaTanque: _estoqueTanqueReferencia ?? 'Tanque',
        filialId: _estoqueFilialId ?? '',
        nomeFilial: _estoqueNomeFilial ?? '',
        data: DateTime.now(),
        onVoltar: _voltarDoEstoqueTanque,
      );
    }
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const _UnfocusIntent(),
      },
      child: Actions(
        actions: {
          _UnfocusIntent: CallbackAction<_UnfocusIntent>(
            onInvoke: (intent) {
              FocusManager.instance.primaryFocus?.unfocus();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line, width: 1)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: _ink),
                onPressed: _editando 
                    ? _cancelarEdicao 
                    : (_mostrandoCardsAcoes 
                        ? () => setState(() => _mostrandoCardsAcoes = false) 
                    : widget.onVoltar),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _editando 
                          ? 'Editar Tanque' 
                          : (_mostrandoCardsAcoes 
                              ? 'Ações do Tanque' 
                              : 'Gerenciamento de Tanques'),
                      style: const TextStyle(
                        fontSize: 19, 
                        fontWeight: FontWeight.bold, 
                        color: _ink
                      ),
                    ),
                  ],
                ),
              ),
              if (!_editando && !_mostrandoCardsAcoes)
                IconButton(
                  icon: const Icon(Icons.refresh, color: _ink),
                  onPressed: _carregarDados,
                  tooltip: 'Recarregar',
                ),
            ]),
          ),

          Expanded(
            child: _editando 
                ? _buildFormularioEdicao()
                : (_mostrandoCardsAcoes ? _buildCardsAcoesDoTanque() : _buildListaTanques()),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaTanques() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 16),
            Text('Carregando tanques...', style: TextStyle(fontSize: 16, color: _ink)),
          ],
        ),
      );
    }

    if (tanques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 64, color: _muted),
            const SizedBox(height: 16),
            Text(
              'Nenhum tanque encontrado',
              style: const TextStyle(fontSize: 16, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              widget.filialSelecionadaId != null && UsuarioAtual.instance!.nivel == 3
                ? 'Não há tanques cadastrados para esta seleção'
                : 'Não há tanques cadastrados',
              style: const TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 18, 60, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEstatisticaCompacta('Total', tanques.length.toString(), Icons.storage),
                Container(height: 36, width: 1.2, color: _line),
                _buildEstatisticaCompacta(
                  'Em operacao',
                  tanques.where((t) => t['status'] == 'Em operação').length.toString(),
                  Icons.check_circle,
                ),
                Container(height: 36, width: 1.2, color: _line),
                _buildEstatisticaCompacta(
                  'Suspensos',
                  tanques.where((t) => t['status'] == 'Operação suspensa').length.toString(),
                  Icons.pause_circle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: tanques.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tanque = tanques[index];
                final isOperando = tanque['status'] == 'Em operação';
                final statusColor = isOperando ? _accent : _warn;

                return _TanqueCard(
                  tanque: tanque,
                  statusColor: statusColor,
                  onTap: () => _mostrarCardsAcoesDoTanque(tanque),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstatisticaCompacta(String titulo, String valor, IconData icone) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: _accent),
            const SizedBox(width: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  Widget _buildFormularioEdicao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final fieldWidth = isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.tune, color: _accent),
                            SizedBox(width: 8),
                            Text(
                              'Editar Tanque',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Atualize os dados operacionais do tanque.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 18),

                        if (_nomeFilial != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _accent.withOpacity(0.6), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 16, color: _accent),
                                const SizedBox(width: 8),
                                Text(
                                  'Filial: $_nomeFilial',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_nomeFilial != null) const SizedBox(height: 18),

                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _referenciaController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Referência *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.tag, color: _accent),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _capacidadeController,
                                decoration: const InputDecoration(
                                  labelText: 'Capacidade *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.analytics, color: _accent),
                                  suffixText: 'Litros',
                                  hintText: '1.000',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: _aplicarMascaraCapacidade,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _lastroController,
                                decoration: const InputDecoration(
                                  labelText: 'Lastro',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.opacity, color: _accent),
                                  suffixText: 'Litros',
                                  hintText: '999.999',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: _aplicarMascaraLastro,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                value: _produtoSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Produto *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.local_gas_station, color: _accent),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Selecione um produto'),
                                  ),
                                  ...produtos.map((produto) {
                                    return DropdownMenuItem(
                                      value: produto['id']?.toString(),
                                      child: Text(produto['nome']?.toString() ?? ''),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _produtoSelecionado = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                value: _statusSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Status *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.info, color: _accent),
                                ),
                                items: _statusOptions.map((status) {
                                  return DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _statusSelecionado = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelarEdicao,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: _accent, width: 1.4),
                                  foregroundColor: _accent,
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _salvarTanque,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ink,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Salvar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsAcoesDoTanque() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 18, 60, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tanqueSelecionadoParaAcoes != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.storage, color: _accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tanqueSelecionadoParaAcoes!['referencia'] ?? 'Tanque',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tanqueSelecionadoParaAcoes!['produto'] ?? 'Produto',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.analytics,
                      titulo: 'CACL Movimentação',
                      descricao: 'Emitir CACL Movimentação',
                      onTap: _abrirCACL,
                      enabled: _filialEmiteCacl,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.inventory_2,
                      titulo: 'Movimentação tanque',
                      descricao: 'Consultar movimentação do tanque',
                      onTap: _abrirEstoqueTanque,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.edit,
                      titulo: 'Editar Tanque',
                      descricao: 'Atualizar dados do tanque',
                      onTap: _abrirEdicaoTanque,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18, color: _accent),
                    const SizedBox(width: 8),
                    const Text(
                      'CACLs emitidos do tanque',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: _accent),
                      onPressed: _tanqueSelecionadoParaAcoes?['id'] == null
                          ? null
                          : () {
                              final tanqueId =
                                  _tanqueSelecionadoParaAcoes?['id']?.toString();
                              if (tanqueId != null && tanqueId.isNotEmpty) {
                                _carregarCaclsDoTanque(tanqueId);
                              }
                            },
                      tooltip: 'Recarregar CACLs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_carregandoCacls)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: _accent),
                  ),
                )
              else if (_caclesTanque.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.receipt_long_outlined, size: 52, color: _muted),
                      SizedBox(height: 10),
                      Text(
                        'Nenhum CACL encontrado para este tanque',
                        style: TextStyle(fontSize: 14, color: _muted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _caclesTanque.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cacl = _caclesTanque[index];
                    final status = cacl['status']?.toString();
                    final solicitaCanc = cacl['solicita_canc'] as bool?;
                    final isCancelado = status?.toLowerCase() == 'cancelado';
                    final statusColor = _getStatusColor(status);
                    final cardColor = _getCardColor(status, solicitaCanc);
                    final borderColor = _getBorderColor(status, solicitaCanc);
                    final statusText = _getStatusText(status);
                    final tanqueRef =
                        cacl['tanques']?['referencia']?.toString() ?? '-';
                    final produto = cacl['produto'] ?? 'Produto não informado';

                    final inicio =
                        _formatarInicio(cacl['data'], cacl['horario_inicial']);

                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 1300,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _hoverCaclIndex = index),
                            onExit: (_) =>
                                setState(() => _hoverCaclIndex = null),
                            child: GestureDetector(
                              onTap: () async {
                                final nivelUsuario =
                                    UsuarioAtual.instance?.nivel ?? 0;
                                if (nivelUsuario == 2 && isCancelado) return;

                                final caclId = cacl['id'].toString();
                                final isPendente =
                                    status?.toLowerCase() == 'pendente';
                                final isAguardando =
                                    status?.toLowerCase() == 'aguardando';

                                if (!context.mounted) return;

                                if (isPendente || isAguardando) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditarCaclPage(
                                        caclId: caclId,
                                        onVoltar: () =>
                                            Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                } else {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CaclHistoricoPage(
                                        caclId: caclId,
                                        onVoltar: () =>
                                            Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                }

                                final tanqueId =
                                    _tanqueSelecionadoParaAcoes?['id']
                                        ?.toString();
                                if (tanqueId != null && tanqueId.isNotEmpty) {
                                  _carregarCaclsDoTanque(tanqueId);
                                }
                              },
                              child: Opacity(
                                opacity: isCancelado ? 0.85 : 1.0,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  transform: _hoverCaclIndex == index
                                      ? (Matrix4.identity()
                                        ..scale(1.01, 1.01))
                                      : Matrix4.identity(),
                                  decoration: BoxDecoration(
                                    color: _hoverCaclIndex == index
                                        ? cardColor.withOpacity(0.85)
                                        : cardColor,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: borderColor, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          _hoverCaclIndex == index
                                              ? 0.15
                                              : 0.05,
                                        ),
                                        blurRadius: _hoverCaclIndex == index
                                            ? 12
                                            : 4,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.storage,
                                                      size: 16,
                                                      color:
                                                          Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tanque $tanqueRef',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isCancelado
                                                          ? Colors.grey
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.local_gas_station,
                                                    size: 14,
                                                    color: isCancelado
                                                        ? Colors.grey
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      produto,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: isCancelado
                                                            ? Colors.grey
                                                            : Colors.black87,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.play_circle_outline,
                                                    size: 14,
                                                    color: isCancelado
                                                        ? Colors.grey
                                                        : Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      inicio,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isCancelado
                                                            ? Colors.grey
                                                            : Colors.black54,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardAcao({
    required IconData icon,
    required String titulo,
    required String descricao,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final cardBg = enabled ? Colors.white : Colors.grey.shade50;
    final innerBg = enabled ? _accent.withOpacity(0.1) : Colors.grey.shade200;
    final iconColor = enabled ? _accent : Colors.grey.shade500;
    final titleColor = enabled ? _ink : Colors.grey.shade600;
    final descColor = enabled ? _muted : Colors.grey.shade500;

    return Material(
      elevation: 2,
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: enabled ? onTap : null,
        hoverColor: enabled ? _accent.withOpacity(0.1) : Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: enabled ? _line : Colors.grey.shade300, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: enabled ? _accent.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                descricao,
                style: TextStyle(
                  fontSize: 12,
                  color: descColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TanqueCard extends StatefulWidget {
  final Map<String, dynamic> tanque;
  final Color statusColor;
  final VoidCallback onTap;

  const _TanqueCard({
    required this.tanque,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_TanqueCard> createState() => _TanqueCardState();
}

class _TanqueCardState extends State<_TanqueCard> {
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _muted = Color(0xFF5A6B7A);
  static const Color _line = Color(0xFFE6DCCB);
  
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: _isHovering ? const Color(0xFFF5F5F5) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _line, width: 1.2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tanque['referencia'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.tanque['produto'],
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.tanque['lastro'] != null &&
                          widget.tanque['lastro'].toString().trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _line, width: 1.2),
                          ),
                          child: Text(
                            'Lastro: ${_formatarMilhar(widget.tanque['lastro'])} L',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (widget.tanque['lastro'] != null &&
                          widget.tanque['lastro'].toString().trim().isNotEmpty)
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _line, width: 1.2),
                        ),
                        child: Text(
                          '${widget.tanque['capacidade']} L',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: widget.statusColor, width: 1.2),
                        ),
                        child: Text(
                          widget.tanque['status'],
                          style: TextStyle(
                            color: widget.statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

class _SelecaoTipoVisualizacaoBottomSheet extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final String filialId;
  final String nomeFilial;
  final VoidCallback onVoltar;

  const _SelecaoTipoVisualizacaoBottomSheet({
    required this.tanqueId,
    required this.referenciaTanque,
    required this.filialId,
    required this.nomeFilial,
    required this.onVoltar,
  });

  @override
  State<_SelecaoTipoVisualizacaoBottomSheet> createState() => _SelecaoTipoVisualizacaoBottomSheetState();
}

class _SelecaoTipoVisualizacaoBottomSheetState extends State<_SelecaoTipoVisualizacaoBottomSheet> {
  bool _tipoDataEspecifica = true;
  bool _tipoMensal = false;
  
  DateTime _dataSelecionada = DateTime.now();
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;
  
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _mesAnoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _atualizarDataController();
    _atualizarMesAnoController();
  }

  void _atualizarDataController() {
    _dataController.text = DateFormat('dd/MM/yyyy').format(_dataSelecionada);
  }

  void _atualizarMesAnoController() {
    _mesAnoController.text = '${_mesSelecionado.toString().padLeft(2, '0')}/${_anoSelecionado}';
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
        _tipoDataEspecifica = true;
        _tipoMensal = false;
        _atualizarDataController();
      });
    }
  }

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[mes - 1];
  }

  Future<void> _selecionarMesAno() async {
    int tempMes = _mesSelecionado;
    int tempAno = _anoSelecionado;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Selecionar Mês/Ano'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: tempMes,
                            decoration: const InputDecoration(
                              labelText: 'Mês',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(12, (index) {
                              final mes = index + 1;
                              return DropdownMenuItem(
                                value: mes,
                                child: Text(_getNomeMes(mes)),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() {
                                  tempMes = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: tempAno.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Ano',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final ano = int.tryParse(value);
                              if (ano != null && ano >= 2000 && ano <= 2100) {
                                setStateDialog(() {
                                  tempAno = ano;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _mesSelecionado = tempMes;
                      _anoSelecionado = tempAno;
                      _tipoMensal = true;
                      _tipoDataEspecifica = false;
                      _atualizarMesAnoController();
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _visualizar() {
    if (!_tipoDataEspecifica && !_tipoMensal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um tipo de visualização'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context);

    if (_tipoDataEspecifica) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EstoqueTanquePage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            filialId: widget.filialId,
            nomeFilial: widget.nomeFilial,
            data: _dataSelecionada,
            onVoltar: widget.onVoltar,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EstoqueTanqueMensalPage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            filialId: widget.filialId,
            nomeFilial: widget.nomeFilial,
            mes: _mesSelecionado,
            ano: _anoSelecionado,
            onVoltar: widget.onVoltar,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'Selecionar Período',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          InkWell(
            onTap: _selecionarData,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _tipoDataEspecifica 
                      ? const Color(0xFF0D47A1) 
                      : Colors.grey.shade300,
                  width: _tipoDataEspecifica ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: _tipoDataEspecifica 
                    ? const Color(0xFF0D47A1).withOpacity(0.05)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _tipoDataEspecifica,
                    onChanged: (value) {
                      setState(() {
                        _tipoDataEspecifica = true;
                        _tipoMensal = false;
                      });
                    },
                    activeColor: const Color(0xFF0D47A1),
                  ),
                  const Expanded(
                    child: Text(
                      'Data específica',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _dataController.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          InkWell(
            onTap: _selecionarMesAno,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _tipoMensal 
                      ? const Color(0xFF0D47A1) 
                      : Colors.grey.shade300,
                  width: _tipoMensal ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: _tipoMensal 
                    ? const Color(0xFF0D47A1).withOpacity(0.05)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _tipoMensal,
                    onChanged: (value) {
                      setState(() {
                        _tipoMensal = true;
                        _tipoDataEspecifica = false;
                      });
                    },
                    activeColor: const Color(0xFF0D47A1),
                  ),
                  const Expanded(
                    child: Text(
                      'Estoque mensal',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _mesAnoController.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF0D47A1)),
                    foregroundColor: const Color(0xFF0D47A1),
                  ),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _visualizar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Visualizar'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dataController.dispose();
    _mesAnoController.dispose();
    super.dispose();
  }
}

class _UnfocusIntent extends Intent {
  const _UnfocusIntent();
}

String _formatarMilhar(dynamic valor) {
  if (valor == null) return '';
  final digitsOnly = valor.toString().replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.isEmpty) return '';

  final buffer = StringBuffer();
  for (int i = 0; i < digitsOnly.length; i++) {
    final reverseIndex = digitsOnly.length - i;
    buffer.write(digitsOnly[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}