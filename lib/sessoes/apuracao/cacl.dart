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
    print('==========================================');
    print('🚀 INICIANDO _calcularVolumesIniciais()');
    print('==========================================');
    
    final medicoes = widget.dadosFormulario['medicoes'];
    
    print('📊 Dados do formulário:');
    print('• Data: ${widget.dadosFormulario['data']}');
    print('• Base: ${widget.dadosFormulario['base']}');
    print('• Produto: ${widget.dadosFormulario['produto']}');
    print('• Tanque: ${widget.dadosFormulario['tanque']}');
    print('• Filial ID: ${widget.dadosFormulario['filial_id']}');
    
    final alturaAguaManha = medicoes['alturaAguaManha'];
    final alturaAguaTarde = medicoes['alturaAguaTarde'];

    final alturaTotalCmManha = medicoes['cmManha']?.toString() ?? '';
    final alturaTotalMmManha = medicoes['mmManha']?.toString() ?? '';
    final alturaTotalCmTarde = medicoes['cmTarde']?.toString() ?? '';
    final alturaTotalMmTarde = medicoes['mmTarde']?.toString() ?? '';

    print('📐 Alturas totais:');
    print('• Manhã: $alturaTotalCmManha cm, $alturaTotalMmManha mm');
    print('• Tarde: $alturaTotalCmTarde cm, $alturaTotalMmTarde mm');
    print('• Água Manhã: $alturaAguaManha');
    print('• Água Tarde: $alturaAguaTarde');

    Map<String, String?> extrairCmMm(String? alturaFormatada) {
      if (alturaFormatada == null || alturaFormatada.isEmpty || alturaFormatada == '-') {
        print('   ⚠️ Altura vazia ou inválida: "$alturaFormatada"');
        return {'cm': null, 'mm': null};
      }
      
      try {
        final semUnidade = alturaFormatada.replaceAll(' cm', '').trim();
        final partes = semUnidade.split(',');
        
        print('   🔧 Extraindo altura: "$alturaFormatada"');
        print('   🔧 Sem unidade: "$semUnidade"');
        print('   🔧 Partes: $partes');
        
        if (partes.length == 2) {
          return {'cm': partes[0], 'mm': partes[1]};
        } else if (partes.length == 1) {
          return {'cm': partes[0], 'mm': '0'};
        } else {
          return {'cm': null, 'mm': null};
        }
      } catch (e) {
        print('   ❌ Erro ao extrair altura: $e');
        return {'cm': null, 'mm': null};
      }
    }
    
    final aguaCmMmManha = extrairCmMm(alturaAguaManha);
    final aguaCmMmTarde = extrairCmMm(alturaAguaTarde);

    print('📏 Alturas da água extraídas:');
    print('• Manhã: cm=${aguaCmMmManha['cm']}, mm=${aguaCmMmManha['mm']}');
    print('• Tarde: cm=${aguaCmMmTarde['cm']}, mm=${aguaCmMmTarde['mm']}');

    final Map<String, String?> totalCmMmManha = {
      'cm': alturaTotalCmManha.isEmpty ? null : alturaTotalCmManha,
      'mm': alturaTotalMmManha.isEmpty ? null : alturaTotalMmManha
    };
    
    final Map<String, String?> totalCmMmTarde = {
      'cm': alturaTotalCmTarde.isEmpty ? null : alturaTotalCmTarde,
      'mm': alturaTotalMmTarde.isEmpty ? null : alturaTotalMmTarde
    };

    print('📈 Buscando volumes reais...');
    
    // Calcular volumes reais
    final volumeTotalLiquidoManha = await _buscarVolumeReal(totalCmMmManha['cm'], totalCmMmManha['mm']);
    final volumeTotalLiquidoTarde = await _buscarVolumeReal(totalCmMmTarde['cm'], totalCmMmTarde['mm']);
    
    final volAguaManha = await _buscarVolumeReal(aguaCmMmManha['cm'], aguaCmMmManha['mm']);
    final volAguaTarde = await _buscarVolumeReal(aguaCmMmTarde['cm'], aguaCmMmTarde['mm']);

    print('💧 Volumes encontrados:');
    print('• Volume Total Líquido Manhã: $volumeTotalLiquidoManha L');
    print('• Volume Total Líquido Tarde: $volumeTotalLiquidoTarde L');
    print('• Volume Água Manhã: $volAguaManha L');
    print('• Volume Água Tarde: $volAguaTarde L');

    // Calcular volume do produto como VOLUME TOTAL - VOLUME DA ÁGUA
    final volProdutoManha = volumeTotalLiquidoManha - volAguaManha;
    final volProdutoTarde = volumeTotalLiquidoTarde - volAguaTarde;

    print('🛢️ Volumes do produto:');
    print('• Produto Manhã: $volProdutoManha L (Total: $volumeTotalLiquidoManha - Água: $volAguaManha)');
    print('• Produto Tarde: $volProdutoTarde L (Total: $volumeTotalLiquidoTarde - Água: $volAguaTarde)');

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

    print('📝 Formatando volumes...');

    widget.dadosFormulario['medicoes']['volumeProdutoManha'] = volumeProdutoManhaFormatado;
    widget.dadosFormulario['medicoes']['volumeProdutoTarde'] = volumeProdutoTardeFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaManha'] = volumeAguaManhaFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaTarde'] = volumeAguaTardeFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoManha'] = _formatarVolumeLitros(volumeTotalLiquidoManha);
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoTarde'] = _formatarVolumeLitros(volumeTotalLiquidoTarde);
    
    widget.dadosFormulario['medicoes']['volumeTotalManha'] = volumeTotalManhaFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalTarde'] = volumeTotalTardeFormatado;

    print('✅ Volumes formatados e armazenados');

    final produtoNome = widget.dadosFormulario['produto']?.toString() ?? '';
    print('📦 Produto para cálculos: "$produtoNome"');

    print('\n==========================================');
    print('🌡️ CALCULANDO DENSIDADE A 20°C - MANHÃ');
    print('==========================================');
    
    // Calcular densidade a 20°C para manhã
    if (medicoes['tempAmostraManha'] != null && 
        medicoes['tempAmostraManha'].toString().isNotEmpty &&
        medicoes['tempAmostraManha'].toString() != '-' &&
        medicoes['densidadeManha'] != null &&
        medicoes['densidadeManha'].toString().isNotEmpty &&
        medicoes['densidadeManha'].toString() != '-' &&
        produtoNome.isNotEmpty) {
      
      print('📊 Dados para densidade manhã:');
      print('• Temp Amostra: ${medicoes['tempAmostraManha']}');
      print('• Densidade Obs: ${medicoes['densidadeManha']}');
      print('• Produto: $produtoNome');
      
      final densidade20Manha = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraManha'].toString(),
        densidadeObservada: medicoes['densidadeManha'].toString(),
        produtoNome: produtoNome,
      );
      
      print('✅ Densidade 20°C Manhã: $densidade20Manha');
      
      widget.dadosFormulario['medicoes']['densidade20Manha'] = densidade20Manha;
    } else {
      print('⚠️ Dados insuficientes para densidade manhã');
      print('• Temp Amostra: ${medicoes['tempAmostraManha']}');
      print('• Densidade: ${medicoes['densidadeManha']}');
      print('• Produto vazio? ${produtoNome.isEmpty}');
      
      widget.dadosFormulario['medicoes']['densidade20Manha'] = '-';
    }

    print('\n==========================================');
    print('🌡️ CALCULANDO DENSIDADE A 20°C - TARDE');
    print('==========================================');
    
    // Calcular densidade a 20°C para tarde
    if (medicoes['tempAmostraTarde'] != null && 
        medicoes['tempAmostraTarde'].toString().isNotEmpty &&
        medicoes['tempAmostraTarde'].toString() != '-' &&
        medicoes['densidadeTarde'] != null &&
        medicoes['densidadeTarde'].toString().isNotEmpty &&
        medicoes['densidadeTarde'].toString() != '-' &&
        produtoNome.isNotEmpty) {
      
      print('📊 Dados para densidade tarde:');
      print('• Temp Amostra: ${medicoes['tempAmostraTarde']}');
      print('• Densidade Obs: ${medicoes['densidadeTarde']}');
      print('• Produto: $produtoNome');
      
      final densidade20Tarde = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraTarde'].toString(),
        densidadeObservada: medicoes['densidadeTarde'].toString(),
        produtoNome: produtoNome,
      );
      
      print('✅ Densidade 20°C Tarde: $densidade20Tarde');
      
      widget.dadosFormulario['medicoes']['densidade20Tarde'] = densidade20Tarde;
    } else {
      print('⚠️ Dados insuficientes para densidade tarde');
      print('• Temp Amostra: ${medicoes['tempAmostraTarde']}');
      print('• Densidade: ${medicoes['densidadeTarde']}');
      print('• Produto vazio? ${produtoNome.isEmpty}');
      
      widget.dadosFormulario['medicoes']['densidade20Tarde'] = '-';
    }

    print('\n==========================================');
    print('🔍 BUSCANDO FCV - MANHÃ');
    print('==========================================');
    
    // BUSCAR FCV PARA MANHÃ
    if (medicoes['tempTanqueManha'] != null &&
        medicoes['tempTanqueManha'].toString().isNotEmpty &&
        medicoes['tempTanqueManha'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Manha'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Manha'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Manha'].toString() != '-') {
      
      print('📊 Dados para FCV manhã:');
      print('• Temp Tanque: ${medicoes['tempTanqueManha']}');
      print('• Densidade 20°C: ${widget.dadosFormulario['medicoes']['densidade20Manha']}');
      print('• Produto: $produtoNome');
      
      final fcvManha = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueManha'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Manha'].toString(),
        produtoNome: produtoNome,
      );
      
      print('✅ FCV Manhã encontrado: $fcvManha');
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoManha'] = fcvManha;
    } else {
      print('⚠️ Condições não atendidas para FCV manhã');
      print('• Temp Tanque: ${medicoes['tempTanqueManha']}');
      print('• Densidade 20°C: ${widget.dadosFormulario['medicoes']['densidade20Manha']}');
      print('• Produto: $produtoNome');
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoManha'] = '-';
    }

    print('\n==========================================');
    print('🔍 BUSCANDO FCV - TARDE');
    print('==========================================');
    
    // BUSCAR FCV PARA TARDE
    if (medicoes['tempTanqueTarde'] != null &&
        medicoes['tempTanqueTarde'].toString().isNotEmpty &&
        medicoes['tempTanqueTarde'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Tarde'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Tarde'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Tarde'].toString() != '-') {
      
      print('📊 Dados para FCV tarde:');
      print('• Temp Tanque: ${medicoes['tempTanqueTarde']}');
      print('• Densidade 20°C: ${widget.dadosFormulario['medicoes']['densidade20Tarde']}');
      print('• Produto: $produtoNome');
      
      final fcvTarde = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueTarde'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Tarde'].toString(),
        produtoNome: produtoNome,
      );
      
      print('✅ FCV Tarde encontrado: $fcvTarde');
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'] = fcvTarde;
    } else {
      print('⚠️ Condições não atendidas para FCV tarde');
      print('• Temp Tanque: ${medicoes['tempTanqueTarde']}');
      print('• Densidade 20°C: ${widget.dadosFormulario['medicoes']['densidade20Tarde']}');
      print('• Produto: $produtoNome');
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'] = '-';
    }

    print('\n==========================================');
    print('🧮 CALCULANDO VOLUME A 20°C');
    print('==========================================');
    
    // CALCULAR VOLUME A 20°C
    if (widget.dadosFormulario['medicoes']['fatorCorrecaoManha'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoManha'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoManha'].toString() != '-') {
      
      print('📊 Calculando volume 20°C manhã:');
      print('• FCV Manhã: ${widget.dadosFormulario['medicoes']['fatorCorrecaoManha']}');
      print('• Volume Produto Manhã: $volProdutoManha L');
      
      try {
        final fcvManhaStr = widget.dadosFormulario['medicoes']['fatorCorrecaoManha'].toString();
        final fcvManha = double.tryParse(fcvManhaStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Manha = volProdutoManha * fcvManha;
        
        print('• FCV como número: $fcvManha');
        print('• Volume 20°C: $volume20Manha L');
        print('• Formatado: ${_formatarVolumeLitros(volume20Manha)}');
        
        widget.dadosFormulario['medicoes']['volume20Manha'] = _formatarVolumeLitros(volume20Manha);
      } catch (e) {
        print('❌ Erro ao calcular volume 20°C manhã: $e');
        widget.dadosFormulario['medicoes']['volume20Manha'] = '-';
      }
    } else {
      print('⚠️ FCV manhã não disponível para cálculo do volume a 20°C');
      widget.dadosFormulario['medicoes']['volume20Manha'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'].toString() != '-') {
      
      print('📊 Calculando volume 20°C tarde:');
      print('• FCV Tarde: ${widget.dadosFormulario['medicoes']['fatorCorrecaoTarde']}');
      print('• Volume Produto Tarde: $volProdutoTarde L');
      
      try {
        final fcvTardeStr = widget.dadosFormulario['medicoes']['fatorCorrecaoTarde'].toString();
        final fcvTarde = double.tryParse(fcvTardeStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Tarde = volProdutoTarde * fcvTarde;
        
        print('• FCV como número: $fcvTarde');
        print('• Volume 20°C: $volume20Tarde L');
        print('• Formatado: ${_formatarVolumeLitros(volume20Tarde)}');
        
        widget.dadosFormulario['medicoes']['volume20Tarde'] = _formatarVolumeLitros(volume20Tarde);
      } catch (e) {
        print('❌ Erro ao calcular volume 20°C tarde: $e');
        widget.dadosFormulario['medicoes']['volume20Tarde'] = '-';
      }
    } else {
      print('⚠️ FCV tarde não disponível para cálculo do volume a 20°C');
      widget.dadosFormulario['medicoes']['volume20Tarde'] = '-';
    }

    print('\n==========================================');
    print('📊 RESUMO FINAL');
    print('==========================================');
    print('• Volume Produto Manhã: ${widget.dadosFormulario['medicoes']['volumeProdutoManha']}');
    print('• Volume Produto Tarde: ${widget.dadosFormulario['medicoes']['volumeProdutoTarde']}');
    print('• Densidade 20°C Manhã: ${widget.dadosFormulario['medicoes']['densidade20Manha']}');
    print('• Densidade 20°C Tarde: ${widget.dadosFormulario['medicoes']['densidade20Tarde']}');
    print('• FCV Manhã: ${widget.dadosFormulario['medicoes']['fatorCorrecaoManha']}');
    print('• FCV Tarde: ${widget.dadosFormulario['medicoes']['fatorCorrecaoTarde']}');
    print('• Volume 20°C Manhã: ${widget.dadosFormulario['medicoes']['volume20Manha']}');
    print('• Volume 20°C Tarde: ${widget.dadosFormulario['medicoes']['volume20Tarde']}');
    print('==========================================\n');

    setState(() {});
    
    print('✅ _calcularVolumesIniciais() finalizado com sucesso!');
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
                        _formatarTemperatura(medicoes['tempTanqueTarde'])), // NOVO CAMPO AQUI
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
    
    print('══════════════════════════════════════════');
    print('🔍 INICIANDO BUSCA FCV');
    print('══════════════════════════════════════════');
    print('📊 Dados recebidos:');
    print('• Temperatura tanque: "$temperaturaTanque"');
    print('• Densidade 20°C: "$densidade20C"');
    print('• Produto: "$produtoNome"');
    
    try {
      // Validar dados de entrada
      if (temperaturaTanque.isEmpty || 
          temperaturaTanque == '-' || 
          densidade20C.isEmpty || 
          densidade20C == '-') {
        print('❌ Dados inválidos para busca FCV');
        return '-';
      }
      
      // Determinar qual VIEW usar baseado no nome do produto
      String nomeView;
      
      // Usar nome do produto para decidir qual tabela usar
      final nomeProdutoLower = produtoNome.toLowerCase().trim();
      print('📝 Produto em minúsculas: "$nomeProdutoLower"');
      
      if (nomeProdutoLower.contains('anidro') || 
          nomeProdutoLower.contains('hidratado')) {
        nomeView = 'tcv_anidro_hidratado_vw';
        print('📋 Usando VIEW: tcv_anidro_hidratado_vw');
      } else {
        nomeView = 'tcv_gasolina_diesel_vw';
        print('📋 Usando VIEW: tcv_gasolina_diesel_vw');
      }
      
      // Formatar temperatura (remover unidades e padronizar)
      String temperaturaFormatada = temperaturaTanque
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      print('🌡️ Temperatura após limpeza: "$temperaturaFormatada"');
      
      // Substituir ponto por vírgula se necessário
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      print('🌡️ Temperatura formatada: "$temperaturaFormatada"');
      
      // Formatar densidade para nome de coluna
      String densidadeFormatada = densidade20C
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();
      
      print('⚖️ Densidade após limpeza: "$densidadeFormatada"');
      
      // Garantir formato correto da densidade
      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');
      print('⚖️ Densidade com vírgula: "$densidadeFormatada"');
      
      // CORREÇÃO: Arredondar para 3 casas decimais (último dígito = 0)
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          print('📐 Partes da densidade: inteira="$parteInteira", decimal="$parteDecimal"');
          
          // CORREÇÃO: Manter apenas 3 dígitos decimais e zerar o 4º
          if (parteDecimal.length >= 4) {
            // Pegar os 3 primeiros dígitos
            String tresPrimeiros = parteDecimal.substring(0, 3);
            // Zerar o 4º dígito
            parteDecimal = '${tresPrimeiros}0';
            print('📐 Decimal arredondado para 3 casas: "$parteDecimal"');
          } else if (parteDecimal.length == 3) {
            // Adicionar um zero no final
            parteDecimal = '${parteDecimal}0';
            print('📐 Decimal com zero adicionado: "$parteDecimal"');
          } else {
            // Completar com zeros até 4 dígitos, mas garantindo que o último seja 0
            parteDecimal = parteDecimal.padRight(4, '0');
            print('📐 Decimal após padding: "$parteDecimal"');
          }
          
          densidadeFormatada = '$parteInteira,$parteDecimal';
        } else {
          print('❌ Formato de densidade inválido (não tem 2 partes)');
          return '-';
        }
      } else {
        // Se não tem vírgula, adicionar
        print('⚠️ Densidade sem vírgula, adicionando...');
        if (densidadeFormatada.length == 4) {
          // Ex: "0728" -> "0,7280"
          densidadeFormatada = '0,${densidadeFormatada.substring(0, 3)}0';
        } else {
          // Ex: "728" -> "0,7280"
          densidadeFormatada = '0,${densidadeFormatada}0';
        }
      }
      
      print('✅ Densidade final formatada (3 casas): "$densidadeFormatada"');
      
      // Criar nome da coluna (ex: 0,7280 → v_07280)
      String nomeColuna;
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          // Garantir 4 dígitos na parte decimal
          parteDecimal = parteDecimal.padRight(4, '0');
          
          // Criar código de 5 dígitos
          String codigo5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');
          
          if (codigo5Digitos.length > 5) {
            codigo5Digitos = codigo5Digitos.substring(0, 5);
          }
          
          nomeColuna = 'v_$codigo5Digitos';
          print('🏷️ Nome da coluna gerado: "$nomeColuna"');
        } else {
          print('❌ Erro ao criar nome da coluna');
          return '-';
        }
      } else {
        print('❌ Densidade sem vírgula para criar nome da coluna');
        return '-';
      }
      
      // Função para formatar resultado
      String _formatarResultadoFCV(String valorBruto) {
        String valorLimpo = valorBruto.trim();
        valorLimpo = valorLimpo.replaceAll('.', ',');
        
        // Garantir formato 0,9999
        if (!valorLimpo.contains(',')) {
          valorLimpo = '$valorLimpo,0';
        }
        
        final partes = valorLimpo.split(',');
        if (partes.length == 2) {
          String parteInteira = partes[0];
          String parteDecimal = partes[1];
          
          // Completar com zeros até 4 dígitos
          parteDecimal = parteDecimal.padRight(4, '0');
          
          // Se tiver mais de 4 dígitos, truncar
          if (parteDecimal.length > 4) {
            parteDecimal = parteDecimal.substring(0, 4);
          }
          
          return '$parteInteira,$parteDecimal';
        }
        
        return valorLimpo;
      }
      
      // Primeira tentativa: busca exata
      print('🔎 Buscando na tabela...');
      print('• Tabela: $nomeView');
      print('• Coluna: $nomeColuna');
      print('• Temperatura: "$temperaturaFormatada"');
      
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();
      
      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        print('✅ FCV encontrado (exato): "$valorBruto"');
        final valorFormatado = _formatarResultadoFCV(valorBruto);
        print('✅ FCV formatado: "$valorFormatado"');
        return valorFormatado;
      } else {
        print('❌ FCV não encontrado (busca exata)');
        print('• Resultado: $resultado');
        if (resultado != null) {
          print('• Coluna $nomeColuna existe? ${resultado.containsKey(nomeColuna)}');
        }
      }
      
      // Se não encontrou, tentar busca por arredondamento de densidade
      print('🔄 Tentando busca por arredondamento...');
      
      if (densidadeFormatada.contains(',')) {
        final partes = densidadeFormatada.split(',');
        if (partes.length == 2) {
                    
          // Converter para número para arredondar
          final densidadeNum = double.tryParse(
            densidadeFormatada.replaceAll(',', '.')
          );
          
          print('🧮 Densidade como número: $densidadeNum');
          
          if (densidadeNum != null) {
            // Tentar colunas próximas (arredondamento para 0,0010)
            final List<String> densidadesParaTentar = [];
            
            // Calcular valores próximos (ex: 0,0010 acima/abaixo)
            final double passo = 0.0010; // Agora passo de 0,0010
            print('📈 Procurando densidades próximas (±0,0020)...');
            
            for (double delta = -0.0020; delta <= 0.0020; delta += passo) {
              final double densidadeTeste = densidadeNum + delta;
              
              // Formatar para string com 4 casas decimais
              final String densidadeTesteStr = densidadeTeste.toStringAsFixed(4);
              final String densidadeTesteFormatada = densidadeTesteStr.replaceAll('.', ',');
              
              print('   • Delta: $delta → Densidade: $densidadeTesteFormatada');
              
              // Converter para nome de coluna
              if (densidadeTesteFormatada.contains(',')) {
                final partesTeste = densidadeTesteFormatada.split(',');
                if (partesTeste.length == 2) {
                  String parteInteiraTeste = partesTeste[0];
                  String parteDecimalTeste = partesTeste[1];
                  
                  // Zerar o 4º dígito
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
                  print('   • Coluna gerada: $colunaProxima');
                }
              }
            }
            
            // Remover duplicatas
            final densidadesUnicas = densidadesParaTentar.toSet().toList();
            print('🔢 Colunas únicas para tentar: $densidadesUnicas');
            
            // Tentar cada coluna próxima
            for (final colunaProxima in densidadesUnicas) {
              print('   🔎 Tentando coluna: $colunaProxima');
              try {
                final resultadoProximo = await supabase
                    .from(nomeView)
                    .select(colunaProxima)
                    .eq('temperatura_obs', temperaturaFormatada)
                    .maybeSingle();
                
                if (resultadoProximo != null && resultadoProximo[colunaProxima] != null) {
                  String valorBruto = resultadoProximo[colunaProxima].toString();
                  print('   ✅ FCV encontrado (arredondado): "$valorBruto"');
                  final valorFormatado = _formatarResultadoFCV(valorBruto);
                  print('   ✅ FCV formatado: "$valorFormatado"');
                  return valorFormatado;
                } else {
                  print('   ❌ Coluna $colunaProxima não encontrada');
                }
              } catch (e) {
                print('   ⚠️ Erro ao buscar coluna $colunaProxima: $e');
                continue;
              }
            }
          }
        }
      }
      
      // Se ainda não encontrou, tentar variações de temperatura
      print('🔄 Tentando variações de temperatura...');
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
      
      // Tentar temperaturas com ponto
      final temperaturasComPonto = temperaturasParaTentar.map((f) => f.replaceAll(',', '.')).toList();
      temperaturasParaTentar.addAll(temperaturasComPonto);
      temperaturasParaTentar = temperaturasParaTentar.toSet().toList();
      
      print('🌡️ Temperaturas para tentar: $temperaturasParaTentar');
      
      for (final formatoTemp in temperaturasParaTentar) {
        print('   🔎 Tentando temperatura: "$formatoTemp"');
        try {
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', formatoTemp)
              .maybeSingle();
          
          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            print('   ✅ FCV encontrado (temp variação): "$valorBruto"');
            final valorFormatado = _formatarResultadoFCV(valorBruto);
            print('   ✅ FCV formatado: "$valorFormatado"');
            return valorFormatado;
          }
        } catch (e) {
          print('   ⚠️ Erro ao buscar temp $formatoTemp: $e');
          continue;
        }
      }
      
      print('❌❌❌ FCV NÃO ENCONTRADO APÓS TODAS TENTATIVAS ❌❌❌');
      return '-';
      
    } catch (e) {
      print('🔥 ERRO NA FUNÇÃO _buscarFCV:');
      print('🔥 Tipo: ${e.runtimeType}');
      print('🔥 Mensagem: $e');
      print('🔥 Stack: ${e.toString()}');
      return '-';
    } finally {
      print('══════════════════════════════════════════');
      print('🏁 FIM DA BUSCA FCV');
      print('══════════════════════════════════════════');
    }
  }

}