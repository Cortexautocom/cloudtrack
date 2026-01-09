import 'package:flutter/material.dart';

enum EtapaCircuito {
  programado,
  checkList,
  operacao,
  emissaoNF,
  liberacao,
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
  EtapaCircuito etapaAtual = EtapaCircuito.programado;

  final List<EtapaInfo> etapas = const [
    EtapaInfo(
      etapa: EtapaCircuito.programado,
      label: 'Programado',
      subtitle: 'Agendamento realizado',
      icon: Icons.calendar_month,
      cor: Color.fromARGB(255, 61, 160, 206),
    ),
    EtapaInfo(
      etapa: EtapaCircuito.checkList,
      label: 'Check-list',
      subtitle: 'Verificação de segurança',
      icon: Icons.checklist_outlined,
      cor: Color(0xFFF57C00),
    ),
    EtapaInfo(
      etapa: EtapaCircuito.operacao,
      label: 'Em operação',
      subtitle: 'Carga em transporte',
      icon: Icons.invert_colors,
      cor: Color(0xFF7B1FA2),
    ),
    EtapaInfo(
      etapa: EtapaCircuito.emissaoNF,
      label: 'Emissão NF',
      subtitle: 'Documentação fiscal',
      icon: Icons.description_outlined,
      cor: Color(0xFFC2185B),
    ),
    EtapaInfo(
      etapa: EtapaCircuito.liberacao,
      label: 'Expedido',
      subtitle: 'Operação concluída',
      icon: Icons.done_outline,
      cor: Color.fromARGB(255, 42, 199, 50),
    ),
  ];

  void _avancarEtapa() {
    if (etapaAtual.index < EtapaCircuito.values.length - 1) {
      setState(() {
        etapaAtual = EtapaCircuito.values[etapaAtual.index + 1];
      });
    }
  }

  void _voltarEtapa() {
    if (etapaAtual.index > 0) {
      setState(() {
        etapaAtual = EtapaCircuito.values[etapaAtual.index - 1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final etapaAtualInfo = etapas.firstWhere((e) => e.etapa == etapaAtual);
    final etapasCompletas = etapas.indexWhere((e) => e.etapa == etapaAtual) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Acompanhamento de Circuito',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Status em tempo real do transporte',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: etapaAtualInfo.cor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: etapaAtualInfo.cor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: etapaAtualInfo.cor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        etapaAtualInfo.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: etapaAtualInfo.cor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha do tempo limpa e conectada
                  Card(
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                      child: Column(
                        children: [
                          // Título minimalista
                          const Text(
                            'Etapas do Circuito',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sequência de execução do transporte',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Linha do tempo horizontal conectada
                          Container(
                            height: 120,
                            child: Stack(
                              children: [
                                // Linha principal conectando todas as etapas
                                Positioned(
                                  left: 40,
                                  right: 40,
                                  top: 20,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),

                                // Etapas sobrepostas na linha
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(etapas.length, (index) {
                                    final etapa = etapas[index];
                                    final etapaIndex = etapas.indexWhere((e) => e.etapa == etapaAtual);
                                    final isCompleta = index < etapaIndex;
                                    final isAtual = index == etapaIndex;

                                    return Expanded(
                                      child: Column(
                                        children: [
                                          // Ponto da etapa com linha preenchida
                                          Stack(
                                            children: [
                                              // Linha preenchida até a etapa atual
                                              if (isCompleta || isAtual)
                                                Positioned(
                                                  left: index == 0 ? 20 : 0,
                                                  top: 20,
                                                  width: index == etapas.length - 1 ? 40 : 80,
                                                  child: Container(
                                                    height: 2,
                                                    color: etapa.cor,
                                                  ),
                                                ),

                                              // Ícone da etapa
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isCompleta || isAtual
                                                      ? etapa.cor
                                                      : Colors.grey.shade300,
                                                  border: isAtual
                                                      ? Border.all(
                                                          color: etapa.cor.withOpacity(0.3),
                                                          width: 2,
                                                        )
                                                      : null,
                                                  boxShadow: isAtual
                                                      ? [
                                                          BoxShadow(
                                                            color: etapa.cor.withOpacity(0.2),
                                                            blurRadius: 6,
                                                            spreadRadius: 1,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Icon(
                                                  etapa.icon,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),

                                              // Check para etapas completas
                                              if (isCompleta)
                                                Positioned(
                                                  right: 0,
                                                  top: 0,
                                                  child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: etapa.cor, width: 1.5),
                                                    ),
                                                    child: Icon(
                                                      Icons.check,
                                                      size: 10,
                                                      color: etapa.cor,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Label da etapa
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Column(
                                              children: [
                                                Text(
                                                  etapa.label,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isAtual
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                    color: isCompleta || isAtual
                                                        ? etapa.cor
                                                        : Colors.grey.shade600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  etapa.subtitle,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Contadores minimalistas
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: etapaAtualInfo.cor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 14,
                                      color: etapaAtualInfo.cor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${etapasCompletas} de ${etapas.length} etapas',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: etapaAtualInfo.cor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Controles de navegação
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 140,
                                child: OutlinedButton(
                                  onPressed: _voltarEtapa,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: const BorderSide(color: Color(0xFF0D47A1)),
                                    foregroundColor: const Color(0xFF0D47A1),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_back, size: 16),
                                      SizedBox(width: 6),
                                      Text('Etapa Anterior', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 140,
                                child: ElevatedButton(
                                  onPressed: _avancarEtapa,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D47A1),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Próxima Etapa', style: TextStyle(fontSize: 13)),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EtapaInfo {
  final EtapaCircuito etapa;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color cor;

  const EtapaInfo({
    required this.etapa,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.cor,
  });
}