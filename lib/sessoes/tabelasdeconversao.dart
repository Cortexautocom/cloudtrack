import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ Detecta se está no navegador
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:universal_html/html.dart' as html; // ✅ Substitui dart:html (seguro para web)
import 'dart:io' show Platform;

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
  bool baixando = false;

  // ✅ Função genérica que funciona em Web, Android e Desktop
  Future<void> baixarTabela(BuildContext context, String titulo, String url) async {
    setState(() => baixando = true);

    try {
      if (kIsWeb) {
        // 🌐 FLUTTER WEB → download direto pelo navegador
        final anchor = html.AnchorElement(href: url)
          ..download = titulo.replaceAll(' ', '_') + '.xlsx'
          ..target = '_blank'
          ..click();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📥 Download iniciado: $titulo')),
        );
      } else {
        // 📱 ANDROID / DESKTOP → salva o arquivo localmente
        final dio = Dio();
        final dir = await getApplicationDocumentsDirectory();
        final nomeArquivo = titulo.replaceAll(' ', '_').toLowerCase() + '.xlsx';
        final caminho = '${dir.path}/$nomeArquivo';

        await dio.download(url, caminho);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📥 Download concluído: $nomeArquivo')),
        );

        await OpenFilex.open(caminho);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro ao baixar: $e')),
      );
    } finally {
      if (mounted) setState(() => baixando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
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
              // ===== Botão de voltar =====
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

              // ===== Tabela de Volume =====
              ListTile(
                leading:
                    const Icon(Icons.stacked_bar_chart, color: Colors.green),
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
                          children: [
                            ListTile(
                              title: const Text("TCV Anidro e Hidratado"),
                              leading: const Icon(
                                  Icons.insert_drive_file_outlined),
                              onTap: () => baixarTabela(
                                context,
                                'TCV Anidro e Hidratado',
                                'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcv_anidro_hidratado/tcv_anidro_hidratado.xlsx',
                              ),
                            ),
                            ListTile(
                              title: const Text("TCV Gasolina e Diesel"),
                              leading: const Icon(
                                  Icons.insert_drive_file_outlined),
                              onTap: () => baixarTabela(
                                context,
                                'TCV Gasolina e Diesel',
                                'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcv_gasolina_diesel/tcv_gasolina_diesel.xlsx',
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ===== Tabela de Densidade =====
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
                          children: [
                            ListTile(
                              title: const Text("TCD Anidro e Hidratado"),
                              leading: const Icon(
                                  Icons.insert_drive_file_outlined),
                              onTap: () => baixarTabela(
                                context,
                                'TCD Anidro e Hidratado',
                                'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcd_anidro_hidratado/TCD%20Anidro%20e%20Hidratado.xlsx',
                              ),
                            ),
                            ListTile(
                              title: const Text("TCD Gasolina e Diesel"),
                              leading: const Icon(
                                  Icons.insert_drive_file_outlined),
                              onTap: () => baixarTabela(
                                context,
                                'TCD Gasolina e Diesel',
                                'https://ikaxzlpaihdkqyjqrxyw.supabase.co/storage/v1/object/public/tcd_gasolina_diesel/tcd_gasolia_diesel.xlsx',
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // ===== Indicador de download =====
        if (baixando)
          Container(
            color: Colors.black45,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 15),
                  Text(
                    'Baixando arquivo...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
