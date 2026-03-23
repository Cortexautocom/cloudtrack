import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'certificado_apuracao_entrada.dart';
import 'certificado_apuracao_saida.dart';

class ListarOrdensAnalisesPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const ListarOrdensAnalisesPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<ListarOrdensAnalisesPage> createState() => _ListarOrdensAnalisesPageState();
}

class _ListarOrdensAnalisesPageState extends State<ListarOrdensAnalisesPage> {
  final supabase = Supabase.instance.client;

  bool _carregando = true;
  List<Map<String, dynamic>> _ordens = [];
  List<Map<String, dynamic>> _terminais = [];

  // filtros
  List<String> produtos = [];
  String? produtoSelecionado;
  DateTime? dataFiltro;
  final TextEditingController dataFiltroCtrl = TextEditingController();
  final TextEditingController terminalController = TextEditingController();

  String? _terminalSelecionado;
  String _busca = '';
  int? _nivel;

  // Estado da ordem selecionada para visualização
  bool _mostrandoCertificado = false;
  String? _ordemSelecionadaId;
  String? _ordemTipoOperacao;

  int? _hoverIndex;

  Map<String, dynamic>? _usuarioData;

  @override
  void initState() {
    super.initState();

    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    dataFiltroCtrl.dispose();
    terminalController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _obterDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      return await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial, terminal_id')
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);
    
    try {
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
      
      _nivel = _usuarioData!['nivel'] as int?;
      
      await _carregarProdutos();
      
      final nivel = _usuarioData!['nivel'];
      final terminalId = UsuarioAtual.instance?.terminalId ?? _usuarioData!['terminal_id'];
      
      if (nivel == 3) {
        await _carregarTerminais();
      }
      
      // Fixar data inicial como hoje para o filtro
      dataFiltro = DateTime.now();
      dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());
      
      // Se não for admin, já fixa o terminal do usuário e carrega
      if (nivel != 3) {
        _terminalSelecionado = terminalId;
        await _carregarNomeTerminal(_terminalSelecionado);
        await _carregarOrdens();
      } else {
        await _carregarOrdensNivel3();
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarProdutos() async {
    try {
      final dados = await supabase.from('produtos').select('nome').order('nome');
      setState(() {
        produtos = List<Map<String, dynamic>>.from(dados).map((p) => p['nome'].toString()).toList();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _carregarNomeTerminal(String? terminalId) async {
    if (terminalId == null) {
      terminalController.clear();
      return;
    }
    try {
      final r = await supabase.from('terminais').select('nome').eq('id', terminalId).maybeSingle();
      setState(() {
        terminalController.text = r != null ? (r['nome']?.toString() ?? terminalId) : terminalId;
      });
    } catch (_) {
      setState(() {
        terminalController.text = terminalId;
      });
    }
  }

  Future<void> _carregarTerminais() async {
    final dados = await supabase.from('terminais').select('id, nome').order('nome');
    setState(() {
      _terminais = List<Map<String, dynamic>>.from(dados);
    });
  }

  Future<void> _carregarOrdens() async {
    if (_terminalSelecionado == null) return;

    setState(() => _carregando = true);

    final hoje = DateTime.now();
    final hojeStr =
        '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    // Montar query com filtros
    var query = supabase.from('ordens_analises').select('''
          id,
          numero_controle,
          data_criacao,
          tipo_analise,
          transportadora,
          motorista,
          notas_fiscais,
          placa_cavalo,
          carreta1,
          carreta2,
          produto_nome,
          temperatura_amostra,
          densidade_observada,
          densidade_20c
        ''');

    query = query.eq('terminal_id', _terminalSelecionado!);

    // Aplicar filtro de data (intervalo do dia selecionado)
    if (dataFiltro != null) {
      final dia = dataFiltro!;
      final diaStr = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      final proximo = dia.add(const Duration(days: 1));
      final proximoStr = '${proximo.year}-${proximo.month.toString().padLeft(2, '0')}-${proximo.day.toString().padLeft(2, '0')}';
      query = query.gte('data_criacao', diaStr).lt('data_criacao', proximoStr);
    } else {
      query = query.gte('data_criacao', hojeStr);
    }

    if (produtoSelecionado != null && produtoSelecionado!.isNotEmpty) {
      query = query.eq('produto_nome', produtoSelecionado!);
    }

    final dados = await query.order('data_criacao', ascending: false);

    setState(() {
      _ordens = List<Map<String, dynamic>>.from(dados);
      _carregando = false;
    });
  }

  String _formatarData(String? d) {
    if (d == null) return '-';
    final dt = DateTime.parse(d);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  bool _matchBusca(Map<String, dynamic> o) {
    if (_busca.isEmpty) return true;
    final b = _busca.toLowerCase();
    return o.values
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(b));
  }

  // ===== MÉTODOS PARA NAVEGAÇÃO INLINE =====
  
  void _voltarParaLista() {
    setState(() {
      _mostrandoCertificado = false;
    });
    _refreshData(); // Atualiza a lista ao voltar
  }

  Widget _buildCardFiltros() {
    if (_usuarioData == null) return const SizedBox();
    
    final nivel = _usuarioData!['nivel'];
    final isAdmin = nivel == 3;
    
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
                      ...produtos.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            p,
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
                      _refreshData();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: isAdmin
                      ? DropdownButtonFormField<String>(
                          value: _terminalSelecionado,
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
                            ..._terminais.map((terminal) {
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
                              _terminalSelecionado = value;
                            });
                            
                            if (value == null || value.isEmpty) {
                              _carregarOrdensNivel3();
                            } else {
                              _carregarOrdens();
                            }
                          },
                        )
                      : TextFormField(
                          controller: terminalController,
                          decoration: InputDecoration(
                            labelText: 'Terminal',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.business, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          readOnly: true,
                          enabled: true,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Builder(builder: (context) {
                    final textoData = dataFiltro != null
                        ? '${dataFiltro!.day.toString().padLeft(2, '0')}/${dataFiltro!.month.toString().padLeft(2, '0')}/${dataFiltro!.year}'
                        : 'Data';

                    return InkWell(
                      onTap: () async {
                        final dataSelecionada = await showDatePicker(
                          context: context,
                          initialDate: dataFiltro ?? DateTime.now(),
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          helpText: 'Filtrar por data',
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

                        if (dataSelecionada != null) {
                          setState(() {
                            dataFiltro = DateTime(
                              dataSelecionada.year,
                              dataSelecionada.month,
                              dataSelecionada.day,
                            );
                            dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());
                          });
                          _refreshData();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Color(0xFF0D47A1),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                textoData,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Buscar',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                      hintText: 'Nº controle, placa...',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _busca = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 8),

                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _refreshData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),

                const SizedBox(width: 8),

                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() {
                        produtoSelecionado = null;
                        dataFiltro = null;
                        dataFiltroCtrl.clear();
                        
                        final nivel = _usuarioData?['nivel'];
                        final terminalId = UsuarioAtual.instance?.terminalId ?? _usuarioData?['terminal_id'];
                        
                        if (nivel != 3) {
                          _terminalSelecionado = terminalId;
                          _carregarNomeTerminal(_terminalSelecionado);
                        } else {
                          _terminalSelecionado = null;
                          terminalController.clear();
                        }
                        
                        _busca = '';
                      });
                      await _refreshData();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Limpar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ===== SE ESTÁ MOSTRANDO CERTIFICADO =====
    if (_mostrandoCertificado) {
      // Mostrar a página adequada em modo somente visualização
      if (_ordemTipoOperacao != null && _ordemTipoOperacao == 'entrada') {
        return Scaffold(
          body: EmitirCertificadoEntrada(
            onVoltar: _voltarParaLista,
            terminalId: _terminalSelecionado ?? '',
            idAnaliseExistente: _ordemSelecionadaId,
            modoSomenteVisualizacao: true,
          ),
        );
      } else {
        return Scaffold(
          body: EmitirCertificadoPage(
            onVoltar: _voltarParaLista,
            idCertificado: _ordemSelecionadaId,
            modoSomenteVisualizacao: true,
          ),
        );
      }
    }

    // ===== SE ESTÁ MOSTRANDO A LISTA =====
    final lista = _ordens.where(_matchBusca).toList();

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
                        'Ordens / Análises',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      if (_nivel != null && _nivel! < 3 && _terminalSelecionado != null)
                        FutureBuilder(
                          future: Supabase.instance.client
                              .from('terminais')
                              .select('nome')
                              .eq('id', _terminalSelecionado!)
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final nomeTerminal = snapshot.data!['nome'];
                              return Text(
                                nomeTerminal,
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
                if (!_carregando)
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
                  flex: 1,
                  child: Text('Nº Controle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Produto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Transportadora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Placas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Notas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                ),
                SizedBox(width: 24), // Espaço para o ícone
              ],
            ),
          ),
          
          const Divider(height: 1),

          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Nenhuma ordem encontrada', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: lista.length,
                        itemBuilder: (context, index) {
                          final o = lista[index];
                          final cor = o['tipo_analise'] == 'entrada' 
                              ? const Color(0xFF2E7D32) // Verde para entrada
                              : const Color(0xFF0D47A1); // Azul para saída

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _hoverIndex = index),
                            onExit: (_) => setState(() => _hoverIndex = null),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _ordemSelecionadaId = o['id']?.toString();
                                  _ordemTipoOperacao = o['tipo_analise']?.toString();
                                  _mostrandoCertificado = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                                color: _hoverIndex == index 
                                    ? Colors.grey.shade200 
                                    : (index.isEven ? Colors.white : Colors.grey.shade50),
                                child: Row(
                                  children: [
                                    // Indicador de tipo
                                    Container(
                                      width: 4,
                                      height: 24,
                                      color: cor,
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Nº Controle
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        o['numero_controle'] ?? '-',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Data
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        _formatarData(o['data_criacao']),
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Produto
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        o['produto_nome'] ?? '-',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Transportadora
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        o['transportadora'] ?? '-',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Placas
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${o['placa_cavalo'] ?? ''} ${o['carreta1'] ?? ''} ${o['carreta2'] ?? ''}'.trim(),
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    // Notas Fiscais
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        o['notas_fiscais'] ?? '-',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFF0D47A1)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarOrdensNivel3() async {
    setState(() => _carregando = true);

    final hoje = DateTime.now();
    final hojeStr =
        '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    var query = supabase
        .from('ordens_analises')
        .select('''
          id,
          numero_controle,
          data_criacao,
          tipo_analise,
          transportadora,
          motorista,
          notas_fiscais,
          placa_cavalo,
          carreta1,
          carreta2,
          produto_nome,
          temperatura_amostra,
          densidade_observada,
          densidade_20c,
          terminal_id
        ''');

    // Aplicar filtro de data (intervalo do dia selecionado)
    if (dataFiltro != null) {
      final dia = dataFiltro!;
      final diaStr = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      final proximo = dia.add(const Duration(days: 1));
      final proximoStr = '${proximo.year}-${proximo.month.toString().padLeft(2, '0')}-${proximo.day.toString().padLeft(2, '0')}';
      query = query.gte('data_criacao', diaStr).lt('data_criacao', proximoStr);
    } else {
      query = query.gte('data_criacao', hojeStr);
    }

    if (_terminalSelecionado != null) {
      query = query.eq('terminal_id', _terminalSelecionado!);
    }

    if (produtoSelecionado != null && produtoSelecionado!.isNotEmpty) {
      query = query.eq('produto_nome', produtoSelecionado!);
    }

    final dados = await query.order('data_criacao', ascending: false);

    setState(() {
      _ordens = List<Map<String, dynamic>>.from(dados);
      _carregando = false;
    });
  }

  // ===== MÉTODO PARA ATUALIZAR OS DADOS =====
  Future<void> _refreshData() async {
    if (_nivel == 3) {
      await _carregarOrdensNivel3();
    } else {
      await _carregarOrdens();
    }
  }
}