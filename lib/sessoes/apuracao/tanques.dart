import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'emitir_cacl.dart';
import 'cacl_historico.dart';
//import 'escolherfilial.dart';

class GerenciamentoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? filialSelecionadaId; // ← NOVO PARÂMETRO
  final Function(String filialId)? onAbrirCACL; // ← CALLBACK PARA ABRIR CACL

  const GerenciamentoTanquesPage({
    super.key, 
    required this.onVoltar,
    this.filialSelecionadaId, // ← NOVO PARÂMETRO
    this.onAbrirCACL, // ← CALLBACK PARA ABRIR CACL
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
  bool _mostrandoCardsAcoes = false; // ← NOVO: MOSTRA CARDS DE AÇÕES
  Map<String, dynamic>? _tanqueEditando;
  Map<String, dynamic>? _tanqueSelecionadoParaAcoes; // ← NOVO: TANQUE PARA CARDS DE AÇÕES
  String? _nomeFilial; // ← PARA MOSTRAR O NOME DA FILIAL
  bool _carregandoCacls = false;
  List<Map<String, dynamic>> _caclesTanque = [];
  int? _hoverCaclIndex;

  final List<String> _statusOptions = ['Em operação', 'Operação suspensa'];
  
  // Controladores para o formulário de edição
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

      // Carrega produtos
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      setState(() {
        produtos = List<Map<String, dynamic>>.from(produtosResponse);
      });

      // ---------------------------
      //   BUSCAR NOME DA FILIAL (SE FOR ADMIN)
      // ---------------------------
      String? nomeFilial;
      if (usuario.nivel == 3 && widget.filialSelecionadaId != null) {
        final filialData = await supabase
            .from('filiais')
            .select('nome')
            .eq('id', widget.filialSelecionadaId!)
            .single();
        nomeFilial = filialData['nome'];
      } else if (usuario.filialId != null) {
        final filialData = await supabase
            .from('filiais')
            .select('nome')
            .eq('id', usuario.filialId!)
            .single();
        nomeFilial = filialData['nome'];
      }

      // Carrega tanques
      final PostgrestTransformBuilder<dynamic> query;
      
      // ---------------------------
      //   ADMINISTRADOR (NÍVEL 3)
      // ---------------------------
      if (usuario.nivel == 3) {
        // Verifica se tem filial selecionada
        if (widget.filialSelecionadaId == null) {
          print("ERRO: Admin não escolheu filial para visualizar tanques");
          setState(() {
            _carregando = false;
            tanques = []; // Lista vazia
            _nomeFilial = null;
          });
          return;
        }
        
        query = supabase
            .from('tanques')
            .select('''
              id,
              referencia,
              capacidade,
              lastro,
              status,
              id_produto,
              id_filial,
              produtos (nome),
              filiais (nome)
            ''')
            .eq('id_filial', widget.filialSelecionadaId!) // ← FILTRAR pela filial escolhida
            .order('referencia');
      } 
      // ---------------------------
      //   USUÁRIO NORMAL
      // ---------------------------
      else {
        final idFilial = usuario.filialId;
        if (idFilial == null) {
          print('Erro: ID da filial não encontrado para usuário não-admin');
          setState(() {
            _carregando = false;
            _nomeFilial = null;
          });
          return;
        }
        
        query = supabase
            .from('tanques')
            .select('''
              id,
              referencia,
              capacidade,
              lastro,
              status,
              id_produto,
              produtos (nome)
            ''')
            .eq('id_filial', idFilial)
            .order('referencia');
      }

      final tanquesResponse = await query;

      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (final tanque in tanquesResponse) {
        // Corrigir o acesso ao nome da filial
        String? nomeFilial;
        if (usuario.nivel == 3) {
          // Para admin, acessa o objeto aninhado filiais
          if (tanque['filiais'] != null) {
            nomeFilial = tanque['filiais'] is Map 
                ? tanque['filiais']['nome']?.toString()
                : tanque['filiais']?.toString();
          }
        }

        tanquesFormatados.add({
          'id': tanque['id'],
          'referencia': tanque['referencia']?.toString() ?? 'SEM REFERÊNCIA',
          'produto': tanque['produtos']?['nome']?.toString() ?? 'PRODUTO NÃO INFORMADO',
          'capacidade': tanque['capacidade']?.toString() ?? '0',
          'lastro': tanque['lastro']?.toString(),
          'status': tanque['status']?.toString() ?? 'Em operação',
          'id_produto': tanque['id_produto'],
          // Adicionar nome da filial se for admin
          'filial': nomeFilial,
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
        _nomeFilial = nomeFilial;
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
      
      // Formata a capacidade existente para o novo padrão
      final capacidade = tanque['capacidade'];
      if (capacidade != null && capacidade.isNotEmpty) {
        final valorNumerico = int.tryParse(capacidade.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (valorNumerico >= 1000) {
          final parteMilhar = (valorNumerico ~/ 1000).toString();
          _capacidadeController.text = '${parteMilhar}.000';
        } else {
          _capacidadeController.text = '1.000'; // Valor mínimo
        }
      } else {
        _capacidadeController.text = '1.000'; // Valor padrão
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
      // Volta para os cards de ações
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
        setState(() {
          _caclesTanque = List<Map<String, dynamic>>.from(response);
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

  String _formatarData(dynamic data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data.toString());
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return data.toString();
    }
  }

  String _formatarHorario(dynamic horarioInicial, dynamic horarioFinal) {
    if (horarioInicial != null && horarioFinal != null) {
      return '$horarioInicial - $horarioFinal';
    } else if (horarioInicial != null) {
      return 'Início: $horarioInicial';
    } else if (horarioFinal != null) {
      return 'Fim: $horarioFinal';
    }
    return 'Sem horário';
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

  void _abrirCACL() {
    final filialId = widget.filialSelecionadaId ?? UsuarioAtual.instance!.filialId;
    final tanqueId = _tanqueSelecionadoParaAcoes?['id']?.toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicaoTanquesPage(
          onVoltar: () => Navigator.pop(context),
          filialSelecionadaId: filialId,
          tanqueSelecionadoId: tanqueId,
        ),
      ),
    );
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

  // Função para aplicar máscara no campo capacidade
  void _aplicarMascaraCapacidade(String valor) {
    // Se o texto já está formatado corretamente, não faz nada
    if (valor.endsWith('.000') && valor.length > 4) {
      return;
    }

    // Remove todos os caracteres não numéricos
    String digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    
    // Se estiver vazio, define como 1.000
    if (digitsOnly.isEmpty) {
      _capacidadeController.text = '1.000';
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: 1),
      );
      return;
    }
    
    // Remove zeros à esquerda, mas garante pelo menos 1
    int valorNumerico = int.parse(digitsOnly);
    if (valorNumerico < 1) {
      valorNumerico = 1;
    }
    
    // Formata como X.000
    final parteMilhar = valorNumerico.toString();
    final novoTexto = '${parteMilhar}.000';
    
    // Só atualiza se for diferente do texto atual
    if (_capacidadeController.text != novoTexto) {
      _capacidadeController.text = novoTexto;
      
      // Posiciona o cursor antes do ponto
      final cursorPosition = parteMilhar.length;
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: cursorPosition),
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
    // Validação do valor mínimo
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
      
      // Determinar id_filial para o tanque
      String? idFilial;
      if (usuario.nivel == 3) {
        // Admin usa a filial selecionada
        idFilial = widget.filialSelecionadaId;
      } else {
        // Usuário normal usa sua própria filial
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
        'id_filial': idFilial, // ← Sempre definir a filial
      };

      if (_tanqueEditando != null) {
        // Atualizar tanque existente
        await supabase
            .from('tanques')
            .update(dadosAtualizados)
            .eq('id', _tanqueEditando!['id']);
      } else {
        // Criar novo tanque (se implementar criação futura)
        // await supabase.from('tanques').insert(dadosAtualizados);
      }

      // Recarrega os dados
      await _carregarDados();
      
      // Volta para a lista
      _cancelarEdicao();

      // Mostra mensagem de sucesso
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
          // Cabeçalho
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
                    if (_nomeFilial != null && !_editando && !_mostrandoCardsAcoes)
                      Text(
                        'Filial: $_nomeFilial',
                        style: TextStyle(
                          fontSize: 12, 
                          color: _accent, 
                          fontWeight: FontWeight.w500
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

          // Conteúdo
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
                ? 'Não há tanques cadastrados para esta filial'
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
                  // Card CACL
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.analytics,
                      titulo: 'CACL',
                      descricao: 'Emitir CACL',
                      onTap: _abrirCACL,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Card Estoque Tanque
                  Expanded(
                    child: _buildCardAcao(
                      icon: Icons.inventory_2,
                      titulo: 'Estoque tanque',
                      descricao: 'Consultar estoque do tanque',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Card Editar Tanque
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
                    final tanqueRef = cacl['tanques']?['referencia']?.toString() ?? '-';
                    final produto = cacl['produto'] ?? 'Produto não informado';
                    final data = _formatarData(cacl['data']);
                    final horario = _formatarHorario(
                      cacl['horario_inicial'],
                      cacl['horario_final'],
                    );

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) {
                        setState(() => _hoverCaclIndex = index);
                      },
                      onExit: (_) {
                        setState(() => _hoverCaclIndex = null);
                      },
                      child: GestureDetector(
                        onTap: () async {
                          final nivelUsuario = UsuarioAtual.instance?.nivel ?? 0;
                          if (nivelUsuario == 2 && isCancelado) {
                            return;
                          }

                          final caclId = cacl['id'].toString();

                          if (!context.mounted) return;

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CaclHistoricoPage(
                                caclId: caclId,
                                onVoltar: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );

                          final tanqueId =
                              _tanqueSelecionadoParaAcoes?['id']?.toString();
                          if (tanqueId != null && tanqueId.isNotEmpty) {
                            _carregarCaclsDoTanque(tanqueId);
                          }
                        },
                        child: Opacity(
                          opacity: isCancelado ? 0.85 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            transform: _hoverCaclIndex == index
                                ? (Matrix4.identity()..scale(1.01))
                                : Matrix4.identity(),
                            decoration: BoxDecoration(
                              color: _hoverCaclIndex == index
                                  ? cardColor.withOpacity(0.85)
                                  : cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    _hoverCaclIndex == index ? 0.15 : 0.05,
                                  ),
                                  blurRadius: _hoverCaclIndex == index ? 12 : 4,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 4,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.storage,
                                              size: 16,
                                              color: Colors.black54,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Tanque $tanqueRef',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
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
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: isCancelado
                                                  ? Colors.grey
                                                  : Colors.black54,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              data,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isCancelado
                                                    ? Colors.grey
                                                    : Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: isCancelado
                                                  ? Colors.grey
                                                  : Colors.black54,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                horario,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isCancelado
                                                      ? Colors.grey
                                                      : Colors.black54,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
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
                    );
                  },
                ),
            ]
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
  }) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        hoverColor: _accent.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: _line, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
                ),
                child: Icon(icon, color: _accent, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                descricao,
                style: const TextStyle(
                  fontSize: 12,
                  color: _muted,
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
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
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
                        if (widget.tanque['lastro'] != null &&
                            widget.tanque['lastro'].toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Lastro: ${_formatarMilhar(widget.tanque['lastro'])} L',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ),
                        if (UsuarioAtual.instance!.nivel == 3 && widget.tanque['filial'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Filial: ${widget.tanque['filial']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _line, width: 1.2),
                        ),
                        child: Text(
                          '${widget.tanque['capacidade']} Litros',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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