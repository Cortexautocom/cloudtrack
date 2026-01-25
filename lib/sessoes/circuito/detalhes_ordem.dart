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

  // Mapa de cores para produtos
  final Map<String, Color> _coresProdutos = {
    'gasolina': Color(0xFFFF6B35),
    'hidratado': Color(0xFF00A8E8),
    's10': Color(0xFF2E294E),
    'etanol': Color(0xFF83B692),
    'diesel': Color(0xFF8D6A9F),
  };

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

  // Agrupar produtos por tipo (somente saídas)
  Map<String, int> _agruparProdutosParaCarregar() {
    final Map<String, int> produtos = {};
    
    for (var mov in _movimentacoes) {
      final saida = mov['saida_amb'];
      if (saida != null && saida > 0) {
        final produto = mov['produtos']?['nome']?.toString().toLowerCase() ?? 'desconhecido';
        produtos[produto] = (produtos[produto] ?? 0) + (saida as int);
      }
    }
    
    return produtos;
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

  // 1️⃣ Card remodelado com produtos organizados
  Widget _buildResumoCompacto() {
    final placasFormatadas = _formatarPlacas(widget.ordem['placas']);
    final produtosAgrupados = _agruparProdutosParaCarregar();
    final totalProdutos = produtosAgrupados.values.fold(0, (sum, qtd) => sum + qtd);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha 1: Ordem e Placa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ordem
                _buildInfoItem(
                  icon: Icons.confirmation_number,
                  label: 'Ordem nº',
                  value: '--',
                  flex: 1,
                ),
                
                // Separador
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.grey.shade300,
                ),
                
                // Placa
                Expanded(
                  flex: 2,
                  child: _buildInfoItem(
                    icon: Icons.directions_car,
                    label: 'Placas',
                    value: placasFormatadas,
                    flex: 2,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Linha 2: Produtos sendo carregados
            if (produtosAgrupados.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Carga',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalProdutos amb.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Grid de produtos
                  _buildGridProdutos(produtosAgrupados),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nenhum produto para carregar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridProdutos(Map<String, int> produtos) {
    final entries = produtos.entries.toList();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final produto = entry.key;
        final quantidade = entry.value;
        final nomeFormatado = _formatarNomeProduto(produto);
        final cor = _obterCorProduto(produto);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de quantidade
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  quantidade.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(width: 6),
              
              // Nome do produto
              Text(
                nomeFormatado,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatarNomeProduto(String produto) {
    final Map<String, String> mapeamento = {
      'gasolina': 'Gasolina',
      'hidratado': 'Hidratado',
      's10': 'S10',
      'etanol': 'Etanol',
      'diesel': 'Diesel',
    };
    
    return mapeamento[produto.toLowerCase()] ?? produto;
  }

  Color _obterCorProduto(String produto) {
    final chave = produto.toLowerCase();
    return _coresProdutos[chave] ?? Colors.grey.shade600;
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D47A1),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
          // 1️⃣ Card remodelado com produtos
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