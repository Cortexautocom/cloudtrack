import 'package:flutter/material.dart';
import 'dart:html' as html;

class CalcPage extends StatelessWidget {
  final VoidCallback? onVoltar;
  final Map<String, dynamic> dadosFormulario;

  const CalcPage({
    super.key,
    this.onVoltar,
    required this.dadosFormulario,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900), // Largura máxima de 900px
          margin: const EdgeInsets.symmetric(vertical: 20),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== BOTÕES DE AÇÃO =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão Voltar
                    ElevatedButton.icon(
                      onPressed: onVoltar,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Voltar ao Formulário'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    
                    // Botões Impressão e Download
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _imprimirDocumento(),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Imprimir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _fazerDownloadPDF(),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ===== CABEÇALHO DO DOCUMENTO =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      "CERTIFICADO DE ARQUEAÇÃO DE CARGAS LÍQUIDAS",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== INFORMAÇÕES EM LINHA (4 CAMPOS) =====
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DATA
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("DATA:"),
                          _linhaValor(dadosFormulario['data'] ?? "10/2025"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    // BASE
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("BASE:"),
                          _linhaValor(dadosFormulario['base'] ?? "POLO DE COMBUSTÍVEL DE CANDEIAS"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    // DESCARGA/RECEBIMENTO
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("Produto:"),
                          _linhaValor(dadosFormulario['produto'] ?? "DIESEL S10 A"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    
                    // TANQUE
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _secaoTitulo("Tanque Nº:"),
                          _linhaValor(dadosFormulario['tanque']?.toString() ?? "05"),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ===== TABELA COM MEDIÇÕES =====
                _subtitulo("CARGA RECEBIDA NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
                const SizedBox(height: 20),

                _tabela([
                  ["Altura média do líquido (1ª medição)", "783,4"],
                  ["Altura média do líquido (2ª medição)", "780,3"],
                  ["Temperatura média no tanque", "28 °C   /   27,5 °C"],
                  ["Volume (altura verificada)", "679.020 L   /   676.337 L"],
                  ["Densidade observada", "0,823 g/ml"],
                  ["Temperatura da amostra", "24,5 °C"],
                  ["Densidade a 20 °C", "0,9940"],
                  ["Volume convertido a 20 °C", "674.699 L   /   672.300 L"],
                ]),

                const SizedBox(height: 35),

                // ===== RESULTADOS =====
                _subtitulo("COMPARAÇÃO DOS RESULTADOS"),
                const SizedBox(height: 10),

                _tabela([
                  ["Litros a Ambiente", "2.683"],
                  ["Litros a 20 °C", "2.399"],
                ]),

                const SizedBox(height: 40),

                // ===== MANIFESTAÇÃO =====
                _subtitulo("MANIFESTAÇÃO"),
                const SizedBox(height: 10),

                _tabela([
                  ["Recebido", ""],
                  ["Diferença", ""],
                  ["Percentual", ""],
                ]),

                const SizedBox(height: 40),

                // ===== ABERTURA / SALDO =====
                _subtitulo("ABERTURA / ENTRADA / SAÍDA / SALDO"),
                const SizedBox(height: 10),

                _tabela([
                  ["Abertura", "674.699 L"],
                  ["Entrada", "0 L"],
                  ["Saída", "0 L"],
                  ["Saldo Final", "674.699 L"],
                ]),

                // ===== RESPONSÁVEL =====
                if (dadosFormulario['responsavel'] != null && dadosFormulario['responsavel']!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      _subtitulo("RESPONSÁVEL PELA MEDIÇÃO"),
                      const SizedBox(height: 10),
                      _linhaValor(dadosFormulario['responsavel']!),
                    ],
                  ),

                const SizedBox(height: 50),

                Center(
                  child: Text(
                    "Página demonstrativa — valores ilustrativos",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================
  // WIDGETS DE FORMATAÇÃO
  // ===========================================

  Widget _secaoTitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _linhaValor(String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
      ),
      child: Text(
        valor,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _tabela(List<List<String>> linhas) {
    return Table(
      border: TableBorder.all(color: Colors.black54),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
      },
      children: linhas.map((l) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l[0], 
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l[1], 
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ===========================================
  // FUNÇÃO DE IMPRESSÃO
  // ===========================================

  void _imprimirDocumento() {
    final cssStyle = """
      <style>
        @media print {
          body { 
            margin: 0; 
            padding: 0; 
            width: 100%; 
            font-family: 'Times New Roman', Times, serif;
            font-size: 12pt;
            line-height: 1.4;
          }
          .documento {
            width: 95%;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: white;
            box-sizing: border-box;
          }
          .cabecalho {
            width: 100%;
            padding: 15px 0;
            background: #E0E0E0;
            border: 1px solid black;
            text-align: center;
            margin-bottom: 20px;
            page-break-inside: avoid;
          }
          .cabecalho h1 {
            font-size: 16pt;
            font-weight: bold;
            margin: 0;
            color: #000;
          }
          .info-linha {
            display: flex;
            justify-content: space-between;
            gap: 10px;
            margin-bottom: 25px;
            page-break-inside: avoid;
          }
          .info-item {
            flex: 1;
          }
          .secao-titulo {
            font-size: 10pt;
            font-weight: bold;
            margin-bottom: 4px;
            page-break-inside: avoid;
          }
          .linha-valor {
            width: 100%;
            padding: 5px;
            border: 1px solid #666;
            font-size: 9pt;
            page-break-inside: avoid;
            min-height: 30px;
          }
          .subtitulo {
            font-size: 13pt;
            font-weight: bold;
            margin: 25px 0 8px 0;
            page-break-inside: avoid;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 25px;
            page-break-inside: avoid;
          }
          table, th, td {
            border: 1px solid #000;
          }
          th, td {
            padding: 6px;
            text-align: left;
            font-size: 11pt;
            page-break-inside: avoid;
          }
          .rodape {
            text-align: center;
            color: #666;
            font-style: italic;
            margin-top: 30px;
            font-size: 10pt;
            page-break-inside: avoid;
          }
          .responsavel {
            margin-top: 40px;
            page-break-inside: avoid;
          }
          @page {
            size: A4;
            margin: 1.5cm;
          }
          * {
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
          }
        }
      </style>
    """;

    final responsavelHtml = dadosFormulario['responsavel'] != null && dadosFormulario['responsavel']!.isNotEmpty
        ? '''
            <div class="responsavel">
              <div class="subtitulo">RESPONSÁVEL PELA MEDIÇÃO</div>
              <div class="linha-valor">${dadosFormulario['responsavel']!}</div>
            </div>
          '''
        : '';

    final htmlContent = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>CALC - Certificado de Arqueação</title>
          <meta charset="UTF-8">
          $cssStyle
        </head>
        <body>
          <div class="documento">
            <div class="cabecalho">
              <h1>CERTIFICADO DE ARQUEAÇÃO DE CARGAS LÍQUIDAS</h1>
            </div>
            
            <div class="info-linha">
              <div class="info-item">
                <div class="secao-titulo">DATA:</div>
                <div class="linha-valor">${dadosFormulario['data'] ?? "10/2025"}</div>
              </div>
              <div class="info-item">
                <div class="secao-titulo">BASE:</div>
                <div class="linha-valor">${dadosFormulario['base'] ?? "POLO DE COMBUSTÍVEL DE CANDEIAS"}</div>
              </div>
              <div class="info-item">
                <div class="secao-titulo">Produto:</div>
                <div class="linha-valor">${dadosFormulario['produto'] ?? "DIESEL S10 A"}</div>
              </div>
              <div class="info-item">
                <div class="secao-titulo">Tanque Nº:</div>
                <div class="linha-valor">${dadosFormulario['tanque']?.toString() ?? "05"}</div>
              </div>
            </div>
            
            <div class="subtitulo">CARGA RECEBIDA NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA</div>
            <table>
              <tr><td>Altura média do líquido (1ª medição)</td><td>783,4</td></tr>
              <tr><td>Altura média do líquido (2ª medição)</td><td>780,3</td></tr>
              <tr><td>Temperatura média no tanque</td><td>28 °C / 27,5 °C</td></tr>
              <tr><td>Volume (altura verificada)</td><td>679.020 L / 676.337 L</td></tr>
              <tr><td>Densidade observada</td><td>0,823 g/ml</td></tr>
              <tr><td>Temperatura da amostra</td><td>24,5 °C</td></tr>
              <tr><td>Densidade a 20 °C</td><td>0,9940</td></tr>
              <tr><td>Volume convertido a 20 °C</td><td>674.699 L / 672.300 L</td></tr>
            </table>
            
            <div class="subtitulo">COMPARAÇÃO DOS RESULTADOS</div>
            <table>
              <tr><td>Litros a Ambiente</td><td>2.683</td></tr>
              <tr><td>Litros a 20 °C</td><td>2.399</td></tr>
            </table>
            
            <div class="subtitulo">MANIFESTAÇÃO</div>
            <table>
              <tr><td>Recebido</td><td></td></tr>
              <tr><td>Diferença</td><td></td></tr>
              <tr><td>Percentual</td><td></td></tr>
            </table>
            
            <div class="subtitulo">ABERTURA / ENTRADA / SAÍDA / SALDO</div>
            <table>
              <tr><td>Abertura</td><td>674.699 L</td></tr>
              <tr><td>Entrada</td><td>0 L</td></tr>
              <tr><td>Saída</td><td>0 L</td></tr>
              <tr><td>Saldo Final</td><td>674.699 L</td></tr>
            </table>
            
            $responsavelHtml
            
            <div class="rodape">
              Página demonstrativa — valores ilustrativos
            </div>
          </div>
          
          <script>
            window.onload = function() {
              setTimeout(function() {
                window.print();
              }, 250);
            };
          </script>
        </body>
      </html>
    """;

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
  }

  // ===========================================
  // FUNÇÃO DE DOWNLOAD PDF
  // ===========================================

  void _fazerDownloadPDF() {
    final cssStyle = """
      <style>
        @media print {
          body { 
            margin: 0; 
            padding: 0; 
            width: 100%; 
            font-family: 'Times New Roman', Times, serif;
            font-size: 12pt;
            line-height: 1.4;
          }
          .documento {
            width: 95%;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: white;
            box-sizing: border-box;
          }
          .cabecalho {
            width: 100%;
            padding: 15px 0;
            background: #E0E0E0;
            border: 1px solid black;
            text-align: center;
            margin-bottom: 20px;
            page-break-inside: avoid;
          }
          .cabecalho h1 {
            font-size: 16pt;
            font-weight: bold;
            margin: 0;
            color: #000;
          }
          .info-linha {
            display: flex;
            justify-content: space-between;
            gap: 10px;
            margin-bottom: 25px;
            page-break-inside: avoid;
          }
          .info-item {
            flex: 1;
          }
          .secao-titulo {
            font-size: 10pt;
            font-weight: bold;
            margin-bottom: 4px;
            page-break-inside: avoid;
          }
          .linha-valor {
            width: 100%;
            padding: 5px;
            border: 1px solid #666;
            font-size: 9pt;
            page-break-inside: avoid;
            min-height: 30px;
          }
          .subtitulo {
            font-size: 13pt;
            font-weight: bold;
            margin: 25px 0 8px 0;
            page-break-inside: avoid;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 25px;
            page-break-inside: avoid;
          }
          table, th, td {
            border: 1px solid #000;
          }
          th, td {
            padding: 6px;
            text-align: left;
            font-size: 11pt;
            page-break-inside: avoid;
          }
          .rodape {
            text-align: center;
            color: #666;
            font-style: italic;
            margin-top: 30px;
            font-size: 10pt;
            page-break-inside: avoid;
          }
          .responsavel {
            margin-top: 40px;
            page-break-inside: avoid;
          }
          @page {
            size: A4;
            margin: 1.5cm;
          }
          * {
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
          }
        }
      </style>
    """;

    final responsavelHtml = dadosFormulario['responsavel'] != null && dadosFormulario['responsavel']!.isNotEmpty
        ? '''
            <div class="responsavel">
              <div class="subtitulo">RESPONSÁVEL PELA MEDIÇÃO</div>
              <div class="linha-valor">${dadosFormulario['responsavel']!}</div>
            </div>
          '''
        : '';

    final htmlContent = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>CALC - Certificado de Arqueação</title>
          <meta charset="UTF-8">
          $cssStyle
        </head>
        <body>
          <div class="documento">
            <div class="cabecalho">
              <h1>CERTIFICADO DE ARQUEAÇÃO DE CARGAS LÍQUIDAS</h1>
            </div>
            
            <div class="info-linha">
              <div class="info-item">
                <div class="secao-titulo">DATA:</div>
                <div class="linha-valor">${dadosFormulario['data'] ?? "10/2025"}</div>
              </div>
              <div class="info-item">
                <div class="secao-titulo">BASE:</div>
                <div class="linha-valor">${dadosFormulario['base'] ?? "POLO DE COMBUSTÍVEL DE CANDEIAS"}</div>
              </div>
              <div class="info-item">
                <div class="secao-titulo">Produto:</div>
                <div class="linha-valor">${dadosFormulario['produto'] ?? "DIESEL S10 A"}</div>
              </div>
              <div class="info-item">
                <div class="secao-titulo">Tanque Nº:</div>
                <div class="linha-valor">${dadosFormulario['tanque']?.toString() ?? "05"}</div>
              </div>
            </div>
            
            <div class="subtitulo">CARGA RECEBIDA NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA</div>
            <table>
              <tr><td>Altura média do líquido (1ª medição)</td><td>783,4</td></tr>
              <tr><td>Altura média do líquido (2ª medição)</td><td>780,3</td></tr>
              <tr><td>Temperatura média no tanque</td><td>28 °C / 27,5 °C</td></tr>
              <tr><td>Volume (altura verificada)</td><td>679.020 L / 676.337 L</td></tr>
              <tr><td>Densidade observada</td><td>0,823 g/ml</td></tr>
              <tr><td>Temperatura da amostra</td><td>24,5 °C</td></tr>
              <tr><td>Densidade a 20 °C</td><td>0,9940</td></tr>
              <tr><td>Volume convertido a 20 °C</td><td>674.699 L / 672.300 L</td></tr>
            </table>
            
            <div class="subtitulo">COMPARAÇÃO DOS RESULTADOS</div>
            <table>
              <tr><td>Litros a Ambiente</td><td>2.683</td></tr>
              <tr><td>Litros a 20 °C</td><td>2.399</td></tr>
            </table>
            
            <div class="subtitulo">MANIFESTAÇÃO</div>
            <table>
              <tr><td>Recebido</td><td></td></tr>
              <tr><td>Diferença</td><td></td></tr>
              <tr><td>Percentual</td><td></td></tr>
            </table>
            
            <div class="subtitulo">ABERTURA / ENTRADA / SAÍDA / SALDO</div>
            <table>
              <tr><td>Abertura</td><td>674.699 L</td></tr>
              <tr><td>Entrada</td><td>0 L</td></tr>
              <tr><td>Saída</td><td>0 L</td></tr>
              <tr><td>Saldo Final</td><td>674.699 L</td></tr>
            </table>
            
            $responsavelHtml
            
            <div class="rodape">
              Página demonstrativa — valores ilustrativos
            </div>
          </div>
        </body>
      </html>
    """;

    // Cria e faz download do arquivo com extensão .pdf
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "certificado-arqueacao.pdf")
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }
}