import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dialog_cadastro_placas.dart';

// ==============================
// PÁGINA PRINCIPAL DE VEÍCULOS
// ==============================
class VeiculosPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(Map<String, dynamic>) onSelecionarVeiculo;
  
  const VeiculosPage({
    super.key,
    required this.onVoltar,
    required this.onSelecionarVeiculo,
  });

  @override
  State<VeiculosPage> createState() => _VeiculosPageState();
}

class _VeiculosPageState extends State<VeiculosPage> {
  List<Map<String, dynamic>> _veiculos = [];
  bool _carregando = true;
  String _filtroPlaca = '';
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select('placa, bocas')
          .order('placa');
      
      setState(() {
        _veiculos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Erro ao carregar veículos: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<int> _parseBocas(dynamic bocasData) {
    if (bocasData is List) return bocasData.cast<int>();
    return [];
  }

  int _calcularTotalBocas(List<int> bocas) {
    return bocas.isNotEmpty ? bocas.reduce((a, b) => a + b) : 0;
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    if (_filtroPlaca.isEmpty) return _veiculos;
    return _veiculos.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      return placa.contains(_filtroPlaca.toLowerCase());
    }).toList();
  }

  void _abrirCadastroVeiculo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DialogCadastroPlacas(),
    ).then((_) => _carregarVeiculos());
  }

  Color _getCorBoca(int capacidade) {
    final cores = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.indigo, Colors.deepOrange, Colors.cyan, Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirCadastroVeiculo,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                const Text('Veículos',
                  style: TextStyle(fontSize: 20, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                const Spacer(),
                SizedBox(width: 200, child: TextField(
                  controller: _buscaController,
                  decoration: InputDecoration(
                    hintText: 'Buscar placa...', filled: true, fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filtroPlaca = v),
                )),
                const SizedBox(width: 12),
                IconButton(onPressed: _carregarVeiculos,
                  icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)), tooltip: 'Atualizar'),
              ],
            ),
          ),
          Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: const Row(children: [
              _CabecalhoTabela(texto: 'PLACA', largura: 120),
              SizedBox(width: 8),
              Expanded(child: Text('COMPARTIMENTOS (m³)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 12))),
            ]),
          ),
          Expanded(child: _carregando
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
              : _veiculosFiltrados.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_filtroPlaca.isEmpty ? 'Nenhum veículo cadastrado' : 'Nenhum veículo encontrado',
                        style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ]))
                  : ListView.builder(itemCount: _veiculosFiltrados.length, itemBuilder: (context, index) {
                      final veiculo = _veiculosFiltrados[index];
                      final placa = veiculo['placa']?.toString() ?? '';
                      final bocas = _parseBocas(veiculo['bocas']);
                      final totalBocas = _calcularTotalBocas(bocas);
                      return Container(height: 48, decoration: BoxDecoration(
                          color: index.isEven ? Colors.white : Colors.grey.shade50,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                        child: InkWell(onTap: () => widget.onSelecionarVeiculo({'placa': placa, 'bocas': bocas}),
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [
                              SizedBox(width: 120, child: Text(placa,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D47A1)),
                                overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Expanded(child: bocas.isEmpty
                                  ? Row(children: [
                                      const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      const Text('Cavalo',
                                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                                    ])
                                  : Wrap(spacing: 6, runSpacing: 4, children: [
                                      ...bocas.map((capacidade) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _getCorBoca(capacidade).withOpacity(0.1),
                                          border: Border.all(color: _getCorBoca(capacidade).withOpacity(0.3), width: 1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text('$capacidade',
                                          style: TextStyle(color: _getCorBoca(capacidade), fontSize: 11, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.withOpacity(0.1),
                                          border: Border.all(color: Colors.blueGrey.withOpacity(0.3), width: 1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text('$totalBocas',
                                          style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ])),
                            ]),
                          ),
                        ),
                      );
                    }),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoTabela extends StatelessWidget {
  final String texto;
  final double largura;

  const _CabecalhoTabela({required this.texto, required this.largura});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: largura, child: Text(texto,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 12)));
  }
}

// ==============================
// PÁGINA DE DETALHES DO VEÍCULO
// ==============================
class VeiculoDetalhesPage extends StatelessWidget {
  final String placa;
  final List<int> bocas;
  final VoidCallback onVoltar;

  const VeiculoDetalhesPage({
    super.key,
    required this.placa,
    required this.bocas,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)), onPressed: onVoltar),
                const SizedBox(width: 8),
                Text('Veículo $placa',
                  style: const TextStyle(fontSize: 20, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
                color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Informações do Veículo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.confirmation_number, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Placa:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text(placa, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.local_gas_station, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Padding(padding: EdgeInsets.only(top: 2),
                      child: Text('Compartimentos:', style: TextStyle(fontWeight: FontWeight.w500))),
                    const SizedBox(width: 8),
                    Expanded(child: bocas.isEmpty
                        ? const Row(children: [
                            Icon(Icons.directions_car, size: 16, color: Colors.grey),
                            SizedBox(width: 6),
                            Text('Cavalo', style: TextStyle(fontStyle: FontStyle.italic)),
                          ])
                        : Wrap(spacing: 8, runSpacing: 4, children: [
                            ...bocas.map((capacidade) => Chip(
                              backgroundColor: _getCorBoca(capacidade).withOpacity(0.1),
                              label: Text('$capacidade m³',
                                style: TextStyle(color: _getCorBoca(capacidade), fontWeight: FontWeight.bold, fontSize: 12)),
                            )).toList(),
                            Chip(backgroundColor: Colors.blueGrey.withOpacity(0.15),
                              label: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('${bocas.reduce((a, b) => a + b)} m³ total',
                                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                            ),
                          ])),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
                color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Documentação',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _carregarDocumentos(placa),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return const Text('Erro ao carregar documentos');
                      }
                      final dados = snapshot.data!;
                      final documentos = [
                        {'nome': 'CIPP', 'coluna': 'cipp'},
                        {'nome': 'CIV', 'coluna': 'civ'},
                        {'nome': 'Aferição', 'coluna': 'afericao'},
                        {'nome': 'Tacógrafo', 'coluna': 'tacografo'},
                        {'nome': 'AET Federal', 'coluna': 'aet_fed'},
                        {'nome': 'AET Bahia', 'coluna': 'aet_ba'},
                        {'nome': 'AET Goiás', 'coluna': 'aet_go'},
                        {'nome': 'AET Alagoas', 'coluna': 'aet_al'},
                        {'nome': 'AET Minas G', 'coluna': 'aet_mg'},
                      ];
                      return Column(children: documentos.map((doc) {
                        final dataStr = dados[doc['coluna']] as String?;
                        final data = _parseData(dataStr);
                        final cor = _getCorStatusData(data);
                        return Padding(padding: const EdgeInsets.only(bottom: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(doc['nome']!, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.calendar_today, size: 16, color: cor),
                              const SizedBox(width: 8),
                              Text(data == null ? '--' : _formatarData(data),
                                style: TextStyle(color: cor, fontWeight: FontWeight.w500, fontSize: 13)),
                              if (data != null) ...[
                                const SizedBox(width: 12),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text(_getDiasRestantes(data), style: TextStyle(color: cor, fontSize: 11))),
                              ],
                            ]),
                          ]),
                        );
                      }).toList());
                    },
                  ),
                ]),
              ),
            ]),
          )),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _carregarDocumentos(String placa) async {
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select()
          .eq('placa', placa)
          .maybeSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return null;
    try {
      final partes = dataStr.split('/');
      if (partes.length != 3) return null;
      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);
      final anoCompleto = ano < 100 ? 2000 + ano : ano;
      return DateTime(anoCompleto, mes, dia);
    } catch (_) {
      return null;
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  Color _getCorStatusData(DateTime? data) {
    if (data == null) return Colors.grey;
    final dias = data.difference(DateTime.now()).inDays;
    if (dias < 0) return Colors.red;
    if (dias <= 30) return Colors.orange;
    if (dias <= 90) return Colors.amber[800]!;
    return Colors.green;
  }

  String _getDiasRestantes(DateTime data) {
    final dias = data.difference(DateTime.now()).inDays;
    if (dias < 0) return 'Vencido há ${dias.abs()} dias';
    if (dias == 0) return 'Vence hoje';
    if (dias == 1) return 'Vence amanhã';
    return 'Vence em $dias dias';
  }

  Color _getCorBoca(int capacidade) {
    final cores = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.indigo, Colors.deepOrange, Colors.cyan, Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }
}