import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EtapaCircuito {
  programado,
  checkList,
  operacao,
  emissaoNF,
  liberacao,
}

class DetalhesOrdemView extends StatefulWidget {
  final Map<String, dynamic> ordem;

  const DetalhesOrdemView({
    super.key,
    required this.ordem,
  });

  @override
  State<DetalhesOrdemView> createState() => _DetalhesOrdemViewState();
}

class _DetalhesOrdemViewState extends State<DetalhesOrdemView> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';

  List<Map<String, dynamic>> _movimentacoes = [];
  late EtapaCircuito _etapaAtual;

  final List<_EtapaInfo> _etapas = const [
    _EtapaInfo(
      etapa: EtapaCircuito.programado,
      label: 'Programado',
      subtitle: 'Agendamento realizado',
      icon: Icons.calendar_month,
      cor: Color.fromARGB(255, 61, 160, 206),
      statusCodigo: 1,
    ),
    _EtapaInfo(
      etapa: EtapaCircuito.checkList,
      label: 'Check-list',
      subtitle: 'Verificação de segurança',
      icon: Icons.checklist_outlined,
      cor: Color(0xFFF57C00),
      statusCodigo: 2,
    ),
    _EtapaInfo(
      etapa: EtapaCircuito.operacao,
      label: 'Em operação',
      subtitle: 'Carga em transporte',
      icon: Icons.invert_colors,
      cor: Color(0xFF7B1FA2),
      statusCodigo: 3,
    ),
    _EtapaInfo(
      etapa: EtapaCircuito.emissaoNF,
      label: 'Emissão NF',
      subtitle: 'Documentação fiscal',
      icon: Icons.description_outlined,
      cor: Color(0xFFC2185B),
      statusCodigo: 4,
    ),
    _EtapaInfo(
      etapa: EtapaCircuito.liberacao,
      label: 'Expedido',
      subtitle: 'Operação concluída',
      icon: Icons.done_outline,
      cor: Color.fromARGB(255, 42, 199, 50),
      statusCodigo: 5,
    ),
  ];

  // Histórico de fatos ocorridos (exemplo)
  final List<Map<String, String>> _historicoFatos = [
    {
      'data': '15/01/2024',
      'hora': '09:30',
      'descricao': 'Programação realizada por Carlos Silva'
    },
    {
      'data': '15/01/2024',
      'hora': '10:15',
      'descricao': 'Veículo deu entrada na base, em fase de check-list.'
    },
    {
      'data': '15/01/2024', 
      'hora': '10:45',
      'descricao': 'Check-list finalizado, entrou em operação.'
    },
    {
      'data': '15/01/2024',
      'hora': '12:20',
      'descricao': 'Veículo carregado. Aguardando emissão de nota fiscal'
    },
    {
      'data': '15/01/2024',
      'hora': '13:05',
      'descricao': 'Nota fiscal entregue ao motorista, expedição realizada.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _etapaAtual = _resolverEtapaPorStatus(widget.ordem['status_circuito']);
    _carregarMovimentacoes();
  }

  Future<void> _carregarMovimentacoes() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final dados = await _supabase
          .from('movimentacoes')
          .select('''
            id,
            placa,
            cliente,
            forma_pagamento,
            entrada_amb,
            saida_amb,
            data_mov,
            produtos!produto_id(nome)
          ''')
          .eq('ordem_id', widget.ordem['ordem_id'])
          .order('id');

      setState(() {
        _movimentacoes = List<Map<String, dynamic>>.from(dados);
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
  }

  EtapaCircuito _resolverEtapaPorStatus(dynamic status) {
    final codigo = status is int ? status : int.tryParse(status.toString()) ?? 1;
    return _etapas
        .firstWhere((e) => e.statusCodigo == codigo,
            orElse: () => _etapas.first)
        .etapa;
  }

  int _obterQuantidade(Map<String, dynamic> mov) {
    final entrada = mov['entrada_amb'];
    final saida = mov['saida_amb'];
    if (entrada != null && entrada > 0) return entrada as int;
    if (saida != null && saida > 0) return saida as int;
    return 0;
  }

  // Contar tanques que vão sair (com saída)
  int _contarTanquesParaCarregar() {
    int count = 0;
    for (var mov in _movimentacoes) {
      final saida = mov['saida_amb'];
      if (saida != null && saida > 0) {
        count++;
      }
    }
    return count;
  }

  String _formatarPlacas(dynamic placasData) {
    if (placasData == null) return 'N/I';
    
    if (placasData is List) {
      return placasData.where((p) => p != null && p.toString().isNotEmpty)
                      .map((p) => p.toString())
                      .join(', ');
    }
    return placasData.toString();
  }

  // 1️⃣ Card compacto com dados da ordem
  Widget _buildResumoCompacto() {
    final placasFormatadas = _formatarPlacas(widget.ordem['placas']);
    final tanquesParaCarregar = _contarTanquesParaCarregar();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Coluna 1: Ordem
            _buildInfoCompacta(
              icon: Icons.confirmation_number,
              label: 'Ordem nº',
              value: '--',
            ),
            
            // Separador vertical
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade300,
            ),
            
            // Coluna 2: Tanques
            _buildInfoCompacta(
              icon: Icons.oil_barrel,
              label: 'Tanques',
              value: '$tanquesParaCarregar',
            ),
            
            // Separador vertical
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade300,
            ),
            
            // Coluna 3: Placas (mais larga)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Placas',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      placasFormatadas,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCompacta({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final etapaIndex = _etapas.indexWhere((e) => e.etapa == _etapaAtual);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            const Text(
              'Status da Ordem',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Stack(
                children: [
                  Positioned(
                    left: 30,
                    right: 30,
                    top: 15,
                    child: Container(
                      height: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_etapas.length, (index) {
                      final etapa = _etapas[index];
                      final isCompleta = index < etapaIndex;
                      final isAtual = index == etapaIndex;

                      return Expanded(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                if (isCompleta || isAtual)
                                  Positioned(
                                    left: index == 0 ? 15 : 0,
                                    top: 15,
                                    width:
                                        index == _etapas.length - 1 ? 30 : 70,
                                    child: Container(
                                      height: 2,
                                      color: etapa.cor,
                                    ),
                                  ),
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleta || isAtual
                                        ? etapa.cor
                                        : Colors.grey.shade300,
                                  ),
                                  child: Icon(
                                    etapa.icon,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              etapa.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isAtual
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isCompleta || isAtual
                                    ? etapa.cor
                                    : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2️⃣ Lista compacta de fatos ocorridos
  Widget _buildHistoricoFatos() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 8),
            ..._historicoFatos.map((fato) => _buildItemHistoricoCompacto(fato)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemHistoricoCompacto(Map<String, String> fato) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fato['data']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  fato['hora']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fato['descricao']!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 65, 65, 65),
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTanqueCompacto(Map<String, dynamic> mov) {
    final produto = mov['produtos']?['nome']?.toString() ?? 'Produto';
    final cliente = mov['cliente']?.toString() ?? 'Cliente não informado';
    final quantidade = _obterQuantidade(mov);
    final tipo = mov['saida_amb'] != null && mov['saida_amb'] > 0 
        ? 'Saída' 
        : 'Entrada';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tipo == 'Saída' ? Colors.orange.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: tipo == 'Saída' ? Colors.orange.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                tipo,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: tipo == 'Saída' ? Colors.orange.shade800 : Colors.blue.shade800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produto,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$quantidade amb. • $cliente',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1️⃣ Card compacto com resumo
          _buildResumoCompacto(),
          
          // 2️⃣ Timeline compacta
          _buildTimeline(),
          
          // 3️⃣ Histórico compacto
          _buildHistoricoFatos(),
          
          // 4️⃣ Lista de tanques
          if (!_carregando && !_erro && _movimentacoes.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Tanques',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 8),
                ..._movimentacoes.map((mov) => _buildItemTanqueCompacto(mov)).toList(),
              ],
            ),
          
          // Estados de carregamento/erro
          if (_carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          
          if (_erro && !_carregando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erro ao carregar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mensagemErro,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
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

class _EtapaInfo {
  final EtapaCircuito etapa;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color cor;
  final int statusCodigo;

  const _EtapaInfo({
    required this.etapa,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.cor,
    required this.statusCodigo,
  });
}