import 'package:flutter/material.dart';

class CompactoFinalPage extends StatelessWidget {
  const CompactoFinalPage({super.key});

  static const double larguraArea = 0.60;
  static const double blocoLargura = 230;
  static const double blocoAltura = 165;
  static const double cellWidth = 44;

  /// 👇 ALTERE AQUI se quiser mudar a largura da coluna de nomes dos produtos
  static const double larguraNomeProduto = 56;

  /// 👇 ALTERE AQUI se quiser mudar a margem esquerda da página
  static const double margemEsquerdaPagina = 10;

  /// 👇 radius dos quadrados das filiais
  static const double radiusBloco = 6;

  /// 👇 radius dos campos numéricos
  static const double radiusCelula = 4;

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final hoje = DateTime.now();
    final data =
        "${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}";

    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      body: Padding(
        padding: const EdgeInsets.only(left: margemEsquerdaPagina),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: larguraTela * larguraArea,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(context, data),
                const SizedBox(height: 8),
                Expanded(
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: const [
                      CompactoBloco(
                        titulo: "JEQUIÉ",
                        linhas: [
                          ["G.A", "913", "150", "1063"],
                          ["S500-A", "544", "", ""],
                          ["S10-A", "612", "105", "717"],
                          ["A", "86", "125", "211"],
                          ["H", "499", "250", "749"],
                          ["B100", "", "", ""],
                        ],
                      ),
                      CompactoBloco(
                        titulo: "CANDEIAS",
                        linhas: [
                          ["G.A", "578", "357", "935"],
                          ["S500-A", "438", "178", "973"],
                          ["S10-A", "-128", "298", "311"],
                          ["A", "83", "124", "207"],
                          ["H", "79", "239", "318"],
                          ["B100", "", "", ""],
                        ],
                      ),
                      CompactoBloco(
                        titulo: "PETRONOL",
                        linhas: [
                          ["G.A", "", "", ""],
                          ["S500-A", "", "", ""],
                          ["S10-A", "", "", ""],
                          ["A", "2455", "", ""],
                          ["H", "0", "", ""],
                          ["B100", "", "", ""],
                        ],
                      ),
                      CompactoBloco(
                        titulo: "TEIXEIRA",
                        linhas: [
                          ["G.A", "86", "63", "149"],
                          ["S500-A", "41", "45", "86"],
                          ["S10-A", "40", "45", "85"],
                          ["A", "", "", ""],
                          ["H", "121", "", ""],
                          ["B100", "", "", ""],
                        ],
                      ),
                      CompactoBloco(
                        titulo: "ITABUNA",
                        linhas: [
                          ["G.A", "", "", ""],
                          ["S500-A", "184", "", ""],
                          ["S10-A", "134", "", ""],
                          ["A", "13", "", ""],
                          ["H", "40", "", ""],
                          ["B100", "", "", ""],
                        ],
                      ),
                      CompactoBloco(
                        titulo: "JANAÚBA",
                        linhas: [
                          ["G.A", "112", "63", "175"],
                          ["S500-A", "140", "", ""],
                          ["S10-A", "125", "", ""],
                          ["A", "124", "", ""],
                          ["H", "77", "", ""],
                          ["B100", "", "", ""],
                        ],
                      ),
                      CompactoBloco(titulo: "FILIAL 7", linhas: [
                        ["G.A", "", "", ""],
                        ["S500-A", "", "", ""],
                        ["S10-A", "", "", ""],
                        ["A", "", "", ""],
                        ["H", "", "", ""],
                        ["B100", "", "", ""]
                      ]),
                      CompactoBloco(titulo: "FILIAL 8", linhas: [
                        ["G.A", "", "", ""],
                        ["S500-A", "", "", ""],
                        ["S10-A", "", "", ""],
                        ["A", "", "", ""],
                        ["H", "", "", ""],
                        ["B100", "", "", ""]
                      ]),
                      CompactoBloco(titulo: "FILIAL 9", linhas: [
                        ["G.A", "", "", ""],
                        ["S500-A", "", "", ""],
                        ["S10-A", "", "", ""],
                        ["A", "", "", ""],
                        ["H", "", "", ""],
                        ["B100", "", "", ""]
                      ]),
                      CompactoBloco(titulo: "FILIAL 10", linhas: [
                        ["G.A", "", "", ""],
                        ["S500-A", "", "", ""],
                        ["S10-A", "", "", ""],
                        ["A", "", "", ""],
                        ["H", "", "", ""],
                        ["B100", "", "", ""]
                      ]),
                      CompactoBloco(titulo: "FILIAL 11", linhas: [
                        ["G.A", "", "", ""],
                        ["S500-A", "", "", ""],
                        ["S10-A", "", "", ""],
                        ["A", "", "", ""],
                        ["H", "", "", ""],
                        ["B100", "", "", ""]
                      ]),
                      CompactoBloco(titulo: "FILIAL 12", linhas: [
                        ["G.A", "", "", ""],
                        ["S500-A", "", "", ""],
                        ["S10-A", "", "", ""],
                        ["A", "", "", ""],
                        ["H", "", "", ""],
                        ["B100", "", "", ""]
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, String data) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          "Relatório Compacto - $data",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class CompactoBloco extends StatelessWidget {
  final String titulo;
  final List<List<String>> linhas;

  const CompactoBloco({
    super.key,
    required this.titulo,
    required this.linhas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CompactoFinalPage.blocoLargura,
      height: CompactoFinalPage.blocoAltura,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(CompactoFinalPage.radiusBloco),
      ),
      child: Column(
        children: [
          Center(
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: linhas.map((l) {
                final temConta = l[2].isNotEmpty || l[3].isNotEmpty;

                return Row(
                  children: [
                    SizedBox(
                      width: CompactoFinalPage.larguraNomeProduto,
                      child: Center(
                        child: Text(
                          l[0],
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    _cell(l[1]),
                    if (temConta) ...[
                      const SizedBox(width: 3),
                      const Text("+", style: TextStyle(fontSize: 9)),
                      const SizedBox(width: 3),
                      _cell(l[2]),
                      const SizedBox(width: 3),
                      const Text("=", style: TextStyle(fontSize: 9)),
                      const SizedBox(width: 3),
                      _cell(l[3], negrito: true),
                    ],
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String v, {bool negrito = false}) {
    return Container(
      width: CompactoFinalPage.cellWidth,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xffeeeeee),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
        borderRadius: BorderRadius.circular(CompactoFinalPage.radiusCelula),
      ),
      child: Text(
        v,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}