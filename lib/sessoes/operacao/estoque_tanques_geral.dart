import 'package:flutter/material.dart';

/// ===============================
/// MODELO DE DADOS DO TANQUE
/// ===============================
class DadosTanque {
  final String id;
  final String nome;
  final double capacidadeTotal;
  final List<DetalheTanque> detalhes;

  DadosTanque({
    required this.id,
    required this.nome,
    required this.capacidadeTotal,
    required this.detalhes,
  });

  double get estoqueAtual {
    double total = 0;
    for (var detalhe in detalhes) {
      total += detalhe.litros;
    }
    return total.clamp(0, capacidadeTotal);
  }
  
  double get percentualPreenchimento =>
      (estoqueAtual / capacidadeTotal * 100).clamp(0, 100);
}

class DetalheTanque {
  final String produto;
  final double litros;
  final String data;
  final String tipo; // 'entrada' ou 'saida'

  DetalheTanque({
    required this.produto,
    required this.litros,
    required this.data,
    required this.tipo,
  });
}

/// ===============================
/// PÁGINA PRINCIPAL - ESTOQUE POR TANQUE
/// ===============================
class EstoquePorTanquePage extends StatefulWidget {
  final VoidCallback? onVoltar;
  
  const EstoquePorTanquePage({
    super.key,
    this.onVoltar,
  });

  @override
  State<EstoquePorTanquePage> createState() => _EstoquePorTanquePageState();
}

class _EstoquePorTanquePageState extends State<EstoquePorTanquePage> {
  late List<DadosTanque> tanques;
  int tanqueSelecionadoIndex = 0;

  @override
  void initState() {
    super.initState();
    _carregarDadosTanques();
  }

  void _carregarDadosTanques() {
    // Dados de exemplo - em produção, buscar do banco de dados
    tanques = [
      DadosTanque(
        id: 'tanque_001',
        nome: 'Tanque 1 - Diesel',
        capacidadeTotal: 50000,
        detalhes: [
          DetalheTanque(
            produto: 'Diesel S10',
            litros: 42500,
            data: '06/02/2025 14:30',
            tipo: 'entrada',
          ),
          DetalheTanque(
            produto: 'Saída para frota',
            litros: -5000,
            data: '05/02/2025 10:15',
            tipo: 'saida',
          ),
        ],
      ),
      DadosTanque(
        id: 'tanque_002',
        nome: 'Tanque 2 - Gasolina',
        capacidadeTotal: 30000,
        detalhes: [
          DetalheTanque(
            produto: 'Gasolina Premium',
            litros: 28750,
            data: '06/02/2025 12:00',
            tipo: 'entrada',
          ),
          DetalheTanque(
            produto: 'Saída para distribuição',
            litros: -1250,
            data: '04/02/2025 16:45',
            tipo: 'saida',
          ),
        ],
      ),
      DadosTanque(
        id: 'tanque_003',
        nome: 'Tanque 3 - Arla 32',
        capacidadeTotal: 20000,
        detalhes: [
          DetalheTanque(
            produto: 'Arla 32',
            litros: 15200,
            data: '01/02/2025 09:30',
            tipo: 'entrada',
          ),
          DetalheTanque(
            produto: 'Saída para manutenção',
            litros: -4800,
            data: '03/02/2025 14:20',
            tipo: 'saida',
          ),
        ],
      ),
      DadosTanque(
        id: 'tanque_004',
        nome: 'Tanque 4 - Querosene',
        capacidadeTotal: 25000,
        detalhes: [
          DetalheTanque(
            produto: 'Querosene',
            litros: 22100,
            data: '06/02/2025 08:45',
            tipo: 'entrada',
          ),
          DetalheTanque(
            produto: 'Saída para clientes',
            litros: -2900,
            data: '05/02/2025 13:30',
            tipo: 'saida',
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Estoque por Tanque',
          style: TextStyle(
            color: Color(0xFF222B45),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222B45)),
          onPressed: () {
            if (widget.onVoltar != null) {
              widget.onVoltar!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Menu de navegação superior com os tanques
          _construirMenuTanques(),
          // Conteúdo principal com detalhes do tanque selecionado
          Expanded(
            child: _construirDetalheTanque(),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// MENU SUPERIOR DE NAVEGAÇÃO
  /// ===============================
  Widget _construirMenuTanques() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: List.generate(tanques.length, (index) {
                final tanque = tanques[index];
                final isSelected = tanqueSelecionadoIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => tanqueSelecionadoIndex = index);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF222B45)
                              : const Color(0xFFF0F1F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF222B45)
                                : const Color(0xFFE0E3EB),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              tanque.nome.split(' - ').first,
                              style: TextStyle(
                                color: isSelected ? Color(0xFFF8F9FA) : Color(0xFF222B45),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (tanque.nome.contains(' - '))
                              Text(
                                tanque.nome.split(' - ').last,
                                style: TextStyle(
                                  color: isSelected ? Color(0xFFBFC8E6) : Color(0xFF8F9BB3),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(
            height: 1,
            color: Color(0xFFE0E3EB),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// DETALHE DO TANQUE SELECIONADO
  /// ===============================
  Widget _construirDetalheTanque() {
    final tanque = tanques[tanqueSelecionadoIndex];
    final percentual = tanque.percentualPreenchimento;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card com informações principais
          _construirCardInformacoesAlterar(tanque, percentual),
          const SizedBox(height: 20),

          // Indicador de nível com barra de progresso
          _construirIndicadorNivel(tanque, percentual),
          const SizedBox(height: 20),

          // Tabela com histórico/detalhes
          _construirTabelaDetalhes(tanque),
        ],
      ),
    );
  }

  /// ===============================
  /// CARD COM INFORMAÇÕES PRINCIPAIS
  /// ===============================
  Widget _construirCardInformacoesAlterar(DadosTanque tanque, double percentual) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFBFC8E6).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tanque.nome,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222B45),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _construirInfoMini(
                    'Estoque Atual',
                    '${tanque.estoqueAtual.toStringAsFixed(0)} L',
                    Color(0xFF3366FF),
                  ),
                  const SizedBox(width: 20),
                  _construirInfoMini(
                    'Capacidade',
                    '${tanque.capacidadeTotal.toStringAsFixed(0)} L',
                    Color(0xFFFFA000),
                  ),
                  const SizedBox(width: 20),
                  _construirInfoMini(
                    'Espaço Livre',
                    '${(tanque.capacidadeTotal - tanque.estoqueAtual).toStringAsFixed(0)} L',
                    Color(0xFF00B686),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getCor(percentual).withOpacity(0.1),
              border: Border.all(
                color: _getCor(percentual),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                '${percentual.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getCor(percentual),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// INDICADOR DE NÍVEL COM BARRA
  /// ===============================
  Widget _construirIndicadorNivel(DadosTanque tanque, double percentual) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFBFC8E6).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nível do Tanque',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentual / 100,
              minHeight: 30,
              backgroundColor: Color(0xFFE0E3EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                _getCor(percentual),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 L',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8F9BB3),
                ),
              ),
              Text(
                '${percentual.toStringAsFixed(1)}% Preenchido',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222B45),
                ),
              ),
              Text(
                '${tanque.capacidadeTotal.toStringAsFixed(0)} L',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8F9BB3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// TABELA COM DETALHES
  /// ===============================
  Widget _construirTabelaDetalhes(DadosTanque tanque) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFBFC8E6).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho da tabela
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF222B45),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Produto / Descrição',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Volume (L)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Data/Hora',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
          // Linhas da tabela
          ...List.generate(tanque.detalhes.length, (index) {
            final detalhe = tanque.detalhes[index];
            final isAlternado = index.isEven;
            final isEntrada = detalhe.tipo == 'entrada';

            return Container(
              color: isAlternado ? Color(0xFFF0F1F6) : Color(0xFFF8F9FA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detalhe.produto,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF222B45),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEntrada ? 'Entrada' : 'Saída',
                          style: TextStyle(
                            fontSize: 11,
                            color: isEntrada ? Color(0xFF00B686) : Color(0xFFFF3D71),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${isEntrada ? '+' : ''} ${detalhe.litros.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isEntrada ? Color(0xFF00B686) : Color(0xFFFF3D71),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      detalhe.data,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Icon(
                      isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isEntrada ? Color(0xFF00B686) : Color(0xFFFF3D71),
                      size: 18,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// ===============================
  /// WIDGETS AUXILIARES
  /// ===============================
  Widget _construirInfoMini(String label, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Color _getCor(double percentual) {
    if (percentual >= 80) return const Color(0xFF00B686);
    if (percentual >= 50) return const Color(0xFFFFA000);
    return const Color(0xFFFF3D71);
  }
}