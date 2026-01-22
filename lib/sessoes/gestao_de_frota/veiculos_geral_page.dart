// veiculos_geral_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VeiculosGeralPage extends StatefulWidget {
  final String filtro; // 🔹 filtro vem da VeiculosPage

  const VeiculosGeralPage({
    super.key,
    required this.filtro,
  });

  @override
  State<VeiculosGeralPage> createState() => _VeiculosGeralPageState();
}

class _VeiculosGeralPageState extends State<VeiculosGeralPage> {
  List<Map<String, dynamic>> _veiculos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('veiculos_geral')
          .select('''
            id,
            placa,
            renavam,
            status,
            tanques,
            transportadora_id,
            transportadoras(nome)
          ''')
          .order('placa');

      setState(() {
        _veiculos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Erro ao carregar veículos de terceiros: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<int> _parseTanques(dynamic data) {
    if (data is List) return data.cast<int>();
    return [];
  }

  int _totalTanques(List<int> tanques) {
    if (tanques.isEmpty) return 0;
    return tanques.reduce((a, b) => a + b);
  }

  String _nomeTransportadora(Map<String, dynamic> v) {
    final t = v['transportadoras'];
    if (t is Map) {
      return t['nome']?.toString() ?? '--';
    }
    return '--';
  }

  Color _corBoca(int capacidade) {
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.cyan,
      Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    final filtro = widget.filtro.trim().toLowerCase();
    if (filtro.isEmpty) return _veiculos;

    return _veiculos.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      final renavam = v['renavam']?.toString().toLowerCase() ?? '';
      final transportadora = _nomeTransportadora(v).toLowerCase();

      return placa.contains(filtro) ||
          renavam.contains(filtro) ||
          transportadora.contains(filtro);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // =========================
        // CABEÇALHO DA TABELA
        // =========================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 100, child: Text('PLACA', style: _h)),
              SizedBox(width: 180, child: Text('TRANSPORTADORA', style: _h)),
              SizedBox(width: 120, child: Text('RENAVAM', style: _h)),
              SizedBox(width: 260, child: Text('COMPARTIMENTOS', style: _h)),
              SizedBox(width: 90, child: Text('CAPAC. TOTAL', style: _h)),
            ],
          ),
        ),

        // =========================
        // LISTA
        // =========================
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0D47A1)),
                )
              : _veiculosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum veículo encontrado',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _veiculosFiltrados.length,
                      itemBuilder: (context, index) {
                        final v = _veiculosFiltrados[index];
                        final tanques = _parseTanques(v['tanques']);
                        final total = _totalTanques(tanques);

                        return Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? Colors.white
                                : Colors.grey.shade50,
                            border: Border(
                              bottom:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // PLACA
                              SizedBox(
                                width: 100,
                                child: Text(
                                  v['placa'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                              ),

                              // TRANSPORTADORA
                              SizedBox(
                                width: 180,
                                child: Text(
                                  _nomeTransportadora(v),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // RENAVAM
                              SizedBox(
                                width: 120,
                                child: Text(
                                  v['renavam'] ?? '--',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),

                              // COMPARTIMENTOS
                              SizedBox(
                                width: 260,
                                child: tanques.isEmpty
                                    ? const Text(
                                        'Cavalo',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: tanques
                                            .map(
                                              (c) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _corBoca(c)
                                                      .withOpacity(0.1),
                                                  border: Border.all(
                                                    color: _corBoca(c)
                                                        .withOpacity(0.3),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10),
                                                ),
                                                child: Text(
                                                  '$c',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: _corBoca(c),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),

                              // CAPAC. TOTAL (MESMO CHIP DA PÁGINA PRINCIPAL)
                              SizedBox(
                                width: 90,
                                child: tanques.isEmpty
                                    ? const SizedBox()
                                    : Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey
                                              .withOpacity(0.1),
                                          border: Border.all(
                                            color: Colors.blueGrey
                                                .withOpacity(0.3),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.arrow_forward,
                                              size: 12,
                                              color: Colors.blueGrey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$total',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

const _h = TextStyle(
  fontWeight: FontWeight.bold,
  color: Color(0xFF0D47A1),
  fontSize: 12,
);
