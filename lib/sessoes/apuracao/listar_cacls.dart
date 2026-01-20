import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'cacl.dart';
import '../../login_page.dart';
import 'emitir_cacl.dart';
import 'editar_cacl.dart';
import 'cacl_historico.dart';

class ListarCaclsPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String filialId;
  final String filialNome;
  final VoidCallback onIrParaEmissao;
  final VoidCallback? onFinalizarCACL;

  const ListarCaclsPage({
    super.key,
    required this.onVoltar,
    required this.filialId,
    required this.filialNome,
    required this.onIrParaEmissao,
    this.onFinalizarCACL,
  });

  @override
  State<ListarCaclsPage> createState() => _ListarCaclsPageState();
}

class _ListarCaclsPageState extends State<ListarCaclsPage> with WidgetsBindingObserver {
  bool _carregando = true;
  List<Map<String, dynamic>> _cacles = [];
  int? _nivelUsuario;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarNivelUsuario();
    _carregarCaclsSimples();
  }

  Future<void> _carregarNivelUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final usuarioId = UsuarioAtual.instance?.id;
      
      if (usuarioId != null) {
        final response = await supabase
            .from('usuarios')
            .select('nivel')
            .eq('id', usuarioId)
            .single();
        
        setState(() {
          _nivelUsuario = response['nivel'] as int? ?? 0;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar nível do usuário: $e');
      setState(() {
        _nivelUsuario = 0;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void didUpdateWidget(ListarCaclsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filialId != widget.filialId) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    await _carregarCaclsSimples();
  }

  Future<void> _carregarCaclsSimples() async {
    if (_carregando && _cacles.isNotEmpty) return;
    
    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final dataAtual = DateTime.now();
      final dataFormatada =
          '${dataAtual.year}-${dataAtual.month.toString().padLeft(2, '0')}-${dataAtual.day.toString().padLeft(2, '0')}';

      final todosCacls = await supabase
          .from('cacl')
          .select('''
            id,
            numero_controle,
            data,
            produto,
            tanque_id,
            tanques:tanque_id (referencia),
            status,
            horario_inicial,
            horario_final,
            volume_produto_inicial,
            volume_produto_final,
            volume_total_liquido_inicial,
            volume_total_liquido_final,
            base,
            solicita_canc
          ''')
          .eq('filial_id', widget.filialId)
          .order('created_at', ascending: false);

      // ALTERAÇÃO: Inclui CACLs cancelados na lista
      final caclsFiltrados = todosCacls.where((cacl) {
        final status = cacl['status']?.toString().toLowerCase() ?? '';
        final data = cacl['data']?.toString() ?? '';

        // Inclui CACLs cancelados
        if (status.contains('cancelado')) {
          return true;
        }

        if (status.contains('pendente') || status.contains('aguardando')) {
          return true;
        }

        if (status.contains('emitido') && data == dataFormatada) {
          return true;
        }

        return false;
      }).toList();

      setState(() {
        _cacles = List<Map<String, dynamic>>.from(caclsFiltrados);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar CACLs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _solicitarCancelamento(String caclId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('cacl')
          .update({'solicita_canc': true})
          .eq('id', caclId);
      
      if (mounted) {
        // Atualiza localmente
        setState(() {
          final index = _cacles.indexWhere((c) => c['id'] == caclId);
          if (index != -1) {
            _cacles[index]['solicita_canc'] = true;
          }
        });
        
        // Mostra mensagem de confirmação
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cancelamento solicitado ao supervisor. Aguarde.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao solicitar cancelamento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao solicitar cancelamento: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _confirmarCancelamento(String caclId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('cacl')
          .update({
            'status': 'cancelado',
            'solicita_canc': false  // Marca como false ao cancelar
          })
          .eq('id', caclId);
      
      if (mounted) {
        // Atualiza localmente
        setState(() {
          final index = _cacles.indexWhere((c) => c['id'] == caclId);
          if (index != -1) {
            _cacles[index]['status'] = 'cancelado';
            _cacles[index]['solicita_canc'] = false;
          }
        });
        
        // Mostra mensagem de confirmação
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('CACL cancelado com sucesso.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao cancelar CACL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar CACL: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cancelarDireto(String caclId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('cacl')
          .update({
            'status': 'cancelado',
            'solicita_canc': false  // Marca como false ao cancelar
          })
          .eq('id', caclId);
      
      if (mounted) {
        // Atualiza localmente
        setState(() {
          final index = _cacles.indexWhere((c) => c['id'] == caclId);
          if (index != -1) {
            _cacles[index]['status'] = 'cancelado';
            _cacles[index]['solicita_canc'] = false;
          }
        });
        
        // Mostra mensagem de confirmação
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('CACL cancelado com sucesso.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao cancelar CACL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cancelar CACL: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
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
    // Para nível 3, card vermelho apenas se tiver solicitação pendente
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
    // Para nível 3, borda vermelha apenas se tiver solicitação pendente
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== CABEÇALHO =====
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Listar CACLs',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.filialNome,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
              onPressed: _refreshData,
              tooltip: 'Atualizar lista',
            ),
            const SizedBox(width: 10),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),

        // ===== BOTÃO EMITIR CACL =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MedicaoTanquesPage(
                    onVoltar: () {
                      Navigator.pop(context);
                      _refreshData();
                    },
                    filialSelecionadaId: widget.filialId,
                    onFinalizarCACL: () {
                      widget.onFinalizarCACL?.call();
                      _refreshData();
                    },
                    caclesHoje: _cacles,
                  ),
                ),
              ).then((_) {
                _refreshData();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text(
                  'Emitir CACL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ===== LISTA DE CACLS =====
        Expanded(
          child: _carregando && _cacles.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : _cacles.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum CACL encontrado',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Clique em "Emitir CACL" para criar um novo',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: const Color(0xFF0D47A1),
                      child: ListView.separated(
                        itemCount: _cacles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          final cacl = _cacles[index];
                          final status = cacl['status']?.toString();
                          final solicitaCanc = cacl['solicita_canc'] as bool?;
                          final isCancelado = status?.toLowerCase() == 'cancelado';
                          final statusColor = _getStatusColor(status);
                          final cardColor = _getCardColor(status, solicitaCanc);
                          final borderColor = _getBorderColor(status, solicitaCanc);
                          final statusText = _getStatusText(status);
                          final tanqueNome = cacl['tanques']?['referencia']?.toString();
                          final tanque = tanqueNome ?? '-';
                          final produto = cacl['produto'] ?? 'Produto não informado';
                          final numeroControle = cacl['numero_controle']?.toString() ?? '';
                          final data = _formatarData(cacl['data']);
                          final horario = _formatarHorario(
                            cacl['horario_inicial'],
                            cacl['horario_final'],
                          );

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) {
                              setState(() => _hoverIndex = index);
                            },
                            onExit: (_) {
                              setState(() => _hoverIndex = null);
                            },
                            child: GestureDetector(
                              onTap: () async {
                                // Verifica se o usuário pode clicar no CACL
                                final nivelUsuario = _nivelUsuario ?? 0;
                                final isCancelado = status?.toLowerCase() == 'cancelado';
                                
                                // Regras de permissão:
                                // - Nível 1: Pode clicar em qualquer CACL
                                // - Nível 2: NÃO pode clicar em CACLs cancelados
                                // - Nível 3: Pode clicar em qualquer CACL (incluindo cancelados)
                                if (nivelUsuario == 2 && isCancelado) {
                                  // Nível 2 não pode clicar em CACLs cancelados
                                  return;
                                }
                                
                                final caclId = cacl['id'].toString(); // Captura o ID
                                print('📤 [ListarCaclsPage] Navegando para CaclHistoricoPage com ID: $caclId');

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
                                
                                _refreshData();
                              },
                              child: Opacity(
                                // Opacidade reduzida para níveis 2 e 3 quando cancelado
                                opacity: isCancelado ? 0.85 : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  transform: _hoverIndex == index
                                      ? (Matrix4.identity()..scale(1.01))
                                      : Matrix4.identity(),
                                  decoration: BoxDecoration(
                                    color: _hoverIndex == index
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
                                          _hoverIndex == index ? 0.15 : 0.05,
                                        ),
                                        blurRadius: _hoverIndex == index ? 12 : 4,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Indicador de status (barra lateral)
                                        Container(
                                          width: 4,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        
                                        // Informações principais
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Linha 1: Tanque (destaque)
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.storage,
                                                    size: 16,
                                                    color: Colors.black54,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tanque $tanque',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      // Texto mais claro para níveis 2 e 3 quando cancelado
                                                      color: isCancelado 
                                                          ? Colors.grey 
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              
                                              // Linha 2: Produto e Número de Controle
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
                                                  Flexible(
                                                    child: RichText(
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: produto,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: isCancelado 
                                                                  ? Colors.grey 
                                                                  : Colors.black87,
                                                            ),
                                                          ),
                                                          if (numeroControle.isNotEmpty) ...[
                                                            const TextSpan(
                                                              text: '  •  ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text: 'CACL: $numeroControle',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: isCancelado 
                                                                    ? Colors.grey 
                                                                    : const Color.fromARGB(255, 92, 92, 92),
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              
                                              // Linha 3: Data e Horário
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
                                        
                                        // Status e ações
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Badge de status
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
                                            const SizedBox(height: 8),
                                            
                                            // Botões de ação
                                            Row(
                                              children: [
                                                // Botão Editar - SOMENTE se status for 'pendente' e não cancelado
                                                if (!isCancelado && 
                                                    (cacl['status']?.toString().toLowerCase() ?? '').contains('pendente'))
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 22,
                                                      color: Color(0xFF0D47A1),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (context) => EditarCaclPage(
                                                            onVoltar: () {
                                                              Navigator.pop(context);
                                                              _refreshData();
                                                            },
                                                            caclId: cacl['id'].toString(),
                                                          ),
                                                        ),
                                                      ).then((_) {
                                                        _refreshData();
                                                      });
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
                                                
                                                // Botão Solicitar Cancelamento (níveis 1 e 2) - Laranja se não solicitado, Vermelho se solicitado
                                                if (!isCancelado && 
                                                    (_nivelUsuario == 1 || _nivelUsuario == 2))
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      if (solicitaCanc == true) {
                                                        // Se já solicitado, mostra mensagem
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Cancelamento já solicitado. Aguarde a análise do supervisor.'),
                                                            backgroundColor: Colors.orange,
                                                            duration: Duration(seconds: 3),
                                                          ),
                                                        );
                                                      } else {
                                                        _showDialogSolicitarCancelamento(cacl);
                                                      }
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: solicitaCanc == true 
                                                          ? Colors.red.shade50 
                                                          : Colors.orange.shade50,
                                                      foregroundColor: solicitaCanc == true 
                                                          ? Colors.red.shade800 
                                                          : Colors.orange.shade800,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: const Size(0, 0),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        side: BorderSide(
                                                          color: solicitaCanc == true 
                                                              ? Colors.red.shade300 
                                                              : Colors.orange.shade300,
                                                        ),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(
                                                      solicitaCanc == true 
                                                          ? 'Cancelamento\nsolicitado' 
                                                          : 'Solicitar\ncancelamento',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                
                                                // Botão Confirmar Cancelamento (nível 3) - Quando solicita_canc = true
                                                if (!isCancelado && 
                                                    _nivelUsuario == 3 && 
                                                    solicitaCanc == true)
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      _showDialogConfirmarCancelamento(cacl);
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade50,
                                                      foregroundColor: Colors.red.shade800,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: const Size(0, 0),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        side: BorderSide(color: Colors.red.shade300),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text(
                                                      'Cancelamento\nsolicitado',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                
                                                // Botão Cancelar CACL direto (nível 3) - Quando solicita_canc = false/null e não está cancelado
                                                if (!isCancelado && 
                                                    _nivelUsuario == 3 && 
                                                    (solicitaCanc == false || solicitaCanc == null) &&
                                                    status?.toLowerCase() != 'cancelado')
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      _showDialogCancelarDireto(cacl);
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade50,
                                                      foregroundColor: Colors.red.shade800,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: const Size(0, 0),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                        side: BorderSide(color: Colors.red.shade300),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text(
                                                      'Cancelar\nCACL',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                    ),
        ),
      ],
    );
  }

  void _showDialogSolicitarCancelamento(Map<String, dynamic> cacl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho com ícone
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Solicitar Cancelamento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Mensagem
                  const Padding(
                    padding: EdgeInsets.only(left: 36),
                    child: Text(
                      'Deseja solicitar o cancelamento deste CACL?\n\nEsta solicitação será enviada ao supervisor para análise.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Botões alinhados à direita
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Voltar à lista',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 102, 102, 102),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _solicitarCancelamento(cacl['id'].toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                          shadowColor: Colors.orange.withOpacity(0.3),
                        ),
                        child: const Text(
                          'Sim, quero solicitar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDialogConfirmarCancelamento(Map<String, dynamic> cacl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho com ícone
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Confirmar Cancelamento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Mensagem
                  const Padding(
                    padding: EdgeInsets.only(left: 36),
                    child: Text(
                      'O operador solicitou cancelamento deste CACL.\n\nDeseja confirmar o cancelamento?',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Botões alinhados à direita
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 102, 102, 102),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _confirmarCancelamento(cacl['id'].toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                          shadowColor: Colors.red.withOpacity(0.3),
                        ),
                        child: const Text(
                          'Confirmar Cancelamento',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDialogCancelarDireto(Map<String, dynamic> cacl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho com ícone
                  Row(
                    children: [
                      Icon(
                        Icons.dangerous_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cancelar CACL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Mensagem
                  const Padding(
                    padding: EdgeInsets.only(left: 36),
                    child: Text(
                      'Deseja cancelar este CACL?\n\n⚠️ Esta ação é irreversível e não pode ser desfeita.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Botões alinhados à direita
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(255, 107, 107, 107),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _cancelarDireto(cacl['id'].toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                          shadowColor: Colors.red.withOpacity(0.3),
                        ),
                        child: const Text(
                          'Sim, cancelar CACL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }  
}