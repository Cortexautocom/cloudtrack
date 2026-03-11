import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl_historico.dart';
import 'cacl.dart';

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
  List<Map<String, dynamic>> terminais = [];
  List<Map<String, dynamic>> tanquesDisponiveis = [];
  List<Map<String, dynamic>> produtosDisponiveis = [];
  
  int paginaAtual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  final int limitePorPagina = 10;
  
  DateTime? dataInicial;
  DateTime? dataFinal;
  String? terminalSelecionadoId;
  String? tanqueSelecionadoId;
  String? produtoSelecionado;
  int? _hoverIndex;
  
  final TextEditingController dataInicialController = TextEditingController();
  final TextEditingController dataFinalController = TextEditingController();

  Map<String, dynamic>? _usuarioData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Definir datas iniciais como hoje
    dataInicial = DateTime.now();
    dataFinal = DateTime.now();
    dataInicialController.text = _formatarData(dataInicial);
    dataFinalController.text = _formatarData(dataFinal);
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dataInicialController.dispose();
    dataFinalController.dispose();
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

  Future<void> _refreshData() async {
    await _aplicarFiltros(resetarPagina: true);
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => carregando = true);
    
    try {
      final supabase = Supabase.instance.client;
      _usuarioData = await _obterDadosUsuario();
      
      if (_usuarioData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Carregar todos os produtos
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');
      setState(() {
        produtosDisponiveis = List<Map<String, dynamic>>.from(produtosResponse);
      });

      // Carregar todos os terminais
      final terminaisResponse = await supabase
          .from('terminais')
          .select('id, nome')
          .order('nome');
      setState(() {
        terminais = List<Map<String, dynamic>>.from(terminaisResponse);
      });

      // Carregar todos os tanques
      final tanquesResponse = await supabase
          .from('tanques')
          .select('id, referencia, terminal_id')
          .order('referencia');
      tanquesDisponiveis = List<Map<String, dynamic>>.from(tanquesResponse);

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

      var query = supabase.from('cacl').select('''
        id,
        tipo,
        data,
        base,
        produto,
        tanque_id,
        terminal_id,
        created_at,
        status,
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

      if (dataInicial == null && dataFinal == null) {
        // Nenhuma data selecionada pelo usuário — mostrar apenas CACLs da data atual
        final hoje = DateTime.now().toIso8601String().split('T')[0];
        query = query.eq('data', hoje);
      } else if (dataInicial != null && dataFinal != null) {
        final inicio = dataInicial!.toIso8601String().split('T')[0];
        final fim = dataFinal!.toIso8601String().split('T')[0];
        query = query.gte('data', inicio).lte('data', fim);
      } else if (dataInicial != null) {
        query = query.eq('data', dataInicial!.toIso8601String().split('T')[0]);
      } else if (dataFinal != null) {
        query = query.eq('data', dataFinal!.toIso8601String().split('T')[0]);
      }

      if (terminalSelecionadoId != null) {
        query = query.eq('terminal_id', terminalSelecionadoId!);
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

  String _formatarHora(dynamic horario) {
    if (horario == null) return '-';
    try {
      final h = horario.toString();
      if (h.contains('T')) {
        final dh = DateTime.parse(h);
        return '${dh.hour.toString().padLeft(2, '0')}:${dh.minute.toString().padLeft(2, '0')}';
      } else {
        return h.length >= 5 ? h.substring(0, 5) : h;
      }
    } catch (_) {
      return '-';
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
    
    return Card(
      color: const Color(0xFFFAFAFA),
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
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
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
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: terminalSelecionadoId,
                    decoration: InputDecoration(
                      labelText: 'Terminal',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.business, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os terminais', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13)),
                      ),
                      ...terminais.map((terminal) {
                        return DropdownMenuItem(
                          value: terminal['id']?.toString(),
                          child: Text(
                            terminal['nome']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        terminalSelecionadoId = value;
                      });
                      _aplicarFiltros();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Builder(builder: (context) {
                    final textoInicial = dataInicial != null
                        ? '${dataInicial!.day.toString().padLeft(2, '0')}/${dataInicial!.month.toString().padLeft(2, '0')}/${dataInicial!.year}'
                        : 'Data inicial';

                    return InkWell(
                      onTap: () async {
                        final data = await showDatePicker(
                          context: context,
                          initialDate: dataInicial ?? DateTime.now(),
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          helpText: 'Data inicial',
                          cancelText: 'Cancelar',
                          confirmText: 'Confirmar',
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

                        if (data != null) {
                          setState(() {
                            dataInicial = data;
                            dataInicialController.text = _formatarData(data);
                          });
                          _aplicarFiltros();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -27,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  'Data inicial',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Text(
                                    textoInicial,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Builder(builder: (context) {
                    final textoFinal = dataFinal != null
                        ? '${dataFinal!.day.toString().padLeft(2, '0')}/${dataFinal!.month.toString().padLeft(2, '0')}/${dataFinal!.year}'
                        : 'Data final';

                    return InkWell(
                      onTap: () async {
                        final data = await showDatePicker(
                          context: context,
                          initialDate: dataFinal ?? DateTime.now(),
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          helpText: 'Data final',
                          cancelText: 'Cancelar',
                          confirmText: 'Confirmar',
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

                        if (data != null) {
                          setState(() {
                            dataFinal = data;
                            dataFinalController.text = _formatarData(data);
                          });
                          _aplicarFiltros();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -27,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  'Data final',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Text(
                                    textoFinal,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(width: 8),

                const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginacao() {
    return Card(
      color: const Color(0xFFFAFAFA),
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

          // Cabeçalho da lista
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Container(width: 4), // Espaço para a barra colorida
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text('Tanque', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Produto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('H.Inicial', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('H.Final', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                SizedBox(width: 24), // Espaço para o ícone
              ],
            ),
          ),
          
          const Divider(height: 1),

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
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Nenhum CACL encontrado',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _refreshData,
                                color: const Color(0xFF0D47A1),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: cacles.length,
                                  itemBuilder: (context, index) {
                                    final cacl = cacles[index];
                                    final status = cacl['status']?.toString();
                                    final isCancelado = status?.toLowerCase() == 'cancelado';
                                    final statusColor = _getStatusColor(status);
                                    final statusText = _getStatusText(status);
                                    final tanqueRef = cacl['tanques']?['referencia']?.toString() ?? '-';
                                    final produto = cacl['produto'] ?? '-';
                                    final data = _formatarData(cacl['data']);
                                    final horarioInicial = _formatarHora(cacl['horario_inicial']);
                                    final horarioFinal = _formatarHora(cacl['horario_final']);

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      onEnter: (_) => setState(() => _hoverIndex = index),
                                      onExit: (_) => setState(() => _hoverIndex = null),
                                      child: GestureDetector(
                                        onTap: () async {
                                          final caclId = cacl['id'].toString();

                                          if (!context.mounted) return;

                                          String? tipo = cacl['tipo']?.toString();
                                          if (tipo == null) {
                                            try {
                                              final resp = await Supabase.instance.client
                                                  .from('cacl')
                                                  .select('tipo')
                                                  .eq('id', caclId)
                                                  .maybeSingle();
                                              tipo = resp?['tipo']?.toString();
                                            } catch (_) {
                                              tipo = null;
                                            }
                                          }

                                          if (tipo == 'verificacao') {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) {
                                                  final Map<String, dynamic> payload = <String, dynamic>{};
                                                  payload['origem_estoque_tanque'] = true;
                                                  return CalcPage(
                                                    dadosFormulario: payload,
                                                    modo: CaclModo.visualizacao,
                                                    caclId: caclId,
                                                    onVoltar: () {
                                                      Navigator.pop(context);
                                                    },
                                                  );
                                                },
                                              ),
                                            );
                                          } else {
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
                                          }

                                          _refreshData();
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                          color: _hoverIndex == index 
                                              ? Colors.grey.shade200 
                                              : (index.isEven ? Colors.white : Colors.grey.shade50),
                                          child: Row(
                                            children: [
                                              // Indicador de status
                                              Container(
                                                width: 4,
                                                height: 24,
                                                color: statusColor,
                                              ),
                                              const SizedBox(width: 12),
                                              
                                              // Tanque
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  tanqueRef,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              
                                              // Produto
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  produto,
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              
                                              // Data
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  data,
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              
                                              // Hora Inicial
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  horarioInicial,
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              
                                              // Hora Final
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  horarioFinal,
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              
                                              // Status
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        statusText,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: statusColor,
                                                        ),
                                                      ),
                                                    ),

                                                  ],
                                                ),
                                              ),
                                              
                                              // Botão de ação (Cancelamento)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 28),
                                                child: (!isCancelado && (status?.toLowerCase() == 'emitido' || status?.toLowerCase() == 'pendente'))
                                                    ? IconButton(
                                                        icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                                        onPressed: () => _showDialogConfirmarCancelamento(cacl),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        tooltip: 'Cancelar CACL',
                                                      )
                                                    : const SizedBox(width: 16, height: 16),
                                              ),
                                            ],
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

  Future<void> _cancelarCacl(String caclId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase
          .from('cacl')
          .update({'status': 'cancelado'})
          .eq('id', caclId);
      
      if (mounted) {
        _showDialogSucessoCancelamento();
        await _refreshData();
      }
    } catch (e) {
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

  void _showDialogSucessoCancelamento() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'CACL cancelado com sucesso.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('OK'),
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
            side: const BorderSide(color: Color(0xFF0D47A1), width: 1),
          ),
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
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
                  
                  const Text(
                    'Tem certeza que quer cancelar o CACL já emitido?',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.4,
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
                          await _cancelarCacl(cacl['id'].toString());
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
                        ),
                        child: const Text(
                          'Sim, cancelar.',
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