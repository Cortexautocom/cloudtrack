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
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
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
    
    if (resultado.isNotEmpty && !resultado.contains(',') && resultado.length < 4) {
      resultado = '0,$resultado';
    } else if (resultado.isNotEmpty && !resultado.contains(',')) {
      resultado = '${resultado.substring(0, 1)},${resultado.substring(1)}';
    }
    
    return resultado;
  }

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
    
    // ====================================================
    // 📊 DEBUG COMPLETO - CÁLCULOS QUE SERÃO MOSTRADOS NO CACL
    // ====================================================
    
    print('\n🔍🔍🔍 DEBUG DETALHADO PARA CACL 🔍🔍🔍');
    print('📅 Data: ${_dataController.text}');
    print('🏭 Base: ${_nomeFilial ?? "POLO DE COMBUSTÍVEL"}');
    print('🛢️ Tanque: ${tanqueAtual['numero']}');
    print('⛽ Produto: ${tanqueAtual['produto']}');
    
    // ------------------------------------------------------------------
    // 1️⃣ ALTURA TOTAL DO LÍQUIDO (que aparece na 1ª linha do CACL)
    // ------------------------------------------------------------------
    print('\n1️⃣ ALTURA TOTAL DO LÍQUIDO NO TANQUE:');
    final cmTotalManha = controllers[1].text;
    final mmTotalManha = controllers[2].text;
    final cmTotalTarde = controllers[11].text;
    final mmTotalTarde = controllers[12].text;
    
    print('   MANHÃ: cm="$cmTotalManha", mm="$mmTotalManha"');
    print('   → Formato para CACL: "$cmTotalManha,$mmTotalManha cm"');
    print('   TARDE: cm="$cmTotalTarde", mm="$mmTotalTarde"');
    print('   → Formato para CACL: "$cmTotalTarde,$mmTotalTarde cm"');
    
    // ------------------------------------------------------------------
    // 2️⃣ ALTURA DA ÁGUA (que aparece na 2ª linha do CACL)
    // ------------------------------------------------------------------
    print('\n2️⃣ ALTURA DA ÁGUA AFERIDA NO TANQUE:');
    final cmAguaManha = controllers[6].text;
    final mmAguaManha = controllers[7].text;
    final cmAguaTarde = controllers[16].text;
    final mmAguaTarde = controllers[17].text;
    
    print('   MANHÃ: cm="$cmAguaManha", mm="$mmAguaManha"');
    print('   → Formato para CACL: "$cmAguaManha,$mmAguaManha cm"');
    print('   TARDE: cm="$cmAguaTarde", mm="$mmAguaTarde"');
    print('   → Formato para CACL: "$cmAguaTarde,$mmAguaTarde cm"');
    
    // ------------------------------------------------------------------
    // 3️⃣ CÁLCULO DA ALTURA DO PRODUTO (3ª linha do CACL)
    // ------------------------------------------------------------------
    print('\n3️⃣ CÁLCULO DA ALTURA DO PRODUTO:');
    print('   FÓRMULA: Altura Produto = Altura Total - Altura Água');
    
    // Converter valores para cálculo
    final totalCmManha = double.tryParse(cmTotalManha) ?? 0.0;
    final totalMmManha = double.tryParse(mmTotalManha) ?? 0.0;
    final aguaCmManha = double.tryParse(cmAguaManha) ?? 0.0;
    final aguaMmManha = double.tryParse(mmAguaManha) ?? 0.0;
    
    final totalCmTarde = double.tryParse(cmTotalTarde) ?? 0.0;
    final totalMmTarde = double.tryParse(mmTotalTarde) ?? 0.0;
    final aguaCmTarde = double.tryParse(cmAguaTarde) ?? 0.0;
    final aguaMmTarde = double.tryParse(mmAguaTarde) ?? 0.0;
    
    // Calcular alturas em cm (com decimais)
    final alturaTotalManhaCm = totalCmManha + (totalMmManha / 10);
    final alturaAguaManhaCm = aguaCmManha + (aguaMmManha / 10);
    final alturaProdutoManhaCm = alturaTotalManhaCm - alturaAguaManhaCm;
    
    final alturaTotalTardeCm = totalCmTarde + (totalMmTarde / 10);
    final alturaAguaTardeCm = aguaCmTarde + (aguaMmTarde / 10);
    final alturaProdutoTardeCm = alturaTotalTardeCm - alturaAguaTardeCm;
    
    print('\n   📐 MANHÃ:');
    print('      Altura Total: $totalCmManha cm + ($totalMmManha mm / 10) = ${alturaTotalManhaCm.toStringAsFixed(1)} cm');
    print('      Altura Água: $aguaCmManha cm + ($aguaMmManha mm / 10) = ${alturaAguaManhaCm.toStringAsFixed(1)} cm');
    print('      Altura Produto: ${alturaTotalManhaCm.toStringAsFixed(1)} - ${alturaAguaManhaCm.toStringAsFixed(1)} = ${alturaProdutoManhaCm.toStringAsFixed(1)} cm');
    
    print('\n   📐 TARDE:');
    print('      Altura Total: $totalCmTarde cm + ($totalMmTarde mm / 10) = ${alturaTotalTardeCm.toStringAsFixed(1)} cm');
    print('      Altura Água: $aguaCmTarde cm + ($aguaMmTarde mm / 10) = ${alturaAguaTardeCm.toStringAsFixed(1)} cm');
    print('      Altura Produto: ${alturaTotalTardeCm.toStringAsFixed(1)} - ${alturaAguaTardeCm.toStringAsFixed(1)} = ${alturaProdutoTardeCm.toStringAsFixed(1)} cm');
    
    // Formatar para exibição no CACL (cm,mm)
    String formatarParaCACL(double alturaCm) {
      final parteInteira = alturaCm.floor();
      final parteDecimal = ((alturaCm - parteInteira) * 10).round();
      return '$parteInteira,$parteDecimal cm';
    }
    
    final alturaProdutoManhaFormatada = formatarParaCACL(alturaProdutoManhaCm);
    final alturaProdutoTardeFormatada = formatarParaCACL(alturaProdutoTardeCm);
    
    print('\n   📝 FORMATADO PARA CACL:');
    print('      MANHÃ: $alturaProdutoManhaFormatada');
    print('      TARDE: $alturaProdutoTardeFormatada');
    
    // ------------------------------------------------------------------
    // 4️⃣ OUTROS CAMPOS QUE APARECEM NO CACL
    // ------------------------------------------------------------------
    print('\n4️⃣ OUTROS CAMPOS DO CACL:');
    print('   Temperatura Tanque (Manhã): ${controllers[3].text}°C');
    print('   Densidade (Manhã): ${controllers[4].text}');
    print('   Temperatura Amostra (Manhã): ${controllers[5].text}°C');
    print('   Volume Canalização (Manhã): ${controllers[8].text}');
    
    // ====================================================
    // 📦 CONSTRUINDO OS DADOS QUE SERÃO ENVIADOS
    // ====================================================
    
    print('\n📦 DADOS QUE SERÃO ENVIADOS PARA O CACL:');
    
    final dadosMedicoes = {
      // Linha 1 do CACL: Altura total
      'cmManha': cmTotalManha,
      'mmManha': mmTotalManha,
      'cmTarde': cmTotalTarde,
      'mmTarde': mmTotalTarde,
      
      // Linha 2 do CACL: Altura da água
      'alturaAguaManha': '$cmAguaManha,$mmAguaManha cm',
      'alturaAguaTarde': '$cmAguaTarde,$mmAguaTarde cm',
      
      // Linha 3 do CACL: Altura do produto (CÁLCULO FINAL!)
      'alturaProdutoManha': alturaProdutoManhaFormatada,
      'alturaProdutoTarde': alturaProdutoTardeFormatada,
      
      // Outros campos
      'horarioManha': controllers[0].text,
      'tempTanqueManha': controllers[3].text,
      'densidadeManha': controllers[4].text,
      'tempAmostraManha': controllers[5].text,
      'volumeCanalizacaoManha': controllers[8].text.replaceAll(' L', '').replaceAll('.', ''),
      
      'horarioTarde': controllers[10].text,
      'tempTanqueTarde': controllers[13].text,
      'densidadeTarde': controllers[14].text,
      'tempAmostraTarde': controllers[15].text,
      'volumeCanalizacaoTarde': controllers[18].text.replaceAll(' L', '').replaceAll('.', ''),
      
      // Campos com valores fixos (para outras partes do CACL)
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
    
    // Mostrar resumo do que vai para o CACL
    print('\n📋 RESUMO PARA VERIFICAÇÃO:');
    print('   1ª Linha CACL (Altura total): $cmTotalManha,$mmTotalManha cm / $cmTotalTarde,$mmTotalTarde cm');
    print('   2ª Linha CACL (Altura água): $cmAguaManha,$mmAguaManha cm / $cmAguaTarde,$mmAguaTarde cm');
    print('   3ª Linha CACL (Altura produto): $alturaProdutoManhaFormatada / $alturaProdutoTardeFormatada');
    
    print('\n✅ CÁLCULOS CONCLUÍDOS - ENVIANDO PARA CACL...');
    
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSection(
                                '1ª Medição',
                                'Abertura',
                                Colors.blue[50]!,
                                Colors.blue,
                                ctrls.sublist(0, 10),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSection(
                                '2ª Medição',
                                'Fechamento',
                                Colors.green[50]!,
                                Colors.green,
                                ctrls.sublist(10, 20),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildSection(
                              'MANHÃ',
                              '06:00h',
                              Colors.blue[50]!,
                              Colors.blue,
                              ctrls.sublist(0, 10),
                            ),
                            const SizedBox(height: 12),
                            _buildSection(
                              'TARDE',
                              '18:00h',
                              Colors.green[50]!,
                              Colors.green,
                              ctrls.sublist(10, 20),
                            ),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeField('Horário Medição', c[0], '', width: 100),    
              _buildNumberField('cm', c[1], '', width: 100, maxLength: 4), 
              _buildNumberField('mm', c[2], '', width: 100, maxLength: 1), 
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTemperatureField('Temp. Tanque', c[3], '', width: 100), 
              _buildDensityField('Densidade', c[4], '', width: 100),        
              _buildTemperatureField('Temp. Amostra', c[5], '', width: 100), 
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNumberField('Água cm', c[6], '', width: 100, maxLength: 3),
              _buildNumberField('Água mm', c[7], '', width: 100, maxLength: 1),
              _buildVolumeField('Vol. Canalização', c[8], '', width: 100),
            ],
          ),
          const SizedBox(height: 12),

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
                controller: c[9],
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