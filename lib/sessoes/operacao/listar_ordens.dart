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
  List<Map<String, dynamic>> _filiais = [];

  // filtros
  List<String> produtos = [];
  String? produtoSelecionado;
  DateTime? dataFiltro;
  final TextEditingController dataFiltroCtrl = TextEditingController();
  final TextEditingController filialController = TextEditingController();

  String? _filialSelecionada;
  String _busca = '';
  int? _nivel;

  // Estado da ordem selecionada para visualização
  bool _mostrandoCertificado = false;
  String? _ordemSelecionadaId;
  String? _ordemTipoOperacao;

  int? _hoverIndex;

  @override
  void initState() {
    super.initState();

    final usuario = UsuarioAtual.instance;
    _nivel = usuario?.nivel;

    // Fixar data inicial como hoje para o filtro
    dataFiltro = DateTime.now();
    dataFiltroCtrl.text = _formatarData(dataFiltro!.toIso8601String());

    // Se não for admin, já fixa a filial do usuário e carrega
    if (_nivel != 3) {
      _filialSelecionada = usuario?.filialId;
      _carregarNomeFilial(_filialSelecionada);
      _carregarOrdens();
    } else {
      // Admin: carrega filiais e também carrega ordens de TODAS
      _carregarFiliais();
      _carregarOrdensNivel3();
    }
    _carregarProdutos();
  }

  @override
  void dispose() {
    dataFiltroCtrl.dispose();
    filialController.dispose();
    super.dispose();
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

  Future<void> _carregarNomeFilial(String? filialId) async {
    if (filialId == null) {
      filialController.clear();
      return;
    }
    try {
      final r = await supabase.from('filiais').select('nome').eq('id', filialId).maybeSingle();
      setState(() {
        filialController.text = r != null ? (r['nome']?.toString() ?? filialId) : filialId;
      });
    } catch (_) {
      setState(() {
        filialController.text = filialId;
      });
    }
  }

  Future<void> _carregarFiliais() async {
    final dados = await supabase.from('filiais').select('id, nome').order('nome');
    setState(() {
      _filiais = List<Map<String, dynamic>>.from(dados);
    });
  }

  Future<void> _carregarOrdens() async {
    if (_filialSelecionada == null) return;

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
          placa_cavalo,
          carreta1,
          carreta2,
          produto_nome
        ''');

    query = query.eq('filial_id', _filialSelecionada!);

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

  @override
  Widget build(BuildContext context) {
    // ===== SE ESTÁ MOSTRANDO CERTIFICADO =====
    if (_mostrandoCertificado) {
      // Mostrar a página adequada em modo somente visualização
      if (_ordemTipoOperacao != null && _ordemTipoOperacao == 'entrada') {
        return Scaffold(
          body: EmitirCertificadoEntrada(
            onVoltar: _voltarParaLista,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CABEÇALHO
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            const Text(
              'Ordens / Análises',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),

            // (Emitir Ordem removed — criação de ordens não disponível aqui)

            if (_nivel == 3)
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  hint: const Text('Selecione a filial'),
                  items: _filiais
                      .map<DropdownMenuItem<String>>(
                        (f) => DropdownMenuItem<String>(
                          value: f['id'] as String,
                          child: Text(f['nome'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _filialSelecionada = v);

                    if (v == null || v.isEmpty) {
                      _carregarOrdensNivel3(); // Todas
                    } else {
                      _carregarOrdens(); // Apenas uma filial
                    }
                  },
                ),
              ),
            const SizedBox(width: 10),
            
            // ===== BOTÃO DE ATUALIZAR =====
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
              onPressed: _refreshData,
              tooltip: 'Atualizar lista',
            ),
          ],
        ),

            const SizedBox(height: 10),

            // filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: const Color(0xFFFAFAFA),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Produto
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: produtoSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Produto',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todos os produtos')),
                            ...produtos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          ],
                          onChanged: (v) => setState(() => produtoSelecionado = v),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão de data idêntico ao de ProgramacaoPage
                      SizedBox(
                        width: 180,
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

                      // Filial (admin editable)
                      SizedBox(
                        width: 240,
                        child: _nivel == 3
                            ? DropdownButtonFormField<String>(
                                value: _filialSelecionada,
                                decoration: const InputDecoration(
                                  labelText: 'Filial',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _filiais.map<DropdownMenuItem<String>>((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['nome'].toString()))).toList(),
                                onChanged: (v) {
                                  setState(() => _filialSelecionada = v);
                                },
                              )
                            : TextFormField(
                                controller: filialController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Filial',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                      ),

                      const SizedBox(width: 8),

                      // Campo de busca inline
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar em qualquer campo...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _busca = v),
                        ),
                      ),

                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _refreshData();
                        },
                        child: const Text('Aplicar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            produtoSelecionado = null;
                            dataFiltro = null;
                            dataFiltroCtrl.clear();
                            if (_nivel != 3) {
                              // recarregar nome da filial do usuário
                              final usuario = UsuarioAtual.instance;
                              _filialSelecionada = usuario?.filialId;
                              _carregarNomeFilial(_filialSelecionada);
                            } else {
                              _filialSelecionada = null;
                              filialController.clear();
                            }
                            _busca = '';
                          });
                          _refreshData();
                        },
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Divider(),

            

        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : lista.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nenhuma ordem encontrada',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Use os filtros ou busque por uma ordem',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final o = lista[index];
                        final cor = const Color(0xFF0D47A1);

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
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: cor.withOpacity(0.5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                        _hoverIndex == index ? 0.15 : 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 60,
                                    color: cor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ordem ${o['numero_controle']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(o['produto_nome'] ?? '-'),
                                        Text(
                                            'Placa: ${o['placa_cavalo'] ?? '-'}  ${o['carreta1'] ?? ''}'),
                                        Text(
                                            'Data: ${_formatarData(o['data_criacao'])}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _carregarOrdensNivel3() async {
    setState(() => _carregando = true);

    final hoje = DateTime.now();
    final hojeStr =
        '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    final dados = await supabase
        .from('ordens_analises')
        .select('''
          id,
          numero_controle,
          data_criacao,
          tipo_analise,
          transportadora,
          motorista,
          placa_cavalo,
          carreta1,
          carreta2,
          produto_nome,
          filial_id
        ''')
        .gte('data_criacao', hojeStr)
        .order('data_criacao', ascending: false);

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