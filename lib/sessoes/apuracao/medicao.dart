import 'package:flutter/material.dart';

class MedicaoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  
  const MedicaoTanquesPage({
    super.key,
    required this.onVoltar,
  });

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
    for (var list in _controllers) {
      for (var c in list) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ==================== CABEÇALHO COM TUDO NA MESMA LINHA ====================
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
              ),
              const SizedBox(width: 12),
              const Text(
                'Medição de tanques',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 24),
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Data da Medição: ',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _dataController.text,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 32),
              const Icon(Icons.person, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Responsável: ',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'João Silva',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ==================== LISTA DE TANQUES ====================
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: tanques.asMap().entries.map((e) {
                final i = e.key;
                final tanque = e.value;
                return _buildTanqueCard(tanque, i);
              }).toList(),
            ),
          ),
        ),

        //_buildActionButtons(),
      ],
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int index) {
    final ctrls = _controllers[index];

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: Text(tanque['numero'], style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tanque['produto'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('Capacidade: ${tanque['capacidade']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ← ALTURA DO CARD CONTROLADA AQUI (ajuste se quiser ainda menor)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSection('MANHÃ', '06:00h', Colors.blue[50]!, Colors.blue, ctrls.sublist(0, 6))),
                const SizedBox(width: 24),
                Container(width: 1, height: 280, color: Colors.grey[300]),
                const SizedBox(width: 24),
                Expanded(child: _buildSection('TARDE', '18:00h', Colors.green[50]!, Colors.green, ctrls.sublist(6, 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String periodo, String hora, Color bg, Color accent, List<TextEditingController> c) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: accent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.access_time, size: 16, color: accent),
            const SizedBox(width: 6),
            Text('$periodo - $hora', style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 2, child: _field('cm', c[0], '735')),
            const SizedBox(width: 8),
            Expanded(child: _field('mm', c[1], '35')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field('Temp. Tanque', c[2], '28.5', decimal: true)),
            const SizedBox(width: 8),
            Expanded(child: _field('Densidade', c[3], '0.745', decimal: true)),
          ]),
          const SizedBox(height: 8),
          _field('Temp. Amostra', c[4], '28.0', decimal: true),
          const SizedBox(height: 10),
          // Campo de observações com altura reduzida
          TextFormField(
            controller: c[5],
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Observações...',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            ),
          ),
        ],
      ),
    );
  }

  // ← INPUTS AGORA BAIXOS E COMPACTOS
  Widget _field(String label, TextEditingController ctrl, String hint, {bool decimal = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,                                        // ← ESSENCIAL
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), // ← REDUZIDO
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]);
  }

  /*Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medições salvas!'), backgroundColor: Colors.green)),
          icon: const Icon(Icons.save),
          label: const Text('SALVAR MEDIÇÕES'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
        ),
        const SizedBox(width: 20),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relatório enviado para impressão!'))),
          icon: const Icon(Icons.print),
          label: const Text('IMPRIMIR RELATÓRIO'),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0D47A1), width: 2), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
        ),
      ]),
    );
  }*/
}