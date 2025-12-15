import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'dart:js' as js;
import 'certificado_pdf.dart';

class CertificadoAnalisePage extends StatefulWidget {
  final VoidCallback onVoltar;

  const CertificadoAnalisePage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<CertificadoAnalisePage> createState() =>
      _CertificadoAnalisePageState();
}

class _CertificadoAnalisePageState extends State<CertificadoAnalisePage> {
  final _formKey = GlobalKey<FormState>();
  String? tipoOperacao;
  // ================= CONTROLLERS =================
  final TextEditingController dataCtrl = TextEditingController();
  final TextEditingController horaCtrl = TextEditingController();
  final FocusNode _focusTempCT = FocusNode();

  final Map<String, TextEditingController> campos = {
    // Cabeçalho
    'transportadora': TextEditingController(),
    'motorista': TextEditingController(),
    'notas': TextEditingController(),

    // Coletas (usuário)
    'tempAmostra': TextEditingController(),
    'densidadeAmostra': TextEditingController(),
    'tempCT': TextEditingController(),

    // Resultados (automáticos)
    'densidade20': TextEditingController(),
    'fatorCorrecao': TextEditingController(),

    // Volumes – Ambiente
    'origemAmb': TextEditingController(),
    'destinoAmb': TextEditingController(),
    'difAmb': TextEditingController(),

    // Volumes – 20°C
    'origem20': TextEditingController(),
    'destino20': TextEditingController(),
    'dif20': TextEditingController(),
  };

  // ================= PRODUTOS =================
  List<String> produtos = [];
  String? produtoSelecionado;
  bool carregandoProdutos = true;

  @override
  void initState() {
    super.initState();
    _setarDataHoraAtual();
    _carregarProdutos();
    _focusTempCT.addListener(() {
      if (!_focusTempCT.hasFocus) {
        _calcularResultadosObtidos();
      }
    });
  }

  void _setarDataHoraAtual() {
    final agora = DateTime.now();
    dataCtrl.text =
        '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    horaCtrl.text =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarProdutos() async {
    try {
      final dados = await Supabase.instance.client
          .from('produtos')
          .select('nome')
          .order('nome');

      setState(() {
        produtos =
            dados.map<String>((p) => p['nome'].toString()).toList();
        carregandoProdutos = false;
      });
    } catch (_) {
      carregandoProdutos = false;
    }
  }

  // ================= CÁLCULOS =================
  Future<void> _calcularResultadosObtidos() async {

    if (produtoSelecionado == null) {
      return;
    }

    final tempAmostra = campos['tempAmostra']!.text;
    final densObs = campos['densidadeAmostra']!.text;
    final tempCT = campos['tempCT']!.text;

    // Limpar campos antes de buscar
    campos['densidade20']!.text = '';
    campos['fatorCorrecao']!.text = '';

    final dens20 = await _buscarDensidade20C(
      temperaturaAmostra: tempAmostra,
      densidadeObservada: densObs,
      produtoNome: produtoSelecionado!,
    );

    campos['densidade20']!.text = dens20;

    final fcv = dens20 != '-'
        ? await _buscarFCV(
            temperaturaTanque: tempCT,
            densidade20C: dens20,
            produtoNome: produtoSelecionado!,
          )
        : '-';

    campos['fatorCorrecao']!.text = fcv;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const Text(
              'Certificado de Análise',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ],
        ),
        const Divider(),

        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ============ SEÇÃO TIPO DE OPERAÇÃO ============
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              'TIPO DE OPERAÇÃO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  // Opção Carregamento
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Carregamento',
                                          groupValue: tipoOperacao,
                                          onChanged: (String? value) {
                                            setState(() {
                                              tipoOperacao = value;
                                            });
                                          },
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                        const Text('Carregamento'),
                                      ],
                                    ),
                                  ),

                                  // Opção Descarga
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: 'Descarga',
                                          groupValue: tipoOperacao,
                                          onChanged: (String? value) {
                                            setState(() {
                                              tipoOperacao = value;
                                            });
                                          },
                                          activeColor: const Color(0xFF0D47A1),
                                        ),
                                        const Text('Descarga'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                        // ================================================

                        // PRIMEIRA LINHA: Nota Fiscal, Produto, Data, Hora (4 campos)
                        // COM CONTROLE DE TAMANHO: Data e Hora menores
                        _linhaFlexivel([
                          {
                            'flex': 5, // Notas Fiscais (41.7%)
                            'widget': _campo('Notas Fiscais', campos['notas']!),
                          },
                          {
                            'flex': 5, // Produto (41.7%)
                            'widget': carregandoProdutos
                                ? const CircularProgressIndicator()
                                : DropdownButtonFormField<String>(
                                    value: produtoSelecionado,
                                    items: produtos
                                        .map(
                                          (p) => DropdownMenuItem<String>(
                                            value: p,
                                            child: Text(p),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (valor) {
                                      setState(() {
                                        produtoSelecionado = valor;
                                      });
                                      _calcularResultadosObtidos();
                                    },
                                    decoration: _decoration('Produto'),
                                  ),
                          },
                          {
                            'flex': 3, // Data (8.3%) - MENOR
                            'widget': _campo('Data', dataCtrl, enabled: false),
                          },
                          {
                            'flex': 2, // Hora (8.3%) - MENOR
                            'widget': _campo('Hora', horaCtrl, enabled: false),
                          },
                        ]),

                        const SizedBox(height: 12),

                        // SEGUNDA LINHA: Motorista e Transportadora (2 campos)
                        _linha([
                          _campo('Motorista', campos['motorista']!),
                          _campo('Transportadora', campos['transportadora']!),
                        ]),

                        const SizedBox(height: 20),
                        _secao('Coletas na presença do motorista'),

                        _linha([
                          _campo('Temperatura da amostra (°C)', campos['tempAmostra']!),
                          _campo('Densidade observada', campos['densidadeAmostra']!),
                          TextFormField(
                            controller: campos['tempCT'],
                            focusNode: _focusTempCT,
                            decoration: _decoration('Temperatura do CT (°C)'),
                            onChanged: (_) => _calcularResultadosObtidos(),
                          ),
                        ]),

                        const SizedBox(height: 20),
                        _secao('Resultados obtidos'),

                        _linha([
                          _campo('Densidade a 20 ºC', campos['densidade20']!, enabled: false),
                          _campo('Fator de correção (FCV)', campos['fatorCorrecao']!, enabled: false),
                        ]),

                        const SizedBox(height: 20),
                        _secao('Volumes apurados - Ambiente'),

                        _linha([
                          _campo('Quantidade de origem', campos['origemAmb']!),
                          _campo('Quantidade de destino', campos['destinoAmb']!),
                          _campo('Diferença', campos['difAmb']!),
                        ]),

                        const SizedBox(height: 20),
                        _secao('Volumes apurados a 20 ºC'),

                        _linha([
                          _campo('Quantidade de origem', campos['origem20']!),
                          _campo('Quantidade de destino', campos['destino20']!),
                          _campo('Diferença', campos['dif20']!),
                        ]),

                        // 🔴 BOTÃO PARA GERAR CERTIFICADO EM PDF
                        const SizedBox(height: 40),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF0D47A1)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[50],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Text(
                                  'GERAR CERTIFICADO EM PDF',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Clique no botão abaixo para baixar o certificado em formato PDF',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _baixarPDF,
                                  icon: const Icon(Icons.picture_as_pdf, size: 24),
                                  label: const Text(
                                    'BAIXAR CERTIFICADO PDF',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D47A1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'O PDF será gerado com todos os dados preenchidos acima',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= UI HELPERS =================
  Widget _linha(List<Widget> campos) => Row(
        children: campos
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );

  // NOVO MÉTODO: Para linhas com controle flexível de tamanho
  Widget _linhaFlexivel(List<Map<String, dynamic>> camposConfig) => Row(
        children: camposConfig
            .map((config) => Expanded(
                  flex: config['flex'] ?? 1, // flex padrão é 1
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: config['widget'],
                  ),
                ))
            .toList(),
      );

  Widget _campo(String label, TextEditingController c,
      {bool enabled = true}) {
    return TextFormField(
      controller: c,
      enabled: enabled,
      decoration: _decoration(label, disabled: !enabled),
    );
  }

  InputDecoration _decoration(String label,
          {bool disabled = false}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
            disabled ? Colors.grey.shade200 : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6)),
      );

  Widget _secao(String t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 6),
          Text(
            t.toUpperCase(),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1)),
          ),
          const SizedBox(height: 10),
        ],
      );

  // ================= CÁLCULOS - CÓPIA FIÉL DO CACL =================
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
      
      // Formata temperatura igual ao CACL
      String temperaturaFormatada = temperaturaAmostra
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();
      
      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');
      
      // Formata densidade igual ao CACL
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
      
      // Busca inicial
      final resultado = await supabase
          .from(nomeView)
          .select(nomeColuna)
          .eq('temperatura_obs', temperaturaFormatada)
          .maybeSingle();
      
      if (resultado != null && resultado[nomeColuna] != null) {
        String valorBruto = resultado[nomeColuna].toString();
        return _formatarResultado(valorBruto);
      }
      
      // Fallback para formatos alternativos de temperatura (igual ao CACL)
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

      // Formata temperatura igual ao CACL
      String temperaturaFormatada = temperaturaTanque
          .replaceAll(' ºC', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .replaceAll('C', '')
          .trim();

      temperaturaFormatada = temperaturaFormatada.replaceAll('.', ',');

      // Formata densidade igual ao CACL
      String densidadeFormatada = densidade20C
          .replaceAll(' ', '')
          .replaceAll('°C', '')
          .replaceAll('ºC', '')
          .replaceAll('°', '')
          .trim();

      densidadeFormatada = densidadeFormatada.replaceAll('.', ',');

      // CORREÇÃO: Se densidade for maior que 0,8780, usar 0,8780 (igual ao CACL)
      final densidadeNum = double.tryParse(densidadeFormatada.replaceAll(',', '.'));
      final densidadeLimite = 0.8780;
      
      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        densidadeFormatada = '0,8780';        
      }

      // Prepara a densidade no formato correto (igual ao CACL)
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

      // Função auxiliar para formatar resultado
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

      // Função para converter densidade para código de 5 dígitos
      String _densidadeParaCodigo5Digitos(String densidadeStr) {
        if (densidadeStr.contains(',')) {
          final partes = densidadeStr.split(',');
          if (partes.length == 2) {
            String parteInteira = partes[0];
            String parteDecimal = partes[1];

            parteDecimal = parteDecimal.padRight(4, '0');

            String codigo5Digitos = '${parteInteira}${parteDecimal}'.padLeft(5, '0');

            if (codigo5Digitos.length > 5) {
              codigo5Digitos = codigo5Digitos.substring(0, 5);
            }

            return codigo5Digitos;
          }
        }
        return '';
      }

      // Função para buscar FCV com uma densidade específica
      Future<String?> _buscarFCVComDensidade(String codigo5Digitos) async {
        final nomeColuna = 'v_$codigo5Digitos';
        
        try {
          final resultado = await supabase
              .from(nomeView)
              .select(nomeColuna)
              .eq('temperatura_obs', temperaturaFormatada)
              .maybeSingle();

          if (resultado != null && resultado[nomeColuna] != null) {
            String valorBruto = resultado[nomeColuna].toString();
            return _formatarResultadoFCV(valorBruto);
          }
        } catch (e) {
          // Ignora erro e tenta próximo
        }
        return null;
      }

      // Tenta buscar com a densidade fornecida primeiro
      final codigoOriginal = _densidadeParaCodigo5Digitos(densidadeFormatada);
      if (codigoOriginal.isNotEmpty) {
        final resultadoOriginal = await _buscarFCVComDensidade(codigoOriginal);
        if (resultadoOriginal != null) {
          return resultadoOriginal;
        }
      }

      // Se densidade > 0,8780, tenta com a coluna 08780
      if (densidadeNum != null && densidadeNum > densidadeLimite) {
        final resultado08780 = await _buscarFCVComDensidade('08780');
        if (resultado08780 != null) {
          return resultado08780;
        }
      }

      // Se não encontrou, busca pela densidade mais próxima
      if (densidadeNum != null) {
        final List<Map<String, dynamic>> densidadesProximas = [];
        final double passo = 0.0010; // Passo de 0,0010
        final int maxTentativas = 10; // Máximo de 10 tentativas em cada direção
        
        // Busca para cima (densidades maiores)
        for (int i = 1; i <= maxTentativas; i++) {
          final double densidadeTeste = densidadeNum + (i * passo);
          
          // Limite superior: 0,8780 para gasolina/diesel
          if (densidadeTeste > densidadeLimite) break;
          
          final String densidadeTesteStr = densidadeTeste.toStringAsFixed(4);
          final String densidadeTesteFormatada = densidadeTesteStr.replaceAll('.', ',');
          final String codigoTeste = _densidadeParaCodigo5Digitos(densidadeTesteFormatada);
          
          if (codigoTeste.isNotEmpty) {
            final resultado = await _buscarFCVComDensidade(codigoTeste);
            if (resultado != null) {
              densidadesProximas.add({
                'densidade': densidadeTeste,
                'diferenca': densidadeTeste - densidadeNum,
                'resultado': resultado,
              });
            }
          }
        }
        
        // Busca para baixo (densidades menores)
        for (int i = 1; i <= maxTentativas; i++) {
          final double densidadeTeste = densidadeNum - (i * passo);
          
          // Limite inferior: 0,6500 (assumindo mínimo)
          if (densidadeTeste < 0.6500) break;
          
          final String densidadeTesteStr = densidadeTeste.toStringAsFixed(4);
          final String densidadeTesteFormatada = densidadeTesteStr.replaceAll('.', ',');
          final String codigoTeste = _densidadeParaCodigo5Digitos(densidadeTesteFormatada);
          
          if (codigoTeste.isNotEmpty) {
            final resultado = await _buscarFCVComDensidade(codigoTeste);
            if (resultado != null) {
              densidadesProximas.add({
                'densidade': densidadeTeste,
                'diferenca': densidadeNum - densidadeTeste,
                'resultado': resultado,
              });
            }
          }
        }
        
        // Encontra a densidade mais próxima
        if (densidadesProximas.isNotEmpty) {
          // Ordena pela menor diferença
          densidadesProximas.sort((a, b) => a['diferenca'].compareTo(b['diferenca']));          
          return densidadesProximas.first['resultado'];
        }
      }

      // Fallback para formatos alternativos de temperatura (igual ao CACL)
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
          if (codigoOriginal.isNotEmpty) {
            final nomeColuna = 'v_$codigoOriginal';
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

  @override
  void dispose() {
    _focusTempCT.dispose();
    super.dispose();
  }

  // ================= DOWNLOAD PDF =================
  Future<void> _baixarPDF() async {
    // 1. Validações
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (tipoOperacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o tipo de operação!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 2. Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // 3. Prepara os dados para o PDF
      final dadosPDF = {
        'transportadora': campos['transportadora']!.text,
        'motorista': campos['motorista']!.text,
        'notas': campos['notas']!.text,
        'tempAmostra': campos['tempAmostra']!.text,
        'densidadeAmostra': campos['densidadeAmostra']!.text,
        'tempCT': campos['tempCT']!.text,
        'densidade20': campos['densidade20']!.text,
        'fatorCorrecao': campos['fatorCorrecao']!.text,
        'origemAmb': campos['origemAmb']!.text,
        'destinoAmb': campos['destinoAmb']!.text,
        'difAmb': campos['difAmb']!.text,
        'origem20': campos['origem20']!.text,
        'destino20': campos['destino20']!.text,
        'dif20': campos['dif20']!.text,
      };
      
      // 4. Gera o PDF usando a classe separada
      final pdfDocument = await CertificadoPDF.gerar(
        data: dataCtrl.text,
        hora: horaCtrl.text,
        produto: produtoSelecionado,
        campos: dadosPDF,
      );
      
      // 5. Converte o documento para bytes
      final pdfBytes = await pdfDocument.save();
      
      // 6. Fecha loading
      if (context.mounted) Navigator.of(context).pop();
      
      // 7. Faz download
      if (kIsWeb) {
        await _downloadForWeb(pdfBytes);
      } else {
        print('PDF gerado (${pdfBytes.length} bytes) - Plataforma não web');
        _showMobileMessage();
      }
      
      // 8. Mensagem de sucesso
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Certificado baixado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      // 9. Tratamento de erro
      print('ERRO no _baixarPDF: $e');
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Função SIMPLES para download Web
  
  Future<void> _downloadForWeb(Uint8List bytes) async {
    try {
      // Converte bytes para Base64
      final base64 = base64Encode(bytes);
      
      // Cria URL de dados
      final dataUrl = 'data:application/pdf;base64,$base64';
      
      // Cria nome do arquivo
      final fileName = 'Certificado_${produtoSelecionado ?? "Analise"}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // JavaScript para fazer o download
      final jsCode = '''
        try {
          // Cria elemento de link
          const link = document.createElement('a');
          link.href = '$dataUrl';
          link.download = '$fileName';
          link.style.display = 'none';
          
          // Adiciona à página
          document.body.appendChild(link);
          
          // Clica no link para iniciar download
          link.click();
          
          // Remove o link depois de um tempo
          setTimeout(() => {
            document.body.removeChild(link);
          }, 100);
          
          console.log('Download iniciado: ' + '$fileName');
        } catch (error) {
          console.error('Erro no download automático:', error);
          // Fallback: abre em nova aba
          window.open('$dataUrl', '_blank');
        }
      ''';
      
      // Executa o JavaScript
      js.context.callMethod('eval', [jsCode]);
      
    } catch (e) {
      print('Erro no download Web: $e');
      
      // Fallback: instruções manuais
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Como baixar manualmente'),
            content: const Text(
              '1. O PDF foi gerado com sucesso\n'
              '2. Se não baixou automaticamente:\n'
              '3. Clique com botão direito na tela\n'
              '4. Selecione "Salvar página como"\n'
              '5. Salve como arquivo PDF',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Função auxiliar para mobile
  void _showMobileMessage() {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF gerado! Em breve disponível para download no mobile.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }  
}