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

  // Adicionado: Variável para armazenar o número de controle da ordem
  String? _numeroControleOrdem;

  // Variáveis para o diálogo do Check-list
  bool _civSelecionado = false;
  bool _cippSelecionado = false;
  bool _mopSelecionado = false;
  bool _nr26Selecionado = false;
  bool _atualizandoChecklist = false;

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
    'gasolina comum': Color(0xFFFF6B35),
    'g comum': Color(0xFFFF6B35),
    'gasolina com': Color(0xFFFF6B35),
    
    'gasolina aditivada': Color(0xFF00A8E8),
    'g aditivada': Color(0xFF00A8E8),
    'gasolina ad': Color(0xFF00A8E8),
    
    'gasolina a': Color(0xFFE91E63),
    'gasolina aditivada a': Color(0xFFE91E63),
    
    // Diesels
    'diesel s500': Color(0xFF8D6A9F),
    'd s500': Color(0xFF8D6A9F),
    'diesel s-500': Color(0xFF8D6A9F),
    
    'diesel s10': Color(0xFF2E294E),
    'd s10': Color(0xFF2E294E),
    'diesel s-10': Color(0xFF2E294E),
    
    's500 a': Color(0xFF9C27B0),
    'diesel s500 a': Color(0xFF9C27B0),
    
    's10 a': Color(0xFF673AB7),
    'diesel s10 a': Color(0xFF673AB7),
    
    // Etanóis
    'etanol': Color(0xFF83B692),
    'etanol hidratado': Color(0xFF83B692),
    'hidratado': Color(0xFF83B692),
    
    'anidro': Color(0xFF4CAF50),
    'etanol anidro': Color(0xFF4CAF50),
    
    // Biodiesel
    'b100': Color(0xFF8BC34A),
    'biodiesel': Color(0xFF8BC34A),
    
    // Padrão para produtos não mapeados
    'desconhecido': Color(0xFF607D8B),
  };

  @override
  void initState() {
    super.initState();
    _etapaAtual = _resolverEtapaPorStatus(widget.ordem['status_circuito']);
    
    // Busca o número de controle da ordem
    _carregarNumeroControleOrdem();
    _carregarMovimentacoes();
  }

  // NOVO MÉTODO: Carrega o número de controle da ordem da tabela 'ordens'
  Future<void> _carregarNumeroControleOrdem() async {
    try {
      final ordemId = widget.ordem['ordem_id']?.toString();
      if (ordemId == null || ordemId.isEmpty) return;
      
      final resultado = await _supabase
          .from('ordens')
          .select('n_controle')
          .eq('id', ordemId)
          .maybeSingle();
          
      if (resultado != null && resultado['n_controle'] != null) {
        setState(() {
          _numeroControleOrdem = resultado['n_controle']?.toString();
        });
      }
    } catch (e) {
      print('Erro ao carregar número de controle da ordem: $e');
    }
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
  
  // NOVO MÉTODO: Abrir diálogo do Check-list
  Future<void> _abrirDialogoChecklist() async {
    // Resetar seleções
    setState(() {
      _civSelecionado = false;
      _cippSelecionado = false;
      _mopSelecionado = false;
      _nr26Selecionado = false;
    });

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    color: Color(0xFFF57C00),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Check-list de Segurança',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marque os itens verificados:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Item 1: CIV
                  _buildChecklistItem(
                    titulo: 'CIV - Certificado de Inspeção Veicular',
                    subtitulo: 'Verificar validade do CIV do veículo',
                    valor: _civSelecionado,
                    onChanged: (value) {
                      setState(() {
                        _civSelecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  
                  // Item 2: CIPP
                  _buildChecklistItem(
                    titulo: 'CIPP - Certificado de Inspeção para Produtos Perigosos',
                    subtitulo: 'Verificar conformidade para transporte de produtos perigosos',
                    valor: _cippSelecionado,
                    onChanged: (value) {
                      setState(() {
                        _cippSelecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  
                  // Item 3: MOP
                  _buildChecklistItem(
                    titulo: 'MOP - Manual de Operações',
                    subtitulo: 'Verificar disponibilidade e conformidade',
                    valor: _mopSelecionado,
                    onChanged: (value) {
                      setState(() {
                        _mopSelecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  
                  // Item 4: NR26
                  _buildChecklistItem(
                    titulo: 'NR26 - Sinalização de Segurança',
                    subtitulo: 'Verificar sinalização do veículo conforme NR26',
                    valor: _nr26Selecionado,
                    onChanged: (value) {
                      setState(() {
                        _nr26Selecionado = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  
                  // Mensagem de validação
                  if (_atualizandoChecklist)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF57C00),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Atualizando status...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Voltar',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _atualizandoChecklist
                      ? null
                      : () async {
                          // Verificar se todos os itens foram selecionados
                          final todosSelecionados = _civSelecionado &&
                              _cippSelecionado &&
                              _mopSelecionado &&
                              _nr26Selecionado;
                          
                          if (!todosSelecionados) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Todos os itens devem ser verificados!'),
                                backgroundColor: Colors.orange.shade700,
                              ),
                            );
                            return;
                          }
                          
                          // Atualizar status no banco de dados
                          await _concluirChecklist();
                          
                          // Fechar diálogo
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF57C00),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                  child: _atualizandoChecklist
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Concluir Check-list'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // NOVO MÉTODO: Widget para item do checklist
  Widget _buildChecklistItem({
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: valor ? Color(0xFFF57C00) : Colors.grey.shade300,
          width: valor ? 2 : 1,
        ),
        color: valor ? Color(0xFFF57C00).withOpacity(0.05) : Colors.white,
      ),
      child: CheckboxListTile(
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valor ? Color(0xFFF57C00) : Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          subtitulo,
          style: TextStyle(
            fontSize: 12,
            color: valor ? Color(0xFFF57C00).withOpacity(0.8) : Colors.grey.shade600,
          ),
        ),
        value: valor,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Color(0xFFF57C00),
        checkColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  // NOVO MÉTODO: Concluir checklist e atualizar banco de dados
  Future<void> _concluirChecklist() async {
    setState(() {
      _atualizandoChecklist = true;
    });

    try {
      // Atualizar todas as movimentações relacionadas a esta ordem
      final ordemId = widget.ordem['ordem_id'];
      if (ordemId != null) {
        await _supabase
            .from('movimentacoes')
            .update({'status_circuito': 3})
            .eq('ordem_id', ordemId);

        // Atualizar estado local
        setState(() {
          _etapaAtual = EtapaCircuito.operacao;
          _atualizandoChecklist = false;
        });

        // Adicionar ao histórico local
        final agora = DateTime.now();
        _historicoFatos.insert(2, {
          'data': '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}',
          'hora': '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}',
          'descricao': 'Check-list concluído por operador'
        });

        // Mostrar mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Check-list concluído! Status atualizado para "Em operação".'),
              backgroundColor: Colors.green.shade600,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Erro ao atualizar checklist: $e');
      setState(() {
        _atualizandoChecklist = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
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

  // NOVO: Formatar número no padrão '999.999'
  String _formatarNumero(double valor) {
    if (valor.isNaN || valor.isInfinite) return '0';
    
    // Arredonda para zero casas decimais
    final valorArredondado = valor.round();
    
    // Converte para string
    String valorStr = valorArredondado.abs().toString();
    
    // Adiciona ponto como separador de milhar
    String resultado = '';
    int contador = 0;
    
    // Percorre de trás para frente
    for (int i = valorStr.length - 1; i >= 0; i--) {
      resultado = valorStr[i] + resultado;
      contador++;
      
      // Adiciona ponto a cada 3 dígitos (exceto no início)
      if (contador == 3 && i > 0) {
        resultado = '.$resultado';
        contador = 0;
      }
    }
    
    // Adiciona sinal negativo se necessário
    if (valorArredondado < 0) {
      resultado = '-$resultado';
    }
    
    return resultado;
  }

  // 1️⃣ Card remodelado com produtos organizados - ATUALIZADO COM NÚMERO DE CONTROLE
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
              children: [
                // Ordem
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ordem nº',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _numeroControleOrdem ?? '--',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
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
                      const SizedBox(height: 4),
                      Text(
                        placasFormatadas,
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
    return produtoNome;
  }

  Color _obterCorProduto(String produtoNome) {
    final Map<String, Color> mapeamentoExato = {
      'G. Comum': Color(0xFFFF6B35),
      'G. Aditivada': Color(0xFF00A8E8),
      'Gasolina A': Color(0xFFE91E63),
      'S500': Color(0xFF8D6A9F),
      'S10': Color(0xFF2E294E),
      'S500 A': Color(0xFF9C27B0),
      'S10 A': Color(0xFF673AB7),
      'Hidratado': Color(0xFF83B692),
      'Anidro': Color(0xFF4CAF50),
      'B100': Color(0xFF8BC34A),
    };
    
    if (mapeamentoExato.containsKey(produtoNome)) {
      return mapeamentoExato[produtoNome]!;
    }
    
    final nomeLower = produtoNome.toLowerCase();
    for (var entry in mapeamentoExato.entries) {
      if (entry.key.toLowerCase() == nomeLower) {
        return entry.value;
      }
    }
    
    return _coresProdutos['desconhecido']!;
  }

  // NOVA TIMELINE - Redesenhada completamente
  Widget _buildTimeline() {
    final etapaIndex = _etapas.indexWhere((e) => e.etapa == _etapaAtual);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12), // Aumentado de 20 para 24
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status da Ordem',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 32), // Aumentado de 28 para 32
            
            // Container principal para timeline - CENTRALIZADO
            Center(
              child: Column(
                children: [
                  // Container para linha e ícones
                  SizedBox(
                    height: 60, // Aumentado de 54 para 60
                    child: Stack(
                      children: [
                        // LINHA DE CONEXÃO CONTÍNUA - CENTRALIZADA
                        Positioned(
                          left: 30,
                          right: 30,
                          top: 19, // Mantido mesmo posicionamento
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        
                        // ÍCONES E LABELS JUNTOS - ALINHADOS VERTICALMENTE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_etapas.length, (index) {
                            final etapa = _etapas[index];
                            final isCompleta = index <= etapaIndex;
                            final isAtual = index == etapaIndex;
                            final isChecklist = etapa.etapa == EtapaCircuito.checkList;
                            
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ÍCONE
                                _buildEtapaIconComLinha(
                                  etapa: etapa,
                                  index: index,
                                  isCompleta: isCompleta,
                                  isAtual: isAtual,
                                  isChecklist: isChecklist,
                                  etapaIndex: etapaIndex,
                                ),
                                
                                const SizedBox(height: 8), // Mantido 8
                                
                                // LABEL - AGORA VINCULADO AO ÍCONE
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    etapa.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isAtual ? FontWeight.bold : FontWeight.w500,
                                      color: isCompleta || isAtual ? etapa.cor : Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // ESPAÇO EXTRA ABAIXO DA TIMELINE
            const SizedBox(height: 8), // Adicionado espaço extra abaixo
          ],
        ),
      ),
    );
  }
  
  Widget _buildEtapaIconComLinha({
    required _EtapaInfo etapa,
    required int index,
    required bool isCompleta,
    required bool isAtual,
    required bool isChecklist,
    required int etapaIndex,
  }) {
    final podeClicar = isChecklist && etapaIndex >= index;
    
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleta ? etapa.cor : Colors.grey.shade300,
            border: Border.all(
              color: podeClicar ? etapa.cor.withOpacity(0.3) : Colors.transparent,
              width: podeClicar ? 2 : 0,
            ),
            boxShadow: podeClicar
                ? [
                    BoxShadow(
                      color: etapa.cor.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: podeClicar ? _abrirDialogoChecklist : null,
              customBorder: const CircleBorder(),
              splashColor: etapa.cor.withOpacity(0.3),
              highlightColor: etapa.cor.withOpacity(0.1),
              child: Center(
                child: Icon(
                  etapa.icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
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