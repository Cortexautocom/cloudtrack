import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'cacl.dart';

class MedicaoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  const MedicaoTanquesPage({super.key, required this.onVoltar});

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
      
      if (usuario.nivel == 3) {
        query = supabase
            .from('tanques')
            .select('''
              referencia,
              capacidade,
              id_produto,
              produtos (nome)
            ''')
            .order('referencia');
      } else {
        final idFilial = usuario.filialId;
        if (idFilial == null) {
          print('Erro: ID da filial não encontrado para usuário não-admin');
          setState(() {
            _carregando = false;
          });
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

      // Inicializa os controllers com campos em branco
      for (int i = 0; i < tanques.length; i++) {
        _controllers.add([
          TextEditingController(), // Horário Medição (06:00)
          TextEditingController(), // cm (735)
          TextEditingController(), // mm (35)
          TextEditingController(), // Temp. Tanque (28.5)
          TextEditingController(), // Densidade (0.745)
          TextEditingController(), // Temp. Amostra (28.0)
          TextEditingController(), // Observações
          TextEditingController(), // Horário Medição (18:00)
          TextEditingController(), // cm (685)
          TextEditingController(), // mm (20)
          TextEditingController(), // Temp. Tanque (29.0)
          TextEditingController(), // Densidade (0.745)
          TextEditingController(), // Temp. Amostra (28.5)
          TextEditingController(), // Observações
        ]);
      }
    } catch (e) {
      setState(() {
        _carregando = false;
      });
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

  void _gerarCACL() {
    if (tanques.isEmpty) return;
    
    final tanqueAtual = tanques[_tanqueSelecionadoIndex];
    final dadosFormulario = {
      'data': _dataController.text,
      'base': 'POLO DE COMBUSTÍVEL',
      'produto': tanqueAtual['produto'],
      'tanque': tanqueAtual['numero'],
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',
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
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // TAMANHO ORIGINAL
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
                                        fontSize: 14, // TAMANHO ORIGINAL
                                        color: isSelected ? Colors.white : const Color(0xFF0D47A1),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tanque['produto']?.toString() ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 10, // TAMANHO ORIGINAL
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

          // Card principal compacto (mantido do anterior)
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
            ctrls.sublist(0, 7),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSection(
            '2ª Medição',
            ' Fechamento',
            Colors.green[50]!,
            Colors.green,
            ctrls.sublist(7, 14),
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
          ctrls.sublist(0, 7),
        ),
        const SizedBox(height: 12),
        _buildSection(
          'TARDE',
          '18:00h',
          Colors.green[50]!,
          Colors.green,
          ctrls.sublist(7, 14),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeField('Horário Medição', c[0], '06:00 h', width: 110),
              _buildNumberField('cm', c[1], '735', width: 90, maxLength: 3),
              _buildNumberField('mm', c[2], '35', width: 90, maxLength: 1),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTemperatureField('Temp. Tanque', c[3], '28,5', width: 100),
              _buildDensityField('Densidade', c[4], '0,745', width: 100),
              _buildTemperatureField('Temp. Amostra', c[5], '28,0', width: 100),
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
                controller: c[6],
                maxLines: 2,
                maxLength: 90,
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
}