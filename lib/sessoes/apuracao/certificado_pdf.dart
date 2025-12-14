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
                      'CERTIFICADO DE ANÁLISE LABORATORIAL',
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
                          _infoLinhaPDF('Transportadora:', campos['transportadora'] ?? ""),
                          _infoLinhaPDF('Motorista:', campos['motorista'] ?? ""),
                          pw.SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 25),
              
              // SEÇÃO: COLETAS
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
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _celulaTabela('PARÂMETRO', true),
                            _celulaTabela('VALOR', true),
                            _celulaTabela('UNIDADE', true),
                          ],
                        ),
                        _linhaTabela('Temperatura da amostra', campos['tempAmostra'] ?? "", '°C'),
                        _linhaTabela('Densidade observada', campos['densidadeAmostra'] ?? "", ''),
                        _linhaTabela('Temperatura do CT', campos['tempCT'] ?? "", '°C'),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 25),
              
              // SEÇÃO: RESULTADOS
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
                      'RESULTADOS OBTIDOS',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: azulPrincipal,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Row(
                      children: [
                        _cardResultado('Densidade a 20°C', campos['densidade20'] ?? ""),
                        pw.SizedBox(width: 15),
                        _cardResultado('Fator de Correção (FCV)', campos['fatorCorrecao'] ?? ""),
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
              
              pw.SizedBox(height: 30),
              
              // RODAPÉ
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
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text('_________________________', style: pw.TextStyle(fontSize: 10)),
                            pw.Text('Responsável pela Coleta', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text('_________________________', style: pw.TextStyle(fontSize: 10)),
                            pw.Text('Responsável Técnico', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
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
        _celulaTabela(valor, false),
        _celulaTabela(unidade, false),
      ],
    );
  }
  
  static pw.Container _celulaTabela(String texto, bool isHeader) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
      decoration: isHeader 
          ? pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1))
          : null,
    );
  }
  
  static pw.Widget _cardResultado(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColor.fromInt(0xFF0D47A1), width: 1.5),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF0D47A1),
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              valor.isEmpty ? '-' : valor,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}