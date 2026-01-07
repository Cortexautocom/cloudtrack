import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControleDocumentosPage extends StatefulWidget {
  const ControleDocumentosPage({super.key});

  @override
  State<ControleDocumentosPage> createState() => _ControleDocumentosPageState();
}

class _ControleDocumentosPageState extends State<ControleDocumentosPage> {
  late final List<Map<String, dynamic>> _veiculos;
  final List<String> _documentos = [
    'CIPP','CIV','Afericao','Tacografo','AET Federal','AET Bahia','AET Goias','AET Alagoas','AET Minas G'
  ];
  final _placaCtrl = TextEditingController();
  final _buscaCtrl = TextEditingController();
  bool _carregando = true;
  bool _addMode = false;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _veiculos = [];
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('equipamentos_3')
          .select()
          .order('placa');
      _veiculos.clear();
      _veiculos.addAll(List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _carregando = false);
  }

  Future<void> _salvarData(String placa, String doc, DateTime? date) async {
    final colunas = {
      'CIPP':'cipp','CIV':'civ','Afericao':'afericao','Tacografo':'tacografo',
      'AET Federal':'aet_fed','AET Bahia':'aet_ba','AET Goias':'aet_go',
      'AET Alagoas':'aet_al','AET Minas G':'aet_mg',
    };
    final valor = date == null ? null : '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
    await Supabase.instance.client
        .from('equipamentos_3')
        .update({colunas[doc]!: valor})
        .eq('placa', placa);
    _carregar();
  }

  Future<void> _addVeiculo() async {
    final placa = _placaCtrl.text.trim().toUpperCase();
    if (placa.isEmpty) return;
    await Supabase.instance.client.from('equipamentos_3').insert({'placa': placa});
    _placaCtrl.clear();
    setState(() => _addMode = false);
    _carregar();
  }
  
  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    final p = s.split(RegExp(r'[/\-]'));
    if (p.length != 3) return null;
    final y = int.parse(p[2]);
    return DateTime(y < 100 ? 2000 + y : y, int.parse(p[1]), int.parse(p[0]));
  }

  String _fmt(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  Color _cor(DateTime? d) {
    if (d == null) return Colors.grey;
    final dias = d.difference(DateTime.now()).inDays;
    if (dias < 0) return Colors.red;
    if (dias <= 30) return Colors.orange;
    if (dias <= 90) return Colors.amber[800]!;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _veiculos.where((v) => v['placa'].toString().toLowerCase().contains(_filtro)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Controle de Documentos'),
        actions: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _buscaCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar placa...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _addMode = true),
            icon: const Icon(Icons.add),
            label: const Text('Novo Veículo'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          if (_addMode)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: Row(children: [
                Expanded(child: TextField(controller: _placaCtrl, decoration: const InputDecoration(labelText: 'Placa (ex: ABC-1234)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _addVeiculo, child: const Text('Adicionar')),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _addMode = false), child: const Text('Cancelar')),
              ]),
            ),

          // Cabeçalho fixo
          Container(
            color: const Color(0xFF0D47A1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              const SizedBox(
                width: 160, // Largura fixa da placa (aumentada)
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('PLACA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              ..._documentos.map((d) => Expanded(
                child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              )),
            ]),
          ),

          // Tabela estilo Excel (leve e fluida)
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                    ? const Center(child: Text('Nenhum veículo encontrado', style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : SingleChildScrollView(
                        child: Column(
                          children: filtrados.asMap().entries.map((entry) {
                            final i = entry.key;
                            final v = entry.value;
                            final placa = v['placa'] as String;

                            return Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: i.isEven ? Colors.grey[50] : Colors.white,
                                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Row(
                                children: [
                                  // Coluna PLACA (sem menu vertical)
                                  SizedBox(
                                    width: 160,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D47A1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          placa,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Células dos documentos
                                  ..._documentos.map((doc) {
                                    final col = {
                                      'CIPP':'cipp','CIV':'civ','Afericao':'afericao','Tacografo':'tacografo',
                                      'AET Federal':'aet_fed','AET Bahia':'aet_ba','AET Goias':'aet_go',
                                      'AET Alagoas':'aet_al','AET Minas G':'aet_mg',
                                    }[doc]!;
                                    final raw = v[col] as String?;
                                    final date = _parse(raw);
                                    final cor = _cor(date);

                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          final nova = await showDatePicker(
                                            context: context,
                                            initialDate: date ?? DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (nova != null) _salvarData(placa, doc, nova);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: cor.withOpacity(0.15),
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            date == null ? 'Toque para definir' : _fmt(date),
                                            style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 11),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}