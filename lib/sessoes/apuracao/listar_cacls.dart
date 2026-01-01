import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl.dart';
import '../../login_page.dart';
import 'emitir_cacl.dart';
import 'editar_cacl.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregarCaclsSimples();
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
    // Recarrega dados sempre que as dependências mudam
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void didUpdateWidget(ListarCaclsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se a filial mudou, recarrega os dados
    if (oldWidget.filialId != widget.filialId) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    await _carregarCaclsSimples();
  }

  Future<void> _carregarCaclsSimples() async {
    // Não recarrega se já estiver carregando
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
            base
          ''')
          .eq('filial_id', widget.filialId)
          .order('created_at', ascending: false);

      final caclsFiltrados = todosCacls.where((cacl) {
        final status = cacl['status']?.toString().toLowerCase() ?? '';
        final data = cacl['data']?.toString() ?? '';

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
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCardColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade50;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade50;
      case 'cancelado':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getBorderColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'emitido':
        return Colors.green.shade300;
      case 'pendente':
      case 'aguardando':
        return Colors.orange.shade300;
      case 'cancelado':
        return Colors.red.shade300;
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
            // Botão de refresh
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
                      // Recarrega os dados ao voltar
                      _refreshData();
                    },
                    filialSelecionadaId: widget.filialId,
                    onFinalizarCACL: () {
                      widget.onFinalizarCACL?.call();
                      // Recarrega os dados após finalizar CACL
                      _refreshData();
                    },
                  ),
                ),
              ).then((_) {
                // Garante recarregamento mesmo se navegar de outras formas
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

        // ===== LISTA DE CACLS (LAYOUT COMPACTO) =====
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
                            'Nenhum CACL encontrado para hoje',
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
                          final statusColor = _getStatusColor(status);
                          final cardColor = _getCardColor(status);
                          final borderColor = _getBorderColor(status);
                          final statusText = _getStatusText(status);
                          final tanqueNome = cacl['tanques']?['referencia']?.toString();
                          final tanque = tanqueNome ?? '-';
                          final produto = cacl['produto'] ?? 'Produto não informado';
                          final data = _formatarData(cacl['data']);
                          final horario = _formatarHorario(
                            cacl['horario_inicial'],
                            cacl['horario_final'],
                          );

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () async {
                                final supabase = Supabase.instance.client;
                                final caclCompleto = await supabase
                                    .from('cacl')
                                    .select('*')
                                    .eq('id', cacl['id'])
                                    .single();

                                final dadosFormularioBruto = _mapearCaclParaFormulario(caclCompleto);
                                final dadosFormulario = Map<String, dynamic>.from(dadosFormularioBruto);

                                if (!context.mounted) return;

                                // Navega e recarrega ao voltar
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CalcPage(
                                      dadosFormulario: dadosFormulario,
                                      modo: CaclModo.visualizacao,
                                    ),
                                  ),
                                );
                                
                                // Recarrega os dados após voltar
                                _refreshData();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
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
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            
                                            // Linha 2: Produto
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.local_gas_station,
                                                  size: 14,
                                                  color: Colors.black54,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    produto,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            
                                            // Linha 3: Data e Horário
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.black54,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  data,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                const Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.black54,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    horario,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black54,
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
                                          
                                          // Botão Editar
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 22,
                                              color: Color(0xFF0D47A1),
                                            ),
                                            onPressed: () {
                                              final status = cacl['status']?.toString().toLowerCase();
                                              
                                              if (status == 'pendente' || status == 'aguardando') {
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
                                                  // Recarrega dados após voltar da edição
                                                  _refreshData();
                                                });
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Este CACL já foi ${status == 'emitido' ? 'emitido' : 'cancelado'}'),
                                                    backgroundColor: status == 'emitido' ? Colors.green : Colors.red,
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
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

  Map<String, dynamic> _mapearCaclParaFormulario(Map<String, dynamic> cacl) {
    String fmt(double? v) {
      if (v == null) return '-';
      final i = v.round().toString();
      if (i.length <= 3) return '$i L';

      final buffer = StringBuffer();
      int c = 0;
      for (int x = i.length - 1; x >= 0; x--) {
        buffer.write(i[x]);
        c++;
        if (c == 3 && x > 0) {
          buffer.write('.');
          c = 0;
        }
      }
      return '${buffer.toString().split('').reversed.join()} L';
    }

    return <String, dynamic>{
      'data': cacl['data']?.toString(),
      'base': cacl['base'],
      'produto': cacl['produto'],
      'tanque': cacl['tanques']?['referencia'] ?? cacl['tanque_id'] ?? '-',
      'filial_id': cacl['filial_id'],
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',

      'medicoes': <String, dynamic>{
        // ===== INICIAL =====
        'horarioInicial': cacl['horario_inicial']?.toString(),
        'cmInicial': cacl['altura_total_cm_inicial']?.toString(),
        'mmInicial': cacl['altura_total_mm_inicial']?.toString(),
        'alturaAguaInicial': cacl['altura_agua_inicial']?.toString(),
        'volumeAguaInicial': cacl['volume_agua_inicial'] != null
            ? fmt(cacl['volume_agua_inicial'])
            : '-',
        'alturaProdutoInicial': cacl['altura_produto_inicial']?.toString(),
        'tempTanqueInicial': cacl['temperatura_tanque_inicial']?.toString(),
        'densidadeInicial': cacl['densidade_observada_inicial']?.toString(),
        'tempAmostraInicial': cacl['temperatura_amostra_inicial']?.toString(),
        'densidade20Inicial': cacl['densidade_20_inicial']?.toString(),
        'fatorCorrecaoInicial': cacl['fator_correcao_inicial']?.toString(),
        'volume20Inicial': cacl['volume_20_inicial'] != null
            ? fmt(cacl['volume_20_inicial'])
            : '-',
        'massaInicial': cacl['massa_inicial']?.toString(),

        // 🔴 CORREÇÃO PRINCIPAL
        'volumeProdutoInicial': cacl['volume_produto_inicial'] != null
            ? fmt(cacl['volume_produto_inicial'])
            : '-',
        'volumeTotalLiquidoInicial':
            cacl['volume_total_liquido_inicial'] != null
                ? fmt(cacl['volume_total_liquido_inicial'])
                : '-',

        // ===== FINAL =====
        'horarioFinal': cacl['horario_final']?.toString(),
        'cmFinal': cacl['altura_total_cm_final']?.toString(),
        'mmFinal': cacl['altura_total_mm_final']?.toString(),
        'alturaAguaFinal': cacl['altura_agua_final']?.toString(),
        'volumeAguaFinal': cacl['volume_agua_final'] != null
            ? fmt(cacl['volume_agua_final'])
            : '-',
        'alturaProdutoFinal': cacl['altura_produto_final']?.toString(),
        'tempTanqueFinal': cacl['temperatura_tanque_final']?.toString(),
        'densidadeFinal': cacl['densidade_observada_final']?.toString(),
        'tempAmostraFinal': cacl['temperatura_amostra_final']?.toString(),
        'densidade20Final': cacl['densidade_20_final']?.toString(),
        'fatorCorrecaoFinal': cacl['fator_correcao_final']?.toString(),
        'volume20Final': cacl['volume_20_final'] != null
            ? fmt(cacl['volume_20_final'])
            : '-',
        'massaFinal': cacl['massa_final']?.toString(),

        // 🔴 CORREÇÃO PRINCIPAL
        'volumeProdutoFinal': cacl['volume_produto_final'] != null
            ? fmt(cacl['volume_produto_final'])
            : '-',
        'volumeTotalLiquidoFinal':
            cacl['volume_total_liquido_final'] != null
                ? fmt(cacl['volume_total_liquido_final'])
                : '-',

        // FATURAMENTO
        'faturadoFinal': cacl['faturado_final']?.toString(),
      }
    };
  }
}