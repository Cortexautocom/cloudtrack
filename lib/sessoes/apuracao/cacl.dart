import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalcPage extends StatefulWidget {
  final Map<String, dynamic> dadosFormulario;
  const CalcPage({super.key, required this.dadosFormulario});

  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  double volumeManha = 0;
  double volumeTarde = 0;
  double volumeTotalLiquidoManha = 0;
  double volumeTotalLiquidoTarde = 0;

  @override
  void initState() {
    super.initState();
    _calcularVolumesIniciais();
  }

  Future<void> _calcularVolumesIniciais() async {
    final medicoes = widget.dadosFormulario['medicoes'];
    
    final alturaAguaManha = medicoes['alturaAguaManha'];
    final alturaAguaTarde = medicoes['alturaAguaTarde'];

    final alturaTotalCmManha = medicoes['cmManha']?.toString() ?? '';
    final alturaTotalMmManha = medicoes['mmManha']?.toString() ?? '';
    final alturaTotalCmTarde = medicoes['cmTarde']?.toString() ?? '';
    final alturaTotalMmTarde = medicoes['mmTarde']?.toString() ?? '';

    Map<String, String?> extrairCmMm(String? alturaFormatada) {
      if (alturaFormatada == null || alturaFormatada.isEmpty || alturaFormatada == '-') {
        return {'cm': null, 'mm': null};
      }
      
      try {
        final semUnidade = alturaFormatada.replaceAll(' cm', '').trim();
        final partes = semUnidade.split(',');
        
        if (partes.length == 2) {
          return {'cm': partes[0], 'mm': partes[1]};
        } else if (partes.length == 1) {
          return {'cm': partes[0], 'mm': '0'};
        } else {
          return {'cm': null, 'mm': null};
        }
      } catch (e) {
        return {'cm': null, 'mm': null};
      }
    }
    
    final aguaCmMmManha = extrairCmMm(alturaAguaManha);
    final aguaCmMmTarde = extrairCmMm(alturaAguaTarde);

    final Map<String, String?> totalCmMmManha = {
      'cm': alturaTotalCmManha.isEmpty ? null : alturaTotalCmManha,
      'mm': alturaTotalMmManha.isEmpty ? null : alturaTotalMmManha
    };
    
    final Map<String, String?> totalCmMmTarde = {
      'cm': alturaTotalCmTarde.isEmpty ? null : alturaTotalCmTarde,
      'mm': alturaTotalMmTarde.isEmpty ? null : alturaTotalMmTarde
    };

    final volumeTotalLiquidoManha = await _buscarVolumeReal(totalCmMmManha['cm'], totalCmMmManha['mm']);
    final volumeTotalLiquidoTarde = await _buscarVolumeReal(totalCmMmTarde['cm'], totalCmMmTarde['mm']);
    
    final volAguaManha = await _buscarVolumeReal(aguaCmMmManha['cm'], aguaCmMmManha['mm']);
    final volAguaTarde = await _buscarVolumeReal(aguaCmMmTarde['cm'], aguaCmMmTarde['mm']);

    final volProdutoManha = volumeTotalLiquidoManha - volAguaManha;
    final volProdutoTarde = volumeTotalLiquidoTarde - volAguaTarde;

    final volumeTotalManha = volProdutoManha;
    final volumeTotalTarde = volProdutoTarde;

    setState(() {
      this.volumeManha = volProdutoManha;
      this.volumeTarde = volProdutoTarde;
      this.volumeTotalLiquidoManha = volumeTotalLiquidoManha;
      this.volumeTotalLiquidoTarde = volumeTotalLiquidoTarde;
    });

    final volumeProdutoManhaFormatado = _formatarVolumeLitros(volProdutoManha);
    final volumeProdutoTardeFormatado = _formatarVolumeLitros(volProdutoTarde);
    final volumeAguaManhaFormatado = _formatarVolumeLitros(volAguaManha);
    final volumeAguaTardeFormatado = _formatarVolumeLitros(volAguaTarde);
    final volumeTotalManhaFormatado = _formatarVolumeLitros(volumeTotalManha);
    final volumeTotalTardeFormatado = _formatarVolumeLitros(volumeTotalTarde);

    widget.dadosFormulario['medicoes']['volumeProdutoManha'] = volumeProdutoManhaFormatado;
    widget.dadosFormulario['medicoes']['volumeProdutoTarde'] = volumeProdutoTardeFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaManha'] = volumeAguaManhaFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaTarde'] = volumeAguaTardeFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoManha'] = _formatarVolumeLitros(volumeTotalLiquidoManha);
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoTarde'] = _formatarVolumeLitros(volumeTotalLiquidoTarde);
    
    widget.dadosFormulario['medicoes']['volumeTotalManha'] = volumeTotalManhaFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalTarde'] = volumeTotalTardeFormatado;

    final produtoNome = widget.dadosFormulario['produto']?.toString() ?? '';
      
    if (medicoes['tempAmostraManha'] != null && 
        medicoes['tempAmostraManha'].toString().isNotEmpty &&
        medicoes['tempAmostraManha'].toString() != '-' &&
        medicoes['densidadeManha'] != null &&
        medicoes['densidadeManha'].toString().isNotEmpty &&
        medicoes['densidadeManha'].toString() != '-' &&
        produtoNome.isNotEmpty) {
      
      final densidade20Manha = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraManha'].toString(),
        densidadeObservada: medicoes['densidadeManha'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['densidade20Manha'] = densidade20Manha;
    } else {
      widget.dadosFormulario['medicoes']['densidade20Manha'] = '-';
    }

    if (medicoes['tempAmostraTarde'] != null && 
        medicoes['tempAmostraTarde'].toString().isNotEmpty &&
        medicoes['tempAmostraTarde'].toString() != '-' &&
        medicoes['densidadeTarde'] != null &&
        medicoes['densidadeTarde'].toString().isNotEmpty &&
        medicoes['densidadeTarde'].toString() != '-' &&
        produtoNome.isNotEmpty) {
      
      final densidade20Tarde = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraTarde'].toString(),
        densidadeObservada: medicoes['densidadeTarde'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['densidade20Tarde'] = densidade20Tarde;
    } else {
      widget.dadosFormulario['medicoes']['densidade20Tarde'] = '-';
    }

    if (medicoes['tempTanqueManha'] != null &&
        medicoes['tempTanqueManha'].toString().isNotEmpty &&
        medicoes['tempTanqueManha'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Manha'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Manha'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Manha'].toString() != '-') {
      
      final fcvManha = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueManha'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Manha'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoManha'] = fcvManha;
    } else {
      widget.dadosFormulario['medicoes']['fatorCorrecaoManha'] = '-';
    }

    if (medicoes['tempTanqueTarde'] != null &&
        medicoes['tempTanqueTarde'].toString().isNotEmpty &&
        medicoes['tempTanqueTarde'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Tarde'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Tarde'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Tarde'].toString() != '-') {
      
      final fcvTarde = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueTarde'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Tarde'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'] = fcvTarde;
    } else {
      widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoManha'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoManha'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoManha'].toString() != '-') {
      
      try {
        final fcvManhaStr = widget.dadosFormulario['medicoes']['fatorCorrecaoManha'].toString();
        final fcvManha = double.tryParse(fcvManhaStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Manha = volProdutoManha * fcvManha;
        
        widget.dadosFormulario['medicoes']['volume20Manha'] = _formatarVolumeLitros(volume20Manha);
      } catch (e) {
        widget.dadosFormulario['medicoes']['volume20Manha'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['volume20Manha'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'].toString() != '-') {
      
      try {
        final fcvTardeStr = widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'].toString();
        final fcvTarde = double.tryParse(fcvTardeStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Tarde = volProdutoTarde * fcvTarde;
        
        widget.dadosFormulario['medicoes']['volume20Tarde'] = _formatarVolumeLitros(volume20Tarde);
      } catch (e) {
        widget.dadosFormulario['medicoes']['volume20Tarde'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['volume20Tarde'] = '-';
    }

    await _calcularMassa();
    
    setState(() {});
  }

  Future<double> _buscarVolumeReal(String? cm, String? mm) async {
    final supabase = Supabase.instance.client;

    if (cm == null || cm.isEmpty) {
      return 0;
    }

    final intCm = int.tryParse(cm) ?? 0;
    final intMm = int.tryParse(mm ?? '0') ?? 0;

    final String? filialId = widget.dadosFormulario['filial_id']?.toString();
    String nomeTabela;
    
    if (filialId != null) {
      switch (filialId) {
        case '9d476aa0-11fe-4470-8881-2699cb528690':
          nomeTabela = 'arqueacao_jequie';
          break;
        case 'bcc92c8e-bd40-4d26-acb0-87acdd2ce2b7':
          nomeTabela = 'arqueacao_base_teste';
          break;
        default:
          nomeTabela = 'arqueacao_base_teste';
      }
    } else {
      nomeTabela = 'arqueacao_base_teste';
    }

    final String tanqueRef = widget.dadosFormulario['tanque']?.toString() ?? '';
    String numeroTanque = '01';
    
    if (tanqueRef.isNotEmpty) {
      final numeros = tanqueRef.replaceAll(RegExp(r'[^0-9]'), '');
      if (numeros.isNotEmpty) {
        numeroTanque = numeros.padLeft(2, '0');
      }
    }

    final colunaCm = 'tq_${numeroTanque}_cm';
    final colunaMm = 'tq_${numeroTanque}_mm';

    try {
      final resultadoCm = await supabase
          .from(nomeTabela)
          .select(colunaCm)
          .eq('altura_cm_mm', intCm)
          .maybeSingle();

      if (resultadoCm == null || resultadoCm[colunaCm] == null) {
        return 0;
      }

      final volumeCm = _converterVolumeLitros(resultadoCm[colunaCm]);

      if (intMm == 0) {
        return volumeCm;
      }

      final resultadoMm = await supabase
          .from(nomeTabela)
          .select(colunaMm)
          .eq('altura_cm_mm', intMm)
          .maybeSingle();

      if (resultadoMm == null || resultadoMm[colunaMm] == null) {
        return volumeCm;
      }

      final volumeMm = _converterVolumeLitros(resultadoMm[colunaMm]);
      final volumeTotal = volumeCm + volumeMm;
      
      return double.parse(volumeTotal.toStringAsFixed(3));
      
    } catch (e) {
      return 0;
    }
  }

  double _converterVolumeLitros(dynamic valor) {
    try {
      if (valor == null) return 0.0;
      
      String str = valor.toString().trim();
      str = str.replaceAll(',', '.');
      
      if (str.contains('.')) {
        final partes = str.split('.');
        
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          if (parteDecimal.length < 3) {
            parteDecimal = parteDecimal.padRight(3, '0');
          }
          
          final numeroCompleto = double.tryParse('$parteInteira.$parteDecimal') ?? 0.0;
          return numeroCompleto * 1000;
        }
      }
      
      return double.tryParse(str) ?? 0.0;
      
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicoes = widget.dadosFormulario['medicoes'] ?? {};

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
                  Stack(
                    children: [
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
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Tooltip(
                          message: 'Voltar para medições',
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 209, 209, 209),
                                border: Border.all(color: const Color.fromARGB(255, 202, 202, 202), width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                size: 20,
                                color: Color.fromARGB(255, 235, 235, 235),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("DATA:"),
                              _linhaValor(_obterApenasData(widget.dadosFormulario['data']?.toString() ?? "")),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("BASE:"),
                              _linhaValor(widget.dadosFormulario['base']?.toString() ?? "POLO DE COMBUSTÍVEL"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("PRODUTO:"),
                              _linhaValor(widget.dadosFormulario['produto']?.toString() ?? ""),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _secaoTitulo("TANQUE Nº:"),
                              _linhaValor(widget.dadosFormulario['tanque']?.toString() ?? ""),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  _subtitulo("VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
                  const SizedBox(height: 12),

                  _tabelaMedicoes([
                    _linhaMedicao("Altura total de líquido no tanque:", 
                        _formatarAlturaTotal(medicoes['cmManha'], medicoes['mmManha']), 
                        _formatarAlturaTotal(medicoes['cmTarde'], medicoes['mmTarde'])),
                    _linhaMedicao("Volume total de líquido no tanque (temp. ambiente):", 
                        _formatarVolumeLitros(volumeTotalLiquidoManha), 
                        _formatarVolumeLitros(volumeTotalLiquidoTarde)),
                    _linhaMedicao("Altura da água aferida no tanque:", 
                        _obterValorMedicao(medicoes['alturaAguaManha']), 
                        _obterValorMedicao(medicoes['alturaAguaTarde'])),
                    _linhaMedicao("Volume correspondente à água:", 
                        _obterValorMedicao(medicoes['volumeAguaManha']), 
                        _obterValorMedicao(medicoes['volumeAguaTarde'])),
                    _linhaMedicao("Altura do produto aferido no tanque:", 
                        _obterValorMedicao(medicoes['alturaProdutoManha']), 
                        _obterValorMedicao(medicoes['alturaProdutoTarde'])),
                    _linhaMedicao(
                      "Volume correspondente ao produto (temp. ambiente):",
                      _formatarVolumeLitros(volumeManha),
                      _formatarVolumeLitros(volumeTarde),
                    ),
                    _linhaMedicao("Temperatura do produto no tanque:", 
                        _formatarTemperatura(medicoes['tempTanqueManha']), 
                        _formatarTemperatura(medicoes['tempTanqueTarde'])),
                    _linhaMedicao("Densidade observada na amostra:", 
                        _obterValorMedicao(medicoes['densidadeManha']), 
                        _obterValorMedicao(medicoes['densidadeTarde'])),
                    _linhaMedicao("Temperatura da amostra:", 
                        _formatarTemperatura(medicoes['tempAmostraManha']), 
                        _formatarTemperatura(medicoes['tempAmostraTarde'])),
                    _linhaMedicao("Densidade da amostra, considerada à temperatura padrão (20 ºC):", 
                        _obterValorMedicao(medicoes['densidade20Manha']), 
                        _obterValorMedicao(medicoes['densidade20Tarde'])),                    
                    _linhaMedicao("Fator de correção de volume do produto (FCV):", 
                        _obterValorMedicao(medicoes['fatorCorrecaoManha']), 
                        _obterValorMedicao(medicoes['fatorCorrecaoTarde'])),                    
                    _linhaMedicao("Volume total do produto, considerada a temperatura padrão (20 ºC):", 
                        _obterValorMedicao(medicoes['volume20Manha']), 
                        _obterValorMedicao(medicoes['volume20Tarde'])),
                  ], medicoes),

                  const SizedBox(height: 25),

                  _subtitulo("COMPARAÇÃO DE RESULTADOS"),
                  const SizedBox(height: 8),

                  _tabelaComparacaoResultados(
                    volumeAmbienteManha: volumeManha,
                    volumeAmbienteTarde: volumeTarde,
                    volume20Manha: _extrairNumero(medicoes['volume20Manha']?.toString()),
                    volume20Tarde: _extrairNumero(medicoes['volume20Tarde']?.toString()),
                    entradaSaidaAmbiente: volumeTarde - volumeManha,
                    entradaSaida20: _extrairNumero(medicoes['volume20Tarde']?.toString()) - 
                                    _extrairNumero(medicoes['volume20Manha']?.toString()),
                  ),

                  // NOVO BLOCO FATURADO ADICIONADO AQUI
                  const SizedBox(height: 20),
                  _blocoFaturado(
                    medicoes: medicoes,
                  ),

                  if (widget.dadosFormulario['responsavel'] != null && widget.dadosFormulario['responsavel']!.isNotEmpty)
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
                            widget.dadosFormulario['responsavel']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),

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

  Widget _tabelaMedicoes(List<TableRow> linhas, Map<String, dynamic> medicoes) {
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
                "1ª MEDIÇÃO, ${_formatarHorarioCACL(medicoes['horarioManha'])}",
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
                "2ª MEDIÇÃO, ${_formatarHorarioCACL(medicoes['horarioTarde'])}",
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
        
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                "Massa do produto (Volume a 20 ºC × Densidade  a 20 ºC):",
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                _obterValorMedicao(medicoes['massaManha']),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                _obterValorMedicao(medicoes['massaTarde']),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatarHorarioCACL(String? horario) {
    if (horario == null || horario.isEmpty) return '--:-- h';
    
    String horarioLimpo = horario.trim();
    
    if (horarioLimpo.toLowerCase().endsWith('h')) {
      return horarioLimpo;
    }
    
    return '$horarioLimpo h';
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

  Widget _tabelaComparacaoResultados({
    required double volumeAmbienteManha,
    required double volumeAmbienteTarde,
    required double volume20Manha,
    required double volume20Tarde,
    required double entradaSaidaAmbiente,
    required double entradaSaida20,
  }) {
    // Função para formatar no padrão "999.999 L"
    String fmt(double v) {
      if (v.isNaN) return "-";
      
      final volumeInteiro = v.round();
      String inteiroFormatado = volumeInteiro.toString();
      
      if (inteiroFormatado.length > 3) {
        final buffer = StringBuffer();
        int contador = 0;
        
        for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
          buffer.write(inteiroFormatado[i]);
          contador++;
          
          if (contador == 3 && i > 0) {
            buffer.write('.');
            contador = 0;
          }
        }
        
        final chars = buffer.toString().split('').reversed.toList();
        inteiroFormatado = chars.join('');
      }
      
      return '$inteiroFormatado L';
    }

    return Table(
      border: TableBorder.all(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.0),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.0),
      },
      children: [
        // CABEÇALHO - REDUZIDO
        TableRow(
          decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
          children: [
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("DESCRIÇÃO",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("1ª MEDIÇÃO",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("2ª MEDIÇÃO",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(6.0),
              child: Text("ENTRADA/SAÍDA",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        // LINHA 1: VOLUME AMBIENTE - REDUZIDA
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text("Volume ambiente", style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volumeAmbienteManha), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volumeAmbienteTarde), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(entradaSaidaAmbiente),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
          ],
        ),

        // LINHA 2: VOLUME A 20 ºC - REDUZIDA
        TableRow(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text("Volume a 20 ºC", style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volume20Manha), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volume20Tarde), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(entradaSaida20),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }


  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";

    if (valor is String) {
      final v = valor.trim();

      if (v.isEmpty) return "-";

      final semUnidade = v.replaceAll(" cm", "").trim();

      if (semUnidade == "," || semUnidade == "0,0" || semUnidade == "0,00" || semUnidade == "0,000" || semUnidade == "0,0000") {
        return "-";
      }

      if (semUnidade == "0,") return "-";

      if (semUnidade.startsWith("0,") && semUnidade.substring(2).replaceAll("0", "").isEmpty) {
        return "-";
      }

      return v;
    }

    return valor.toString();
  }

  String _obterApenasData(String dataCompleta) {
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

  String _formatarVolumeLitros(double volume) {
    final volumeInteiro = volume.round();
    
    String inteiroFormatado = volumeInteiro.toString();
    
    if (inteiroFormatado.length > 3) {
      final buffer = StringBuffer();
      int contador = 0;
      
      for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
        buffer.write(inteiroFormatado[i]);
        contador++;
        
        if (contador == 3 && i > 0) {
          buffer.write('.');
          contador = 0;
        }
      }
      
      final chars = buffer.toString().split('').reversed.toList();
      inteiroFormatado = chars.join('');
    }
    
    return '$inteiroFormatado L';
  }

  String _formatarTemperatura(dynamic valor) {
    if (valor == null) return "-";
    if (valor is String && valor.isEmpty) return "-";
    
    final strValor = valor.toString().trim();
    
    final valorSemUnidade = strValor
        .replaceAll(' ºC', '')
        .replaceAll('°C', '')
        .replaceAll('ºC', '')
        .trim();
    
    if (valorSemUnidade.isEmpty) return "-";
    
    return '$valorSemUnidade ºC';
  }

  Future<String> _buscarDensidade20C({
    required String temperaturaAmostra,
    required String densidadeObservada,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;
    
    try {
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        return '-';
      }
      
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final bool usarViewAnidroHidratado = 
          nomeProdutoLower.contains('anidro') || 
          nomeProdutoLower.contains('hidratado');
      
      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      
      String densidadeFormatada = densidadeObservada
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();
      
      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');
      
      if (!densidadeFormatada.contains(',')) {
        if (densidadeFormatada.length == 4) {
          densidadeFormatada = '0,${densidadeFormatada.substring(0, 3)}';
        } else {
          densidadeFormatada = '0,$densidadeFormatada';
        }
      }
      
      String nomeColuna;
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          parteDecimal = parteDecimal.padRight(4, '0');
          
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          String densidade5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');
          
          if (densidade5Digitos.length > 5) {
            densidade5Digitos = densidade5Digitos.substring(0, 5);
          }
          
          nomeColuna = 'd_$densidade5Digitos';
        } else {
          return '-';
        }
      } else {
        return '-';
      }
      
      final nomeView = usarViewAnidroHidratado 
          ? 'tcd_anidro_hidratado_vw' 
          : 'tcd_gasolina_diesel_vw';
      
      String _formatarResultado(String valorBruto) {
        String valorLimpo = valorBruto.trim();
        valorLimpo = valorLimpo.replaceAll('.', ',');
        
        if (!valorLimpo.contains(',')) {
          valorLimpo = '$valorLimpo,0';
        }
        
        final partes = valorLimpo.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          parteDecimal = parteDecimal.padRight(4, '0');
          
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          return '$parteInteira,$parteDecimal';
        }
        
        return valorLimpo;
      }
      
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();
      
      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        return _formatarResultado(valorBruto);
      }
      
      List<String> formatosParaTentar = [];
      
      if (temperaturaFormatada.contains(',')) {
        final partes = temperaturaFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          if (usarViewAnidroHidratado) {
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',
              '$parteInteira,${parteDecimal}0',
              '$parteInteira,${parteDecimal.padLeft(2, '0')}',
              '$parteInteira,0$parteDecimal',
            ]);
            
            if (parteDecimal.length == 1) {
              formatosParaTentar.add('$parteInteira,${parteDecimal}0');
            }
            
            if (parteDecimal.length == 2) {
              formatosParaTentar.add('$parteInteira,${parteDecimal.substring(0, 1)}');
            }
          } else {
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',
              '$parteInteira,${parteDecimal}0',
              '$parteInteira,0',
            ]);
          }
        }
      } else {
        if (usarViewAnidroHidratado) {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,00',
            '$temperaturaFormatada,0',
            temperaturaFormatada,
          ]);
        } else {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,0',
            temperaturaFormatada,
            '$temperaturaFormatada,00',
          ]);
        }
      }
      
      final formatosComPonto = formatosParaTentar.map((f) => f.replaceAll(',', '.')).toList();
      formatosParaTentar.addAll(formatosComPonto);
      formatosParaTentar = formatosParaTentar.toSet().toList();
      
      for (final formatoTemp in formatosParaTentar) {
        try {
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();
          
          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            return _formatarResultado(valorBruto);
          }
        } catch (e) {
          continue;
        }
      }
      
      return '-';
      
    } catch (e) {
      return '-';
    }
  }

  Future<String> _buscarFCV({
    required String temperaturaTanque,
    required String densidade20C,
    required String produtoNome,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      if (temperaturaTanque.isEmpty ||
          temperaturaTanque == '-' ||
          densidade20C.isEmpty ||
          densidade20C == '-') {
        return '-';
      }

      String nomeView;
      final nomeProdutoLower = produtoNome.toLowerCase().trim();

      if (nomeProdutoLower.contains('anidro') ||
          nomeProdutoLower.contains('hidratado')) {
        nomeView = 'tcv_anidro_hidratado_vw';
      } else {
        nomeView = 'tcv_gasolina_diesel_vw';
      }

      String temperaturaFormatada = temperaturaTanque
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();

      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');

      String densidadeFormatada = densidade20C
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();

      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');

      // CORREÇÃO: Se densidade for maior que 0,8780, usar 0,8780
      final densidadeNum = double.tryParse(densidadeFormatada.replaceAll(',', '.'));
      final densidadeLimite = 0.8780;
      
      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        densidadeFormatada = '0,8780';        
      }

      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];

          if (parteDecimal.length >= 4) {
            String tresPrimeiros = parteDecimal.substring(0, 3);
            parteDecimal = '${tresPrimeiros}0';
          } else if (parteDecimal.length == 3) {
            parteDecimal = '${parteDecimal}0';
          } else {
            parteDecimal = parteDecimal.padRight(4, '0');
          }

          densidadeFormatada = '$parteInteira,$parteDecimal';
        } else {
          return '-';
        }
      } else {
        if (densidadeFormatada.length == 4) {
          densidadeFormatada = '0,${densidadeFormatada.substring(0, 3)}0';
        } else {
          densidadeFormatada = '0,${densidadeFormatada}0';
        }
      }

      String nomeColuna;
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];

          parteDecimal = parteDecimal.padRight(4, '0');

          String codigo5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');

          if (codigo5Digitos.length > 5) {
            codigo5Digitos = codigo5Digitos.substring(0, 5);
          }

          nomeColuna = 'v_$codigo5Digitos';
        } else {
          return '-';
        }
      } else {
        return '-';
      }

      String _formatarResultadoFCV(String valorBruto) {
        String valorLimpo = valorBruto.trim();
        valorLimpo = valorLimpo.replaceAll('.', ',');

        if (!valorLimpo.contains(',')) {
          valorLimpo = '$valorLimpo,0';
        }

        final partes = valorLimpo.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];

          parteDecimal = parteDecimal.padRight(4, '0');

          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }

          return '$parteInteira,$parteDecimal';
        }

        return valorLimpo;
      }

      // Busca inicial
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();

      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        final valorFormatado = _formatarResultadoFCV(valorBruto);
        return valorFormatado;
      }

      // Se a densidade já foi ajustada para 0,8780 e ainda não encontrou,
      // não tenta densidades menores
      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        // Tenta apenas com a coluna 08780
        final coluna08780 = 'v_08780';
        try {
          final resultado08780 = await supabase
              .from(nomeView)
              .select(coluna08780)
              .eq('temperatura_obs', temperaturaFormatada)
              .maybeSingle();

          if (resultado08780 != null && resultado08780[coluna08780] != null) {
            String valorBruto = resultado08780[coluna08780].toString();
            return _formatarResultadoFCV(valorBruto);
          }
        } catch (e) {
          // Continua para os fallbacks de temperatura
        }
      } else {
        // Busca por densidades próximas (apenas se densidade não foi ajustada para 0,8780)
        if (densidadeFormatada.contains(',')) {
          final partes = densidadeFormatada.split(',');
          if (partes.length == 2) {
            final densidadeNumAtual = double.tryParse(
              densidadeFormatada.replaceAll(',', '.')
            );

            if (densidadeNumAtual != null) {
              final List<String> densidadesParaTentar = [];
              final double passo = 0.0010;

              // Começa com a densidade atual e depois tenta valores menores
              // Não tenta valores maiores se já está próximo do limite
              for (double delta = 0.0; delta >= -0.0050; delta -= passo) {
                final double densidadeTeste = densidadeNumAtual + delta;
                
                // Não vai abaixo de 0,6500 (assumindo que seja o mínimo)
                if (densidadeTeste < 0.6500) break;
                
                final String densidadeTesteStr = densidadeTeste.toStringAsFixed(4);
                final String densidadeTesteFormatada = densidadeTesteStr.replaceAll('.', ',');

                if (densidadeTesteFormatada.contains(',')) {
                  final partesTeste = densidadeTesteFormatada.split(',');
                  if (partesTeste.length == 2) {
                    String parteInteiraTeste = partesTeste[0];
                    String parteDecimalTeste = partesTeste[1];

                    if (parteDecimalTeste.length >= 4) {
                      parteDecimalTeste = '${parteDecimalTeste.substring(0, 3)}0';
                    } else if (parteDecimalTeste.length == 3) {
                      parteDecimalTeste = '${parteDecimalTeste}0';
                    }

                    String codigo5DigitosTeste = '${parteInteiraTeste}${parteDecimalTeste}'.padLeft(5, '0');
                    if (codigo5DigitosTeste.length > 5) {
                      codigo5DigitosTeste = codigo5DigitosTeste.substring(0, 5);
                    }

                    final colunaProxima = 'v_$codigo5DigitosTeste';
                    densidadesParaTentar.add(colunaProxima);
                  }
                }
              }

              final densidadesUnicas = densidadesParaTentar.toSet().toList();

              for (final colunaProxima in densidadesUnicas) {
                try {
                  final resultadoProximo = await supabase
                      .from(nomeView)
                      .select(colunaProxima)
                      .eq('temperatura_obs', temperaturaFormatada)
                      .maybeSingle();

                  if (resultadoProximo != null && resultadoProximo[colunaProxima] != null) {
                    String valorBruto = resultadoProximo[colunaProxima].toString();
                    final valorFormatado = _formatarResultadoFCV(valorBruto);
                    return valorFormatado;
                  }
                } catch (e) {
                  continue;
                }
              }
            }
          }
        }
      }

      // Fallback para formatos alternativos de temperatura
      List<String> temperaturasParaTentar = [];

      if (temperaturaFormatada.contains(',')) {
        final partes = temperaturaFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];

          temperaturasParaTentar.addAll([
            '$parteInteira,$parteDecimal',
            '$parteInteira,${parteDecimal}0',
            '$parteInteira,${parteDecimal.padLeft(2, '0')}',
            '$parteInteira,0$parteDecimal',
          ]);

          if (parteDecimal.length == 1) {
            temperaturasParaTentar.add('$parteInteira,${parteDecimal}0');
          }
        }
      } else {
        temperaturasParaTentar.addAll([
          '$temperaturaFormatada,0',
          '$temperaturaFormatada,00',
          temperaturaFormatada,
        ]);
      }

      final temperaturasComPonto = temperaturasParaTentar.map((f) => f.replaceAll(',', '.')).toList();
      temperaturasParaTentar.addAll(temperaturasComPonto);
      temperaturasParaTentar = temperaturasParaTentar.toSet().toList();

      for (final formatoTemp in temperaturasParaTentar) {
        try {
          // Tenta com a coluna original
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();

          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            final valorFormatado = _formatarResultadoFCV(valorBruto);
            return valorFormatado;
          }
          
          // Se densidade > 0,8780, tenta com a coluna 08780
          if (densidadeNum != null && densidadeNum > densidadeLimite) {
            final coluna08780 = 'v_08780';
            final resultado08780 = await supabase
                .from(nomeView)
                .select(coluna08780)
                .eq('temperatura_obs', formatoTemp)
                .maybeSingle();

            if (resultado08780 != null && resultado08780[coluna08780] != null) {
              String valorBruto = resultado08780[coluna08780].toString();
              return _formatarResultadoFCV(valorBruto);
            }
          }
        } catch (e) {
          continue;
        }
      }

      return '-';
    } catch (e) {
      return '-';
    }
  }

  Future<void> _calcularMassa() async {
    final medicoes = widget.dadosFormulario['medicoes'];
    
    // Para 1ª medição (Manhã) - Volume20 × Densidade20
    if (medicoes['volume20Manha'] != null && 
        medicoes['volume20Manha'].toString().isNotEmpty &&
        medicoes['volume20Manha'].toString() != '-' &&
        medicoes['densidade20Manha'] != null &&
        medicoes['densidade20Manha'].toString().isNotEmpty &&
        medicoes['densidade20Manha'].toString() != '-') {
      
      try {
        // Converter volume a 20ºC formatado para double
        final volume20Manha = _converterVolumeParaDouble(medicoes['volume20Manha'].toString());
        
        // Converter densidade a 20ºC para double
        final densidade20Manha = double.tryParse(
          medicoes['densidade20Manha'].toString()
              .replaceAll(' kg/L', '')
              .replaceAll(',', '.')
              .trim()
        ) ?? 0.0;
        
        // Cálculo da massa: Volume a 20ºC × Densidade a 20ºC
        final massaManha = volume20Manha * densidade20Manha;
        
        // Formatar massa: ponto como milhar, vírgula como decimal, 1 casa decimal
        final massaManhaFormatada = _formatarMassa(massaManha);
        
        widget.dadosFormulario['medicoes']['massaManha'] = massaManhaFormatada;
      } catch (e) {
        widget.dadosFormulario['medicoes']['massaManha'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['massaManha'] = '-';
    }
    
    // Para 2ª medição (Tarde) - Volume20 × Densidade20
    if (medicoes['volume20Tarde'] != null && 
        medicoes['volume20Tarde'].toString().isNotEmpty &&
        medicoes['volume20Tarde'].toString() != '-' &&
        medicoes['densidade20Tarde'] != null &&
        medicoes['densidade20Tarde'].toString().isNotEmpty &&
        medicoes['densidade20Tarde'].toString() != '-') {
      
      try {
        // Converter volume a 20ºC formatado para double
        final volume20Tarde = _converterVolumeParaDouble(medicoes['volume20Tarde'].toString());
        
        // Converter densidade a 20ºC para double
        final densidade20Tarde = double.tryParse(
          medicoes['densidade20Tarde'].toString()
              .replaceAll(' kg/L', '')
              .replaceAll(',', '.')
              .trim()
        ) ?? 0.0;
        
        // Cálculo da massa: Volume a 20ºC × Densidade a 20ºC
        final massaTarde = volume20Tarde * densidade20Tarde;
        
        // Formatar massa: ponto como milhar, vírgula como decimal, 1 casa decimal
        final massaTardeFormatada = _formatarMassa(massaTarde);
        
        widget.dadosFormulario['medicoes']['massaTarde'] = massaTardeFormatada;
      } catch (e) {
        widget.dadosFormulario['medicoes']['massaTarde'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['massaTarde'] = '-';
    }
  }

  String _formatarMassa(double massa) {
    try {
      if (massa.isNaN || massa.isInfinite || massa == 0.0) {
        return '-';
      }
      
      // Arredonda para 1 casa decimal
      final massaArredondada = massa.toStringAsFixed(1);
      
      // Separa parte inteira e decimal
      final partes = massaArredondada.split('.');
      if (partes.length != 2) {
        return massaArredondada;
      }
      
      String parteInteira = partes[0];
      String parteDecimal = partes[1];
      
      // Formata parte inteira com pontos como separadores de milhar
      String parteInteiraFormatada = '';
      int contador = 0;
      
      // Percorre de trás para frente para adicionar pontos
      for (int i = parteInteira.length - 1; i >= 0; i--) {
        parteInteiraFormatada = parteInteira[i] + parteInteiraFormatada;
        contador++;
        
        // Adiciona ponto a cada 3 dígitos (exceto no início)
        if (contador == 3 && i > 0) {
          parteInteiraFormatada = '.$parteInteiraFormatada';
          contador = 0;
        }
      }
      
      // Retorna no formato: "194.458,3"
      return '$parteInteiraFormatada,$parteDecimal';
      
    } catch (e) {
      return '-';
    }
  }

  double _converterVolumeParaDouble(String volumeStr) {
    try {
      
      // Remove "L" e espaços
      String limpo = volumeStr.replaceAll(' L', '').trim();
      
      // Se estiver vazio após limpar, retorna 0
      if (limpo.isEmpty || limpo == '-') {
        return 0.0;
      }
      
      // Remove pontos usados como separadores de milhar (formato: 1.500)
      if (limpo.contains('.')) {
        // Verifica se é formato brasileiro (ponto como separador de milhar)
        final partes = limpo.split('.');
        if (partes.length > 1) {
          // Se a última parte tem 3 dígitos, provavelmente é separador de milhar
          if (partes.last.length == 3) {
            limpo = limpo.replaceAll('.', '');
          } else {
            // Caso contrário, trata como decimal (substitui ponto por vírgula)
            limpo = limpo.replaceAll('.', ',');
          }
        } else {
          limpo = limpo.replaceAll('.', '');
        }
      }
      
      // Converte vírgula para ponto para parse
      limpo = limpo.replaceAll(',', '.');
      
      return double.tryParse(limpo) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _extrairNumero(String? valor) {
    if (valor == null) return 0;

    final somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (somenteNumeros.isEmpty) return 0;

    return double.tryParse(somenteNumeros) ?? 0;
  }

  Widget _blocoFaturado({
    required Map<String, dynamic> medicoes,
  }) {
    // Função para formatar no padrão "999.999 L" - Corrigida para negativos
    String fmt(num v) {
      if (v.isNaN) return "-";
      
      // Arredonda e converte para inteiro
      final volumeInteiro = v.round();
      
      // Converte para string e remove sinal negativo temporariamente
      final isNegativo = volumeInteiro < 0;
      String inteiroFormatado = volumeInteiro.abs().toString();
      
      // Adiciona pontos como separadores de milhar
      if (inteiroFormatado.length > 3) {
        final buffer = StringBuffer();
        int contador = 0;
        
        for (int i = inteiroFormatado.length - 1; i >= 0; i--) {
          buffer.write(inteiroFormatado[i]);
          contador++;
          
          if (contador == 3 && i > 0) {
            buffer.write('.');
            contador = 0;
          }
        }
        
        final chars = buffer.toString().split('').reversed.toList();
        inteiroFormatado = chars.join('');
      }
      
      // Adiciona sinal negativo se necessário
      final sinal = isNegativo ? '-' : '';
      return '$sinal$inteiroFormatado L';
    }

    // Função para formatar porcentagem com 2 casas decimais
    String fmtPercent(double v) {
      if (v.isNaN || v.isInfinite) return "-";
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
    }

    // Pega o valor do usuário para "Faturado"
    final faturadoUsuarioStr = medicoes['faturadoTarde']?.toString() ?? '';
    
    // Converte para double (se não for vazio)
    double faturadoUsuario = 0.0;
    if (faturadoUsuarioStr.isNotEmpty && faturadoUsuarioStr != '-') {
      try {
        // Remove pontos de milhar e converte vírgula para ponto
        String limpo = faturadoUsuarioStr.replaceAll('.', '').replaceAll(',', '.');
        faturadoUsuario = double.tryParse(limpo) ?? 0.0;
      } catch (e) {
        faturadoUsuario = 0.0;
      }
    }
    
    // Pega os volumes
    final volume20Tarde = _extrairNumero(medicoes['volume20Tarde']?.toString());
    final volume20Manha = _extrairNumero(medicoes['volume20Manha']?.toString());
    
    // Cálculo da diferença: Volume a 20ºC - Faturado
    final entradaSaida20 = volume20Tarde - volume20Manha;
    final diferenca = entradaSaida20 - faturadoUsuario;
    
    // Formata
    final faturadoFormatado = faturadoUsuario > 0 ? fmt(faturadoUsuario) : "-";
    final diferencaFormatada = fmt(diferenca);
    
    // Porcentagem
    final entradaSaida20Double = entradaSaida20.toDouble();
    final porcentagem = entradaSaida20Double != 0 ? (diferenca.toDouble() / entradaSaida20Double) * 100 : 0.0;
    final porcentagemFormatada = fmtPercent(porcentagem);
    
    // Concatenação: "-114 L | -0,36%"
    final concatenacao = '$diferencaFormatada  |  $porcentagemFormatada';

    // REGRAS DE CORES:
    // 1. "Faturado": cor automática (preto) - REMOVER O VERDE
    // 2. "Diferença": vermelho se negativo, azul se positivo
    final corDiferenca = diferenca < 0 ? Colors.red[700] : Colors.blue[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 7, child: SizedBox()),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Table(
                  defaultColumnWidth: IntrinsicColumnWidth(),
                  border: TableBorder.all(color: Colors.black54),
                  children: [
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Color(0xFFF5F5F5),
                          child: Center(
                            child: Text(
                              "Faturado",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              faturadoFormatado,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87, // ALTERADO: COR AUTOMÁTICA (PRETO)
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Color(0xFFF5F5F5),
                          child: Center(
                            child: Text(
                              "Diferença",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              concatenacao,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: corDiferenca, // ALTERADO: COR CONDICIONAL
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 140),
          child: Text(
            "Diferença = Volume a 20ºC - Faturado",
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

}