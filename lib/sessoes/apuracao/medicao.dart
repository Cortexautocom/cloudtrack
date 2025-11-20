import 'package:flutter/material.dart';

class MedicaoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  const MedicaoTanquesPage({super.key, required this.onVoltar});

  @override
  State<MedicaoTanquesPage> createState() => _MedicaoTanquesPageState();
}

class _MedicaoTanquesPageState extends State<MedicaoTanquesPage> {
  final List<Map<String, dynamic>> tanques = [
    {'numero': 'TQ-001', 'produto': 'GASOLINA COMUM', 'capacidade': '50.000 L'},
    {'numero': 'TQ-002', 'produto': 'ÓLEO DIESEL S10', 'capacidade': '75.000 L'},
    {'numero': 'TQ-003', 'produto': 'ETANOL HIDRATADO', 'capacidade': '30.000 L'},
    {'numero': 'TQ-004', 'produto': 'GASOLINA PREMIUM', 'capacidade': '25.000 L'},
  ];

  final List<List<TextEditingController>> _controllers = [];
  final TextEditingController _dataController = TextEditingController(
    text: '${DateTime.now().day.toString().padLeft(2,'0')}/${DateTime.now().month.toString().padLeft(2,'0')}/${DateTime.now().year}'
  );

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < tanques.length; i++) {
      _controllers.add([
        TextEditingController(text: '735'), TextEditingController(text: '35'),
        TextEditingController(text: '28.5'), TextEditingController(text: '0.745'),
        TextEditingController(text: '28.0'), TextEditingController(),
        TextEditingController(text: '685'), TextEditingController(text: '20'),
        TextEditingController(text: '29.0'), TextEditingController(text: '0.745'),
        TextEditingController(text: '28.5'), TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    for (var list in _controllers) { for (var c in list) c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // opcional: fundo igual ao cabeçalho
      body: Center(                              // ← centraliza na tela
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              // === CABEÇALHO (permanece igual) ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
                ),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                    onPressed: widget.onVoltar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Medição de tanques',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(width: 20),
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(_dataController.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 20),
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text('João Silva', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                ]),
              ),

              // === CONTEÚDO COM ROLAGEM ===
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: tanques.asMap().entries.map((e) => _buildTanqueCard(e.value, e.key)).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int index) {
    final ctrls = _controllers[index];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: const BoxDecoration(color: Color(0xFF0D47A1), borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10))),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: Text(tanque['numero'], style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 14))),
            const SizedBox(width: 12),
            Text(tanque['produto'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Text(tanque['capacidade'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _buildSection('MANHÃ', '06:00h', Colors.blue[50]!, Colors.blue, ctrls.sublist(0, 6))),
            const SizedBox(width: 8),
            Expanded(child: _buildSection('TARDE', '18:00h', Colors.green[50]!, Colors.green, ctrls.sublist(6, 12))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSection(String periodo, String hora, Color bg, Color accent, List<TextEditingController> c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: accent.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.access_time, size: 15, color: accent),
          const SizedBox(width: 6),
          Text('$periodo - $hora', style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 13)),
        ]),
        const SizedBox(height: 14),

        // 1ª linha – cm e mm CENTRALIZADOS (com legendas à esquerda)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _fieldLarge('cm', c[0], '735'),
            _fieldLarge('mm', c[1], '35'),
          ],
        ),
        const SizedBox(height: 14),

        // 2ª linha – 3 campos centralizados
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _fieldLarge('Temp. Tanque', c[2], '28.5', decimal: true),
            _fieldLarge('Densidade', c[3], '0.745', decimal: true),
            _fieldLarge('Temp. Amostra', c[4], '28.0', decimal: true),
          ],
        ),
        const SizedBox(height: 14),

        // 3ª linha – Observações
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 12, right: 10), child: Text('Obs:', style: TextStyle(fontSize: 11.5, color: Colors.grey))),
          Expanded(
            child: TextFormField(
              controller: c[5],
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Observações...',
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // Campo único usado em todas as linhas – legenda à esquerda, campo centralizado
  Widget _fieldLarge(String label, TextEditingController ctrl, String hint, {bool decimal = false}) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 3), // reduzi um pouco aqui também
      SizedBox(
        width: 100,
        child: TextFormField(
          controller: ctrl,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    ]);
  }
}