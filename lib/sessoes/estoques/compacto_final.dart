import 'package:flutter/material.dart';

class CompactoFinalPage extends StatelessWidget {
  const CompactoFinalPage({super.key});

  /// 👇 % da largura da tela usada pelo relatório
  static const double larguraArea = 0.60;

  /// 👇 largura de cada bloco de filial (muito fácil de ajustar)
  static const double blocoLargura = 230;

  /// 👇 altura dos blocos
  static const double blocoAltura = 165;

  /// 👇 largura das células numéricas
  static const double cellWidth = 44;

  /// 👇 largura da coluna de nomes de produto (G.A, S500-A etc)
  static const double larguraNomeProduto = 56;

  /// 👇 margem esquerda da página (ajuste rápido aqui)
  static const double margemEsquerdaPagina = 10;

  /// 👇 radius dos blocos de filial
  static const double radiusBloco = 6;

  /// 👇 radius das células com números
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
                        titulo: "Base Guarulhos",
                        linhas: [
                          ["G.A","820","140","960"],
                          ["S500-A","740","120","860"],
                          ["S10-A","690","110","800"],
                          ["A","210","90","300"],
                          ["H","430","70","500"],
                          ["B100","120","40","160"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Osasco",
                        linhas: [
                          ["G.A","780","150","930"],
                          ["S500-A","650","140","790"],
                          ["S10-A","620","135","755"],
                          ["A","240","95","335"],
                          ["H","410","85","495"],
                          ["B100","130","45","175"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Barueri",
                        linhas: [
                          ["G.A","810","160","970"],
                          ["S500-A","700","150","850"],
                          ["S10-A","660","140","800"],
                          ["A","250","100","350"],
                          ["H","420","80","500"],
                          ["B100","140","50","190"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Santo André",
                        linhas: [
                          ["G.A","790","150","940"],
                          ["S500-A","710","140","850"],
                          ["S10-A","670","130","800"],
                          ["A","230","90","320"],
                          ["H","400","75","475"],
                          ["B100","135","40","175"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base São Bernardo",
                        linhas: [
                          ["G.A","860","170","1030"],
                          ["S500-A","740","160","900"],
                          ["S10-A","720","150","870"],
                          ["A","260","110","370"],
                          ["H","450","90","540"],
                          ["B100","150","55","205"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Diadema",
                        linhas: [
                          ["G.A","720","140","860"],
                          ["S500-A","640","130","770"],
                          ["S10-A","610","120","730"],
                          ["A","210","85","295"],
                          ["H","390","70","460"],
                          ["B100","120","35","155"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base São Caetano",
                        linhas: [
                          ["G.A","700","130","830"],
                          ["S500-A","620","120","740"],
                          ["S10-A","600","115","715"],
                          ["A","200","80","280"],
                          ["H","370","65","435"],
                          ["B100","110","30","140"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Cotia",
                        linhas: [
                          ["G.A","750","145","895"],
                          ["S500-A","670","135","805"],
                          ["S10-A","640","125","765"],
                          ["A","220","90","310"],
                          ["H","405","75","480"],
                          ["B100","125","40","165"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Curitiba",
                        linhas: [
                          ["G.A","900","180","1080"],
                          ["S500-A","820","170","990"],
                          ["S10-A","780","160","940"],
                          ["A","300","120","420"],
                          ["H","480","95","575"],
                          ["B100","170","60","230"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base São José dos Pinhais",
                        linhas: [
                          ["G.A","840","165","1005"],
                          ["S500-A","760","155","915"],
                          ["S10-A","720","145","865"],
                          ["A","270","105","375"],
                          ["H","440","85","525"],
                          ["B100","150","55","205"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Colombo",
                        linhas: [
                          ["G.A","770","150","920"],
                          ["S500-A","690","140","830"],
                          ["S10-A","650","130","780"],
                          ["A","240","95","335"],
                          ["H","410","80","490"],
                          ["B100","135","45","180"],
                        ],
                      ),

                      CompactoBloco(
                        titulo: "Base Araucária",
                        linhas: [
                          ["G.A","830","170","1000"],
                          ["S500-A","750","160","910"],
                          ["S10-A","710","150","860"],
                          ["A","260","110","370"],
                          ["H","430","90","520"],
                          ["B100","145","50","195"],
                        ],
                      ),
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

                    const SizedBox(width: 3),
                    const Text("+", style: TextStyle(fontSize: 9)),
                    const SizedBox(width: 3),

                    _cell(l[2]),

                    const SizedBox(width: 3),
                    const Text("=", style: TextStyle(fontSize: 9)),
                    const SizedBox(width: 3),

                    _cell(l[3], negrito: true),
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