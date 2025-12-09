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

    final alturaProdutoManha = medicoes['alturaProdutoManha'];
    final alturaProdutoTarde = medicoes['alturaProdutoTarde'];
    final alturaAguaManha = medicoes['alturaAguaManha'];
    final alturaAguaTarde = medicoes['alturaAguaTarde'];

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

    final produtoCmMmManha = extrairCmMm(alturaProdutoManha);
    final produtoCmMmTarde = extrairCmMm(alturaProdutoTarde);
    final aguaCmMmManha = extrairCmMm(alturaAguaManha);
    final aguaCmMmTarde = extrairCmMm(alturaAguaTarde);

    final volProdutoManha = await _buscarVolumeReal(produtoCmMmManha['cm'], produtoCmMmManha['mm']);
    final volProdutoTarde = await _buscarVolumeReal(produtoCmMmTarde['cm'], produtoCmMmTarde['mm']);
    final volAguaManha = await _buscarVolumeReal(aguaCmMmManha['cm'], aguaCmMmManha['mm']);
    final volAguaTarde = await _buscarVolumeReal(aguaCmMmTarde['cm'], aguaCmMmTarde['mm']);

    final volumeTotalLiquidoManha = volProdutoManha + volAguaManha;
    final volumeTotalLiquidoTarde = volProdutoTarde + volAguaTarde;

    final volumeCanalizacaoManhaStr = medicoes['volumeCanalizacaoManha']?.toString() ?? '0';
    final volumeCanalizacaoTardeStr = medicoes['volumeCanalizacaoTarde']?.toString() ?? '0';
    
    double converterVolumeString(String volumeStr) {
      if (volumeStr == '-' || volumeStr.isEmpty) {
        return 0;
      }
      
      try {
        String limpo = volumeStr.replaceAll(' L', '').trim();
        limpo = limpo.replaceAll('.', '');
        limpo = limpo.replaceAll(',', '.');
        
        return double.tryParse(limpo) ?? 0;
      } catch (e) {
        return 0;
      }
    }

    final volumeCanalizacaoManha = converterVolumeString(volumeCanalizacaoManhaStr);
    final volumeCanalizacaoTarde = converterVolumeString(volumeCanalizacaoTardeStr);

    final volumeTotalManha = volProdutoManha + volumeCanalizacaoManha;
    final volumeTotalTarde = volProdutoTarde + volumeCanalizacaoTarde;

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
      
      if (valor is String) {
        final str = valor.trim();
        
        if (str.contains('.') && str.split('.')[1].length == 3) {
          final semPonto = str.replaceAll('.', '');
          return double.tryParse(semPonto) ?? 0.0;
        }
        
        return double.tryParse(str.replaceAll(',', '.')) ?? 0.0;
      }
      
      if (valor is num) {
        final numVal = valor.toDouble();
        
        if (numVal < 1000 && numVal.toString().contains('.')) {
          final strVal = numVal.toString();
          final partes = strVal.split('.');
          
          if (partes.length == 2 && partes[1].length == 3) {
            return numVal * 1000;
          }
        }
        
        return numVal;
      }
      
      return 0.0;
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
                    _linhaMedicao("Altura do produto aferido no tanque:", 
                        _obterValorMedicao(medicoes['alturaProdutoManha']), 
                        _obterValorMedicao(medicoes['alturaProdutoTarde'])),
                    _linhaMedicao(
                      "Volume correspondente ao produto (temp. ambiente):",
                      _formatarVolumeLitros(volumeManha),
                      _formatarVolumeLitros(volumeTarde),
                    ),
                    _linhaMedicao("Volume correspondente à água:", 
                        _obterValorMedicao(medicoes['volumeAguaManha']), 
                        _obterValorMedicao(medicoes['volumeAguaTarde'])),
                    _linhaMedicao("Volume em litros do produto na tubulação:", 
                        _obterValorMedicao(medicoes['volumeCanalizacaoManha']), 
                        _obterValorMedicao(medicoes['volumeCanalizacaoTarde'])),
                    _linhaMedicao("Volume total em litros do produto no tanque e na tubulação:", 
                        _obterValorMedicao(medicoes['volumeTotalManha']), 
                        _obterValorMedicao(medicoes['volumeTotalTarde'])),                    
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

                  _subtitulo("COMPARAÇÃO DOS RESULTADOS"),
                  const SizedBox(height: 8),

                  _tabela([
                    ["Litros a Ambiente", _calcularLitrosAmbiente(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Litros a 20 °C", _calcularLitros20C(medicoes['cmManha'], medicoes['mmManha'], medicoes['densidadeManha'], medicoes['tempTanqueManha'])],
                  ]),

                  const SizedBox(height: 25),

                  _subtitulo("MANIFESTAÇÃO"),
                  const SizedBox(height: 8),

                  _tabela([
                    ["Recebido", _calcularRecebido(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Diferença", _calcularDiferenca(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Percentual", _calcularPercentual(medicoes['cmManha'], medicoes['mmManha'])],
                  ]),

                  const SizedBox(height: 25),

                  _subtitulo("ABERTURA / ENTRADA / SAÍDA / SALDO"),
                  const SizedBox(height: 8),

                  _tabela([
                    ["Abertura", _calcularAbertura()],
                    ["Entrada", _calcularEntrada(medicoes['cmManha'], medicoes['mmManha'])],
                    ["Saída", _calcularSaida()],
                    ["Saldo Final", _calcularSaldoFinal(medicoes['cmManha'], medicoes['mmManha'])],
                  ]),

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

  String _obterValorMedicao(dynamic valor) {
    if (valor == null) return "-";

    if (valor is String) {
      final v = valor.trim();

      if (v.isEmpty) return "-";

      // Interpreta "cm,mm cm"
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
    final volume = alturaTotal * 100;
    return '${volume.toStringAsFixed(0)} L';
  }

  String _calcularVolumeA20(String? cm, String? mm, String? densidade, String? temperatura) {
    if (cm == null || cm.isEmpty) return "-";
    final volumeAmbiente = _calcularVolume(cm, mm);    
    return volumeAmbiente;
  }

  String _calcularRecebido(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final volumeRecebido = cmValue * 95;
    return '${volumeRecebido.toStringAsFixed(0)} L';
  }

  String _calcularDiferenca(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final diferenca = cmValue * 2;
    return '${diferenca.toStringAsFixed(0)} L';
  }

  String _calcularPercentual(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final cmValue = double.tryParse(cm.replaceAll(',', '.')) ?? 0;
    final percentual = (cmValue * 0.5);
    return '${percentual.toStringAsFixed(1)} %';
  }

  String _calcularAbertura() {
    return "1.500 L";
  }

  String _calcularEntrada(String? cm, String? mm) {
    return _calcularRecebido(cm, mm);
  }

  String _calcularSaida() {
    return "850 L";
  }

  String _calcularSaldoFinal(String? cm, String? mm) {
    if (cm == null || cm.isEmpty) return "-";
    final abertura = 1500.0;
    final entrada = double.tryParse(_calcularRecebido(cm, mm).replaceAll(' L', '')) ?? 0;
    final saida = 850.0;
    final saldo = abertura + entrada - saida;
    return '${saldo.toStringAsFixed(0)} L';
  }

  String _formatarVolumeLitros(double volume) {
    // Arredondar para número inteiro (sem casas decimais)
    final volumeInteiro = volume.round();
    
    // Formatar parte inteira com pontos
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
    
    // Remover ºC se já existir para evitar duplicação
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
      print('🚀 INICIANDO BUSCA DENSIDADE 20°C');
      print('📥 Entrada - Temp: "$temperaturaAmostra", Dens: "$densidadeObservada", Produto: "$produtoNome"');
      
      if (temperaturaAmostra.isEmpty || densidadeObservada.isEmpty) {
        print('❌ Dados vazios');
        return '-';
      }
      
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      final bool usarViewAnidroHidratado = 
          nomeProdutoLower.contains('anidro') || 
          nomeProdutoLower.contains('hidratado');
      
      print('📊 View selecionada: ${usarViewAnidroHidratado ? "Anidro/Hidratado" : "Gasolina/Diesel"}');
      
      // Limpar temperatura (manter formatação original)
      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      // Converte ponto para vírgula para padronizar
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      print('🔧 Temperatura formatada: "$temperaturaFormatada"');
      
      // Formatar densidade para nome da coluna
      String densidadeFormatada = densidadeObservada
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();
      
      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');
      print('🔧 Densidade formatada: "$densidadeFormatada"');
      
      // Garantir formato com vírgula (ex: "0,7800")
      if (!densidadeFormatada.contains(',')) {
        if (densidadeFormatada.length == 4) {
          densidadeFormatada = '0,${densidadeFormatada.substring(0, 3)}';
        } else {
          densidadeFormatada = '0,$densidadeFormatada';
        }
        print('🔧 Densidade ajustada: "$densidadeFormatada"');
      }
      
      // Converter densidade para nome de coluna (5 dígitos)
      String nomeColuna;
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0]; // "0"
          String parteDecimal = partes[1]; // "7800" ou "8010"
          
          // Completa com zeros à direita para ter 4 dígitos decimais
          parteDecimal = parteDecimal.padRight(4, '0');
          
          // Corta se tiver mais de 4 dígitos
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          // Junta: "0" + "7800" = "07800"
          String densidade5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');
          
          // Garante exatamente 5 dígitos
          if (densidade5Digitos.length > 5) {
            densidade5Digitos = densidade5Digitos.substring(0, 5);
          }
          
          nomeColuna = 'd_$densidade5Digitos';
          print('🔢 Densidade para coluna: $densidade5Digitos → $nomeColuna');
        } else {
          print('❌ Formato de densidade inválido');
          return '-';
        }
      } else {
        print('❌ Densidade sem vírgula');
        return '-';
      }
      
      final nomeView = usarViewAnidroHidratado 
          ? 'tcd_anidro_hidratado_vw' 
          : 'tcd_gasolina_diesel_vw';
      
      print('🗂️ View: $nomeView');
      print('🔍 Buscando: temperatura_obs = "$temperaturaFormatada", coluna = "$nomeColuna"');
      
      // FUNÇÃO PARA FORMATAR O RESULTADO (completar com zeros até 4 casas)
      String _formatarResultado(String valorBruto) {
        print('   🔧 Valor bruto da tabela: "$valorBruto"');
        
        // Remove espaços
        String valorLimpo = valorBruto.trim();
        
        // Converte ponto para vírgula se necessário
        valorLimpo = valorLimpo.replaceAll('.', ',');
        
        // Se não tem vírgula, adiciona uma
        if (!valorLimpo.contains(',')) {
          valorLimpo = '$valorLimpo,0';
        }
        
        // Separa parte inteira e decimal
        final partes = valorLimpo.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          // Completa a parte decimal com zeros até 4 casas
          parteDecimal = parteDecimal.padRight(4, '0');
          
          // Se tiver mais de 4 dígitos, corta (mantém apenas 4)
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          String resultado = '$parteInteira,$parteDecimal';
          print('   🔧 Valor formatado (4 casas): "$resultado"');
          return resultado;
        }
        
        return valorLimpo;
      }
      
      // PRIMEIRA TENTATIVA: com o formato exato da temperatura
      try {
        final resultado = await supabase
            .from(nomeView)
            .select(nomeColuna)
            .eq('temperatura_obs', temperaturaFormatada)
            .maybeSingle();
        
        if (resultado != null && resultado[nomeColuna] != null) {
          String valorBruto = resultado[nomeColuna].toString();
          String valorFormatado = _formatarResultado(valorBruto);
          print('✅ VALOR ENCONTRADO (formato exato): $valorBruto → $valorFormatado');
          return valorFormatado;
        } else {
          print('❌ Nenhum resultado com formato exato');
        }
      } catch (e) {
        print('❌ Erro na busca com formato exato: ${e.toString().split('\n').first}');
      }
      
      // SEGUNDA TENTATIVA: diferentes formatos de temperatura
      print('🔄 Tentando diferentes formatos de temperatura...');
      
      List<String> formatosParaTentar = [];
      
      if (temperaturaFormatada.contains(',')) {
        final partes = temperaturaFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          if (usarViewAnidroHidratado) {
            // Para Anidro/Hidratado: pode ser "25,5" ou "25,50" ou "25,0" ou "25,00"
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',           // "25,5"
              '$parteInteira,${parteDecimal}0',        // "25,50"
              '$parteInteira,${parteDecimal.padLeft(2, '0')}', // "25,05" se parteDecimal = "5"
              '$parteInteira,0$parteDecimal',          // "25,05" alternativa
            ]);
            
            // Se parteDecimal tem 1 dígito, tentar com 2
            if (parteDecimal.length == 1) {
              formatosParaTentar.add('$parteInteira,${parteDecimal}0'); // "25,50"
            }
            
            // Se parteDecimal tem 2 dígitos, tentar com 1
            if (parteDecimal.length == 2) {
              formatosParaTentar.add('$parteInteira,${parteDecimal.substring(0, 1)}'); // "25,5"
            }
          } else {
            // Para Gasolina/Diesel: pode ser "25,5" ou "25,0"
            formatosParaTentar.addAll([
              '$parteInteira,$parteDecimal',           // "25,5"
              '$parteInteira,${parteDecimal}0',        // "25,50"
              '$parteInteira,0',                       // "25,0" (se parteDecimal for "0" ou vazio)
            ]);
          }
        }
      } else {
        // Temperatura sem vírgula (inteira)
        if (usarViewAnidroHidratado) {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,00',                // "25,00"
            '$temperaturaFormatada,0',                 // "25,0"
            temperaturaFormatada,                      // "25"
          ]);
        } else {
          formatosParaTentar.addAll([
            '$temperaturaFormatada,0',                 // "25,0"
            temperaturaFormatada,                      // "25"
            '$temperaturaFormatada,00',                // "25,00"
          ]);
        }
      }
      
      // Adicionar formatos com ponto (caso a tabela use ponto)
      final formatosComPonto = formatosParaTentar.map((f) => f.replaceAll(',', '.')).toList();
      formatosParaTentar.addAll(formatosComPonto);
      
      // Remover duplicados
      formatosParaTentar = formatosParaTentar.toSet().toList();
      
      print('📋 Formatos a tentar:');
      for (final formato in formatosParaTentar) {
        print('   - "$formato"');
      }
      
      for (final formatoTemp in formatosParaTentar) {
        try {
          print('   🔎 Buscando com formato: "$formatoTemp"');
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();
          
          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            String valorFormatado = _formatarResultado(valorBruto);
            print('   ✅ VALOR ENCONTRADO (formato "$formatoTemp"): $valorBruto → $valorFormatado');
            return valorFormatado;
          }
        } catch (e) {
          print('   ❌ Erro com formato "$formatoTemp": ${e.toString().split('\n').first}');
        }
      }
      
      // DEBUG: Verificar que existe na tabela
      print('🔍 Verificando se a temperatura existe na view...');
      try {
        final temperaturas = await supabase
            .from(nomeView)
            .select('temperatura_obs')
            .limit(10);
        
        if (temperaturas.isNotEmpty) {
          print('📋 Temperaturas disponíveis (primeiras 10):');
          for (final temp in temperaturas) {
            print('   - "${temp['temperatura_obs']}"');
          }
        }
      } catch (e) {
        print('   ❌ Não foi possível listar temperaturas');
      }
      
      print('❌ Nenhum valor encontrado na tabela');
      return '-';
      
    } catch (e) {
      print('💥 ERRO CRÍTICO: $e');
      return '-';
    }
  }

}