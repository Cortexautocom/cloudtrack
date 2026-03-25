import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'estoque_tanque.dart';
import 'estoque_tanque_mensal.dart';

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
    return detalhes.first.litros.clamp(0, capacidadeTotal);
  }
  
  double get percentualPreenchimento =>
      (estoqueAtual / capacidadeTotal * 100).clamp(0, 100);
}

class DetalheTanque {
  final String produto;
  final double litros;
  final String data;
  final String tipo;

  DetalheTanque({
    required this.produto,
    required this.litros,
    required this.data,
    required this.tipo,
  });
}

class EstoquePorTanquePage extends StatefulWidget {
  final VoidCallback? onVoltar;
  final String? terminalSelecionadoId;
  
  const EstoquePorTanquePage({
    super.key,
    this.onVoltar,
    this.terminalSelecionadoId,
  });

  @override
  State<EstoquePorTanquePage> createState() => _EstoquePorTanquePageState();
}

class _EstoquePorTanquePageState extends State<EstoquePorTanquePage> {
  List<DadosTanque> tanques = [];
  bool _carregando = true;
  int tanqueSelecionadoIndex = 0;
  int? _hoverIndex;
  String? _nomeTerminal;
  bool _mostrarPrevisto = false;
  bool _usarMetrosCubicos = false;
  String? _hoverSwitchOption;
  String? _hoverUnitOption;

  @override
  void initState() {
    super.initState();
    _carregarDadosTanques();
    _carregarNomeTerminal();
  }

  Future<void> _carregarNomeTerminal() async {
    if (widget.terminalSelecionadoId == null) return;
    try {
      final resp = await Supabase.instance.client
          .from('terminais')
          .select('nome')
          .eq('id', widget.terminalSelecionadoId!)
          .maybeSingle();
      if (resp != null && mounted) {
        setState(() {
          _nomeTerminal = resp['nome']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _carregarDadosTanques() async {
    setState(() => _carregando = true);

    if (widget.terminalSelecionadoId == null) {
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
          .select('id, referencia, capacidade, lastro, produtos(nome)')
          .eq('terminal_id', widget.terminalSelecionadoId!)
          .order('referencia');

      final List<DadosTanque> lista = [];
      final now = DateTime.now();
      final dataStr = DateFormat('yyyy-MM-dd').format(now);

      for (final t in List<Map<String, dynamic>>.from(resp)) {
        final id = t['id'].toString();
        final referencia = t['referencia']?.toString() ?? 'Tanque';
        final produtoNome = t['produtos']?['nome']?.toString();
        final nomeCompleto = produtoNome != null ? '$referencia - $produtoNome' : referencia;
        final capacidadeVal = (t['capacidade'] as num).toDouble();

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
          estoqueInicial = 0.0;
        }

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
          nome: nomeCompleto,
          capacidadeTotal: capacidadeVal,
          lastro: lastroVal,
          detalhes: detalhes,
        ));
      }

      setState(() {
        tanques = lista;
        tanqueSelecionadoIndex = lista.isNotEmpty ? lista.length - 1 : 0;
        _carregando = false;
      });
    } catch (e) {
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
                    _construirMenuTanques(),
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
                                ? const Color(0xFF0D47A1)
                                : (isHovered
                                    ? const Color(0xFFE8EAF2)
                                    : const Color(0xFFF0F1F6)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0D47A1)
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
                                      : const Color(0xFF0D47A1),
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

  Widget _construirDetalheTanque() {
    final tanque = tanques[tanqueSelecionadoIndex];
    final percentual = tanque.percentualPreenchimento;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirIndicadorNivelIlustrativo(tanque, percentual),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final tanque = tanques[tanqueSelecionadoIndex];
                    final terminalId = widget.terminalSelecionadoId ?? '';
                    final nomeTerminal = _nomeTerminal ?? '';

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      enableDrag: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => _SelecaoTipoVisualizacaoEstoqueBottomSheet(
                        tanqueId: tanque.id,
                        referenciaTanque: tanque.nome.split(' - ').first,
                        terminalId: terminalId,
                        nomeTerminal: nomeTerminal,
                        onVoltar: () {
                          _carregarDadosTanques();
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text(
                    'Ver movimentação do tanque',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
   
  // Novo widget com tanque ilustrativo
  Widget _construirIndicadorNivelIlustrativo(DadosTanque tanque, double percentual) {
    final double capacidade = tanque.capacidadeTotal;
    final double estoque = tanque.estoqueAtual.clamp(0, capacidade);
    final double lastro = tanque.lastro.clamp(0, capacidade);
    final double produtoDisponivel = (estoque - lastro).clamp(0, capacidade);
    final double espacoLivre = (capacidade - estoque).clamp(0, capacidade);
    
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6), // Alinhamento com o topo do primeiro switch
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: 'Nível do Tanque'),
                        TextSpan(
                          text: ' - ${tanque.nome}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 170, // Largura fixa para ambos os switches
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _mostrarPrevisto = !_mostrarPrevisto;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE4E9F2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoverSwitchOption = "atual"),
                                  onExit: (_) => setState(() => _hoverSwitchOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _mostrarPrevisto = false),
                                    child: _buildSwitchOption("Nível atual", !_mostrarPrevisto, _hoverSwitchOption == "atual"),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoverSwitchOption = "previsto"),
                                  onExit: (_) => setState(() => _hoverSwitchOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _mostrarPrevisto = true),
                                    child: _buildSwitchOption("Previsto", _mostrarPrevisto, _hoverSwitchOption == "previsto", isPrevistoSide: true),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _usarMetrosCubicos = !_usarMetrosCubicos;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF1F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE4E9F2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoverUnitOption = "m3"),
                                  onExit: (_) => setState(() => _hoverUnitOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _usarMetrosCubicos = true),
                                    child: _buildSwitchOption("metros³", _usarMetrosCubicos, _hoverUnitOption == "m3"),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoverUnitOption = "litros"),
                                  onExit: (_) => setState(() => _hoverUnitOption = null),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _usarMetrosCubicos = false),
                                    child: _buildSwitchOption("Litros", !_usarMetrosCubicos, _hoverUnitOption == "litros", isPrevistoSide: true),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Tanque ilustrativo com informações ao lado
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Legenda de cores à esquerda
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendaItem(const Color(0xFFE0E3EB), "Espaço Livre"),
                  const SizedBox(height: 12),
                  _legendaItem(const Color(0xFF00B686), "Estoque"),
                  const SizedBox(height: 12),
                  _legendaItem(const Color(0xFFFF3D71), "Lastro"),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Center(
                  child: SizedBox(
                    width: 260,
                    height: 300,
                    child: TankIllustration(
                      percentual: percentual / 100,
                      lastroPercentual: capacidade > 0 ? (lastro / capacidade).clamp(0, 1) : 0,
                      estoqueAtual: estoque,
                      capacidade: capacidade,
                      produtoDisponivel: produtoDisponivel,
                      espacoLivre: espacoLivre,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _construirInfoMiniLateral(
                      'Estoque Atual',
                      '${formatNumber(estoque)} L',
                      const Color(0xFF6A1B9A),
                    ),
                    const SizedBox(height: 16),
                    _construirInfoMiniLateral(
                      'Estoque Disponível',
                      '${formatNumber(produtoDisponivel)} L',
                      const Color(0xFF00B686),
                    ),
                    const SizedBox(height: 16),
                    _construirInfoMiniLateral(
                      'Espaço Livre',
                      '${formatNumber(espacoLivre)} L',
                      const Color(0xFF424242),
                    ),
                    const SizedBox(height: 16),
                    _construirInfoMiniLateral(
                      'Capacidade',
                      '${formatNumber(capacidade)} L',
                      const Color.fromARGB(255, 69, 69, 69),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _legendaItem(Color cor, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }  

  Widget _construirInfoMiniLateral(String label, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchOption(String text, bool isSelected, bool isHovered, {bool isPrevistoSide = false}) {
    Color activeBlue = const Color(0xFF3366FF);
    
    Color activeColor = activeBlue;
    Color textColor = isSelected 
        ? Colors.white
        : const Color(0xFF8F9BB3);
    
    Color hoverColor = activeBlue.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? activeColor 
            : (isHovered ? hoverColor : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: activeBlue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }  
}

final NumberFormat _fmtInteiro = NumberFormat('#,##0', 'pt_BR');
final NumberFormat _fmtUmaCasa = NumberFormat('#,##0.0', 'pt_BR');

String formatNumber(num value) => _fmtInteiro.format(value);
String formatPercent(double value) => _fmtUmaCasa.format(value);

// Widget do Tanque Ilustrativo
class TankIllustration extends StatefulWidget {
  final double percentual;
  final double lastroPercentual;
  final double estoqueAtual;
  final double capacidade;
  final double produtoDisponivel;
  final double espacoLivre;

  const TankIllustration({
    Key? key,
    required this.percentual,
    required this.lastroPercentual,
    required this.estoqueAtual,
    required this.capacidade,
    required this.produtoDisponivel,
    required this.espacoLivre,
  }) : super(key: key);

  @override
  State<TankIllustration> createState() => _TankIllustrationState();
}

class _TankIllustrationState extends State<TankIllustration> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _liquidAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _liquidAnimation = Tween<double>(begin: 0, end: widget.percentual).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(TankIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentual != widget.percentual) {
      _liquidAnimation = Tween<double>(
        begin: _liquidAnimation.value,
        end: widget.percentual,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _liquidAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: TankPainter(
            percentual: _liquidAnimation.value,
            lastroPercentual: widget.lastroPercentual,
            estoqueAtual: widget.estoqueAtual,
            capacidade: widget.capacidade,
            produtoDisponivel: widget.produtoDisponivel,
            espacoLivre: widget.espacoLivre,
          ),
          size: const Size(280, 320),
        );
      },
    );
  }
}

class TankPainter extends CustomPainter {
  final double percentual;
  final double lastroPercentual;
  final double estoqueAtual;
  final double capacidade;
  final double produtoDisponivel;
  final double espacoLivre;

  TankPainter({
    required this.percentual,
    required this.lastroPercentual,
    required this.estoqueAtual,
    required this.capacidade,
    required this.produtoDisponivel,
    required this.espacoLivre,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tankWidth = size.width * 0.65;
    final tankHeight = size.height * 0.75;
    final tankX = (size.width - tankWidth) / 2;
    final tankY = size.height * 0.1;
    
    // Desenha a base do tanque (suporte)
    final basePaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;
    
    final basePath = Path()
      ..moveTo(tankX - 10, tankY + tankHeight)
      ..lineTo(tankX + tankWidth + 10, tankY + tankHeight)
      ..lineTo(tankX + tankWidth + 5, tankY + tankHeight + 15)
      ..lineTo(tankX - 5, tankY + tankHeight + 15)
      ..close();
    canvas.drawPath(basePath, basePaint);
    
    // Desenha o corpo do tanque (retângulo com bordas arredondadas)
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tankX, tankY, tankWidth, tankHeight),
      const Radius.circular(16),
    );
    
    final tankBorderPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final tankFillPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(tankRect, tankFillPaint);
    canvas.drawRRect(tankRect, tankBorderPaint);
    
    // Desenha o topo do tanque (tampa)
    final topPaint = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.fill;
    
    final topRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tankX - 5, tankY - 8, tankWidth + 10, 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(topRect, topPaint);
    
    // Desenha a válvula no topo
    final valvePaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(tankX + tankWidth / 2, tankY - 5),
      6,
      valvePaint,
    );
    
    // Desenha o nível do líquido (estoque disponível)
    final liquidHeight = tankHeight * percentual;
    if (liquidHeight > 0) {
      final liquidRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          tankX,
          tankY + tankHeight - liquidHeight,
          tankWidth,
          liquidHeight,
        ),
        const Radius.circular(12),
      );
      
      final liquidPaint = Paint()
        ..color = _getLiquidColor(percentual)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(liquidRect, liquidPaint);
      
      // Adiciona efeito de brilho no líquido
      final shinePaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      final shineRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          tankX + 5,
          tankY + tankHeight - liquidHeight,
          tankWidth - 10,
          liquidHeight * 0.3,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(shineRect, shinePaint);
    }
    
    // Desenha a linha do lastro
    if (lastroPercentual > 0 && lastroPercentual < 1) {
      final lastroY = tankY + tankHeight - (tankHeight * lastroPercentual);
      final lastroPaint = Paint()
        ..color = const Color(0xFFFF3D71)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(tankX + 5, lastroY),
        Offset(tankX + tankWidth - 5, lastroY),
        lastroPaint,
      );
      
      // Adiciona pequenos marcadores na linha do lastro
      final markerPaint = Paint()
        ..color = const Color(0xFFFF3D71)
        ..style = PaintingStyle.fill;
      
      for (double i = -3; i <= 3; i++) {
        canvas.drawCircle(
          Offset(tankX + tankWidth / 2 + (i * 8), lastroY),
          2,
          markerPaint,
        );
      }
    }
    
    // Adiciona indicadores de nível nas laterais
    _drawLevelIndicators(canvas, tankX, tankY, tankWidth, tankHeight);
    
    // Adiciona textura metálica no tanque
    _drawMetalTexture(canvas, tankX, tankY, tankWidth, tankHeight);
    
    // Desenha o percentual acompanhando o nível do líquido
    _drawFloatingPercent(canvas, tankX, tankY, tankWidth, tankHeight, percentual);
  }
  
  Color _getLiquidColor(double percentual) {
    if (percentual >= 0.3) return const Color(0xFF00B686);
    if (percentual >= 0.15) return const Color(0xFFFFA000);
    return const Color(0xFFFF3D71);
  }
  
  void _drawLevelIndicators(Canvas canvas, double tankX, double tankY, double tankWidth, double tankHeight) {
    final markerPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    final textStyle = TextStyle(
      fontSize: 9,
      color: Colors.grey.shade600,
      fontWeight: FontWeight.w500,
    );
    
    for (int i = 0; i <= 4; i++) {
      final level = i / 4;
      final markerY = tankY + tankHeight - (tankHeight * level);
      final percentValue = (level * 100).round();
      
      // Marcadores na lateral esquerda
      canvas.drawLine(
        Offset(tankX - 8, markerY),
        Offset(tankX - 2, markerY),
        markerPaint,
      );
      
      // Marcadores na lateral direita
      canvas.drawLine(
        Offset(tankX + tankWidth + 2, markerY),
        Offset(tankX + tankWidth + 8, markerY),
        markerPaint,
      );
      
      // Texto dos percentuais
      final textSpan = TextSpan(
        text: '$percentValue%',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(tankX - 35, markerY - 6),
      );
    }
  }
  
  void _drawMetalTexture(Canvas canvas, double tankX, double tankY, double tankWidth, double tankHeight) {
    final texturePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    for (double i = tankX; i < tankX + tankWidth; i += 20) {
      final path = Path()
        ..moveTo(i, tankY)
        ..lineTo(i + 5, tankY + 5)
        ..lineTo(i + 5, tankY + tankHeight - 5)
        ..lineTo(i, tankY + tankHeight)
        ..close();
      canvas.drawPath(path, texturePaint);
    }
  }
  
  void _drawFloatingPercent(Canvas canvas, double tankX, double tankY, double tankWidth, double tankHeight, double percentual) {
    // Calcula a posição Y baseada no nível do líquido
    final liquidY = tankY + tankHeight - (tankHeight * percentual);
    
    // Texto do percentual
    final percentText = '${(percentual * 100).toInt()}%';
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: _getLiquidColor(percentual),
    );
    
    final textSpan = TextSpan(
      text: percentText,
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Posiciona à direita do tanque, alinhado com o topo do líquido
    // Adicionamos um pequeno deslocamento para não encostar na borda
    textPainter.paint(
      canvas,
      Offset(tankX + tankWidth + 12, liquidY - (textPainter.height / 2)),
    );

    // Opcional: Desenha uma pequena linha indicadora conectando o nível ao texto
    final linePaint = Paint()
      ..color = _getLiquidColor(percentual).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawLine(
      Offset(tankX + tankWidth, liquidY),
      Offset(tankX + tankWidth + 10, liquidY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) {
    return oldDelegate.percentual != percentual ||
           oldDelegate.lastroPercentual != lastroPercentual;
  }
}

class _SelecaoTipoVisualizacaoEstoqueBottomSheet extends StatefulWidget {
  final String tanqueId;
  final String referenciaTanque;
  final String terminalId;
  final String nomeTerminal;
  final VoidCallback onVoltar;

  const _SelecaoTipoVisualizacaoEstoqueBottomSheet({
    required this.tanqueId,
    required this.referenciaTanque,
    required this.terminalId,
    required this.nomeTerminal,
    required this.onVoltar,
  });

  @override
  State<_SelecaoTipoVisualizacaoEstoqueBottomSheet> createState() => _SelecaoTipoVisualizacaoEstoqueBottomSheetState();
}

class _SelecaoTipoVisualizacaoEstoqueBottomSheetState extends State<_SelecaoTipoVisualizacaoEstoqueBottomSheet> {
  bool _tipoDataEspecifica = true;
  bool _tipoMensal = false;
  bool _mostrarDetalhado = true;

  DateTime _dataSelecionada = DateTime.now();
  int _mesSelecionado = DateTime.now().month;
  int _anoSelecionado = DateTime.now().year;

  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _mesAnoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _atualizarDataController();
    _atualizarMesAnoController();
  }

  void _atualizarDataController() {
    _dataController.text = DateFormat('dd/MM/yyyy').format(_dataSelecionada);
  }

  void _atualizarMesAnoController() {
    _mesAnoController.text = '${_mesSelecionado.toString().padLeft(2, '0')}/${_anoSelecionado}';
  }

  Future<void> _selecionarData() async {
    DateTime tempDate = _dataSelecionada;
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF0D47A1), size: 24),
                        const SizedBox(width: 12),
                        const Text('Selecionar data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(), color: Colors.grey, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFF0D47A1)), onPressed: () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month - 1, tempDate.day); }); }),
                          Text('${_getNomeMes(tempDate.month)} ${tempDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                          IconButton(icon: const Icon(Icons.chevron_right, color: Color(0xFF0D47A1)), onPressed: () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month + 1, tempDate.day); }); }),
                        ],
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'].map((day) {
                        return Center(child: Text(day, style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)));
                      }).toList(),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 7,
                      childAspectRatio: 1.0,
                      children: _getDaysInMonth(tempDate).map((day) {
                        final isSelected = day != null && day == tempDate.day;
                        final isToday = day != null && day == DateTime.now().day && tempDate.month == DateTime.now().month && tempDate.year == DateTime.now().year;
                        return GestureDetector(
                          onTap: day != null ? () { setStateDialog(() { tempDate = DateTime(tempDate.year, tempDate.month, day); }); } : null,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: isSelected ? const Color(0xFF0D47A1) : isToday ? const Color(0x220D47A1) : Colors.transparent, shape: BoxShape.circle),
                            child: Center(child: Text(day != null ? day.toString() : '', style: TextStyle(color: isSelected ? Colors.white : isToday ? const Color(0xFF0D47A1) : Colors.black87, fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), style: TextButton.styleFrom(foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('CANCELAR')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempDate),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('SELECIONAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
        _tipoDataEspecifica = true;
        _tipoMensal = false;
        _atualizarDataController();
      });
    }
  }

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[mes - 1];
  }

  List<int?> _getDaysInMonth(DateTime date) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;
    List<int?> days = [];
    for (int i = 0; i < startOffset; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(i);
    }
    while (days.length < 42) {
      days.add(null);
    }
    return days;
  }

  Future<void> _selecionarMesAno() async {
    int tempMes = _mesSelecionado;
    int tempAno = _anoSelecionado;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Selecionar Mês/Ano',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: tempMes,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D47A1)),
                                  items: List.generate(12, (index) {
                                    final mes = index + 1;
                                    return DropdownMenuItem(
                                      value: mes,
                                      child: Text(
                                        _getNomeMes(mes),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    );
                                  }),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setStateDialog(() => tempMes = value);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: tempAno.toString(),
                              decoration: InputDecoration(
                                labelText: 'Ano',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final ano = int.tryParse(value);
                                if (ano != null && ano >= 2000 && ano <= 2100) {
                                  setStateDialog(() => tempAno = ano);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      InkWell(
                        onTap: () {
                          setState(() => _mostrarDetalhado = !_mostrarDetalhado);
                          setStateDialog(() {});
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: _mostrarDetalhado,
                              onChanged: (val) {
                                setState(() => _mostrarDetalhado = val ?? true);
                                setStateDialog(() {});
                              },
                              activeColor: const Color(0xFF0D47A1),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text('Mostrar detalhado', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFF0D47A1)),
                                foregroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pop(context);

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => EstoqueTanqueMensalPage(
                                      tanqueId: widget.tanqueId,
                                      referenciaTanque: widget.referenciaTanque,
                                      terminalId: widget.terminalId,
                                      nomeTerminal: widget.nomeTerminal,
                                      mes: tempMes,
                                      ano: tempAno,
                                      mostrarDetalhado: _mostrarDetalhado,
                                      onVoltar: () {
                                        Navigator.of(ctx).pop();
                                        widget.onVoltar();
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFF0D47A1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text('Confirmar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _visualizar() {
    if (!_tipoDataEspecifica && !_tipoMensal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um tipo de visualização'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context);

    if (_tipoDataEspecifica) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EstoqueTanquePage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            data: _dataSelecionada,
            onVoltar: () {
              Navigator.of(ctx).pop();
              widget.onVoltar();
            },
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => EstoqueTanqueMensalPage(
            tanqueId: widget.tanqueId,
            referenciaTanque: widget.referenciaTanque,
            terminalId: widget.terminalId,
            nomeTerminal: widget.nomeTerminal,
            mes: _mesSelecionado,
            ano: _anoSelecionado,
            mostrarDetalhado: _mostrarDetalhado,
            onVoltar: () {
              Navigator.of(ctx).pop();
              widget.onVoltar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'Selecionar Período',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _selecionarData,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _tipoDataEspecifica
                          ? const Color(0xFF0D47A1)
                          : Colors.grey.shade300,
                      width: _tipoDataEspecifica ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _tipoDataEspecifica
                        ? const Color(0xFF0D47A1).withOpacity(0.05)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _tipoDataEspecifica,
                        onChanged: (value) {
                          setState(() {
                            _tipoDataEspecifica = true;
                            _tipoMensal = false;
                          });
                        },
                        activeColor: const Color(0xFF0D47A1),
                      ),
                      const Expanded(
                        child: Text(
                          'Data específica',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _dataController.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: _selecionarMesAno,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _tipoMensal
                          ? const Color(0xFF0D47A1)
                          : Colors.grey.shade300,
                      width: _tipoMensal ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _tipoMensal
                        ? const Color(0xFF0D47A1).withOpacity(0.05)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _tipoMensal,
                        onChanged: (value) {
                          setState(() {
                            _tipoMensal = true;
                            _tipoDataEspecifica = false;
                          });
                        },
                        activeColor: const Color(0xFF0D47A1),
                      ),
                      const Expanded(
                        child: Text(
                          'Estoque mensal',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _mesAnoController.text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_tipoMensal)
                InkWell(
                  onTap: () => setState(() => _mostrarDetalhado = !_mostrarDetalhado),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _mostrarDetalhado,
                          onChanged: (val) => setState(() => _mostrarDetalhado = val ?? true),
                          activeColor: const Color(0xFF0D47A1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const Text('Mostrar detalhado', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF0D47A1)),
                        foregroundColor: const Color(0xFF0D47A1),
                      ),
                      child: const Text('Voltar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _visualizar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Visualizar'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  @override
  void dispose() {
    _dataController.dispose();
    _mesAnoController.dispose();
    super.dispose();
  }
}