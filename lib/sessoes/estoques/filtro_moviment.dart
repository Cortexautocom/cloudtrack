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
        .select('id, nome')
        .eq('empresa_id', usuario.empresaId!)
        .order('nome');

    final lista = List<Map<String, dynamic>>.from(dados);

    if (usuario.nivel == 3) {
      _filiais = [
        {'id': 'todas', 'nome': 'Todas'},
        ...lista,
      ];
    } else {
      _filiais = lista;
    }
  }

  Future<void> _carregarProdutos() async {
    final dados = await _supabase
        .from('produtos')
        .select('id, nome')
        .order('nome');

    _produtos = [
      {'id': 'todos', 'nome': 'Todos os produtos'},
      ...List<Map<String, dynamic>>.from(dados),
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
          _buildResumo(),
          const SizedBox(height: 30),
          _buildBotoes(),
        ],
      ),
    );
  }

  // ===================== COMPONENTES =====================

  Widget _buildCardFiltros() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de Consulta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Filial',
                    value: _filialSelecionada,
                    items: _filiais
                        .map((f) => DropdownMenuItem(
                              value: f['id'],
                              child: Text(f['nome']),
                            ))
                        .toList(),
                    onChanged: usuario.nivel == 3
                        ? (v) => setState(() => _filialSelecionada = v)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: _buildDropdown(
                    label: 'Produto',
                    value: _produtoSelecionado,
                    items: _produtos
                        .map((p) => DropdownMenuItem(
                              value: p['id'],
                              child: Text(p['nome']),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _produtoSelecionado = v),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: _buildDropdown(
                    label: 'Tipo movimentação',
                    value: _tipoMov,
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                      DropdownMenuItem(value: 'saida', child: Text('Saída')),
                    ],
                    onChanged: (v) => setState(() => _tipoMov = v!),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: _buildDropdown(
                    label: 'Tipo operação',
                    value: _tipoOp,
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'venda', child: Text('Venda')),
                      DropdownMenuItem(
                          value: 'transf', child: Text('Transferência')),
                    ],
                    onChanged: (v) => setState(() => _tipoOp = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                    child: _buildCampoData(
                        label: 'Data início',
                        controller: _dataInicioController)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildCampoData(
                        label: 'Data fim',
                        controller: _dataFimController)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Relatório',
                    value: _modoRelatorio,
                    items: const [
                      DropdownMenuItem(
                          value: 'sintetico', child: Text('Sintético')),
                      DropdownMenuItem(
                          value: 'analitico', child: Text('Analítico')),
                    ],
                    onChanged: (v) =>
                        setState(() => _modoRelatorio = v!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoData({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            hintText: 'dd/mm/aaaa',
          ),
          onChanged: (novoValor) {
            _aplicarMascaraData(controller, controller.text, novoValor);
          },
        ),
      ],
    );
  }

  Widget _buildResumo() {
    return Card(
      elevation: 1,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Resumo pronto. Nenhuma ação ainda.',
          style: TextStyle(color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildBotoes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: OutlinedButton(
            onPressed: () {},
            child: const Text('Redefinir'),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 200,
          child: ElevatedButton(
            onPressed: () {
              try {
                final partesInicio =
                    _dataInicioController.text.split('/');
                final partesFim =
                    _dataFimController.text.split('/');

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
                    content:
                        Text('Data inválida. Use o formato dd/mm/aaaa'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Consultar'),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem> items,
    required ValueChanged? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
