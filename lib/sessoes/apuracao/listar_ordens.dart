import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'ordem.dart';

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

  String? _filialSelecionada;
  String _busca = '';
  int? _nivel;

  int? _hoverIndex;

  @override
  void initState() {
    super.initState();

    final usuario = UsuarioAtual.instance;
    _nivel = usuario?.nivel;

    // Se não for admin, já fixa a filial do usuário e carrega
    if (_nivel != 3) {
      _filialSelecionada = usuario?.filialId;
      _carregarOrdens();
    } else {
      // Admin: carrega filiais e também carrega ordens de TODAS
      _carregarFiliais();
      _carregarOrdensNivel3();
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

    final dados = await supabase
        .from('ordens_analises')
        .select('''
          id,
          numero_controle,
          criado_em,
          status,
          tipo_operacao,
          transportadora,
          motorista,
          placa_cavalo,
          carreta1,
          carreta2,
          produto_nome
        ''')
        .eq('filial_id', _filialSelecionada!)
        .order('criado_em', ascending: false);

    final filtrados = dados.where((o) {
      final status = (o['status'] ?? '').toString().toLowerCase();
      final criado = o['criado_em']?.toString().substring(0, 10) ?? '';
      return status == 'pendente' || criado == hojeStr;
    }).toList();

    setState(() {
      _ordens = List<Map<String, dynamic>>.from(filtrados);
      _carregando = false;
    });
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pendente':
        return Colors.orange;
      case 'aprovada':
        return Colors.green;
      case 'concluida':
        return Colors.blue;
      case 'rejeitada':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  @override
  Widget build(BuildContext context) {
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
          ],
        ),

        const SizedBox(height: 10),
        const Divider(),

        // BUSCA
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar em qualquer campo...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),

        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : lista.isEmpty
                  ? const Center(child: Text('Nenhuma ordem encontrada'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final o = lista[index];
                        final status = o['status'] ?? '';
                        final cor = _statusColor(status);

                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoverIndex = index),
                          onExit: (_) => setState(() => _hoverIndex = null),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CertificadoAnalisePage(
                                    onVoltar: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ),
                              );
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
                                            'Data: ${_formatarData(o['criado_em'])}'),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status.toString().toUpperCase(),
                                      style: TextStyle(color: cor, fontSize: 11),
                                    ),
                                  )
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
          criado_em,
          status,
          tipo_operacao,
          transportadora,
          motorista,
          placa_cavalo,
          carreta1,
          carreta2,
          produto_nome,
          filial_id
        ''')
        .order('criado_em', ascending: false);

    final filtrados = dados.where((o) {
      final status = (o['status'] ?? '').toString().toLowerCase();
      final criado = o['criado_em']?.toString().substring(0, 10) ?? '';
      return status == 'pendente' || criado == hojeStr;
    }).toList();

    setState(() {
      _ordens = List<Map<String, dynamic>>.from(filtrados);
      _carregando = false;
    });
  }
}
