import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

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
  int _anoSelecionado = DateTime.now().year;
  int _mesSelecionado = DateTime.now().month;
  String _modoRelatorio = 'sintetico';

  // ===== LISTAS =====
  List<Map<String, dynamic>> _filiais = [];
  List<Map<String, dynamic>> _produtos = [];

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _carregarFiliais(),
      _carregarProdutos(),
    ]);

    if (usuario.nivel < 3) {
      _filialSelecionada = usuario.filialId;
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

    _filiais = List<Map<String, dynamic>>.from(dados);
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

            // FILIAL
            _buildDropdown(
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

            const SizedBox(height: 12),

            // PRODUTO
            _buildDropdown(
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

            const SizedBox(height: 12),

            // TIPO MOV / OP
            Row(
              children: [
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
                      DropdownMenuItem(value: 'transf', child: Text('Transferência')),
                    ],
                    onChanged: (v) => setState(() => _tipoOp = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ANO / MÊS / MODO
            Row(
              children: [
                Expanded(child: _buildAno()),
                const SizedBox(width: 12),
                Expanded(child: _buildMes()),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown(
                  label: 'Relatório',
                  value: _modoRelatorio,
                  items: const [
                    DropdownMenuItem(value: 'sintetico', child: Text('Sintético')),
                    DropdownMenuItem(value: 'analitico', child: Text('Analítico')),
                  ],
                  onChanged: (v) => setState(() => _modoRelatorio = v!),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAno() {
    return _buildDropdown(
      label: 'Ano',
      value: _anoSelecionado,
      items: List.generate(11, (i) {
        final ano = 2020 + i;
        return DropdownMenuItem(value: ano, child: Text(ano.toString()));
      }),
      onChanged: (v) => setState(() => _anoSelecionado = v as int),
    );
  }

  Widget _buildMes() {
    final meses = [
      'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'
    ];

    return _buildDropdown(
      label: 'Mês',
      value: _mesSelecionado,
      items: List.generate(12, (i) {
        return DropdownMenuItem(
          value: i + 1,
          child: Text(meses[i]),
        );
      }),
      onChanged: (v) => setState(() => _mesSelecionado = v as int),
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
            onPressed: null, // proposital
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
