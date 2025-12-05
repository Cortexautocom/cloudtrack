import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'cacl.dart';

class MedicaoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? filialSelecionadaId;

  const MedicaoTanquesPage({
    super.key,
    required this.onVoltar,
    this.filialSelecionadaId,
  });

  @override
  State<MedicaoTanquesPage> createState() => _MedicaoTanquesPageState();
}

class _MedicaoTanquesPageState extends State<MedicaoTanquesPage> {
  List<Map<String, dynamic>> tanques = [];
  final List<List<TextEditingController>> _controllers = [];
  final TextEditingController _dataController = TextEditingController(
    text: '${DateTime.now().day.toString().padLeft(2,'0')}/${DateTime.now().month.toString().padLeft(2,'0')}/${DateTime.now().year}'
  );
  
  int _tanqueSelecionadoIndex = 0;
  bool _carregando = true;
  String? _nomeFilial;

  @override
  void initState() {
    super.initState();
    _carregarTanques();
  }

  Future<void> _carregarTanques() async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;
      
      final PostgrestTransformBuilder<dynamic> query;

      // ---------------------------
      //   BUSCAR NOME DA FILIAL
      // ---------------------------
      String? nomeFilial;
      if (usuario.nivel == 3 && widget.filialSelecionadaId != null) {
        final filialData = await supabase
            .from('filiais')
            .select('nome')
            .eq('id', widget.filialSelecionadaId!)
            .single();
        nomeFilial = filialData['nome'];
      } else if (usuario.filialId != null) {
        final filialData = await supabase
            .from('filiais')
            .select('nome')
            .eq('id', usuario.filialId!)
            .single();
        nomeFilial = filialData['nome'];
      }

      setState(() {
        _nomeFilial = nomeFilial;
      });

      // ---------------------------
      //   ADMINISTRADOR (NÍVEL 3)
      // ---------------------------
      if (usuario.nivel == 3) {
        if (widget.filialSelecionadaId == null) {
          print("ERRO: Admin não escolheu filial.");
          setState(() => _carregando = false);
          return;
        }

        query = supabase
            .from('tanques')
            .select('''
              referencia,
              capacidade,
              id_produto,
              produtos (nome)
            ''')
            .eq('id_filial', widget.filialSelecionadaId!)
            .order('referencia');
      } 
      
      // ---------------------------
      //   USUÁRIO NÍVEL 2
      // ---------------------------
      else {
        final idFilial = usuario.filialId;

        if (idFilial == null) {
          print('Erro: ID da filial não encontrado para usuário não-admin');
          setState(() => _carregando = false);
          return;
        }

        query = supabase
            .from('tanques')
            .select('''
              referencia,
              capacidade,
              id_produto,
              produtos (nome)
            ''')
            .eq('id_filial', idFilial)
            .order('referencia');
      }

      // ---------------------------
      //      EXECUTA CONSULTA
      // ---------------------------
      final tanquesResponse = await query;

      print('Tanques encontrados: ${tanquesResponse.length}');

      final List<Map<String, dynamic>> tanquesFormatados = [];

      for (final tanque in tanquesResponse) {
        tanquesFormatados.add({
          'numero': tanque['referencia']?.toString() ?? 'SEM REFERÊNCIA',
          'produto': tanque['produtos']?['nome']?.toString() ?? 'PRODUTO NÃO INFORMADO',
          'capacidade': '${tanque['capacidade']?.toString() ?? '0'} L',
        });
      }

      setState(() {
        tanques = tanquesFormatados;
        _carregando = false;
      });

      // ---------------------------
      //    INICIALIZA CONTROLLERS
      // ---------------------------
      for (int i = 0; i < tanques.length; i++) {
        _controllers.add([
          // Manhã (06:00) - 7 campos originais
          TextEditingController(), // [0] Horário Medição
          TextEditingController(), // [1] cm
          TextEditingController(), // [2] mm
          TextEditingController(), // [3] Temp. Tanque
          TextEditingController(), // [4] Densidade
          TextEditingController(), // [5] Temp. Amostra
          TextEditingController(), // [6] Observações
          
          // Novos campos para manhã
          TextEditingController(), // [7] Altura Água cm
          TextEditingController(), // [8] Altura Água mm
          TextEditingController(), // [9] Vol. Canalização
          
          // Tarde (18:00) - 7 campos originais
          TextEditingController(), // [10] Horário Medição
          TextEditingController(), // [11] cm
          TextEditingController(), // [12] mm
          TextEditingController(), // [13] Temp. Tanque
          TextEditingController(), // [14] Densidade
          TextEditingController(), // [15] Temp. Amostra
          TextEditingController(), // [16] Observações
          
          // Novos campos para tarde
          TextEditingController(), // [17] Altura Água cm
          TextEditingController(), // [18] Altura Água mm
          TextEditingController(), // [19] Vol. Canalização
        ]);
      }

    } catch (e) {
      setState(() => _carregando = false);
      print('Erro ao carregar tanques: $e');
    }
  }

  // Máscara para horário no formato "12:34 h"
  String _aplicarMascaraHorario(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.length > 4) {
      apenasNumeros = apenasNumeros.substring(0, 4);
    }
    
    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2) {
        resultado += ':';
      }
      resultado += apenasNumeros[i];
    }
    
    if (resultado.isNotEmpty) {
      resultado += ' h';
    }
    
    return resultado;
  }

  // Máscara para temperatura no formato "12,3"
  String _aplicarMascaraTemperatura(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.length > 3) {
      apenasNumeros = apenasNumeros.substring(0, 3);
    }
    
    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 2 && apenasNumeros.length > 2) {
        resultado += ',';
      }
      resultado += apenasNumeros[i];
    }
    
    return resultado;
  }

  // Máscara para densidade no formato "0,123"
  String _aplicarMascaraDensidade(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.length > 4) {
      apenasNumeros = apenasNumeros.substring(0, 4);
    }
    
    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i == 1) {
        resultado += ',';
      }
      resultado += apenasNumeros[i];
    }
    
    // Garante que começa com 0 se não tiver dígito antes da vírgula
    if (resultado.isNotEmpty && !resultado.contains(',') && resultado.length < 4) {
      resultado = '0,$resultado';
    } else if (resultado.isNotEmpty && !resultado.contains(',')) {
      resultado = '${resultado.substring(0, 1)},${resultado.substring(1)}';
    }
    
    return resultado;
  }

  // Máscara para volume no formato "1.234"
  String _aplicarMascaraVolume(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }
    
    String resultado = '';
    for (int i = 0; i < apenasNumeros.length; i++) {
      if (i > 0 && (apenasNumeros.length - i) % 3 == 0) {
        resultado += '.';
      }
      resultado += apenasNumeros[i];
    }
    
    if (resultado.isNotEmpty) {
      resultado += ' L';
    }
    
    return resultado;
  }

  void _gerarCACL() {
    if (tanques.isEmpty) return;
    
    final tanqueAtual = tanques[_tanqueSelecionadoIndex];
    final controllers = _controllers[_tanqueSelecionadoIndex];
    
    // Coletar dados das medições COMPLETO
    final dadosMedicoes = {
      // Medição da manhã (06:00)
      'horarioManha': controllers[0].text,
      'cmManha': controllers[1].text,
      'mmManha': controllers[2].text,
      'tempTanqueManha': controllers[3].text,
      'densidadeManha': controllers[4].text,
      'tempAmostraManha': controllers[5].text,
      'alturaAguaManha': '${controllers[7].text}.${controllers[8].text}', // cm.mm
      'volumeCanalizacaoManha': controllers[9].text.replaceAll(' L', '').replaceAll('.', ''),
      
      // Medição da tarde (18:00)  
      'horarioTarde': controllers[10].text,
      'cmTarde': controllers[11].text,
      'mmTarde': controllers[12].text,
      'tempTanqueTarde': controllers[13].text,
      'densidadeTarde': controllers[14].text,
      'tempAmostraTarde': controllers[15].text,
      'alturaAguaTarde': '${controllers[17].text}.${controllers[18].text}', // cm.mm
      'volumeCanalizacaoTarde': controllers[19].text.replaceAll(' L', '').replaceAll('.', ''),

      // Campos que serão calculados na tela de cálculo
      'volumeProdutoManha': '0',
      'volumeProdutoTarde': '0',
      'volumeAguaManha': '0',
      'volumeAguaTarde': '0',
      'volumeTotalManha': '0',
      'volumeTotalTarde': '0',
      'fatorCorrecaoManha': '1.0',
      'fatorCorrecaoTarde': '1.0',
      'volume20Manha': '0',
      'volume20Tarde': '0',
      'densidade20Manha': '0.000',
      'densidade20Tarde': '0.000',
    };

    // APENAS DATA (sem hora)
    final dataApenas = _dataController.text;

    final dadosFormulario = {
      'data': dataApenas, // ← Apenas data, sem hora
      'base': _nomeFilial ?? 'POLO DE COMBUSTÍVEL',
      'produto': tanqueAtual['produto'],
      'tanque': tanqueAtual['numero'],
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',
      'medicoes': dadosMedicoes,
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CalcPage(dadosFormulario: dadosFormulario),
      ),
    );
  }

  @override
  void dispose() {
    _dataController.dispose();
    for (var list in _controllers) { for (var c in list) c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Header compacto
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1), size: 20),
                onPressed: widget.onVoltar,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              const Text('Medição de tanques',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_dataController.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Icon(Icons.person, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(UsuarioAtual.instance?.nome ?? 'Usuário', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              if (_nomeFilial != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.business, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_nomeFilial!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
              ],
              const Spacer(),
            ]),
          ),

          // Seletor de tanques NO TAMANHO ORIGINAL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: _carregando 
                ? _buildLoadingIndicator()
                : tanques.isEmpty
                    ? _buildEmptyIndicator()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: tanques.asMap().entries.map((entry) {
                            final index = entry.key;
                            final tanque = entry.value;
                            final isSelected = index == _tanqueSelecionadoIndex;
                            
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _tanqueSelecionadoIndex = index;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected ? const Color(0xFF0D47A1) : Colors.white,
                                  foregroundColor: isSelected ? Colors.white : const Color(0xFF0D47A1),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: isSelected ? 2 : 0,
                                  shadowColor: Colors.grey.shade300,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tanque['numero']?.toString() ?? 'N/A',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected ? Colors.white : const Color(0xFF0D47A1),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tanque['produto']?.toString() ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
          ),

          // Card principal compacto
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: _carregando 
                  ? _buildLoadingCard()
                  : tanques.isEmpty
                      ? _buildEmptyCard()
                      : _buildTanqueCard(tanques[_tanqueSelecionadoIndex], _tanqueSelecionadoIndex),
            ),
          ),

          // Botão Gerar CACL compacto
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ElevatedButton(
              onPressed: _gerarCACL,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 2,
                minimumSize: const Size(0, 40),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Gerar CACL',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nenhum tanque encontrado',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 16),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Carregando tanques...', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Nenhum tanque encontrado',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              'Não há tanques cadastrados para esta filial',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int index) {
    final ctrls = _controllers[index];

    return SingleChildScrollView(
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            // Header do card compacto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tanque['numero']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tanque['produto']?.toString() ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tanque['capacidade']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo compacto
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  
                  return isWide
                      ? _buildWideLayout(ctrls)
                      : _buildNarrowLayout(ctrls);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(List<TextEditingController> ctrls) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSection(
            '1ª Medição',
            'Abertura',
            Colors.blue[50]!,
            Colors.blue,
            ctrls.sublist(0, 10), // Agora 10 controllers para manhã
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSection(
            '2ª Medição',
            'Fechamento',
            Colors.green[50]!,
            Colors.green,
            ctrls.sublist(10, 20), // Agora 10 controllers para tarde
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(List<TextEditingController> ctrls) {
    return Column(
      children: [
        _buildSection(
          'MANHÃ',
          '06:00h',
          Colors.blue[50]!,
          Colors.blue,
          ctrls.sublist(0, 10), // Agora 10 controllers para manhã
        ),
        const SizedBox(height: 12),
        _buildSection(
          'TARDE',
          '18:00h',
          Colors.green[50]!,
          Colors.green,
          ctrls.sublist(10, 20), // Agora 10 controllers para tarde
        ),
      ],
    );
  }

  Widget _buildSection(String periodo, String hora, Color bg, Color accent, List<TextEditingController> c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                '$periodo - $hora',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // LINHA 1: Horário, cm, mm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeField('Horário Medição', c[0], '', width: 100),    
              _buildNumberField('cm', c[1], '', width: 100, maxLength: 4), 
              _buildNumberField('mm', c[2], '', width: 100, maxLength: 1), 
            ],
          ),
          const SizedBox(height: 12),

          // LINHA 2: Temperatura, Densidade, Temperatura Amostra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTemperatureField('Temp. Tanque', c[3], '', width: 100), 
              _buildDensityField('Densidade', c[4], '', width: 100),        
              _buildTemperatureField('Temp. Amostra', c[5], '', width: 100), 
            ],
          ),
          const SizedBox(height: 12),

          // LINHA 3: NOVOS CAMPOS - Altura da água cm/mm e Volume na canalização
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNumberField('Água cm', c[6], '', width: 100, maxLength: 3),   // ← MUDOU para 100
              _buildNumberField('Água mm', c[7], '', width: 100, maxLength: 1),   // ← MUDOU para 100
              _buildVolumeField('Vol. Canalização', c[8], '', width: 100),        // ← MUDOU para 100
            ],
          ),
          const SizedBox(height: 12),

          // Observações
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Observações:',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: c[9], // Observações agora é o 10º controller
                maxLines: 2,
                maxLength: 140,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Digite suas observações...',
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, TextEditingController ctrl, String hint, {double width = 100}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final cursorPosition = ctrl.selection.baseOffset;
              final maskedValue = _aplicarMascaraHorario(value);
              
              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: cursorPosition + (maskedValue.length - value.length),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, TextEditingController ctrl, String hint, {double width = 100, int maxLength = 3}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureField(String label, TextEditingController ctrl, String hint, {double width = 100}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final cursorPosition = ctrl.selection.baseOffset;
              final maskedValue = _aplicarMascaraTemperatura(value);
              
              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: cursorPosition + (maskedValue.length - value.length),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDensityField(String label, TextEditingController ctrl, String hint, {double width = 100}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final cursorPosition = ctrl.selection.baseOffset;
              final maskedValue = _aplicarMascaraDensidade(value);
              
              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: cursorPosition + (maskedValue.length - value.length),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeField(String label, TextEditingController ctrl, String hint, {double width = 100}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 36,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final cursorPosition = ctrl.selection.baseOffset;
              final maskedValue = _aplicarMascaraVolume(value);
              
              if (maskedValue != value) {
                ctrl.value = TextEditingValue(
                  text: maskedValue,
                  selection: TextSelection.collapsed(
                    offset: cursorPosition + (maskedValue.length - value.length),
                  ),
                );
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}