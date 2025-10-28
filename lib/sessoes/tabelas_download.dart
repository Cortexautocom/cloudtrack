import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
//import 'dart:io';

class TabelaDownloadPage extends StatefulWidget {
  final String titulo;
  final String url;

  const TabelaDownloadPage({
    super.key,
    required this.titulo,
    required this.url,
  });

  @override
  State<TabelaDownloadPage> createState() => _TabelaDownloadPageState();
}

class _TabelaDownloadPageState extends State<TabelaDownloadPage> {
  bool downloading = false;
  double progress = 0;

  Future<void> baixarArquivo() async {
    setState(() {
      downloading = true;
      progress = 0;
    });

    try {
      final dio = Dio();
      final dir = await getApplicationDocumentsDirectory();
      final nomeArquivo =
          widget.titulo.replaceAll(' ', '_').toLowerCase() + '.xlsx';
      final caminho = '${dir.path}/$nomeArquivo';

      await dio.download(
        widget.url,
        caminho,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() => progress = received / total);
          }
        },
      );

      setState(() => downloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📥 Download concluído: $nomeArquivo')),
      );

      await OpenFilex.open(caminho);
    } catch (e) {
      setState(() => downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro ao baixar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.titulo,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        centerTitle: true,
      ),
      body: Center(
        child: downloading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Baixando arquivo...',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  CircularProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              )
            : ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Baixar Tabela Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25, vertical: 15),
                ),
                onPressed: baixarArquivo,
              ),
      ),
    );
  }
}
