import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'movimentacoes.dart';

class FiltroMovimentacoesPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const FiltroMovimentacoesPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<FiltroMovimentacoesPage> createState() => _FiltroMovimentacoesPageState();
}

class _FiltroMovimentacoesPageState extends State<FiltroMovimentacoesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final usuario = UsuarioAtual.instance!;

  // ===== FILTROS =====
  String? _filialSelecionada;
  String? _produtoSelecionado = 'todos';
  String _tipoMov = 'todos';
  String _tipoOp = 'todos';

  // Datas
  final TextEditingController _dataInicioController = TextEditingController();
  final TextEditingController _dataFimController = TextEditingController();

  String _modoRelatorio = 'sintetico';

  // ===== LISTAS =====
  List<Map<String, dynamic>> _filiais = [];
  List<Map<String, dynamic>> _produtos = [];

  bool _carregando = true;

  @override
  void initState() {
    super.initState();

    // Inicializar datas padrão com a data atual em ambos os campos
    final now = DateTime.now();
    final hojeFormatado = _formatarData(now);
    _dataInicioController.text = hojeFormatado;
    _dataFimController.text = hojeFormatado;

    _init();
  }

  @override
  void dispose() {
    _dataInicioController.dispose();
    _dataFimController.dispose();
    super.dispose();
  }

  // ===================== UTIL =====================

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
  }

  void _aplicarMascaraData(
      TextEditingController controller, String valorAntigo, String valorNovo) {
    if (valorNovo.length < valorAntigo.length) return;

    final digitos = valorNovo.replaceAll(RegExp(r'[^0-9]'), '');
    final digitosLimitados = digitos.length > 8 ? digitos.substring(0, 8) : digitos;

    String resultado = '';
    for (int i = 0; i < digitosLimitados.length; i++) {
      if (i == 2 || i == 4) resultado += '/';
      resultado += digitosLimitados[i];
    }

    controller.text = resultado;
    controller.selection =
        TextSelection.collapsed(offset: resultado.length);
  }

  Future<void> _init() async {
    await Future.wait([
      _carregarFiliais(),
      _carregarProdutos(),
    ]);

    if (usuario.nivel < 3) {
      _filialSelecionada = usuario.filialId;
    } else {
      _filialSelecionada = 'todas';
    }

    setState(() => _carregando = false);
  }

  // ===================== DADOS =====================

  Future<void> _carregarFiliais() async {
    if (usuario.empresaId == null) return;

    final dados = await _supabase
        .from('filiais')
        .select('id, nome_dois, nome')
        .eq('empresa_id', usuario.empresaId!)
        .order('nome_dois');

    final lista = List<Map<String, dynamic>>.from(dados);

    if (usuario.nivel == 3) {
      _filiais = [
        {'id': 'todas', 'nome_dois': 'Todas', 'nome': 'Todas'},
        ...lista,
      ];
    } else {
      _filiais = lista;
    }
  }

  Future<void> _carregarProdutos() async {
    final dados = await _supabase
        .from('produtos')
        .select('id, nome');

    final produtos = List<Map<String, dynamic>>.from(dados);

    // MESMA ORDEM DEFINIDA NO NovaVendaDialog / NovaTransferenciaDialog
    const ordemPorId = {
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 1,  // Gasolina Comum
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 2,  // Gasolina Aditivada
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 3,  // Diesel S500
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 4,  // Diesel S10
      '66ca957a-5698-4a02-8c9e-987770b6a151': 5,  // Etanol
      'f8e95435-471a-424c-947f-def8809053a0': 6,  // Gasolina A
      '4da89784-301f-4abe-b97e-c48729969e3d': 7,  // S500 A
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 8,  // S10 A
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 9,  // Anidro
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 10, // B100
    };

    produtos.sort((a, b) {
      final idA = a['id'].toString().toLowerCase();
      final idB = b['id'].toString().toLowerCase();

      return (ordemPorId[idA] ?? 999)
          .compareTo(ordemPorId[idB] ?? 999);
    });

    _produtos = [
      {'id': 'todos', 'nome': 'Todos os produtos'},
      ...produtos,
    ];
  }
  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: const Text(
          'Filtros de Movimentações',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando ? _buildLoading() : _buildConteudo(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
    );
  }

  Widget _buildConteudo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardFiltros(),
          const SizedBox(height: 20),
          _buildBotoes(),
        ],
      ),
    );
  }

  // ===================== COMPONENTES =====================

  Widget _buildCardFiltros() {
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
                Icon(Icons.filter_alt, color: const Color(0xFF0D47A1), size: 20),
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

          // Linha 1: Filial, Produto, Tipo Movimentação, Tipo Operação
          Row(
            children: [
              // Campo Filial
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filial',
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
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filialSelecionada,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          onChanged: usuario.nivel == 3
                              ? (v) => setState(() => _filialSelecionada = v)
                              : null,
                          items: _filiais.map((filial) {
                            return DropdownMenuItem<String>(
                              value: filial['id']?.toString(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(filial['nome_dois']?.toString() ?? ''),
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
              
              // Campo Produto
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produto',
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
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _produtoSelecionado,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          onChanged: (v) => setState(() => _produtoSelecionado = v),
                          items: _produtos.map((produto) {
                            return DropdownMenuItem<String>(
                              value: produto['id']?.toString(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(produto['nome']?.toString() ?? ''),
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
              
              // Campo Tipo Movimentação
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo movimentação',
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
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoMov,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          onChanged: (v) => setState(() => _tipoMov = v!),
                          items: const [
                            DropdownMenuItem(value: 'todos', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Todas'),
                            )),
                            DropdownMenuItem(value: 'entrada', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Entrada'),
                            )),
                            DropdownMenuItem(value: 'saida', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Saída'),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Campo Tipo Operação
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo operação',
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
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tipoOp,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          onChanged: (v) => setState(() => _tipoOp = v!),
                          items: const [
                            DropdownMenuItem(value: 'todos', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Todos'),
                            )),
                            DropdownMenuItem(value: 'venda', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Venda'),
                            )),
                            DropdownMenuItem(value: 'transf', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Transferência'),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Linha 2: Data Início, Data Fim, Relatório
          Row(
            children: [
              // Campo Data Início
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data início',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _dataInicioController,
                      keyboardType: TextInputType.datetime,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (novoValor) {
                        _aplicarMascaraData(_dataInicioController, _dataInicioController.text, novoValor);
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'dd/mm/aaaa',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Campo Data Fim
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data fim',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _dataFimController,
                      keyboardType: TextInputType.datetime,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (novoValor) {
                        _aplicarMascaraData(_dataFimController, _dataFimController.text, novoValor);
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'dd/mm/aaaa',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Campo Relatório
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Relatório',
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
                        border: Border.all(color: Colors.grey.shade400, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _modoRelatorio,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          onChanged: (v) => setState(() => _modoRelatorio = v!),
                          items: const [
                            DropdownMenuItem(value: 'sintetico', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Sintético'),
                            )),
                            DropdownMenuItem(value: 'analitico', child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Analítico'),
                            )),
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
              onPressed: () {
                setState(() {
                  if (usuario.nivel < 3) {
                    _filialSelecionada = usuario.filialId;
                  } else {
                    _filialSelecionada = 'todas';
                  }
                  _produtoSelecionado = 'todos';
                  _tipoMov = 'saida';
                  _tipoOp = 'todos';
                  _modoRelatorio = 'sintetico';
                  
                  final now = DateTime.now();
                  final hojeFormatado = _formatarData(now);
                  _dataInicioController.text = hojeFormatado;
                  _dataFimController.text = hojeFormatado;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: Colors.grey.shade400, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Redefinir',
                style: TextStyle(
                  fontSize: 13,
                  color: Color.fromARGB(255, 95, 95, 95),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Botão Consultar
          SizedBox(
            width: 140,
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                try {
                  final partesInicio = _dataInicioController.text.split('/');
                  final partesFim = _dataFimController.text.split('/');

                  final dataInicio = DateTime(
                    int.parse(partesInicio[2]),
                    int.parse(partesInicio[1]),
                    int.parse(partesInicio[0]),
                  );

                  final dataFim = DateTime(
                    int.parse(partesFim[2]),
                    int.parse(partesFim[1]),
                    int.parse(partesFim[0]),
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MovimentacoesPage(
                        filialId: _filialSelecionada ?? 'todas',
                        dataInicio: dataInicio,
                        dataFim: dataFim,
                        produtoId: _produtoSelecionado ?? 'todos',
                        tipoMov: _tipoMov,
                        tipoOp: _tipoOp,
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data inválida. Use o formato dd/mm/aaaa'),
                      backgroundColor: Colors.orange,
                    ),
                  );
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
}