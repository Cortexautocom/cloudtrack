import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'estoque_tanque.dart';

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

  @override
  void initState() {
    super.initState();
    _carregarDadosTanques();
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
          .select('id, referencia, capacidade, lastro, produtos (nome)')
          .eq('terminal_id', widget.terminalSelecionadoId!)
          .order('referencia');

      final List<DadosTanque> lista = [];
      final now = DateTime.now();
      final dataStr = DateFormat('yyyy-MM-dd').format(now);

      for (final t in List<Map<String, dynamic>>.from(resp)) {
        final id = t['id'].toString();
        final referencia = t['referencia']?.toString() ?? 'Tanque';
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
          nome: referencia,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirCardInformacoesAlterar(tanque, percentual),
          const SizedBox(height: 20),
          _construirIndicadorNivel(tanque, percentual),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final tanque = tanques[tanqueSelecionadoIndex];
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EstoqueTanquePage(
                          tanqueId: tanque.id,
                          referenciaTanque: tanque.nome,
                          data: DateTime.now(),
                          onVoltar: () => Navigator.of(context).pop(),
                        ),
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

  Widget _construirCardInformacoesAlterar(
      DadosTanque tanque, double percentual) {

    final double capacidade = tanque.capacidadeTotal;
    final double estoqueAtual = tanque.estoqueAtual.clamp(0, capacidade);
    final double lastro = tanque.lastro.clamp(0, capacidade);
    final double estoqueDisponivel =
        (estoqueAtual - lastro).clamp(0, capacidade);
    final double espacoLivre =
        (capacidade - estoqueAtual).clamp(0, capacidade);

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

              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                      _construirInfoMini(
                        'Capacidade',
                        '${formatNumber(capacidade)} L',
                        const Color.fromARGB(255, 69, 69, 69),
                      ),
                      _construirInfoMini(
                        'Estoque Atual',
                        '${formatNumber(estoqueAtual)} L',
                        const Color(0xFF6A1B9A),
                      ),
                      _construirInfoMini(
                        'Estoque Disponível',
                        '${formatNumber(estoqueDisponivel)} L',
                        const Color(0xFF00B686),
                      ),
                      _construirInfoMini(
                        'Espaço Livre',
                        '${formatNumber(espacoLivre)} L',
                        const Color(0xFF424242),
                      ),
                ],
              ),
            ],
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Percentual ocupado',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8F9BB3),
                ),
              ),
              const SizedBox(height: 8),
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
        ],
      ),
    );
  }
  
  Widget _construirIndicadorNivel(DadosTanque tanque, double percentual) {
    final double capacidade = tanque.capacidadeTotal;
    final double estoque = tanque.estoqueAtual.clamp(0, capacidade);
    final double lastro = tanque.lastro.clamp(0, capacidade);
    final double produtoDisponivel =
        (estoque - lastro).clamp(0, capacidade);
    final double espacoLivre =
        (capacidade - estoque).clamp(0, capacidade);
    final double propLastro =
        capacidade > 0 ? (lastro / capacidade).clamp(0, 1) : 0;
    final double propProduto =
        capacidade > 0 ? (produtoDisponivel / capacidade).clamp(0, 1) : 0;
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
              height: 34,
              child: Builder(builder: (context) {
                const int scale = 1000;
                final int flexLastro = (propLastro * scale).toInt();
                final int flexProduto = (propProduto * scale).toInt();
                final int flexEspaco = (propEspaco * scale).toInt();
                const int minFlexToShow = 20;

                return Row(
                  children: [
                    if (propLastro > 0)
                      Expanded(
                        flex: flexLastro,
                        child: Container(
                          color: const Color(0xFFFF3D71),
                          alignment: Alignment.center,
                          child: flexLastro >= minFlexToShow
                              ? Text(
                                  formatNumber(lastro),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    if (propProduto > 0)
                      Expanded(
                        flex: flexProduto,
                        child: Container(
                          color: const Color(0xFF00B686),
                          alignment: Alignment.center,
                          child: flexProduto >= minFlexToShow
                              ? Text(
                                  formatNumber(produtoDisponivel),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    if (propEspaco > 0)
                      Expanded(
                        flex: flexEspaco,
                        child: Container(
                          color: const Color(0xFFE0E3EB),
                          alignment: Alignment.center,
                          child: flexEspaco >= minFlexToShow
                              ? Text(
                                  formatNumber(espacoLivre),
                                  style: const TextStyle(
                                    color: Color(0xFF222B45),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              _legendaItem(const Color(0xFFFF3D71), "Lastro"),
              const SizedBox(width: 14),
              _legendaItem(const Color(0xFF00B686), "Estoque Disponível"),
              const SizedBox(width: 14),
              _legendaItem(const Color(0xFFE0E3EB), "Espaço Livre"),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _legendaItem(Color cor, String texto) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(2),
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

  Widget _construirInfoMini(String label, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          textAlign: TextAlign.center,
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

final NumberFormat _fmtInteiro = NumberFormat('#,##0', 'pt_BR');
final NumberFormat _fmtUmaCasa = NumberFormat('#,##0.0', 'pt_BR');

String formatNumber(num value) => _fmtInteiro.format(value);
String formatPercent(double value) => _fmtUmaCasa.format(value);