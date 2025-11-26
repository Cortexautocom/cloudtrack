import 'package:flutter/material.dart';

class CalcPage extends StatelessWidget {
  final Map<String, dynamic> dadosFormulario;

  const CalcPage({
    super.key,
    required this.dadosFormulario,
  });

  @override
  Widget build(BuildContext context) {
    final medicoes = dadosFormulario['medicoes'] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 670,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== CABEÇALHO DO DOCUMENTO =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      border: Border.all(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text(
                        "CERTIFICADO DE ARQUEAÇÃO DE CARGAS LÍQUIDAS",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== INFORMAÇÕES EM LINHA (4 CAMPOS) =====
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // DATA
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("DATA:"),
                              _linhaValor(_obterApenasData(dadosFormulario['data']?.toString() ?? "")),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        // BASE
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("BASE:"),
                              _linhaValor(dadosFormulario['base']?.toString() ?? "POLO DE COMBUSTÍVEL"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        // PRODUTO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("PRODUTO:"),
                              _linhaValor(dadosFormulario['produto']?.toString() ?? ""),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        // TANQUE
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("TANQUE Nº:"),
                              _linhaValor(dadosFormulario['tanque']?.toString() ?? ""),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ===== MEDIÇÕES COM DUAS COLUNAS =====
                  _subtitulo("CARGA RECEBIDA NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
                  const SizedBox(height: 12),

                  _tabelaMedicoes([
                    _linhaMedicao("Altura total de líquido no tanque", 
                        _formatarAlturaTotal(medicoes['cmManha'], medicoes['mmManha']), 
                        _formatarAlturaTotal(medicoes['cmTarde'], medicoes['mmTarde'])),
                    _linhaMedicao("Altura da água aferida no tanque", 
                        _obterValorMedicao(medicoes['alturaAguaManha']), 
                        _obterValorMedicao(medicoes['alturaAguaTarde'])),
                    _linhaMedicao("Altura do produto aferido no tanque", 
                        _calcularAlturaProduto(medicoes['cmManha'], medicoes['mmManha'], medicoes['alturaAguaManha']), 
                        _calcularAlturaProduto(medicoes['cmTarde'], medicoes['mmTarde'], medicoes['alturaAguaTarde'])),
                    _linhaMedicao("Volume em litros, correspondente à altura total do produto", 
                        _obterValorMedicao(medicoes['volumeProdutoManha']), 
                        _obterValorMedicao(medicoes['volumeProdutoTarde'])),
                    _linhaMedicao("Volume em litros, correspondente à altura total da água", 
                        _obterValorMedicao(medicoes['volumeAguaManha']), 
                        _obterValorMedicao(medicoes['volumeAguaTarde'])),
                    _linhaMedicao("Volume em litros do produto eventualmente existente na canalização", 
                        _obterValorMedicao(medicoes['volumeCanalizacaoManha']), 
                        _obterValorMedicao(medicoes['volumeCanalizacaoTarde'])),
                    _linhaMedicao("Volume total em litros do produto no tanque e na canalização", 
                        _obterValorMedicao(medicoes['volumeTotalManha']), 
                        _obterValorMedicao(medicoes['volumeTotalTarde'])),
                    _linhaMedicao("Temperatura do produto no tanque (ºC)", 
                        _obterValorMedicao(medicoes['tempTanqueManha']), 
                        _obterValorMedicao(medicoes['tempTanqueTarde'])),
                    _linhaMedicao("Densidade observada na amostra", 
                        _obterValorMedicao(medicoes['densidadeManha']), 
                        _obterValorMedicao(medicoes['densidadeTarde'])),
                    _linhaMedicao("Temperatura da amostra (ºC)", 
                        _obterValorMedicao(medicoes['tempAmostraManha']), 
                        _obterValorMedicao(medicoes['tempAmostraTarde'])),
                    _linhaMedicao("Fator de correção de volume do produto (FCV)", 
                        _obterValorMedicao(medicoes['fatorCorrecaoManha']), 
                        _obterValorMedicao(medicoes['fatorCorrecaoTarde'])),                    
                    _linhaMedicao("Densidade da amostra, considerada a temperatura padrão (20 ºC)", 
                        _obterValorMedicao(medicoes['densidade20Manha']), 
                        _obterValorMedicao(medicoes['densidade20Tarde'])),
                    _linhaMedicao("Volume total do produto, considerada a temperatura padrão (20 ºC)", 
                        _obterValorMedicao(medicoes['volume20Manha']), 
                        _obterValorMedicao(medicoes['volume20Tarde'])),
                  ]),

                  const SizedBox(height: 25),

                  // ===== RESULTADOS =====
                  _subtitulo("COMPARAÇÃO DOS RESULTADOS"),
                  const SizedBox(height: 8),

                  _tabela([
                    ["Litros a Ambiente", _calcularLitrosAmbiente(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Litros a 20 °C", _calcularLitros20C(medicoes['cmManha'], medicoes['mmManha'], medicoes['densidadeManha'], medicoes['tempTanqueManha'])],
                  ]),

                  const SizedBox(height: 25),

                  // ===== MANIFESTAÇÃO =====
                  _subtitulo("MANIFESTAÇÃO"),
                  const SizedBox(height: 8),

                  _tabela([
                    ["Recebido", _calcularRecebido(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Diferença", _calcularDiferenca(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Percentual", _calcularPercentual(medicoes['cmManha'], medicoes['mmManha'])],
                  ]),

                  const SizedBox(height: 25),

                  // ===== ABERTURA / SALDO =====
                  _subtitulo("ABERTURA / ENTRADA / SAÍDA / SALDO"),
                  const SizedBox(height: 8),

                  _tabela([
                    ["Abertura", _calcularAbertura()],
                    ["Entrada", _calcularEntrada(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Saída", _calcularSaida()],
                    ["Saldo Final", _calcularSaldoFinal(medicoes['cmManha'], medicoes['mmManha'])],
                  ]),

                  // ===== RESPONSÁVEL =====
                  if (dadosFormulario['responsavel'] != null && dadosFormulario['responsavel']!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 25),
                        _subtitulo("RESPONSÁVEL PELA MEDIÇÃO"),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dadosFormulario['responsavel']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),

                  // ===== RODAPÉ INFORMATIVO =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Página demonstrativa — valores ilustrativos",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Use Ctrl+P para imprimir • Botão Voltar do navegador para retornar",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
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
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _subtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _linhaValor(String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        valor,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _tabela(List<List<String>> linhas) {
    return Table(
      border: TableBorder.all(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.5),
      },
      children: linhas.map((l) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                l[0], 
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                l[1], 
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ===========================================
  // WIDGETS PARA TABELA DE MEDIÇÕES
  // ===========================================

  Widget _tabelaMedicoes(List<TableRow> linhas) {
    return Table(
      border: TableBorder.all(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.0),
      },
      children: [
        // CABEÇALHO DA TABELA DE MEDIÇÕES
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey[200],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "DESCRIÇÃO",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "1ª MEDIÇÃO, 07:45 h",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                "2ª MEDIÇÃO, 14:30 h",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        ...linhas,
      ],
    );
  }

  TableRow _linhaMedicao(String descricao, String valorManha, String valorTarde) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            descricao,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorManha,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorTarde,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ===========================================
  // FUNÇÕES AUXILIARES
  // ===========================================

  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String && valor.isEmpty) return "-";
    return valor.toString();
  }

  String _obterApenasData(String dataCompleta) {
    // Remove a parte da hora se existir (tudo depois da vírgula)
    if (dataCompleta.contains(',')) {
      return dataCompleta.split(',').first.trim();
    }
    return dataCompleta;
  }

  String _formatarAlturaTotal(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final mmValue = (mm == null || mm.isEmpty) ? "0" : mm;
    return "$cm,$mmValue cm";
  }

  String _calcularAlturaProduto(String? cmTotal, String? mmTotal, String? alturaAgua) {
    if (cmTotal == null || cmTotal.isEmpty) return "-";
    
    // Converter altura total para centímetros
    final cmTotalValue = double.tryParse(cmTotal.replaceAll(',', '.')) ?? 0;
    final mmTotalValue = double.tryParse(mmTotal?.replaceAll(',', '.') ?? '0') ?? 0;
    final alturaTotal = cmTotalValue + (mmTotalValue / 10);
    
    // Converter altura da água para centímetros
    final alturaAguaValue = double.tryParse(alturaAgua?.replaceAll(',', '.') ?? '0') ?? 0;
    
    // Calcular altura do produto (total - água)
    final alturaProduto = alturaTotal - alturaAguaValue;
    
    if (alturaProduto <= 0) return "0,0 cm";
    
    // Formatar resultado (parte inteira e decimal)
    final parteInteira = alturaProduto.floor();
    final parteDecimal = ((alturaProduto - parteInteira) * 10).round();
    
    return "$parteInteira,$parteDecimal cm";
  }

  // ===========================================
  // FUNÇÕES DE CÁLCULO (MANTIDAS PARA OUTROS BLOCOS)
  // ===========================================

  String _calcularLitrosAmbiente(String? cm, String? mm) {
    return _calcularVolume(cm, mm);
  }

  String _calcularLitros20C(String? cm, String? mm, String? densidade, String? temperatura) {
    return _calcularVolumeA20(cm, mm, densidade, temperatura);
  }

  String _calcularVolume(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final mmValue = double.tryParse(mm?.replaceAll(',', '.') ?? '0') ?? 0;
    final alturaTotal = cmValue + (mmValue / 10);
    // Cálculo simplificado - volume baseado na altura (ajustar conforme tabela do tanque)
    final volume = alturaTotal * 100; // Exemplo: 1cm = 100L
    return '${volume.toStringAsFixed(0)} L';
  }

  String _calcularVolumeA20(String? cm, String? mm, String? densidade, String? temperatura) {
    if (cm == null || cm.isEmpty) return "-";
    final volumeAmbiente = _calcularVolume(cm, mm);    
    // Cálculo simplificado - na prática usaria tabelas de correção
    return volumeAmbiente; // Placeholder
  }

  String _calcularRecebido(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final volumeRecebido = cmValue * 95; // Exemplo simplificado
    return '${volumeRecebido.toStringAsFixed(0)} L';
  }

  String _calcularDiferenca(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final diferenca = cmValue * 2; // Exemplo simplificado
    return '${diferenca.toStringAsFixed(0)} L';
  }

  String _calcularPercentual(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final percentual = (cmValue * 0.5); // Exemplo simplificado
    return '${percentual.toStringAsFixed(1)} %';
  }

  String _calcularAbertura() {
    return "1.500 L"; // Placeholder - deveria vir do banco
  }

  String _calcularEntrada(String? cm, String? mm) {
    return _calcularRecebido(cm, mm);
  }

  String _calcularSaida() {
    return "850 L"; // Placeholder - deveria vir do banco
  }

  String _calcularSaldoFinal(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final abertura = 1500.0;
    final entrada = double.tryParse(_calcularRecebido(cm, mm).replaceAll(' L', '')) ?? 0;
    final saida = 850.0;
    final saldo = abertura + entrada - saida;
    return '${saldo.toStringAsFixed(0)} L';
  }
}