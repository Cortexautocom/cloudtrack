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

  // Mapa de cores para produtos - EXPANDIDO PARA TODOS OS PRODUTOS
  final Map<String, Color> _coresProdutos = {
    // Gasolinas
    'gasolina comum': Color(0xFFFF6B35), // Laranja vibrante
    'g comum': Color(0xFFFF6B35),
    'gasolina com': Color(0xFFFF6B35),
    
    'gasolina aditivada': Color(0xFF00A8E8), // Azul claro
    'g aditivada': Color(0xFF00A8E8),
    'gasolina ad': Color(0xFF00A8E8),
    
    'gasolina a': Color(0xFFE91E63), // Rosa
    'gasolina aditivada a': Color(0xFFE91E63),
    
    // Diesels
    'diesel s500': Color(0xFF8D6A9F), // Roxo claro
    'd s500': Color(0xFF8D6A9F),
    'diesel s-500': Color(0xFF8D6A9F),
    
    'diesel s10': Color(0xFF2E294E), // Azul escuro
    'd s10': Color(0xFF2E294E),
    'diesel s-10': Color(0xFF2E294E),
    
    's500 a': Color(0xFF9C27B0), // Roxo vibrante
    'diesel s500 a': Color(0xFF9C27B0),
    
    's10 a': Color(0xFF673AB7), // Roxo azulado
    'diesel s10 a': Color(0xFF673AB7),
    
    // Etanóis
    'etanol': Color(0xFF83B692), // Verde claro
    'etanol hidratado': Color(0xFF83B692),
    'hidratado': Color(0xFF83B692),
    
    'anidro': Color(0xFF4CAF50), // Verde
    'etanol anidro': Color(0xFF4CAF50),
    
    // Biodiesel
    'b100': Color(0xFF8BC34A), // Verde limão
    'biodiesel': Color(0xFF8BC34A),
    
    // Padrão para produtos não mapeados
    'desconhecido': Color(0xFF607D8B), // Cinza azulado
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
            tipo_op,
            g_comum,
            g_aditivada,
            d_s10,
            d_s500,
            etanol,
            anidro,
            b100,
            gasolina_a,
            s500_a,
            s10_a,
            produtos!produto_id(id, nome_dois)
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
    
  // Agrupar produtos por tipo considerando tipo_op
  Map<String, double> _agruparProdutosParaCarregar() {
    final Map<String, double> produtos = {};
    
    for (var mov in _movimentacoes) {
      final tipoOp = mov['tipo_op']?.toString().toLowerCase();
      final produtoNome = mov['produtos']?['nome_dois']?.toString() ?? 'desconhecido';
      
      double quantidade = 0;
      
      if (tipoOp == 'venda' || tipoOp == 'transf') {
        // Usar colunas específicas de produto
        final produtoId = mov['produtos']?['id']?.toString();
        if (produtoId != null) {
          final colunaProduto = _resolverColunaProduto(produtoId);
          if (colunaProduto != null) {
            final qtd = mov[colunaProduto];
            if (qtd != null && qtd > 0) {
              quantidade = (qtd as num).toDouble();
            }
          }
        }
      } else if (tipoOp == 'cacl' || tipoOp == 'emprestimo' || tipoOp == null) {
        // Usar saida_amb
        final saida = mov['saida_amb'];
        if (saida != null && saida > 0) {
          quantidade = (saida as num).toDouble();
        }
      }
      
      if (quantidade > 0) {
        produtos[produtoNome] = (produtos[produtoNome] ?? 0) + quantidade;
      }
    }
    
    return produtos;
  }

  String? _resolverColunaProduto(String produtoId) {
    final Map<String, String> mapaProdutoColuna = {
      '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',
      '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',
      '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',
      '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',
      '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',
      '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada',
      'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 'd_s500',
      'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',
      'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',
      'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a',
    };
    
    return mapaProdutoColuna[produtoId.toLowerCase()];
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

  // Formatar número sem unidade
  String _formatarNumero(double valor) {
    if (valor % 1 == 0) {
      // Valor inteiro
      return valor.toInt().toString();
    } else {
      // Valor decimal - formata com separador de milhar
      final partes = valor.toStringAsFixed(3).split('.');
      final parteInteira = int.parse(partes[0]);
      final parteDecimal = partes[1].replaceAll(RegExp(r'0*$'), '');
      
      if (parteDecimal.isEmpty) {
        return parteInteira.toString();
      } else {
        // Corrigindo o erro - usando a função min do dart:math ou uma alternativa
        final maxCasas = parteDecimal.length < 3 ? parteDecimal.length : 3;
        return '$parteInteira.${parteDecimal.substring(0, maxCasas)}';
      }
    }
  }

  // 1️⃣ Card remodelado com produtos organizados
  Widget _buildResumoCompacto() {
    final placasFormatadas = _formatarPlacas(widget.ordem['placas']);
    final produtosAgrupados = _agruparProdutosParaCarregar();
    final totalProdutos = produtosAgrupados.values.fold(0.0, (sum, qtd) => sum + qtd);

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
                        _formatarNumero(totalProdutos),
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

  Widget _buildGridProdutos(Map<String, double> produtos) {
    final entries = produtos.entries.toList();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final produtoNome = entry.key;
        final quantidade = entry.value;
        final nomeFormatado = _formatarNomeProduto(produtoNome);
        final cor = _obterCorProduto(produtoNome);
        
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
                  _formatarNumero(quantidade),
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

  String _formatarNomeProduto(String produtoNome) {
    // Usar o nome_dois diretamente, já formatado
    return produtoNome;
  }

  Color _obterCorProduto(String produtoNome) {
    // Mapeamento direto baseado nos nomes EXATOS que vêm do banco
    final Map<String, Color> mapeamentoExato = {
      // Gasolinas
      'G. Comum': Color(0xFFFF6B35),
      
      'G. Aditivada': Color(0xFF00A8E8),
      
      'Gasolina A': Color(0xFFE91E63),
      
      // Diesels
      'S500': Color(0xFF8D6A9F),
      
      'S10': Color(0xFF2E294E),
      
      'S500 A': Color(0xFF9C27B0),
      
      'S10 A': Color(0xFF673AB7),
      
      // Etanóis      
      'Hidratado': Color(0xFF83B692),
      
      'Anidro': Color(0xFF4CAF50),
      
      // Biodiesel
      'B100': Color(0xFF8BC34A),
    };
    
    // Primeiro tenta match exato
    if (mapeamentoExato.containsKey(produtoNome)) {
      return mapeamentoExato[produtoNome]!;
    }
    
    // Se não encontrar, tenta por case insensitive
    final nomeLower = produtoNome.toLowerCase();
    for (var entry in mapeamentoExato.entries) {
      if (entry.key.toLowerCase() == nomeLower) {
        return entry.value;
      }
    }
    
    // Fallback para lógica antiga (se necessário)
    return _coresProdutos['desconhecido']!;
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