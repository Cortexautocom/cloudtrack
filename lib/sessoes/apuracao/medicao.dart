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
  
  int _tanqueSelecionadoIndex = 0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < tanques.length; i++) {
      _controllers.add([
        TextEditingController(text: '06:00'), // NOVO: Horário da medição MANHÃ
        TextEditingController(text: '735'), TextEditingController(text: '35'),
        TextEditingController(text: '28.5'), TextEditingController(text: '0.745'),
        TextEditingController(text: '28.0'), TextEditingController(),
        TextEditingController(text: '18:00'), // NOVO: Horário da medição TARDE
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // === CABEÇALHO ===
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

          // === MENU DE NAVEGAÇÃO DOS TANQUES - NOVO LAYOUT ===
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tanques.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tanque = entry.value;
                  final isSelected = index == _tanqueSelecionadoIndex;
                  
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _tanqueSelecionadoIndex = index;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                        foregroundColor: isSelected ? Colors.white : const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        elevation: isSelected ? 2 : 0,
                        shadowColor: Colors.grey.shade300,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tanque['numero'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected ? Colors.white : const Color(0xFF0D47A1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tanque['produto'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white70 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // === CONTEÚDO PRINCIPAL ===
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: _buildTanqueCard(tanques[_tanqueSelecionadoIndex], _tanqueSelecionadoIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int index) {
    final ctrls = _controllers[index];

    return SingleChildScrollView(
      child: Card(
        elevation: 3,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // Cabeçalho do card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tanque['numero'],
                      style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      tanque['produto'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    tanque['capacidade'],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo do card
            Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  
                  return isWide
                      ? _buildWideLayout(ctrls)
                      : _buildNarrowLayout(ctrls);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(List<TextEditingController> ctrls) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSection(
            '1ª Medição',
            'Manhã',
            Colors.blue[50]!,
            Colors.blue,
            ctrls.sublist(0, 7), // ATUALIZADO: agora 7 campos
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildSection(
            '2ª Medição',
            ' Tarde',
            Colors.green[50]!,
            Colors.green,
            ctrls.sublist(7, 14), // ATUALIZADO: agora 7 campos
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(List<TextEditingController> ctrls) {
    return Column(
      children: [
        _buildSection(
          'MANHÃ',
          '06:00h',
          Colors.blue[50]!,
          Colors.blue,
          ctrls.sublist(0, 7), // ATUALIZADO: agora 7 campos
        ),
        const SizedBox(height: 16),
        _buildSection(
          'TARDE',
          '18:00h',
          Colors.green[50]!,
          Colors.green,
          ctrls.sublist(7, 14), // ATUALIZADO: agora 7 campos
        ),
      ],
    );
  }

  Widget _buildSection(String periodo, String hora, Color bg, Color accent, List<TextEditingController> c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                '$periodo - $hora',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accent,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Linha 1 - Horário da medição, cm e mm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeField('Horário Medição', c[0], '06:00', width: 120),
              _buildField('cm', c[1], '735', width: 100),
              _buildField('mm', c[2], '35', width: 100),
            ],
          ),
          const SizedBox(height: 16),

          // Linha 2 - 3 campos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildField('Temp. Tanque', c[3], '28.5', width: 110, decimal: true),
              _buildField('Densidade', c[4], '0.745', width: 110, decimal: true),
              _buildField('Temp. Amostra', c[5], '28.0', width: 110, decimal: true),
            ],
          ),
          const SizedBox(height: 16),

          // Observações
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Observações:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: c[6],
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Digite suas observações...',
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {double width = 100, bool decimal = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: width,
          height: 40,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // NOVO MÉTODO: Campo para horário da medição
  Widget _buildTimeField(String label, TextEditingController ctrl, String hint, {double width = 100}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: width,
          height: 40,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}