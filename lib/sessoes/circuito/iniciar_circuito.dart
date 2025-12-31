import 'package:flutter/material.dart';

enum EtapaCircuito {
  chegada,
  documentacao,
  carregamento,
  liberacao,
  saida,
}

class IniciarCircuitoPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const IniciarCircuitoPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<IniciarCircuitoPage> createState() => _IniciarCircuitoPageState();
}

class _IniciarCircuitoPageState extends State<IniciarCircuitoPage> {
  EtapaCircuito etapaAtual = EtapaCircuito.chegada;

  final List<_EtapaConfig> etapas = const [
    _EtapaConfig(label: 'Chegada', icon: Icons.local_shipping),
    _EtapaConfig(label: 'Documentação', icon: Icons.description),
    _EtapaConfig(label: 'Carregamento', icon: Icons.local_gas_station),
    _EtapaConfig(label: 'Liberação', icon: Icons.verified),
    _EtapaConfig(label: 'Saída', icon: Icons.exit_to_app),
  ];

  void _avancarEtapa() {
    if (etapaAtual.index < EtapaCircuito.values.length - 1) {
      setState(() {
        etapaAtual = EtapaCircuito.values[etapaAtual.index + 1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
              ),
              const SizedBox(width: 10),
              const Text(
                'Iniciar Circuito',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 40),

          _buildTimeline(),

          const SizedBox(height: 50),

          ElevatedButton.icon(
            onPressed: _avancarEtapa,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Avançar etapa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Row(
      children: List.generate(etapas.length, (index) {
        final ativa = index <= etapaAtual.index;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index != 0)
                    Expanded(
                      child: Container(
                        height: 4,
                        color: ativa ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ativa ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(etapas[index].icon, color: Colors.white),
                  ),
                  if (index != etapas.length - 1)
                    Expanded(
                      child: Container(
                        height: 4,
                        color: ativa ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                etapas[index].label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ativa ? const Color(0xFF2E7D32) : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _EtapaConfig {
  final String label;
  final IconData icon;

  const _EtapaConfig({required this.label, required this.icon});
}
