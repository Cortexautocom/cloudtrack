import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EtapaCircuito {
  programado,
  checkList,
  operacao,
  emissaoNF,
  liberacao,
}

// ✅ 7️⃣ RENOMEIE a classe
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

  String _formatarPlacas(dynamic placaData) {
    if (placaData == null) return 'N/I';
    if (placaData is List) {
      return placaData.map((p) => p.toString()).join(', ');
    }
    return placaData.toString();
  }

  String _formatarData(String? data) {
    if (data == null) return 'N/I';
    final d = DateTime.tryParse(data);
    if (d == null) return data;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildTimeline() {
    final etapaIndex =
        _etapas.indexWhere((e) => e.etapa == _etapaAtual);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            const Text(
              'Status da Ordem',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  Positioned(
                    left: 40,
                    right: 40,
                    top: 20,
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
                                    left: index == 0 ? 20 : 0,
                                    top: 20,
                                    width:
                                        index == _etapas.length - 1 ? 40 : 80,
                                    child: Container(
                                      height: 2,
                                      color: etapa.cor,
                                    ),
                                  ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleta || isAtual
                                        ? etapa.cor
                                        : Colors.grey.shade300,
                                  ),
                                  child: Icon(
                                    etapa.icon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
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

  Widget _buildResumo() {
    final placas = (widget.ordem['placas'] as List).join(', ');
    final quantidadeTotal = widget.ordem['quantidade_total'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ordem ${widget.ordem['ordem_id']}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Data: ${_formatarData(widget.ordem['data_mov']?.toString())}'),
            Text('Placas: $placas'),
            Text('Tanques: ${_movimentacoes.length}'),
            Text('Quantidade total: $quantidadeTotal'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTanque(Map<String, dynamic> mov) {
    final produto = mov['produtos']?['nome']?.toString() ?? 'Produto';
    final cliente = mov['cliente']?.toString() ?? 'Cliente não informado';
    final pagamento = mov['forma_pagamento']?.toString() ?? 'Não informado';
    final quantidade = _obterQuantidade(mov);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$produto • $quantidade'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: $cliente'),
            Text('Pagamento: $pagamento'),
            Text('Placa: ${_formatarPlacas(mov['placa'])}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 8️⃣ REMOVA o Scaffold e SUBSTITUA POR:
    return Column(
      children: [
        _buildTimeline(),
        _buildResumo(),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _erro
                  ? Center(child: Text(_mensagemErro))
                  : ListView.builder(
                      itemCount: _movimentacoes.length,
                      itemBuilder: (context, index) {
                        return _buildItemTanque(
                          _movimentacoes[index],
                        );
                      },
                    ),
        ),
      ],
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