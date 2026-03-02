import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String? filialSelecionadaId; // aceita terminal ou filial
  
  const EstoquePorTanquePage({
    super.key,
    this.onVoltar,
    this.filialSelecionadaId,
  });

  @override
  State<EstoquePorTanquePage> createState() => _EstoquePorTanquePageState();
}

class _EstoquePorTanquePageState extends State<EstoquePorTanquePage> {
  List<DadosTanque> tanques = [];
  bool _carregando = true;
  int tanqueSelecionadoIndex = 0;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _carregarDadosTanques();
  }

  Future<void> _carregarDadosTanques() async {
    setState(() {
      _carregando = true;
    });

    if (widget.filialSelecionadaId == null) {
      setState(() {
        tanques = [];
        _carregando = false;
      });
      return;
    }

    final SupabaseClient supabase = Supabase.instance.client;

    try {
      final resp = await supabase
          .from('tanques')
          .select('id, referencia, capacidade, id_produto, produtos (nome)')
          .eq('terminal_id', widget.filialSelecionadaId!)
          .order('referencia');

      final List<DadosTanque> lista = [];

      final now = DateTime.now();
      final inicioDia = DateTime(now.year, now.month, now.day);
      final inicioDiaIso = inicioDia.toIso8601String();
      final agoraIso = now.toIso8601String();
      final dataStr = DateFormat('yyyy-MM-dd').format(now);

      for (final t in List<Map<String, dynamic>>.from(resp)) {
        final id = t['id']?.toString() ?? '';
        final referencia = t['referencia']?.toString() ?? 'Tanque';
        final capacidadeVal =
            num.tryParse(t['capacidade']?.toString() ?? '0')?.toDouble() ?? 0.0;
        final produtoNome =
            (t['produtos'] is Map) ? (t['produtos']['nome']?.toString()) : null;

        double estoqueInicial = 0.0;
        try {
          final rpc = await supabase.rpc('fn_estoque_inicial_tanque', params: {
            'p_tanque_id': id,
            'p_data': dataStr,
          });
          if (rpc != null) {
            estoqueInicial = (rpc as num).toDouble();
          }
        } catch (_) {
          estoqueInicial = 0.0;
        }

        double entradas = 0.0;
        double saidas = 0.0;

        try {
          final movsAgg = await supabase
              .from('movimentacoes_tanque')
              .select('sum(entrada_vinte) as e, sum(saida_vinte) as s')
              .eq('tanque_id', id)
              .gte('data_mov', inicioDiaIso)
              .lte('data_mov', agoraIso)
              .maybeSingle();

          if (movsAgg != null) {
            final eVal = movsAgg['e'];
            final sVal = movsAgg['s'];

            entradas = eVal is num
                ? eVal.toDouble()
                : double.tryParse(eVal?.toString() ?? '0') ?? 0.0;

            saidas = sVal is num
                ? sVal.toDouble()
                : double.tryParse(sVal?.toString() ?? '0') ?? 0.0;
          }
        } catch (_) {
          entradas = 0.0;
          saidas = 0.0;
        }

        final estoqueAtualCalc = estoqueInicial + entradas - saidas;

        // 🔹 Agora filtra no próprio Supabase apenas movimentações do dia atual
        final detalhesResp = await supabase
            .from('movimentacoes_tanque')
            .select(
                'data_mov, descricao, cliente, entrada_vinte, saida_vinte')
            .eq('tanque_id', id)
            .gte('data_mov', inicioDiaIso)
            .lte('data_mov', agoraIso)
            .order('data_mov', ascending: false)
            .limit(20);

        final List<DetalheTanque> detalhes = [];

        // Abertura permanece igual
        detalhes.add(DetalheTanque(
          produto: produtoNome ?? 'Saldo Atual',
          litros: estoqueAtualCalc,
          data: DateFormat('dd/MM/yyyy HH:mm').format(now),
          tipo: estoqueAtualCalc >= 0 ? 'entrada' : 'saida',
        ));

        for (final d in List<Map<String, dynamic>>.from(detalhesResp)) {
          final eVal = d['entrada_vinte'];
          final sVal = d['saida_vinte'];

          double entrada = eVal is num
              ? eVal.toDouble()
              : double.tryParse(eVal?.toString() ?? '0') ?? 0.0;

          double saida = sVal is num
              ? sVal.toDouble()
              : double.tryParse(sVal?.toString() ?? '0') ?? 0.0;

          final isEntrada = entrada > 0;
          final litros = isEntrada ? entrada : -saida;

          final descricao = (d['cliente']?.toString().isNotEmpty == true)
              ? d['cliente'].toString()
              : (d['descricao']?.toString() ?? '');

          final dataFmt = () {
            try {
              final dt = DateTime.parse(d['data_mov']);
              return DateFormat('dd/MM/yyyy HH:mm').format(dt);
            } catch (_) {
              return d['data_mov']?.toString() ?? '';
            }
          }();

          detalhes.add(DetalheTanque(
            produto: descricao,
            litros: litros,
            data: dataFmt,
            tipo: isEntrada ? 'entrada' : 'saida',
          ));
        }

        lista.add(DadosTanque(
          id: id,
          nome:
              '$referencia${produtoNome != null ? ' - $produtoNome' : ''}',
          capacidadeTotal: capacidadeVal,
          detalhes: detalhes,
        ));
      }

      final ordered = lista.reversed.toList();

      setState(() {
        tanques = ordered;
        if (tanqueSelecionadoIndex >= tanques.length) {
          tanqueSelecionadoIndex = 0;
        }
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        tanques = [];
        _carregando = false;
      });
      debugPrint('Erro ao carregar tanques: $e');
    }
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
      body: _carregando
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          : (tanques.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.storage, size: 64, color: Color(0xFF8F9BB3)),
                        SizedBox(height: 12),
                        Text('Nenhum tanque encontrado', style: TextStyle(fontSize: 16, color: Color(0xFF222B45))),
                        SizedBox(height: 6),
                        Text('Verifique a seleção do terminal ou tente recarregar.', style: TextStyle(fontSize: 13, color: Color(0xFF8F9BB3))),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Menu de navegação superior com os tanques
                    _construirMenuTanques(),
                    // Conteúdo principal com detalhes do tanque selecionado
                    Expanded(
                      child: _construirDetalheTanque(),
                    ),
                  ],
                )),
    );
  }

  /// ===============================
  /// MENU SUPERIOR DE NAVEGAÇÃO COM EFEITO HOVER
  /// ===============================
  Widget _construirMenuTanques() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Adiciona padding vertical extra para evitar "empurrar" ao fazer hover
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: List.generate(tanques.length, (index) {
                final tanque = tanques[index];
                final isSelected = tanqueSelecionadoIndex == index;
                final isHovered = _hoverIndex == index;

                return Padding(
                  padding: EdgeInsets.only(right: index < tanques.length - 1 ? 12 : 0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setState(() {
                        _hoverIndex = index;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        _hoverIndex = null;
                      });
                    },
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          tanqueSelecionadoIndex = index;
                        });
                      },
                      child: SizedBox(
                        height: 62, // altura aumentada para acomodar o scale sem overflow
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                            transform: isHovered && !isSelected
                              ? (Matrix4.identity()..scale(1.0, 1.08))
                              : Matrix4.identity(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF222B45)
                                : (isHovered
                                    ? const Color(0xFFE8EAF2)
                                    : const Color(0xFFF0F1F6)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF222B45)
                                  : (isHovered
                                      ? const Color(0xFF3366FF)
                                      : const Color(0xFFE0E3EB)),
                              width: isHovered && !isSelected ? 2.0 : 1.5,
                            ),
                            boxShadow: isHovered && !isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF3366FF).withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tanque.nome.split(' - ').first,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFF8F9FA)
                                      : const Color(0xFF222B45),
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected || isHovered ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (tanque.nome.contains(' - '))
                                Text(
                                  tanque.nome.split(' - ').last,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFBFC8E6)
                                        : (isHovered
                                            ? const Color(0xFF3366FF)
                                            : const Color(0xFF8F9BB3)),
                                    fontSize: 10,
                                    fontWeight: isHovered ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8), // Espaço entre botões e linha divisória
          Container(
            height: 1,
            color: const Color(0xFFE0E3EB),
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBFC8E6).withOpacity(0.08),
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
                    '${formatNumber(tanque.estoqueAtual * 1000)} L',
                    const Color(0xFF3366FF),
                  ),
                  const SizedBox(width: 20),
                  _construirInfoMini(
                    'Capacidade',
                    '${formatNumber(tanque.capacidadeTotal * 1000)} L',
                    const Color(0xFFFFA000),
                  ),
                  const SizedBox(width: 20),
                  _construirInfoMini(
                    'Espaço Livre',
                    '${formatNumber((tanque.capacidadeTotal - tanque.estoqueAtual) * 1000)} L',
                    const Color(0xFF00B686),
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
                '${formatPercent(percentual)}%',
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
  
  Widget _construirIndicadorNivel(DadosTanque tanque, double percentual) {
    // Valores em litros (exemplo - estes valores devem vir do modelo de dados)
    final double lastroMinimo = tanque.capacidadeTotal * 0.15; // 15% de lastro mínimo
    final double produtoDisponivel = tanque.estoqueAtual - lastroMinimo;
    final double espacoLivre = tanque.capacidadeTotal - tanque.estoqueAtual;
    
    // Cálculo das proporções para a barra
    final double proporcaoLastro = (lastroMinimo / tanque.capacidadeTotal).clamp(0, 1);
    final double proporcaoProduto = (produtoDisponivel / tanque.capacidadeTotal).clamp(0, 1);
    final double proporcaoEspaco = (espacoLivre / tanque.capacidadeTotal).clamp(0, 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBFC8E6).withOpacity(0.08),
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
          
          // Barra de progresso personalizada com 3 cores
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 30,
              child: Row(
                children: [
                  // Lastro do tanque (vermelho)
                  if (proporcaoLastro > 0)
                    Expanded(
                      flex: (proporcaoLastro * 1000).toInt(),
                      child: Container(
                        color: const Color(0xFFFF3D71), // Vermelho
                          child: Center(
                          child: Text(
                            '${formatNumber(lastroMinimo * 1000)} L',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // Produto disponível (azul)
                  if (proporcaoProduto > 0)
                    Expanded(
                      flex: (proporcaoProduto * 1000).toInt(),
                      child: Container(
                        color: const Color(0xFF3366FF), // Azul
                          child: Center(
                          child: Text(
                            '${formatNumber(produtoDisponivel * 1000)} L',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // Espaço livre (cinza)
                  if (proporcaoEspaco > 0)
                    Expanded(
                      flex: (proporcaoEspaco * 1000).toInt(),
                      child: Container(
                        color: const Color(0xFFE0E3EB), // Cinza
                          child: Center(
                          child: Text(
                            '${formatNumber(espacoLivre * 1000)} L',
                            style: const TextStyle(
                              color: Color(0xFF222B45),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Legenda das cores
          Row(
            children: [
              _construirLegenda('Lastro', const Color(0xFFFF3D71)),
              const SizedBox(width: 16),
              _construirLegenda('Produto', const Color(0xFF3366FF)),
              const SizedBox(width: 16),
              _construirLegenda('Livre', const Color(0xFFE0E3EB)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Informações detalhadas
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _construirInfoBarra(
                  'Lastro Mínimo',
                  '${formatNumber(lastroMinimo * 1000)} L',
                  const Color(0xFFFF3D71),
                ),
                _construirInfoBarra(
                  'Produto Disponível',
                  '${formatNumber(produtoDisponivel * 1000)} L',
                  const Color(0xFF3366FF),
                ),
                _construirInfoBarra(
                  'Espaço Livre',
                  '${formatNumber(espacoLivre * 1000)} L',
                  const Color(0xFF8F9BB3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget auxiliar para legenda
  Widget _construirLegenda(String texto, Color cor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8F9BB3),
          ),
        ),
      ],
    );
  }

  /// Widget auxiliar para informações da barra
  Widget _construirInfoBarra(String label, String valor, Color cor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8F9BB3),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }
  
  Widget _construirTabelaDetalhes(DadosTanque tanque) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBFC8E6).withOpacity(0.08),
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
            decoration: const BoxDecoration(
              color: Color(0xFF222B45),
              borderRadius: BorderRadius.only(
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
                    'Entrada',
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
                    'Saída',
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
            final isAbertura = index == 0;

            // Define o texto da descrição
            String textoDescricao;
            String textoTipo;

            if (isAbertura) {
              // Primeira linha (saldo atual) - mostra "Abertura" e sem tipo
              textoDescricao = "Abertura";
              textoTipo = "";
            } else {
              textoDescricao = detalhe.produto;
              textoTipo = isEntrada ? 'Entrada' : 'Saída';
            }

            return Container(
              color: isAlternado ? const Color(0xFFF0F1F6) : const Color(0xFFF8F9FA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isAbertura
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8FA),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF00B686)),
                                ),
                                child: Text(
                                  textoDescricao,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF00B686),
                                  ),
                                ),
                              )
                            : Text(
                                textoDescricao,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF222B45),
                                ),
                              ),
                        if (textoTipo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            textoTipo,
                            style: TextStyle(
                              fontSize: 11,
                              color: isEntrada ? const Color(0xFF00B686) : const Color(0xFFFF3D71),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      isEntrada ? '+ ${formatNumber(detalhe.litros.abs())}' : '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: const Color(0xFF00B686),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      !isEntrada ? '${formatNumber(detalhe.litros.abs())}' : '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: const Color(0xFFFF3D71),
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
                      color: isEntrada ? const Color(0xFF00B686) : const Color(0xFFFF3D71),
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

// Helpers de formatação (ponto de milhar para pt_BR)
final NumberFormat _fmtInteiro = NumberFormat('#,##0', 'pt_BR');
final NumberFormat _fmtUmaCasa = NumberFormat('#,##0.0', 'pt_BR');

String formatNumber(num value) => _fmtInteiro.format(value);
String formatPercent(double value) => _fmtUmaCasa.format(value);