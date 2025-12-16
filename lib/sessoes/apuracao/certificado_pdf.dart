import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


class CertificadoPDF {
  // Função principal para gerar o PDF
  static Future<pw.Document> gerar({
    required String data,
    required String hora,
    required String? produto,
    required Map<String, String> campos,
  }) async {
    final pdf = pw.Document();
    
    // Cores personalizadas
    final azulPrincipal = PdfColor.fromInt(0xFF0D47A1);
    final cinzaClaro = PdfColor.fromInt(0xFFF5F5F5);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO COM BORDAS
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  border: pw.Border.all(color: azulPrincipal, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'CERTIFICADO DE ANÁLISE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Documento Oficial - Válido para Fins Regulatórios',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 25),
              
              // INFORMAÇÕES PRINCIPAIS EM CARTÕES
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // CARTÃO 1: Dados da Amostra
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DADOS DA AMOSTRA',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: azulPrincipal,
                            ),
                          ),
                          pw.Divider(color: azulPrincipal, height: 15),
                          _infoLinhaPDF('Produto:', produto ?? "Não informado"),
                          _infoLinhaPDF('Notas Fiscais:', campos['notas'] ?? ""),
                          _infoLinhaPDF('Data Coleta:', data),
                          _infoLinhaPDF('Hora Coleta:', hora),
                        ],
                      ),
                    ),
                  ),
                  
                  pw.SizedBox(width: 15),
                  
                  // CARTÃO 2: Dados do Transporte
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DADOS DO TRANSPORTE',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: azulPrincipal,
                            ),
                          ),
                          pw.Divider(color: azulPrincipal, height: 15),
                          _infoLinhaPDF('Placa do veículo:', campos['placa'] ?? ""),
                          _infoLinhaPDF('Motorista:', campos['motorista'] ?? ""),
                          _infoLinhaPDF('Transportadora:', campos['transportadora'] ?? ""),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 25),
              
              // SEÇÃO: COLETAS (COM DOIS QUADROS)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cinzaClaro,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'COLETAS REALIZADAS NA PRESENÇA DO MOTORISTA',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    
                    // PRIMEIRO QUADRO: Parâmetros das coletas
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.8), // Parâmetro
                        1: const pw.FlexColumnWidth(1),   // Valor (centralizado)
                        2: const pw.FlexColumnWidth(0.7), // Unidade
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _celulaTabela('PARÂMETRO', true),
                            _celulaTabela('VALOR', true, centralizado: true),
                            _celulaTabela('UNIDADE', true),
                          ],
                        ),
                        _linhaTabela('Temperatura da amostra', campos['tempAmostra'] ?? "", '°C'),
                        _linhaTabela('Densidade observada', campos['densidadeAmostra'] ?? "", ''),
                        _linhaTabela('Temperatura do CT', campos['tempCT'] ?? "", '°C'),
                      ],
                    ),
                    
                    pw.SizedBox(height: 20),
                    
                    // SEGUNDO QUADRO: Resultados obtidos
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.8), // Resultados Obtidos
                        1: const pw.FlexColumnWidth(1),   // Valor (centralizado)
                        2: const pw.FlexColumnWidth(0.7), // Unidade
                      },
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _celulaTabela('RESULTADOS OBTIDOS', true),
                            _celulaTabela('VALOR', true, centralizado: true),
                            _celulaTabela('UNIDADE', true),
                          ],
                        ),
                        _linhaTabela('Densidade a 20ºC', campos['densidade20'] ?? "", ''),
                        _linhaTabela('Fator de conversão de volume (FCV)', campos['fatorCorrecao'] ?? "", ''),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 25),
              
              // SEÇÃO: VOLUMES
              pw.Row(
                children: [
                  // Volumes Ambiente
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'VOLUMES - AMBIENTE',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: azulPrincipal,
                              fontSize: 14,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _infoLinhaPDF('Origem:', campos['origemAmb'] ?? ""),
                          _infoLinhaPDF('Destino:', campos['destinoAmb'] ?? ""),
                          _infoLinhaPDF('Diferença:', campos['difAmb'] ?? ""),
                        ],
                      ),
                    ),
                  ),
                  
                  pw.SizedBox(width: 15),
                  
                  // Volumes 20°C
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'VOLUMES - 20°C',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: azulPrincipal,
                              fontSize: 14,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _infoLinhaPDF('Origem:', campos['origem20'] ?? ""),
                          _infoLinhaPDF('Destino:', campos['destino20'] ?? ""),
                          _infoLinhaPDF('Diferença:', campos['dif20'] ?? ""),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // ESPAÇO FLEXÍVEL PARA AJUSTAR O TAMANHO
              pw.Spacer(),
              
              // RODAPÉ COM ASSINATURAS OFICIAIS - CORRIGIDO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'DOCUMENTO VÁLIDO APENAS COM ASSINATURA',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 15),
                    
                    // ASSINATURAS EM LINHA
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        // Assinatura do Responsável pela Coleta
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('_________________________', 
                              style: pw.TextStyle(fontSize: 10, height: 1.2)),
                            pw.SizedBox(height: 4),
                            pw.Text('Responsável pela Coleta', 
                              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                        
                        // Assinatura do Responsável Técnico
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('_________________________', 
                              style: pw.TextStyle(fontSize: 10, height: 1.2)),
                            pw.SizedBox(height: 4),
                            pw.Text('Responsável Técnico', 
                              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 15),
                    
                    // ASSINATURA DO MOTORISTA CENTRALIZADA
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('_________________________', 
                          style: pw.TextStyle(fontSize: 10, height: 1.2)),
                        pw.SizedBox(height: 4),
                        pw.Text('Motorista - ${campos['motorista'] ?? "Não informado"}', 
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('(Assinou o documento eletronicamente)', 
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                    
                    pw.SizedBox(height: 10),
                    pw.Divider(height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Documento gerado automaticamente pelo CloudTrack - $data $hora',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }
  
  // ================= FUNÇÕES AUXILIARES (privadas) =================
  
  static pw.Widget _infoLinhaPDF(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? 'Não informado' : value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.TableRow _linhaTabela(String parametro, String valor, String unidade) {
    return pw.TableRow(
      children: [
        _celulaTabela(parametro, false),
        _celulaTabela(valor, false, centralizado: true),
        _celulaTabela(unidade, false),
      ],
    );
  }
  
  static pw.Container _celulaTabela(String texto, bool isHeader, {bool centralizado = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: centralizado ? pw.TextAlign.center : pw.TextAlign.left,
      ),
      decoration: isHeader 
          ? pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1))
          : null,
    );
  }
  
}