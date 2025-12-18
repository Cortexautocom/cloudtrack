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
  final List<List<FocusNode>> _focusNodes = [];
  
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

      if (usuario.nivel == 3) {
        if (widget.filialSelecionadaId == null) {
          setState(() => _carregando = false);
          return;
        }

        query = supabase
            .from('tanques')
            .select('''
              referencia,
              capacidade,
              id_produto,
              numero,
              produtos (nome)
            ''')
            .eq('id_filial', widget.filialSelecionadaId!)
            .order('numero', ascending: true);
      } else {
        final idFilial = usuario.filialId;

        if (idFilial == null) {
          setState(() => _carregando = false);
          return;
        }

        query = supabase
            .from('tanques')
            .select('''
              referencia,
              capacidade,
              id_produto,
              numero,
              produtos (nome)
            ''')
            .eq('id_filial', idFilial)
            .order('numero', ascending: true);
      }

      final tanquesResponse = await query;

      final List<Map<String, dynamic>> tanquesFormatados = [];

      for (final tanque in tanquesResponse) {
        tanquesFormatados.add({
          'numero': tanque['referencia']?.toString() ?? '',
          'produto': tanque['produtos']?['nome']?.toString() ?? '',
          'capacidade': '${tanque['capacidade']?.toString() ?? '0'} L',
        });
      }

      setState(() {
        tanques = tanquesFormatados;
        _carregando = false;
      });

      for (int i = 0; i < tanques.length; i++) {
        _controllers.add([
          TextEditingController(), // 0 - horário manhã
          TextEditingController(), // 1 - cm manhã
          TextEditingController(), // 2 - mm manhã
          TextEditingController(), // 3 - temp tanque manhã
          TextEditingController(), // 4 - densidade manhã
          TextEditingController(), // 5 - temp amostra manhã
          TextEditingController(), // 6 - água cm manhã
          TextEditingController(), // 7 - água mm manhã
          TextEditingController(), // 8 - faturado manhã  // NOVO CAMPO
          TextEditingController(), // 9 - observações manhã // MOVED DOWN
          TextEditingController(), // 10 - horário tarde
          TextEditingController(), // 11 - cm tarde
          TextEditingController(), // 12 - mm tarde
          TextEditingController(), // 13 - temp tanque tarde
          TextEditingController(), // 14 - densidade tarde
          TextEditingController(), // 15 - temp amostra tarde
          TextEditingController(), // 16 - água cm tarde
          TextEditingController(), // 17 - água mm tarde
          TextEditingController(), // 18 - faturado tarde  // NOVO CAMPO          
        ]);

        _focusNodes.add([
          FocusNode(), // 0 - horário manhã
          FocusNode(), // 1 - cm manhã
          FocusNode(), // 2 - mm manhã
          FocusNode(), // 3 - temp tanque manhã
          FocusNode(), // 4 - densidade manhã
          FocusNode(), // 5 - temp amostra manhã
          FocusNode(), // 6 - água cm manhã
          FocusNode(), // 7 - água mm manhã
          FocusNode(), // 8 - faturado manhã  // NOVO
          FocusNode(), // 9 - observações manhã
          FocusNode(), // 10 - horário tarde
          FocusNode(), // 11 - cm tarde
          FocusNode(), // 12 - mm tarde
          FocusNode(), // 13 - temp tanque tarde
          FocusNode(), // 14 - densidade tarde
          FocusNode(), // 15 - temp amostra tarde
          FocusNode(), // 16 - água cm tarde
          FocusNode(), // 17 - água mm tarde
          FocusNode(), // 18 - faturado tarde  // NOVO          
        ]);
      }

    } catch (e) {
      setState(() => _carregando = false);
    }
  }

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

  String _aplicarMascaraDensidade(String texto) {
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');

    if (apenasNumeros.length > 5) {
      apenasNumeros = apenasNumeros.substring(0, 5);
    }

    if (apenasNumeros.isEmpty) return '';

    String parteInteira = apenasNumeros.substring(0, 1);
    String parteDecimal = '';
    if (apenasNumeros.length > 1) {
      parteDecimal = apenasNumeros.substring(1);
    }

    return parteDecimal.isEmpty
        ? '$parteInteira,'
        : '$parteInteira,$parteDecimal';
  }

  void _gerarCACL() {
    if (tanques.isEmpty) return;
    
    final tanqueAtual = tanques[_tanqueSelecionadoIndex];
    final controllers = _controllers[_tanqueSelecionadoIndex];
    
    final cmTotalManha = controllers[1].text;
    final mmTotalManha = controllers[2].text;
    final cmTotalTarde = controllers[10].text;
    final mmTotalTarde = controllers[11].text;
    
    final cmAguaManha = controllers[6].text;
    final mmAguaManha = controllers[7].text;
    final cmAguaTarde = controllers[15].text;
    final mmAguaTarde = controllers[16].text;
    
    final totalCmManha = double.tryParse(cmTotalManha) ?? 0.0;
    final totalMmManha = double.tryParse(mmTotalManha) ?? 0.0;
    final aguaCmManha = double.tryParse(cmAguaManha) ?? 0.0;
    final aguaMmManha = double.tryParse(mmAguaManha) ?? 0.0;
    
    final totalCmTarde = double.tryParse(cmTotalTarde) ?? 0.0;
    final totalMmTarde = double.tryParse(mmTotalTarde) ?? 0.0;
    final aguaCmTarde = double.tryParse(cmAguaTarde) ?? 0.0;
    final aguaMmTarde = double.tryParse(mmAguaTarde) ?? 0.0;
    
    final alturaTotalManhaCm = totalCmManha + (totalMmManha / 10);
    final alturaAguaManhaCm = aguaCmManha + (aguaMmManha / 10);
    final alturaProdutoManhaCm = alturaTotalManhaCm - alturaAguaManhaCm;
    
    final alturaTotalTardeCm = totalCmTarde + (totalMmTarde / 10);
    final alturaAguaTardeCm = aguaCmTarde + (aguaMmTarde / 10);
    final alturaProdutoTardeCm = alturaTotalTardeCm - alturaAguaTardeCm;
    
    String formatarParaCACL(double alturaCm) {
      final parteInteira = alturaCm.floor();
      final parteDecimal = ((alturaCm - parteInteira) * 10).round();
      return '$parteInteira,$parteDecimal cm';
    }
    
    final alturaProdutoManhaFormatada = formatarParaCACL(alturaProdutoManhaCm);
    final alturaProdutoTardeFormatada = formatarParaCACL(alturaProdutoTardeCm);
    
    final dadosMedicoes = {
      'cmManha': cmTotalManha,
      'mmManha': mmTotalManha,
      'cmTarde': cmTotalTarde,
      'mmTarde': mmTotalTarde,
      
      'alturaAguaManha': '$cmAguaManha,$mmAguaManha cm',
      'alturaAguaTarde': '$cmAguaTarde,$mmAguaTarde cm',
      
      'alturaProdutoManha': alturaProdutoManhaFormatada,
      'alturaProdutoTarde': alturaProdutoTardeFormatada,
      
      'horarioManha': controllers[0].text,
      'tempTanqueManha': controllers[3].text,
      'densidadeManha': controllers[4].text,
      'tempAmostraManha': controllers[5].text,
      
      'horarioTarde': controllers[9].text,
      'tempTanqueTarde': controllers[12].text,
      'densidadeTarde': controllers[13].text,
      'tempAmostraTarde': controllers[14].text,
      
      'faturadoTarde': controllers[17].text,
      
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
    
    final dadosFormulario = {
      'data': _dataController.text,
      'base': _nomeFilial ?? 'POLO DE COMBUSTÍVEL',
      'produto': tanqueAtual['produto'],
      'tanque': tanqueAtual['numero'],
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',
      'medicoes': dadosMedicoes,
      'filial_id': UsuarioAtual.instance!.nivel == 3 && widget.filialSelecionadaId != null 
          ? widget.filialSelecionadaId 
          : UsuarioAtual.instance!.filialId,
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
    for (var list in _controllers) { 
      for (var c in list) c.dispose(); 
    }
    for (var list in _focusNodes) { 
      for (var f in list) f.dispose(); 
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
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
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : tanques.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Nenhum tanque encontrado',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: tanques.asMap().entries.map((entry) {
                            final index = entry.key;
                            final tanque = entry.value;
                            final isSelected = index == _tanqueSelecionadoIndex;
                            
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 120,
                              constraints: const BoxConstraints(minWidth: 30),
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

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: _carregando 
                  ? Card(
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
                    )
                  : tanques.isEmpty
                      ? Card(
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
                        )
                      : _buildTanqueCard(tanques[_tanqueSelecionadoIndex], _tanqueSelecionadoIndex),
            ),
          ),

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
                    'Pré-visualização',
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

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int index) {
    final ctrls = _controllers[index];
    final focusNodes = _focusNodes[index];

    return SingleChildScrollView(
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
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

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSection(
                      '1ª Medição',
                      'Abertura',
                      Colors.blue[50]!,
                      Colors.blue,
                      ctrls.sublist(0, 9), // PRIMEIRA MEDIÇÃO: 9 campos (0-8)
                      focusNodes.sublist(0, 9),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSection(
                      '2ª Medição',
                      'Fechamento',
                      Colors.green[50]!,
                      Colors.green,
                      ctrls.sublist(9, 19), // SEGUNDA MEDIÇÃO: 10 campos (9-18)
                      focusNodes.sublist(9, 19),
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

  Widget _buildSection(String periodo, String hora, Color bg, Color accent, 
      List<TextEditingController> c, List<FocusNode> f) {
    
    // Determina se é a segunda medição (com faturado)
    final bool ehSegundaMedicao = periodo.contains('2ª');
    
    return FocusScope(
      child: Container(
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

            // PRIMEIRA LINHA: Horário, cm, mm
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeField('Horário Medição', c[0], '', 
                    width: 100, focusNode: f[0], nextFocus: f[1]),
                _buildNumberField('cm', c[1], '', 
                    width: 100, maxLength: 4, focusNode: f[1], nextFocus: f[2]),
                _buildNumberField('mm', c[2], '', 
                    width: 100, maxLength: 1, focusNode: f[2], nextFocus: f[3]),
              ],
            ),
            const SizedBox(height: 12),

            // SEGUNDA LINHA: Temp. Tanque, Densidade, Temp. Amostra
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTemperatureField('Temp. Tanque', c[3], '', 
                    width: 100, focusNode: f[3], nextFocus: f[4]),
                _buildDensityField('Densidade Obs.', c[4], '', 
                    width: 100, focusNode: f[4], nextFocus: f[5]),
                _buildTemperatureField('Temp. Amostra', c[5], '', 
                    width: 100, focusNode: f[5], nextFocus: f[6]),
              ],
            ),
            const SizedBox(height: 12),

            // TERCEIRA LINHA: Água cm, Água mm, (Faturado ou fantasma)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNumberField('Água cm', c[6], '', 
                    width: 100, maxLength: 1, focusNode: f[6], nextFocus: f[7]),
                _buildNumberField('Água mm', c[7], '', 
                    width: 100, maxLength: 1, focusNode: f[7], nextFocus: f[8]),
                // Faturado apenas na segunda medição
                ehSegundaMedicao 
                    ? _buildFaturadoField('Faturado', c[8], '', 
                        width: 100, focusNode: f[8], nextFocus: f[9])
                    : _buildGhostField(width: 100),
              ],
            ),
            const SizedBox(height: 12),

            // OBSERVAÇÕES
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
                  controller: ehSegundaMedicao ? c[9] : c[8],
                  focusNode: ehSegundaMedicao ? f[9] : f[8],
                  textInputAction: TextInputAction.done,
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
      ),
    );
  }

  Widget _buildTimeField(String label, TextEditingController ctrl, String hint, 
      {double width = 100, FocusNode? focusNode, FocusNode? nextFocus}) {
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
            focusNode: focusNode,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
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

  Widget _buildNumberField(String label, TextEditingController ctrl, String hint, 
      {double width = 100, int maxLength = 3, FocusNode? focusNode, FocusNode? nextFocus}) {
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
            focusNode: focusNode,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
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

  Widget _buildTemperatureField(String label, TextEditingController ctrl, String hint, 
      {double width = 100, FocusNode? focusNode, FocusNode? nextFocus}) {
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
            focusNode: focusNode,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
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

  Widget _buildDensityField(String label, TextEditingController ctrl, String hint, 
      {double width = 100, FocusNode? focusNode, FocusNode? nextFocus}) {
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
            focusNode: focusNode,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
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

  String _aplicarMascaraFaturado(String texto) {
    // Remove tudo que não é número
    String apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limita a 6 dígitos (999999 = 999.999)
    if (apenasNumeros.length > 6) {
      apenasNumeros = apenasNumeros.substring(0, 6);
    }
    
    if (apenasNumeros.isEmpty) return '';
    
    // Se tiver mais de 3 dígitos, adiciona o ponto
    if (apenasNumeros.length > 3) {
      String parteMilhar = apenasNumeros.substring(0, apenasNumeros.length - 3);
      String parteCentena = apenasNumeros.substring(apenasNumeros.length - 3);
      return '$parteMilhar.$parteCentena';
    }
    
    return apenasNumeros;
  }

  Widget _buildFaturadoField(String label, TextEditingController ctrl, String hint, 
      {double width = 100, FocusNode? focusNode, FocusNode? nextFocus}) {
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
            focusNode: focusNode,
            textInputAction: nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => nextFocus?.requestFocus(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            onChanged: (value) {
              final cursorPosition = ctrl.selection.baseOffset;
              final maskedValue = _aplicarMascaraFaturado(value);
              
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

  Widget _buildGhostField({double width = 100}) {
    return Column(
      children: [
        // Label invisível (mantém o espaço)
        Opacity(
          opacity: 0,
          child: Text(
            ' ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Container vazio com mesma altura
        Container(
          width: width,
          height: 36,
        ),
      ],
    );
  }

}