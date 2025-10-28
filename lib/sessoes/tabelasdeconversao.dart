import 'package:flutter/material.dart';

class TabelasDeConversao extends StatefulWidget {
  final VoidCallback onVoltar; // Função para voltar aos cards

  const TabelasDeConversao({super.key, required this.onVoltar});

  @override
  State<TabelasDeConversao> createState() => _TabelasDeConversaoState();
}

class _TabelasDeConversaoState extends State<TabelasDeConversao>
    with SingleTickerProviderStateMixin {
  bool showTabelaVolume = false;
  bool showTabelaDensidade = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('list'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botão de voltar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
              ),
              const Text(
                "Tabelas de conversão",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const Divider(),

          // ===== Volume =====
          ListTile(
            leading: const Icon(Icons.stacked_bar_chart, color: Colors.green),
            title: const Text("Tabela de Conversão de Volume"),
            trailing: Icon(
              showTabelaVolume ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                showTabelaVolume = !showTabelaVolume;
                showTabelaDensidade = false;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: showTabelaVolume
                ? Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ListTile(
                          title: Text("TCV Anidro e Hidratado"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                        ListTile(
                          title: Text("TCV Gasolina e Diesel"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ===== Densidade =====
          ListTile(
            leading: const Icon(Icons.science, color: Colors.blue),
            title: const Text("Tabela de Conversão de Densidade"),
            trailing: Icon(
              showTabelaDensidade ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                showTabelaDensidade = !showTabelaDensidade;
                showTabelaVolume = false;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: showTabelaDensidade
                ? Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ListTile(
                          title: Text("TCD Anidro e Hidratado"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                        ListTile(
                          title: Text("TCD Gasolina e Diesel"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
