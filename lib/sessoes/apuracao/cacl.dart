import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl_pdf.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;

// ✅ ETAPA 1 — Criar enum de modo do CACL
enum CaclModo {
  emissao,
  visualizacao,
  edicao,
}

class CalcPage extends StatefulWidget {
  final Map<String, dynamic> dadosFormulario;
  final CaclModo modo;
  final String? caclId;
  final VoidCallback? onFinalizar;
  final VoidCallback? onVoltar;

  const CalcPage({
    super.key,
    required this.dadosFormulario,
    this.modo = CaclModo.emissao,
    this.caclId,
    this.onFinalizar,
    this.onVoltar,
  });

  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  double volumeInicial = 0;
  double volumeFinal = 0;
  double volumeTotalLiquidoInicial = 0;
  double volumeTotalLiquidoFinal = 0;
  bool _isGeneratingPDF = false;
  bool _isEmittingCACL = false;
  bool _caclJaEmitido = false;

  @override
  void initState() {
    super.initState();

    // ✅ ETAPA 2.2 — Ajustar initState
    if (widget.modo == CaclModo.emissao) {
      _calcularVolumesIniciais();
    } else {
      // Modo visualização: carrega os dados já calculados do banco
      _carregarDadosParaVisualizacao();
    }
  }

  Future<void> _carregarDadosParaVisualizacao() async {
    try {
      // Verifica se já temos dados completos
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};
      
      // Se os dados já estão completos (vindos do mapeamento), usa-os
      if (medicoes.isNotEmpty && medicoes.containsKey('volumeProdutoInicial')) {
        volumeInicial = _extrairNumero(medicoes['volumeProdutoInicial']?.toString());
        volumeFinal = _extrairNumero(medicoes['volumeProdutoFinal']?.toString());
        
        setState(() {
          _caclJaEmitido = true;
        });
        return;
      }
      
      // Se não, busca valores diretos do banco
      final dadosDoBanco = widget.dadosFormulario;
      
      volumeInicial = dadosDoBanco['volume_produto_inicial']?.toDouble() ?? 0.0;
      volumeFinal = dadosDoBanco['volume_produto_final']?.toDouble() ?? 0.0;
      volumeTotalLiquidoInicial = dadosDoBanco['volume_total_liquido_inicial']?.toDouble() ?? 0.0;
      volumeTotalLiquidoFinal = dadosDoBanco['volume_total_liquido_final']?.toDouble() ?? 0.0;
      
      // Mantém os dados existentes e adiciona os faltantes
      final medicoesAtualizadas = <String, dynamic>{
        ...medicoes,
        'volumeProdutoInicial': _formatarVolumeLitros(volumeInicial),
        'volumeProdutoFinal': _formatarVolumeLitros(volumeFinal),
        'volumeTotalLiquidoInicial': _formatarVolumeLitros(volumeTotalLiquidoInicial),
        'volumeTotalLiquidoFinal': _formatarVolumeLitros(volumeTotalLiquidoFinal),
      };
      
      widget.dadosFormulario['medicoes'] = medicoesAtualizadas;
      
      setState(() {
        _caclJaEmitido = true;
      });
      
    } catch (e) {
      debugPrint('Erro ao carregar dados para visualização: $e');
    }
  }  

  Future<void> _calcularVolumesIniciais() async {
    final medicoes = widget.dadosFormulario['medicoes'];
    
    final alturaAguaInicial = medicoes['alturaAguaInicial'];
    final alturaAguaFinal = medicoes['alturaAguaFinal'];

    final alturaTotalCmInicial = medicoes['cmInicial']?.toString() ?? '';
    final alturaTotalMmInicial = medicoes['mmInicial']?.toString() ?? '';
    final alturaTotalCmFinal = medicoes['cmFinal']?.toString() ?? '';
    final alturaTotalMmFinal = medicoes['mmFinal']?.toString() ?? '';

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
    
    final aguaCmMmInicial = extrairCmMm(alturaAguaInicial);
    final aguaCmMmFinal = extrairCmMm(alturaAguaFinal);

    final Map<String, String?> totalCmMmInicial = {
      'cm': alturaTotalCmInicial.isEmpty ? null : alturaTotalCmInicial,
      'mm': alturaTotalMmInicial.isEmpty ? null : alturaTotalMmInicial
    };
    
    final Map<String, String?> totalCmMmFinal = {
      'cm': alturaTotalCmFinal.isEmpty ? null : alturaTotalCmFinal,
      'mm': alturaTotalMmFinal.isEmpty ? null : alturaTotalMmFinal
    };

    final volumeTotalLiquidoInicial = await _buscarVolumeReal(totalCmMmInicial['cm'], totalCmMmInicial['mm']);
    final volumeTotalLiquidoFinal = await _buscarVolumeReal(totalCmMmFinal['cm'], totalCmMmFinal['mm']);
    
    final volAguaInicial = await _buscarVolumeReal(aguaCmMmInicial['cm'], aguaCmMmInicial['mm']);
    final volAguaFinal = await _buscarVolumeReal(aguaCmMmFinal['cm'], aguaCmMmFinal['mm']);

    final volProdutoInicial = volumeTotalLiquidoInicial - volAguaInicial;
    final volProdutoFinal = volumeTotalLiquidoFinal - volAguaFinal;

    final volumeTotalInicial = volProdutoInicial;
    final volumeTotalFinal = volProdutoFinal;

    setState(() {
      this.volumeInicial = volProdutoInicial;
      this.volumeFinal = volProdutoFinal;
      this.volumeTotalLiquidoInicial = volumeTotalLiquidoInicial;
      this.volumeTotalLiquidoFinal = volumeTotalLiquidoFinal;
    });

    final volumeProdutoInicialFormatado = _formatarVolumeLitros(volProdutoInicial);
    final volumeProdutoFinalFormatado = _formatarVolumeLitros(volProdutoFinal);
    final volumeAguaInicialFormatado = _formatarVolumeLitros(volAguaInicial);
    final volumeAguaFinalFormatado = _formatarVolumeLitros(volAguaFinal);
    final volumeTotalInicialFormatado = _formatarVolumeLitros(volumeTotalInicial);
    final volumeTotalFinalFormatado = _formatarVolumeLitros(volumeTotalFinal);

    widget.dadosFormulario['medicoes']['volumeProdutoInicial'] = volumeProdutoInicialFormatado;
    widget.dadosFormulario['medicoes']['volumeProdutoFinal'] = volumeProdutoFinalFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaInicial'] = volumeAguaInicialFormatado;
    widget.dadosFormulario['medicoes']['volumeAguaFinal'] = volumeAguaFinalFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoInicial'] = _formatarVolumeLitros(volumeTotalLiquidoInicial);
    widget.dadosFormulario['medicoes']['volumeTotalLiquidoFinal'] = _formatarVolumeLitros(volumeTotalLiquidoFinal);
    
    widget.dadosFormulario['medicoes']['volumeTotalInicial'] = volumeTotalInicialFormatado;
    widget.dadosFormulario['medicoes']['volumeTotalFinal'] = volumeTotalFinalFormatado;

    final produtoNome = widget.dadosFormulario['produto']?.toString() ?? '';
      
    if (medicoes['tempAmostraInicial'] != null && 
        medicoes['tempAmostraInicial'].toString().isNotEmpty &&
        medicoes['tempAmostraInicial'].toString() != '-' &&
        medicoes['densidadeInicial'] != null &&
        medicoes['densidadeInicial'].toString().isNotEmpty &&
        medicoes['densidadeInicial'].toString() != '-' &&
        produtoNome.isNotEmpty) {
      
      final densidade20Inicial = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraInicial'].toString(),
        densidadeObservada: medicoes['densidadeInicial'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['densidade20Inicial'] = densidade20Inicial;
    } else {
      widget.dadosFormulario['medicoes']['densidade20Inicial'] = '-';
    }

    if (medicoes['tempAmostraFinal'] != null && 
        medicoes['tempAmostraFinal'].toString().isNotEmpty &&
        medicoes['tempAmostraFinal'].toString() != '-' &&
        medicoes['densidadeFinal'] != null &&
        medicoes['densidadeFinal'].toString().isNotEmpty &&
        medicoes['densidadeFinal'].toString() != '-' &&
        produtoNome.isNotEmpty) {
      
      final densidade20Final = await _buscarDensidade20C(
        temperaturaAmostra: medicoes['tempAmostraFinal'].toString(),
        densidadeObservada: medicoes['densidadeFinal'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['densidade20Final'] = densidade20Final;
    } else {
      widget.dadosFormulario['medicoes']['densidade20Final'] = '-';
    }

    if (medicoes['tempTanqueInicial'] != null &&
        medicoes['tempTanqueInicial'].toString().isNotEmpty &&
        medicoes['tempTanqueInicial'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Inicial'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Inicial'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Inicial'].toString() != '-') {
      
      final fcvInicial = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueInicial'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Inicial'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'] = fcvInicial;
    } else {
      widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'] = '-';
    }

    if (medicoes['tempTanqueFinal'] != null &&
        medicoes['tempTanqueFinal'].toString().isNotEmpty &&
        medicoes['tempTanqueFinal'].toString() != '-' &&
        widget.dadosFormulario['medicoes']['densidade20Final'] != null &&
        widget.dadosFormulario['medicoes']['densidade20Final'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['densidade20Final'].toString() != '-') {
      
      final fcvFinal = await _buscarFCV(
        temperaturaTanque: medicoes['tempTanqueFinal'].toString(),
        densidade20C: widget.dadosFormulario['medicoes']['densidade20Final'].toString(),
        produtoNome: produtoNome,
      );
      
      widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'] = fcvFinal;
    } else {
      widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'].toString() != '-') {
      
      try {
        final fcvInicialStr = widget.dadosFormulario['medicoes']['fatorCorrecaoInicial'].toString();
        final fcvInicial = double.tryParse(fcvInicialStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Inicial = volProdutoInicial * fcvInicial;
        
        widget.dadosFormulario['medicoes']['volume20Inicial'] = _formatarVolumeLitros(volume20Inicial);
      } catch (e) {
        widget.dadosFormulario['medicoes']['volume20Inicial'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['volume20Inicial'] = '-';
    }

    if (widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'] != null &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'].toString().isNotEmpty &&
        widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'].toString() != '-') {
      
      try {
        final fcvFinalStr = widget.dadosFormulario['medicoes']['fatorCorrecaoFinal'].toString();
        final fcvFinal = double.tryParse(fcvFinalStr.replaceAll(',', '.')) ?? 1.0;
        final volume20Final = volProdutoFinal * fcvFinal;
        
        widget.dadosFormulario['medicoes']['volume20Final'] = _formatarVolumeLitros(volume20Final);
      } catch (e) {
        widget.dadosFormulario['medicoes']['volume20Final'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['volume20Final'] = '-';
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

  Future<void> _emitirCACL() async {
    if (_isEmittingCACL) return;
    
    setState(() {
      _isEmittingCACL = true;
    });
    
    try {
      final supabase = Supabase.instance.client;
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};
      
      // ✅ DEBUG: Verificar se o caclId está chegando corretamente
      print('=== DEBUG: _emitirCACL() ===');
      print('Modo: ${widget.modo}');
      print('CACL ID recebido: ${widget.caclId}');
      print('Modo é edição: ${widget.modo == CaclModo.edicao}');
      print('ID nos dadosFormulario: ${widget.dadosFormulario['id_cacl']}');
      
      // Verifica se o usuário está logado
      final session = supabase.auth.currentSession;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você precisa estar logado para emitir o CACL'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ✅ DETERMINAR O TIPO DO CACL BASEADO NAS CHECKBOXES
      String? tipoCACL;
      final bool caclVerificacao = widget.dadosFormulario['cacl_verificacao'] ?? false;
      final bool caclMovimentacao = widget.dadosFormulario['cacl_movimentacao'] ?? false;
      
      if (caclVerificacao) {
        tipoCACL = 'verificacao';
      } else if (caclMovimentacao) {
        tipoCACL = 'movimentacao';
      }
      
      // Formatar data para o padrão YYYY-MM-DD
      String? dataFormatada;
      final dataOriginal = widget.dadosFormulario['data']?.toString() ?? '';
      if (dataOriginal.isNotEmpty) {
        dataFormatada = _formatarDataParaSQL(dataOriginal);
      }
      
      // Função auxiliar para converter horário
      String? formatarHorarioParaTime(String? horario) {
        if (horario == null || horario.isEmpty || horario == '-') return null;
        
        String limpo = horario.trim().replaceAll('h', '').replaceAll('H', '');
        
        if (limpo.contains(':')) {
          final partes = limpo.split(':');
          if (partes.length == 2) {
            final horas = int.tryParse(partes[0]) ?? 0;
            final minutos = int.tryParse(partes[1]) ?? 0;
            
            if (horas >= 0 && horas < 24 && minutos >= 0 && minutos < 60) {
              return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:00';
            }
          }
        }
        
        return null;
      }
      
      // Função auxiliar para converter texto para double (tratando "-" como null)
      double? converterParaDouble(String? valor) {
        if (valor == null || valor.isEmpty || valor == '-') return null;
        
        try {
          String limpo = valor.replaceAll(' L', '').replaceAll(' cm', '')
              .replaceAll(' ºC', '').replaceAll('°C', '')
              .replaceAll(',', '.').replaceAll('.', '');
          return double.tryParse(limpo);
        } catch (e) {
          return null;
        }
      }
      
      // Função auxiliar para extrair números de valores formatados (como "1.500 L")
      double? extrairNumeroFormatado(String? valor) {
        if (valor == null || valor.isEmpty || valor == '-') return null;
        
        try {
          // Remove tudo que não é número
          String somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
          if (somenteNumeros.isEmpty) return null;
          return double.tryParse(somenteNumeros);
        } catch (e) {
          return null;
        }
      }
      
      // Preparar dados para inserção/atualização
      final dadosParaInserir = {
        // Dados principais (mantém os existentes)
        'data': dataFormatada,
        'base': widget.dadosFormulario['base']?.toString(),
        'produto': widget.dadosFormulario['produto']?.toString(),
        'tanque': widget.dadosFormulario['tanque']?.toString(),
        'filial_id': widget.dadosFormulario['filial_id']?.toString(),
        'status': 'emitido', // ✅ ATUALIZAR STATUS PARA EMITIDO
        
        // ✅ ADICIONAR O CAMPO TIPO
        'tipo': tipoCACL,
        
        // Medições INICIAL (MANTÉM OS EXISTENTES - não alterar)
        'horario_inicial': formatarHorarioParaTime(medicoes['horarioInicial']?.toString()),
        'altura_total_liquido_inicial': medicoes['alturaTotalInicial']?.toString(),
        'altura_total_cm_inicial': medicoes['cmInicial']?.toString(),
        'altura_total_mm_inicial': medicoes['mmInicial']?.toString(),
        'volume_total_liquido_inicial': volumeTotalLiquidoInicial,
        'altura_agua_inicial': medicoes['alturaAguaInicial']?.toString(),
        'volume_agua_inicial': extrairNumeroFormatado(medicoes['volumeAguaInicial']?.toString()),
        'altura_produto_inicial': medicoes['alturaProdutoInicial']?.toString(),
        'volume_produto_inicial': volumeInicial,
        'temperatura_tanque_inicial': medicoes['tempTanqueInicial']?.toString(),
        'densidade_observada_inicial': medicoes['densidadeInicial']?.toString(),
        'temperatura_amostra_inicial': medicoes['tempAmostraInicial']?.toString(),
        'densidade_20_inicial': medicoes['densidade20Inicial']?.toString(),
        'fator_correcao_inicial': medicoes['fatorCorrecaoInicial']?.toString(),
        'volume_20_inicial': extrairNumeroFormatado(medicoes['volume20Inicial']?.toString()),
        'massa_inicial': medicoes['massaInicial']?.toString(),
        
        // Medições FINAL (PREENCHE OS QUE ESTAVAM NULL)
        'horario_final': formatarHorarioParaTime(medicoes['horarioFinal']?.toString()),
        'altura_total_liquido_final': medicoes['alturaTotalFinal']?.toString(),
        'altura_total_cm_final': medicoes['cmFinal']?.toString(),
        'altura_total_mm_final': medicoes['mmFinal']?.toString(),
        'volume_total_liquido_final': volumeTotalLiquidoFinal,
        'altura_agua_final': medicoes['alturaAguaFinal']?.toString(),
        'volume_agua_final': extrairNumeroFormatado(medicoes['volumeAguaFinal']?.toString()),
        'altura_produto_final': medicoes['alturaProdutoFinal']?.toString(),
        'volume_produto_final': volumeFinal,
        'temperatura_tanque_final': medicoes['tempTanqueFinal']?.toString(),
        'densidade_observada_final': medicoes['densidadeFinal']?.toString(),
        'temperatura_amostra_final': medicoes['tempAmostraFinal']?.toString(),
        'densidade_20_final': medicoes['densidade20Final']?.toString(),
        'fator_correcao_final': medicoes['fatorCorrecaoFinal']?.toString(),
        'volume_20_final': extrairNumeroFormatado(medicoes['volume20Final']?.toString()),
        'massa_final': medicoes['massaFinal']?.toString(),
        
        // Cálculos comparativos (ATUALIZA COM OS NOVOS VALORES)
        'volume_ambiente_inicial': volumeInicial,
        'volume_ambiente_final': volumeFinal,
        'entrada_saida_ambiente': volumeFinal - volumeInicial,
        'entrada_saida_20': (_extrairNumero(medicoes['volume20Final']?.toString()) - 
                            _extrairNumero(medicoes['volume20Inicial']?.toString())),
        
        // Informações de faturamento (ADICIONA SE EXISTIR)
        'faturado_final': converterParaDouble(medicoes['faturadoFinal']?.toString()),
        'diferenca_faturado': (extrairNumeroFormatado(medicoes['volume20Final']?.toString()) ?? 0) -
                            (extrairNumeroFormatado(medicoes['volume20Inicial']?.toString()) ?? 0) -
                            (converterParaDouble(medicoes['faturadoFinal']?.toString()) ?? 0),
        
        // Auditoria - SEMPRE atualizar
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Calcular porcentagem da diferença
      final entradaSaida20 = _extrairNumero(medicoes['volume20Final']?.toString()) - 
                            _extrairNumero(medicoes['volume20Inicial']?.toString());
      final diferenca = entradaSaida20 - (converterParaDouble(medicoes['faturadoFinal']?.toString()) ?? 0);
      
      if (entradaSaida20 != 0) {
        final porcentagem = (diferenca / entradaSaida20) * 100;
        dadosParaInserir['porcentagem_diferenca'] = '${porcentagem >= 0 ? '+' : ''}${porcentagem.toStringAsFixed(2)}%';
      } else {
        dadosParaInserir['porcentagem_diferenca'] = '0.00%';
      }
      
      // Remover campos nulos
      dadosParaInserir.removeWhere((key, value) => value == null);
      
      // ✅ VERIFICAR ID DE MULTIPLAS FONTES
      String? idParaUpdate = widget.caclId;
      
      // Se não tiver no widget, tenta buscar do dadosFormulario
      if ((idParaUpdate == null || idParaUpdate.isEmpty) && 
          widget.dadosFormulario.containsKey('id_cacl')) {
        idParaUpdate = widget.dadosFormulario['id_cacl']?.toString();
        print('⚠️ ID encontrado em dadosFormulario: $idParaUpdate');
      }
      
      // ✅ DECISÃO: UPDATE se tiver ID, INSERT se não tiver
      if (idParaUpdate != null && idParaUpdate.isNotEmpty) {
        // ✅ ATUALIZAR CACL EXISTENTE
        print('🔄 ATUALIZANDO CACL EXISTENTE - ID: $idParaUpdate');
        
        try {
          // Primeiro, verifica se o registro existe
          final verificaExistencia = await supabase
              .from('cacl')
              .select('id, status')
              .eq('id', idParaUpdate)
              .maybeSingle();
              
          if (verificaExistencia == null) {
            print('❌ CACL não encontrado no banco. Criando novo...');
            throw Exception('CACL não encontrado para atualização');
          }
          
          print('✅ CACL encontrado para atualização. Status atual: ${verificaExistencia['status']}');
                              
          print('✅✅✅ CACL ATUALIZADO COM SUCESSO! ID: $idParaUpdate');
          
          // Sucesso - UPDATE
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ CACL atualizado com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          
        } catch (e) {
          print('❌ Erro ao atualizar CACL: $e');
          
          // Fallback: inserir como novo se falhar o update
          print('🔄 Tentando inserir como novo CACL...');
          dadosParaInserir['created_by'] = session.user.id;
          dadosParaInserir['created_at'] = DateTime.now().toIso8601String();
          
          await supabase
              .from('cacl')
              .insert(dadosParaInserir);
              
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Novo CACL criado (fallback)'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
        
      } else {
        // ✅ INSERIR NOVO CACL (MODO EMISSÃO NORMAL)
        print('🆕 INSERINDO NOVO CACL - NENHUM ID ENCONTRADO PARA UPDATE');
        
        // Adicionar campos de criação
        dadosParaInserir['created_by'] = session.user.id;
        dadosParaInserir['created_at'] = DateTime.now().toIso8601String();
                
        print('✅✅✅ NOVO CACL INSERIDO COM SUCESSO!');
        
        // Sucesso - INSERT
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ CACL emitido e salvo no banco com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      // Atualizar estado
      if (mounted) {
        setState(() {
          _caclJaEmitido = true;
        });
      }
      
    } catch (e) {
      print('❌❌❌ ERRO GRAVE ao emitir/atualizar CACL: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmittingCACL = false;
        });
      }
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
            SizedBox(
              width: 670,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO COM BANDEIRA DE PRÉ-VISUALIZAÇÃO
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          border: Border.all(color: Colors.black, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.modo == CaclModo.emissao
                                ? "CACL - PRÉ-VISUALIZAÇÃO"
                                : widget.modo == CaclModo.edicao
                                  ? "CACL - EDIÇÃO"  // ← NOVO TÍTULO PARA MODO EDIÇÃO
                                  : "CACL - HISTÓRICO",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                            ),                           
                          ],
                        ),
                      ),                                            
                    ],
                  ),

                  const SizedBox(height: 20),                  

                  // DADOS PRINCIPAIS
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

                  // SEÇÃO DE MEDIÇÕES
                  _subtitulo("VOLUME RECEBIDO NOS TANQUES DE TERRA E CANALIZAÇÃO RESPECTIVA"),
                  const SizedBox(height: 12),

                  _tabelaMedicoes([
                    _linhaMedicao("Altura total de líquido no tanque:", 
                        _formatarAlturaTotal(medicoes['cmInicial'], medicoes['mmInicial']), 
                        _formatarAlturaTotal(medicoes['cmFinal'], medicoes['mmFinal'])),
                    _linhaMedicao("Volume total de líquido no tanque (temp. ambiente):", 
                        _formatarVolumeLitros(volumeTotalLiquidoInicial), 
                        _formatarVolumeLitros(volumeTotalLiquidoFinal)),
                    _linhaMedicao("Altura da água aferida no tanque:", 
                        _obterValorMedicao(medicoes['alturaAguaInicial']), 
                        _obterValorMedicao(medicoes['alturaAguaFinal'])),
                    _linhaMedicao("Volume correspondente à água:", 
                        _obterValorMedicao(medicoes['volumeAguaInicial']), 
                        _obterValorMedicao(medicoes['volumeAguaFinal'])),
                    _linhaMedicao("Altura do produto aferido no tanque:", 
                        _obterValorMedicao(medicoes['alturaProdutoInicial']), 
                        _obterValorMedicao(medicoes['alturaProdutoFinal'])),
                    _linhaMedicao(
                      "Volume correspondente ao produto (temp. ambiente):",
                      _formatarVolumeLitros(volumeInicial),
                      _formatarVolumeLitros(volumeFinal),
                    ),
                    _linhaMedicao("Temperatura do produto no tanque:", 
                        _formatarTemperatura(medicoes['tempTanqueInicial']), 
                        _formatarTemperatura(medicoes['tempTanqueFinal'])),
                    _linhaMedicao("Densidade observada na amostra:", 
                        _obterValorMedicao(medicoes['densidadeInicial']), 
                        _obterValorMedicao(medicoes['densidadeFinal'])),
                    _linhaMedicao("Temperatura da amostra:", 
                        _formatarTemperatura(medicoes['tempAmostraInicial']), 
                        _formatarTemperatura(medicoes['tempAmostraFinal'])),
                    _linhaMedicao("Densidade da amostra, considerada à temperatura padrão (20 ºC):", 
                        _obterValorMedicao(medicoes['densidade20Inicial']), 
                        _obterValorMedicao(medicoes['densidade20Final'])),                    
                    _linhaMedicao("Fator de correção de volume do produto (FCV):", 
                        _obterValorMedicao(medicoes['fatorCorrecaoInicial']), 
                        _obterValorMedicao(medicoes['fatorCorrecaoFinal'])),                    
                    _linhaMedicao("Volume total do produto, considerada a temperatura padrão (20 ºC):", 
                        _obterValorMedicao(medicoes['volume20Inicial']), 
                        _obterValorMedicao(medicoes['volume20Final'])),
                  ], medicoes),

                  const SizedBox(height: 25),

                  // COMPARAÇÃO DE RESULTADOS
                  _subtitulo("COMPARAÇÃO DE RESULTADOS"),
                  const SizedBox(height: 8),

                  _tabelaComparacaoResultados(
                    volumeAmbienteInicial: volumeInicial,
                    volumeAmbienteFinal: volumeFinal,
                    volume20Inicial: _extrairNumero(medicoes['volume20Inicial']?.toString()),
                    volume20Final: _extrairNumero(medicoes['volume20Final']?.toString()),
                    entradaSaidaAmbiente: volumeFinal - volumeInicial,
                    entradaSaida20: _extrairNumero(medicoes['volume20Final']?.toString()) - 
                                    _extrairNumero(medicoes['volume20Inicial']?.toString()),
                  ),

                  // BLOCO FATURADO
                  const SizedBox(height: 20),
                  _blocoFaturado(
                    medicoes: medicoes,
                  ),                 

                  // RODAPÉ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                          ? const Color(0xFFFFF3E0)  // Laranja claro se pendente
                          : const Color(0xFFE3F2FD),  // Azul claro se completo/visualização
                      border: Border.all(
                        color: widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                            ? Colors.orange
                            : const Color(0xFF2196F3),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                              ? Icons.pending
                              : Icons.info_outline,
                          color: widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                              ? Colors.orange
                              : const Color(0xFF2196F3),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                                  ? "CACL Pendente"
                                  : widget.modo == CaclModo.emissao
                                    ? "Pré-visualização do CACL"
                                    : "Visualização do CACL",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                                      ? Colors.orange[800]
                                      : const Color(0xFF0D47A1),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                                  ? "Faltam dados da medição final. Salve como pendente para completar depois."
                                  : widget.modo == CaclModo.edicao
                                    ? "Editando CACL pendente. Verifique os dados antes de finalizar."
                                    : widget.modo == CaclModo.emissao
                                      ? "Verifique os dados antes de emitir o documento oficial."
                                      : "Este CACL já foi emitido e está salvo no histórico.",
                                style: TextStyle(
                                  color: widget.modo == CaclModo.emissao && !_dadosFinaisEstaoCompletos()
                                      ? Colors.orange[700]
                                      : widget.modo == CaclModo.edicao
                                        ? Colors.blue[700]  // ← COR DIFERENTE PARA EDIÇÃO
                                        : Colors.grey[700],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // ✅ BOTÕES PRINCIPAIS
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // BOTÃO VOLTAR (AZUL) - DESABILITADO SE CACL JÁ FOI EMITIDO
                        ElevatedButton.icon(
                          onPressed: (_caclJaEmitido && widget.modo == CaclModo.emissao) 
                              ? null  // Desabilita se já foi emitido
                              : () {
                                  // Verifica se tem callback personalizado para voltar
                                  if (widget.onVoltar != null) {
                                    widget.onVoltar!(); // Usa o callback fornecido
                                  } else {
                                    Navigator.of(context).pop(); // Fallback padrão
                                  }
                                },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Voltar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1), // Azul
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 20), // Espaço entre botões
                        
                        // VERIFICA SE OS DADOS FINAIS ESTÃO COMPLETOS
                        if ((widget.modo == CaclModo.emissao || widget.modo == CaclModo.edicao) && !_caclJaEmitido)
                          ElevatedButton.icon(
                            onPressed: _isEmittingCACL 
                                ? null 
                                : (_dadosFinaisEstaoCompletos() 
                                    ? _emitirCACL 
                                    : _salvarComoPendente),
                            icon: _isEmittingCACL
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : _dadosFinaisEstaoCompletos()
                                    ? const Icon(Icons.send, size: 18)
                                    : const Icon(Icons.pending_actions, size: 18),
                            label: _isEmittingCACL
                                ? const Text('Processando...')
                                : _dadosFinaisEstaoCompletos()
                                    ? const Text('Emitir CACL')
                                    : const Text('Salvar como Pendente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _dadosFinaisEstaoCompletos() 
                                  ? Colors.green 
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        
                        // ESPAÇO ENTRE BOTÕES
                        if (_caclJaEmitido || widget.modo == CaclModo.visualizacao)
                          const SizedBox(width: 20),
                        
                        // BOTÃO GERAR PDF (só se já emitido)
                        if (_caclJaEmitido || widget.modo == CaclModo.visualizacao)
                          ElevatedButton.icon(
                            onPressed: _isGeneratingPDF ? null : _baixarPDFCACL,
                            icon: _isGeneratingPDF
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf, size: 18),
                            label: Text(_isGeneratingPDF ? 'Gerando...' : 'Gerar PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        
                        // BOTÃO FINALIZAR (só se já emitido no modo emissão)
                        if (widget.modo == CaclModo.emissao && _caclJaEmitido)
                          const SizedBox(width: 20),
                        
                        if (widget.modo == CaclModo.emissao && _caclJaEmitido)
                          ElevatedButton.icon(
                            onPressed: _irParaApuracao,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Finalizar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                "1ª MEDIÇÃO, ${_formatarHorarioCACL(medicoes['horarioInicial'])}",
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
                "2ª MEDIÇÃO, ${_formatarHorarioCACL(medicoes['horarioFinal'])}",
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
                _obterValorMedicao(medicoes['massaInicial']),
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(
                _obterValorMedicao(medicoes['massaFinal']),
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

  TableRow _linhaMedicao(String descricao, String valorInicial, String valorFinal) {
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
            valorInicial,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            valorFinal,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _tabelaComparacaoResultados({
    required double volumeAmbienteInicial,
    required double volumeAmbienteFinal,
    required double volume20Inicial,
    required double volume20Final,
    required double entradaSaidaAmbiente,
    required double entradaSaida20,
  }) {
    // Função para formatar no padrão "999.999 L"
    String fmt(double v) {
      if (v.isNaN) return "-";
      
      final volumeInteiro = v.round();
      final isNegativo = volumeInteiro < 0;
      String inteiroFormatado = volumeInteiro.abs().toString();
      
      // CORREÇÃO: Só adiciona pontos se tiver mais de 3 dígitos
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
      
      // Se número for menor que 1000, não adiciona ponto
      final sinal = isNegativo ? '-' : (v > 0 ? '+' : '');
      return '$sinal$inteiroFormatado L';
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
              child: Text(fmt(volumeAmbienteInicial), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volumeAmbienteFinal), 
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
              child: Text(fmt(volume20Inicial), 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
              child: Text(fmt(volume20Final), 
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
    
    // Para 1ª medição (Inicial) - Volume20 × Densidade20
    if (medicoes['volume20Inicial'] != null && 
        medicoes['volume20Inicial'].toString().isNotEmpty &&
        medicoes['volume20Inicial'].toString() != '-' &&
        medicoes['densidade20Inicial'] != null &&
        medicoes['densidade20Inicial'].toString().isNotEmpty &&
        medicoes['densidade20Inicial'].toString() != '-') {
      
      try {
        // Converter volume a 20ºC formatado para double
        final volume20Inicial = _converterVolumeParaDouble(medicoes['volume20Inicial'].toString());
        
        // Converter densidade a 20ºC para double
        final densidade20Inicial = double.tryParse(
          medicoes['densidade20Inicial'].toString()
              .replaceAll(' kg/L', '')
              .replaceAll(',', '.')
              .trim()
        ) ?? 0.0;
        
        // Cálculo da massa: Volume a 20ºC × Densidade a 20ºC
        final massaInicial = volume20Inicial * densidade20Inicial;
        
        // Formatar massa: ponto como milhar, vírgula como decimal, 1 casa decimal
        final massaInicialFormatada = _formatarMassa(massaInicial);
        
        widget.dadosFormulario['medicoes']['massaInicial'] = massaInicialFormatada;
      } catch (e) {
        widget.dadosFormulario['medicoes']['massaInicial'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['massaInicial'] = '-';
    }
    
    // Para 2ª medição (Final) - Volume20 × Densidade20
    if (medicoes['volume20Final'] != null && 
        medicoes['volume20Final'].toString().isNotEmpty &&
        medicoes['volume20Final'].toString() != '-' &&
        medicoes['densidade20Final'] != null &&
        medicoes['densidade20Final'].toString().isNotEmpty &&
        medicoes['densidade20Final'].toString() != '-') {
      
      try {
        // Converter volume a 20ºC formatado para double
        final volume20Final = _converterVolumeParaDouble(medicoes['volume20Final'].toString());
        
        // Converter densidade a 20ºC para double
        final densidade20Final = double.tryParse(
          medicoes['densidade20Final'].toString()
              .replaceAll(' kg/L', '')
              .replaceAll(',', '.')
              .trim()
        ) ?? 0.0;
        
        // Cálculo da massa: Volume a 20ºC × Densidade a 20ºC
        final massaFinal = volume20Final * densidade20Final;
        
        // Formatar massa: ponto como milhar, vírgula como decimal, 1 casa decimal
        final massaFinalFormatada = _formatarMassa(massaFinal);
        
        widget.dadosFormulario['medicoes']['massaFinal'] = massaFinalFormatada;
      } catch (e) {
        widget.dadosFormulario['medicoes']['massaFinal'] = '-';
      }
    } else {
      widget.dadosFormulario['medicoes']['massaFinal'] = '-';
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
    final faturadoUsuarioStr = medicoes['faturadoFinal']?.toString() ?? '';
    
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
    final volume20Final = _extrairNumero(medicoes['volume20Final']?.toString());
    final volume20Inicial = _extrairNumero(medicoes['volume20Inicial']?.toString());
    
    // Cálculo da diferença: Volume a 20ºC - Faturado
    final entradaSaida20 = volume20Final - volume20Inicial;
    final diferenca = entradaSaida20 - faturadoUsuario;
    
    // Formata
    final faturadoFormatado = faturadoUsuario > 0 ? fmt(faturadoUsuario) : "-";
    final diferencaFormatada = fmt(diferenca);
    
    // Porcentagem
    final entradaSaida20Double = entradaSaida20.toDouble();
    final porcentagem = entradaSaida20Double != 0 ? (diferenca.toDouble() / entradaSaida20Double) * 100 : 0.0;
    final porcentagemFormatada = fmtPercent(porcentagem);
    
    // Concatenação: "-114 L | -0,36%"
    final concatenacao = '$diferencaFormatada ║ $porcentagemFormatada';

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
        SizedBox(height: 15),        
      ],
    );
  }

  Future<void> _baixarPDFCACL() async {
    setState(() {
      _isGeneratingPDF = true;
    });
    
    try {
      // Gera o PDF usando a classe CACLPdf
      final pdfDocument = await CACLPdf.gerar(
        dadosFormulario: widget.dadosFormulario,
      );
      
      // Converte o documento para bytes
      final pdfBytes = await pdfDocument.save();
      
      // Faz download
      if (kIsWeb) {
        await _downloadForWebCACL(pdfBytes);
      } else {
        print('PDF CACL gerado (${pdfBytes.length} bytes)');
        _showMobileMessageCACL();
      }
      
      // Mensagem de sucesso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado CACL baixado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('ERRO ao gerar PDF CACL: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  // Função para download Web
  Future<void> _downloadForWebCACL(Uint8List bytes) async {
    try {
      final base64 = base64Encode(bytes);
      final dataUrl = 'data:application/pdf;base64,$base64';
      
      final produto = widget.dadosFormulario['produto']?.toString() ?? 'CACL';
      final data = widget.dadosFormulario['data']?.toString() ?? '';
      final fileName = 'CACL_${produto}_${data.replaceAll('/', '-')}.pdf';
      
      final jsCode = '''
        try {
          const link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$fileName';
          link.style.display = 'none';
          
          document.body.appendChild(link);
          link.click();
          
          setTimeout(() => {
            document.body.removeChild(link);
          }, 100);
          
          console.log('Download CACL iniciado: ' + '$fileName');
        } catch (error) {
          console.error('Erro no download automático:', error);
          window.open('$dataUrl', '_blank');
        }
      ''';
      
      js.context.callMethod('eval', [jsCode]);
      
    } catch (e) {
      print('Erro no download Web CACL: $e');
    }
  }

  void _showMobileMessageCACL() {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF CACL gerado! Em breve disponível para download no mobile.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatarDataParaSQL(String dataDisplay) {
    try {
      // Converte "22/12/2025" para "2025-12-22"
      final partes = dataDisplay.split('/');
      if (partes.length == 3) {
        final dia = partes[0];
        final mes = partes[1];
        final ano = partes[2];
        return '$ano-$mes-$dia';  // Formato SQL: yyyy-MM-dd
      }
      return dataDisplay;
    } catch (e) {
      // Fallback: data atual no formato SQL
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _irParaApuracao() async {
    try {
      // Obter dados necessários para a Apuração
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você precisa estar logado para continuar'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final dataFormatada = _formatarDataParaSQL(widget.dadosFormulario['data']?.toString() ?? '');
      final produto = widget.dadosFormulario['produto']?.toString() ?? '';
      
      final response = await supabase
          .from('cacl')
          .select('id')
          .eq('created_by', session.user.id)
          .eq('data', dataFormatada)
          .eq('produto', produto)
          .order('created_at', ascending: false)
          .limit(1);
      
      if (response.isNotEmpty) {
        
        // Mensagem de confirmação
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ CACL finalizado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // Aguardar um pouco para mostrar a mensagem
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // **CORREÇÃO PRINCIPAL**: Lógica simplificada e segura
        if (context.mounted) {
          // Para qualquer modo (edição ou emissão), usar Navigator.popUntil
          // Isso garante que voltaremos para a HomePage de forma segura
          
          // Primeiro, verifica se há um callback personalizado
          if (widget.onFinalizar != null) {
            widget.onFinalizar!(); // Executa o callback se existir
          } else {
            // Navegação segura para voltar à HomePage
            Navigator.of(context).popUntil((route) {
              // Volta até encontrar a HomePage (ou até a primeira rota)
              return route.isFirst;
            });
          }
        }
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível encontrar o CACL emitido'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
    } catch (e) {
      print('Erro ao finalizar CACL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _salvarComoPendente() async {
    if (_isEmittingCACL) return;
    
    setState(() {
      _isEmittingCACL = true;
    });
    
    try {
      final supabase = Supabase.instance.client;
      final medicoes = widget.dadosFormulario['medicoes'] ?? {};
      
      final session = supabase.auth.currentSession;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você precisa estar logado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ✅ DETERMINAR O TIPO DO CACL BASEADO NAS CHECKBOXES (MESMA LÓGICA)
      String? tipoCACL;
      final bool caclVerificacao = widget.dadosFormulario['cacl_verificacao'] ?? false;
      final bool caclMovimentacao = widget.dadosFormulario['cacl_movimentacao'] ?? false;
      
      if (caclVerificacao) {
        tipoCACL = 'verificacao';
      } else if (caclMovimentacao) {
        tipoCACL = 'movimentacao';
      }
      
      String? dataFormatada;
      final dataOriginal = widget.dadosFormulario['data']?.toString() ?? '';
      if (dataOriginal.isNotEmpty) {
        dataFormatada = _formatarDataParaSQL(dataOriginal);
      }
      
      String? formatarHorarioParaTime(String? horario) {
        if (horario == null || horario.isEmpty || horario == '-') return null;
        String limpo = horario.trim().replaceAll('h', '').replaceAll('H', '');
        if (limpo.contains(':')) {
          final partes = limpo.split(':');
          if (partes.length == 2) {
            final horas = int.tryParse(partes[0]) ?? 0;
            final minutos = int.tryParse(partes[1]) ?? 0;
            if (horas >= 0 && horas < 24 && minutos >= 0 && minutos < 60) {
              return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:00';
            }
          }
        }
        return null;
      }
      
      double? extrairNumeroFormatado(String? valor) {
        if (valor == null || valor.isEmpty || valor == '-') return null;
        try {
          String somenteNumeros = valor.replaceAll(RegExp(r'[^0-9]'), '');
          if (somenteNumeros.isEmpty) return null;
          return double.tryParse(somenteNumeros);
        } catch (e) {
          return null;
        }
      }
      
      final dadosParaInserir = {
        'data': dataFormatada,
        'base': widget.dadosFormulario['base']?.toString(),
        'produto': widget.dadosFormulario['produto']?.toString(),
        'tanque': widget.dadosFormulario['tanque']?.toString(),
        'filial_id': widget.dadosFormulario['filial_id']?.toString(),
        'status': 'pendente',      
        'tipo': tipoCACL,
        
        'horario_inicial': formatarHorarioParaTime(medicoes['horarioInicial']?.toString()),
        'altura_total_cm_inicial': medicoes['cmInicial']?.toString(),
        'altura_total_mm_inicial': medicoes['mmInicial']?.toString(),
        'volume_total_liquido_inicial': volumeTotalLiquidoInicial,
        'altura_agua_inicial': medicoes['alturaAguaInicial']?.toString(),
        'volume_agua_inicial': extrairNumeroFormatado(medicoes['volumeAguaInicial']?.toString()),
        'altura_produto_inicial': medicoes['alturaProdutoInicial']?.toString(),
        'volume_produto_inicial': volumeInicial,
        'temperatura_tanque_inicial': medicoes['tempTanqueInicial']?.toString(),
        'densidade_observada_inicial': medicoes['densidadeInicial']?.toString(),
        'temperatura_amostra_inicial': medicoes['tempAmostraInicial']?.toString(),
        'densidade_20_inicial': medicoes['densidade20Inicial']?.toString(),
        'fator_correcao_inicial': medicoes['fatorCorrecaoInicial']?.toString(),
        'volume_20_inicial': extrairNumeroFormatado(medicoes['volume20Inicial']?.toString()),
        'massa_inicial': medicoes['massaInicial']?.toString(),
        
        'horario_final': null,
        'altura_total_cm_final': null,
        'altura_total_mm_final': null,
        'volume_total_liquido_final': null,
        'altura_agua_final': null,
        'volume_agua_final': null,
        'altura_produto_final': null,
        'volume_produto_final': null,
        'temperatura_tanque_final': null,
        'densidade_observada_final': null,
        'temperatura_amostra_final': null,
        'densidade_20_final': null,
        'fator_correcao_final': null,
        'volume_20_final': null,
        'massa_final': null,
        
        'volume_ambiente_inicial': volumeInicial,
        'volume_ambiente_final': null,
        'entrada_saida_ambiente': null,
        'entrada_saida_20': null,
        'faturado_final': null,
        'diferenca_faturado': null,
        'porcentagem_diferenca': null,
        
        'created_by': session.user.id,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      dadosParaInserir.removeWhere((key, value) => value == null);
      
      await supabase.from('cacl').insert(dadosParaInserir);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ CACL salvo como pendente!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 1500));
        
        int contadorPop = 0;
        Navigator.of(context).popUntil((route) {
          if (contadorPop >= 2) {
            return true;
          }
          contadorPop++;
          return false;
        });
      }
      
    } catch (e) {
      print('ERRO ao salvar como pendente: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEmittingCACL = false;
        });
      }
    }
  }

  bool _dadosFinaisEstaoCompletos() {
    final medicoes = widget.dadosFormulario['medicoes'] ?? {};
    
    // Lista dos campos OBRIGATÓRIOS para medição final
    final camposObrigatorios = [
      'cmFinal',          // Altura total cm
      'mmFinal',          // Altura total mm  
      'alturaAguaFinal',  // Altura da água
      'tempTanqueFinal',  // Temperatura tanque
      'densidadeFinal',   // Densidade observada
      'tempAmostraFinal', // Temperatura amostra
      'horarioFinal',     // Horário final
    ];
    
    // Verifica cada campo
    for (var campo in camposObrigatorios) {
      final valor = medicoes[campo]?.toString() ?? '';
      
      // Se o campo estiver vazio, com "-" ou "0", considera incompleto
      if (valor.isEmpty || valor == '-' || valor == '0') {
        return false; // Dados finais incompletos
      }
    }
    
    return true; // Todos os dados finais estão preenchidos
  }
}