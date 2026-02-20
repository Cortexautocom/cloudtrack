import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'cacl_historico.dart';

class HistoricoCaclPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const HistoricoCaclPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<HistoricoCaclPage> createState() => _HistoricoCaclPageState();
}

class _HistoricoCaclPageState extends State<HistoricoCaclPage> with WidgetsBindingObserver {
  bool carregando = true;
  bool buscando = false;
  List<Map<String, dynamic>> cacles = [];
  List<Map<String, dynamic>> filiais = [];
  List<Map<String, dynamic>> tanquesDisponiveis = [];
  List<Map<String, dynamic>> produtosDisponiveis = [];
  
  int paginaAtual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  final int limitePorPagina = 10;
  
  DateTime? dataEmissao;
  String? filialSelecionadaId;
  String? tanqueSelecionadoId;
  String? produtoSelecionado;
  
  int? _nivelUsuario;
  int? _hoverIndex;
  
  final TextEditingController dataEmissaoController = TextEditingController();

  Map<String, dynamic>? _usuarioData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dataEmissao = DateTime.now();
    dataEmissaoController.text = _formatarData(dataEmissao!);
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dataEmissaoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<Map<String, dynamic>?> _obterDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      return await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial, senha_temporaria, Nome_apelido')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
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
      setState(() {
        _nivelUsuario = 0;
      });
    }
  }

  Future<void> _refreshData() async {
    await _aplicarFiltros(resetarPagina: true);
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => carregando = true);
    
    try {
      final supabase = Supabase.instance.client;
      _usuarioData = await _obterDadosUsuario();
      await _carregarNivelUsuario();
      
      if (_usuarioData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final nivel = _usuarioData!['nivel'];
      final filialId = _usuarioData!['id_filial']?.toString();
      
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');
      setState(() {
        produtosDisponiveis = List<Map<String, dynamic>>.from(produtosResponse);
      });
      
      if (nivel == 3) {
        final filiaisResponse = await supabase
            .from('filiais')
            .select('id, nome')
            .order('nome');
        setState(() {
          filiais = List<Map<String, dynamic>>.from(filiaisResponse);
        });
      }
      
      if (nivel == 3) {
        final tanquesResponse = await supabase
            .from('tanques')
            .select('id, referencia, id_filial')
            .order('referencia');
        tanquesDisponiveis = List<Map<String, dynamic>>.from(tanquesResponse);
      } else if (filialId != null) {
        final tanquesResponse = await supabase
            .from('tanques')
            .select('id, referencia')
            .eq('id_filial', filialId)
            .order('referencia');
        tanquesDisponiveis = List<Map<String, dynamic>>.from(tanquesResponse);
      }
      
      await _aplicarFiltros();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _aplicarFiltros({bool resetarPagina = true}) async {
    if (resetarPagina) {
      paginaAtual = 1;
    }

    setState(() => buscando = true);

    try {
      final supabase = Supabase.instance.client;

      _usuarioData ??= await _obterDadosUsuario();

      if (_usuarioData == null) {
        return;
      }

      final nivel = _usuarioData!['nivel'];
      final filialId = _usuarioData!['id_filial']?.toString();

      var query = supabase.from('cacl').select('''
        id,
        data,
        base,
        produto,
        tanque_id,
        filial_id,
        created_at,
        status,
        solicita_canc,
        horario_inicial,
        horario_final,
        volume_produto_inicial,
        volume_produto_final,
        volume_total_liquido_inicial,
        volume_total_liquido_final,
        tanques:tanque_id (referencia),
        entrada_saida_20,
        faturado_final,
        diferenca_faturado,
        porcentagem_diferenca
      ''');

      if (nivel < 3 && filialId != null) {
        query = query.eq('filial_id', filialId);
      }

      if (dataEmissao != null) {
        query = query.eq(
          'data',
          dataEmissao!.toIso8601String().split('T')[0],
        );
      }

      if (filialSelecionadaId != null && nivel == 3) {
        query = query.eq('filial_id', filialSelecionadaId!);
      }

      if (tanqueSelecionadoId != null && tanqueSelecionadoId!.isNotEmpty) {
        query = query.eq('tanque_id', tanqueSelecionadoId!);
      }

      if (produtoSelecionado != null && produtoSelecionado!.isNotEmpty) {
        query = query.eq('produto', produtoSelecionado!);
      }

      final countResponse = await query;

      final response = await query
          .order('data', ascending: false)
          .order('created_at', ascending: false)
          .range(
            (paginaAtual - 1) * limitePorPagina,
            (paginaAtual * limitePorPagina) - 1,
          );

      setState(() {
        cacles = List<Map<String, dynamic>>.from(response);
        totalRegistros = countResponse.length;
        totalPaginas = (totalRegistros / limitePorPagina).ceil();
        if (totalPaginas == 0) totalPaginas = 1;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na busca: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => buscando = false);
    }
  }

  void _limparFiltros() {
    setState(() {
      dataEmissao = null;
      filialSelecionadaId = null;
      tanqueSelecionadoId = null;
      produtoSelecionado = null;
      dataEmissaoController.clear();
    });
    _aplicarFiltros();
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

  Widget _buildCardFiltros() {
    if (_usuarioData == null) return const SizedBox();
    
    final nivel = _usuarioData!['nivel'];
    final isAdmin = nivel == 3;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de Busca',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: produtoSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Produto',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_gas_station, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os produtos', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...produtosDisponiveis.map((produto) {
                        return DropdownMenuItem(
                          value: produto['nome']?.toString(),
                          child: Text(
                            produto['nome']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        produtoSelecionado = value;
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: tanqueSelecionadoId,
                    decoration: InputDecoration(
                      labelText: 'Tanque',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.storage, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os tanques', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...tanquesDisponiveis.map((tanque) {
                        return DropdownMenuItem(
                          value: tanque['id']?.toString(),
                          child: Text(
                            tanque['referencia']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        tanqueSelecionadoId = value;
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                if (isAdmin) Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: filialSelecionadaId,
                    decoration: InputDecoration(
                      labelText: 'Filial',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.business, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas as filiais', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...filiais.map((filial) {
                        return DropdownMenuItem(
                          value: filial['id']?.toString(),
                          child: Text(
                            filial['nome']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        filialSelecionadaId = value;
                      });
                    },
                  ),
                ),
                
                if (isAdmin) const SizedBox(width: 8),
                
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: dataEmissaoController,
                    decoration: InputDecoration(
                      labelText: 'Data de emissão',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() {
                            dataEmissao = null;
                            dataEmissaoController.clear();
                          });
                        },
                      ),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      
                      if (data != null) {
                        setState(() {
                          dataEmissao = data;
                          dataEmissaoController.text = _formatarData(data);
                        });
                      }
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                SizedBox(
                  width: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _limparFiltros,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFF0D47A1)),
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text(
                            'Limpar',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _aplicarFiltros(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 40),
                          ),
                          child: buscando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Filtrar',
                                  style: TextStyle(fontSize: 13),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            /*
            if (isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: filialSelecionadaId,
                      decoration: InputDecoration(
                        labelText: 'Filial',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.business, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas as filiais', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                        ),
                        ...filiais.map((filial) {
                          return DropdownMenuItem(
                            value: filial['id']?.toString(),
                            child: Text(
                              filial['nome']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          filialSelecionadaId = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],*/
          ],
        ),
      ),
    );
  }

  Widget _buildPaginacao() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              onPressed: paginaAtual > 1
                  ? () {
                      setState(() => paginaAtual--);
                      _aplicarFiltros(resetarPagina: false);
                    }
                  : null,
              color: paginaAtual > 1 ? const Color(0xFF0D47A1) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              'Página $paginaAtual de $totalPaginas',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(width: 12),
            Text(
              '($totalRegistros registros)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: paginaAtual < totalPaginas
                  ? () {
                      setState(() => paginaAtual++);
                      _aplicarFiltros(resetarPagina: false);
                    }
                  : null,
              color: paginaAtual < totalPaginas ? const Color(0xFF0D47A1) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarioData == null && !carregando) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Usuário não autenticado'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }
    
    final nivel = _usuarioData?['nivel'];
    final filialId = _usuarioData?['id_filial']?.toString();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Histórico de CACLs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      if (nivel != null && nivel < 3 && filialId != null)
                        FutureBuilder(
                          future: Supabase.instance.client
                              .from('filiais')
                              .select('nome')
                              .eq('id', filialId)
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final nomeFilial = snapshot.data!['nome'];
                              return Text(
                                nomeFilial,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                    ],
                  ),
                ),
                if (!carregando)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                    onPressed: _refreshData,
                  ),
              ],
            ),
          ),

          _buildCardFiltros(),

          Expanded(
            child: carregando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0D47A1),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: cacles.isEmpty
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
                                      'Ajuste os filtros para encontrar CACLs',
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
                                  itemCount: cacles.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6), // ↓ cards mais próximos
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4, // ↓ reduz espaçamento vertical geral
                                  ),
                                  itemBuilder: (context, index) {
                                    final cacl = cacles[index];
                                    final status = cacl['status']?.toString();
                                    final solicitaCanc = cacl['solicita_canc'] as bool?;
                                    final isCancelado =
                                        status?.toLowerCase() == 'cancelado';
                                    final statusColor = _getStatusColor(status);
                                    final cardColor =
                                        _getCardColor(status, solicitaCanc);
                                    final borderColor =
                                        _getBorderColor(status, solicitaCanc);
                                    final statusText = _getStatusText(status);
                                    final tanqueRef =
                                        cacl['tanques']?['referencia']?.toString() ?? '-';
                                    final produto =
                                        cacl['produto'] ?? 'Produto não informado';
                                    final data = _formatarData(cacl['data']);
                                    final horario = _formatarHorario(
                                      cacl['horario_inicial'],
                                      cacl['horario_final'],
                                    );

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4, // ↓ reduz apenas a distância vertical entre cards
                                      ),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: SizedBox(
                                          width: 1400, // ← largura máxima dos cards no histórico
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            onEnter: (_) {
                                              setState(() => _hoverIndex = index);
                                            },
                                            onExit: (_) {
                                              setState(() => _hoverIndex = null);
                                            },
                                            child: GestureDetector(
                                              onTap: () async {
                                                final caclId = cacl['id'].toString();

                                                final nivelUsuario = _nivelUsuario ?? 0;

                                                if (nivelUsuario == 2 && isCancelado) {
                                                  return;
                                                }

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
                                                opacity: isCancelado ? 0.85 : 1.0,
                                                child: AnimatedContainer(
                                                  duration:
                                                      const Duration(milliseconds: 180),
                                                  curve: Curves.easeOut,
                                                  alignment: Alignment.center,
                                                  transformAlignment: Alignment.center,
                                                  transform: _hoverIndex == index
                                                      ? (Matrix4.identity()
                                                        ..scale(1.01, 1.01))
                                                      : Matrix4.identity(),
                                                  decoration: BoxDecoration(
                                                    color: _hoverIndex == index
                                                        ? cardColor.withOpacity(0.85)
                                                        : cardColor,
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: borderColor,
                                                      width: 1.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(
                                                          _hoverIndex == index
                                                              ? 0.15
                                                              : 0.05,
                                                        ),
                                                        blurRadius:
                                                            _hoverIndex == index ? 12 : 4,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      Padding(
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
                                                                      const Icon(
                                                                        Icons.storage,
                                                                        size: 16,
                                                                        color:
                                                                            Colors.black54,
                                                                      ),
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
                                                                        Icons
                                                                            .local_gas_station,
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
                                                                              TextOverflow
                                                                                  .ellipsis,
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
                                                                          overflow:
                                                                              TextOverflow
                                                                                  .ellipsis,
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
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                    horizontal: 8,
                                                                    vertical: 4,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: statusColor
                                                                        .withOpacity(0.15),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            6),
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
                                                                const SizedBox(height: 8),
                                                                if (!isCancelado &&
                                                                    (_nivelUsuario == 1 ||
                                                                        _nivelUsuario == 2))
                                                                  ElevatedButton(
                                                                    onPressed: () {
                                                                      if (solicitaCanc ==
                                                                          true) {
                                                                        ScaffoldMessenger.of(
                                                                                context)
                                                                            .showSnackBar(
                                                                          const SnackBar(
                                                                            content: Text(
                                                                                'Cancelamento já solicitado. Aguarde a análise do supervisor.'),
                                                                            backgroundColor:
                                                                                Colors.orange,
                                                                            duration: Duration(
                                                                                seconds: 3),
                                                                          ),
                                                                        );
                                                                      } else {
                                                                        _showDialogSolicitarCancelamento(
                                                                            cacl);
                                                                      }
                                                                    },
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          solicitaCanc == true
                                                                              ? Colors.red
                                                                                  .shade50
                                                                              : Colors.orange
                                                                                  .shade50,
                                                                      foregroundColor:
                                                                          solicitaCanc == true
                                                                              ? Colors.red
                                                                                  .shade800
                                                                              : Colors.orange
                                                                                  .shade800,
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        horizontal: 8,
                                                                        vertical: 4,
                                                                      ),
                                                                      minimumSize:
                                                                          const Size(0, 0),
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius
                                                                                .circular(6),
                                                                        side: BorderSide(
                                                                          color: solicitaCanc ==
                                                                                  true
                                                                              ? Colors.red
                                                                                  .shade300
                                                                              : Colors.orange
                                                                                  .shade300,
                                                                        ),
                                                                      ),
                                                                      elevation: 0,
                                                                    ),
                                                                    child: Text(
                                                                      solicitaCanc == true
                                                                          ? 'Cancelamento\nsolicitado'
                                                                          : 'Solicitar\ncancelamento',
                                                                      textAlign:
                                                                          TextAlign.center,
                                                                      style: const TextStyle(
                                                                        fontSize: 10,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                        if (_nivelUsuario == 3 &&
                                                          (status?.toLowerCase() == 'emitido' ||
                                                            status?.toLowerCase() == 'pendente'))
                                                        Positioned(
                                                          right: 4,
                                                          bottom: 2,
                                                          child: PopupMenuButton<String>(
                                                            padding: EdgeInsets.zero,
                                                            iconSize: 14,
                                                            tooltip: 'Ações do CACL',
                                                            icon: Icon(
                                                              Icons.settings,
                                                              size: 14,
                                                              color: Colors.grey.shade700,
                                                            ),
                                                            onSelected: (value) async {
                                                              if (value == 'cancelar') {
                                                                await _cancelarCaclNivel3(
                                                                  cacl['id'].toString(),
                                                                );
                                                              }
                                                            },
                                                            itemBuilder: (context) => const [
                                                              PopupMenuItem<String>(
                                                                value: 'cancelar',
                                                                child: Text('Cancelar CACL'),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
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
                              ),
                      ),
                      _buildPaginacao(),
                    ],
                  ),
          ),

        ],
      ),
    );
  }

  Future<void> _solicitarCancelamento(String caclId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('cacl')
          .update({'solicita_canc': true})
          .eq('id', caclId);
      
      if (mounted) {
        setState(() {
          final index = cacles.indexWhere((c) => c['id'] == caclId);
          if (index != -1) {
            cacles[index]['solicita_canc'] = true;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancelamento solicitado ao supervisor. Aguarde.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        await _refreshData();
      }
    } catch (e) {
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

  Future<void> _cancelarCaclNivel3(String caclId) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('cacl').delete().eq('id', caclId);

      if (!mounted) return;

      setState(() {
        cacles.removeWhere((c) => c['id']?.toString() == caclId);
        totalRegistros = totalRegistros > 0 ? totalRegistros - 1 : 0;
        totalPaginas = (totalRegistros / limitePorPagina).ceil();
        if (totalPaginas == 0) totalPaginas = 1;
        if (paginaAtual > totalPaginas) paginaAtual = totalPaginas;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CACL cancelado e removido com sucesso.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await _aplicarFiltros(resetarPagina: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cancelar CACL: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
}