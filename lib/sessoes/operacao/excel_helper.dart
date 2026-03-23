// excel_helper.dart
import 'dart:html' as html;
import 'package:excel/excel.dart';

void gerarExcelEstoqueTanque({
  required List<Map<String, dynamic>> dados,
  required Map<String, num?> estoqueInicial,
  required Map<String, num?> estoqueFinal,
  required String nomeArquivo,
}) {
  final excel = Excel.createExcel();
  final sheet = excel['Relatório'];

  // =========================
  // 🎯 ESTILOS
  // =========================

  final tituloStyle = CellStyle(
    bold: true,
    fontSize: 14,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  final headerStyle = CellStyle(
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  final centerStyle = CellStyle(
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );  

  final destaqueStyle = CellStyle(
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  // =========================
  // 📄 TÍTULO
  // =========================

  sheet.appendRow(['RELATÓRIO DE ESTOQUE']);
  sheet.merge(
    CellIndex.indexByString("A1"),
    CellIndex.indexByString("H1"),
  );

  sheet
      .cell(CellIndex.indexByString("A1"))
      .cellStyle = tituloStyle;

  sheet.appendRow([]);

  // =========================
  // 📊 CABEÇALHO
  // =========================

  final header = [
    'Data',
    'Descrição',
    'Entrada (Amb)',
    'Entrada (20ºC)',
    'Saída (Amb)',
    'Saída (20ºC)',
    'Saldo (Amb)',
    'Saldo (20ºC)',
  ];

  sheet.appendRow(header);

  for (int i = 0; i < header.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2))
        .cellStyle = headerStyle;
  }

  // =========================
  // 📦 ESTOQUE INICIAL
  // =========================

  sheet.appendRow([
    '',
    'Estoque Inicial',
    '',
    '',
    '',
    '',
    _formatNumber(estoqueInicial['amb'] ?? 0),
    _formatNumber(estoqueInicial['vinte'] ?? 0),
  ]);

  int linhaAtual = 3;

  // Aplica estilo centralizado na linha do estoque inicial
  for (int c = 0; c < 8; c++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: linhaAtual - 1),
    );
    cell.cellStyle = centerStyle;
  }

  // =========================
  // 📋 DADOS
  // =========================

  for (final e in dados) {
    sheet.appendRow([
      e['data_mov'] ?? '',
      e['descricao'] ?? '',
      _formatNumber(e['entrada_amb'] ?? 0),
      _formatNumber(e['entrada_vinte'] ?? 0),
      _formatNumber(e['saida_amb'] ?? 0),
      _formatNumber(e['saida_vinte'] ?? 0),
      _formatNumber(e['saldo_amb'] ?? 0),
      _formatNumber(e['saldo_vinte'] ?? 0),
    ]);

    // aplica estilos por linha (centralizado)
    for (int c = 0; c < 8; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: linhaAtual),
      );
      cell.cellStyle = centerStyle;
    }

    linhaAtual++;
  }

  // =========================
  // 📦 ESTOQUE FINAL
  // =========================

  sheet.appendRow([
    '',
    'Estoque Final',
    '',
    '',
    '',
    '',
    _formatNumber(estoqueFinal['amb'] ?? 0),
    _formatNumber(estoqueFinal['vinte'] ?? 0),
  ]);

  // aplica destaque na última linha (centralizado)
  for (int c = 0; c < 8; c++) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: linhaAtual),
    );

    if (c >= 6) {
      cell.cellStyle = destaqueStyle;
    } else if (c == 1) {
      cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center, verticalAlign: VerticalAlign.Center);
    } else {
      cell.cellStyle = centerStyle;
    }
  }

  // =========================
  // 📐 LARGURA DAS COLUNAS
  // =========================

  sheet.setColWidth(0, 12); // Data
  sheet.setColWidth(1, 35); // Descrição
  sheet.setColWidth(2, 14); // Entrada (Amb) - largura 14
  sheet.setColWidth(3, 14); // Entrada (20ºC) - largura 14
  sheet.setColWidth(4, 14); // Saída (Amb) - largura 14
  sheet.setColWidth(5, 14); // Saída (20ºC) - largura 14
  sheet.setColWidth(6, 15); // Saldo (Amb)
  sheet.setColWidth(7, 15); // Saldo (20ºC)

  // =========================
  // 📥 DOWNLOAD
  // =========================

  final bytes = excel.encode();
  final blob = html.Blob([bytes!]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', nomeArquivo)
    ..click();

  html.Url.revokeObjectUrl(url);
}

// =========================
// 🔧 FUNÇÃO AUXILIAR PARA FORMATAR NÚMEROS COM PONTO DE MILHAR
// =========================

String _formatNumber(num? value) {
  if (value == null) return '0';
  
  // Converte para número inteiro (remove decimais se houver)
  final intValue = value.toInt();
  
  // Formata com ponto de milhar
  final parts = intValue.toString().split('');
  final result = StringBuffer();
  
  int count = 0;
  for (int i = parts.length - 1; i >= 0; i--) {
    result.write(parts[i]);
    count++;
    if (count % 3 == 0 && i != 0) {
      result.write('.');
    }
  }
  
  return result.toString().split('').reversed.join('');
}