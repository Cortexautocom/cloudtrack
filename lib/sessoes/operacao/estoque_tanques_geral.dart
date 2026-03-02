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
  final double lastro;
  final List<DetalheTanque> detalhes;

  DadosTanque({
    required this.id,
    required this.nome,
    required this.capacidadeTotal,
    required this.lastro,
    required this.detalhes,
  });

  double get estoqueAtual {
    if (detalhes.isEmpty) return 0;
    // A primeira posição sempre é a Abertura (saldo real calculado)
    return detalhes.first.litros.clamp(0, capacidadeTotal);
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
    setState(() => _carregando = true);

    if (widget.filialSelecionadaId == null) {
      setState(() {
        tanques = [];
        _carregando = false;
      });
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      final resp = await supabase
          .from('tanques')
          .select('id, referencia, capacidade, lastro, produtos (nome)')
          .eq('terminal_id', widget.filialSelecionadaId!)
          .order('referencia');

      final List<DadosTanque> lista = [];

      final now = DateTime.now();
      final dataStr = DateFormat('yyyy-MM-dd').format(now);

      debugPrint("\n===== INÍCIO CARGA TANQUES =====");

      for (final t in List<Map<String, dynamic>>.from(resp)) {
        final id = t['id'].toString();
        final referencia = t['referencia']?.toString() ?? 'Tanque';

        // 🔥 Agora vem como numeric direto
        final capacidadeVal = (t['capacidade'] as num).toDouble();

        debugPrint("\n--- TANQUE $referencia ---");
        debugPrint("Capacidade (numeric): $capacidadeVal L");

        double estoqueInicial = 0.0;

        try {
          final rpc = await supabase.rpc(
            'fn_estoque_inicial_tanque',
            params: {
              'p_tanque_id': id,
              'p_data': dataStr,
            },
          );

          estoqueInicial = (rpc as num?)?.toDouble() ?? 0.0;
        } catch (e) {
          debugPrint("Erro RPC estoque inicial: $e");
        }

        debugPrint("Estoque Inicial: $estoqueInicial L");

        final detalhes = [
          DetalheTanque(
            produto: "Saldo Atual",
            litros: estoqueInicial,
            data: DateFormat('dd/MM/yyyy HH:mm').format(now),
            tipo: estoqueInicial >= 0 ? 'entrada' : 'saida',
          ),
        ];

        final lastroVal = (t['lastro'] as num?)?.toDouble() ?? 0.0;
            
        lista.add(DadosTanque(
          id: id,
          nome: referencia,
          capacidadeTotal: capacidadeVal,
          lastro: lastroVal,
          detalhes: detalhes,
        ));
      }

      debugPrint("\n===== FIM CARGA TANQUES =====\n");

      setState(() {
        tanques = lista;
        tanqueSelecionadoIndex = 0;
        _carregando = false;
      });
    } catch (e) {
      debugPrint("ERRO GERAL: $e");
      setState(() {
        tanques = [];
        _carregando = false;
      });
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

  Widget _construirMenuTanques() {
    final tanquesInvertidos = tanques.reversed.toList();

    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: List.generate(tanquesInvertidos.length, (index) {
                final tanque = tanquesInvertidos[index];

                // 🔥 Precisamos mapear o índice invertido para o índice real
                final realIndex = tanques.length - 1 - index;

                final isSelected = tanqueSelecionadoIndex == realIndex;
                final isHovered = _hoverIndex == realIndex;

                return Padding(
                  padding: EdgeInsets.only(
                      right: index < tanquesInvertidos.length - 1 ? 12 : 0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setState(() {
                        _hoverIndex = realIndex;
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
                          tanqueSelecionadoIndex = realIndex;
                        });
                      },
                      child: SizedBox(
                        height: 62,
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
                                      color: const Color(0xFF3366FF)
                                          .withOpacity(0.2),
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
                                  fontWeight: isSelected || isHovered
                                      ? FontWeight.w600
                                      : FontWeight.w500,
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
                                    fontWeight: isHovered
                                        ? FontWeight.w600
                                        : FontWeight.w400,
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
          const SizedBox(height: 8),
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
                    '${formatNumber(tanque.estoqueAtual)} L',
                    const Color(0xFF3366FF),
                  ),
                  const SizedBox(width: 20),
                  _construirInfoMini(
                    'Capacidade',
                    '${formatNumber(tanque.capacidadeTotal)} L',
                    const Color(0xFFFFA000),
                  ),
                  const SizedBox(width: 20),
                  _construirInfoMini(
                    'Espaço Livre',
                    '${formatNumber((tanque.capacidadeTotal - tanque.estoqueAtual))} L',
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
    final double capacidade = tanque.capacidadeTotal;
    final double estoque = tanque.estoqueAtual.clamp(0, capacidade);
    final double lastro = tanque.lastro.clamp(0, capacidade);

    final double produtoUtilizavel =
        (estoque - lastro).clamp(0, capacidade);

    final double espacoLivre =
        (capacidade - estoque).clamp(0, capacidade);

    final double propLastro =
        capacidade > 0 ? (lastro / capacidade).clamp(0, 1) : 0;

    final double propProduto =
        capacidade > 0 ? (produtoUtilizavel / capacidade).clamp(0, 1) : 0;

    final double propEspaco =
        capacidade > 0 ? (espacoLivre / capacidade).clamp(0, 1) : 0;

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
            'Nível Real do Tanque',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [

                  // 🔴 LASTRO (vermelho)
                  if (propLastro > 0)
                    Expanded(
                      flex: (propLastro * 1000).toInt(),
                      child: Container(
                        color: const Color(0xFFFF3D71),
                      ),
                    ),

                  // 🔵 PRODUTO UTILIZÁVEL (azul)
                  if (propProduto > 0)
                    Expanded(
                      flex: (propProduto * 1000).toInt(),
                      child: Container(
                        color: const Color(0xFF3366FF),
                      ),
                    ),

                  // ⚪ ESPAÇO LIVRE (cinza)
                  if (propEspaco > 0)
                    Expanded(
                      flex: (propEspaco * 1000).toInt(),
                      child: Container(
                        color: const Color(0xFFE0E3EB),
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