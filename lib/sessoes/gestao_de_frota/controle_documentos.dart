import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControleDocumentosPage extends StatefulWidget {
  const ControleDocumentosPage({super.key});

  @override
  State<ControleDocumentosPage> createState() => _ControleDocumentosPageState();
}

class _ControleDocumentosPageState extends State<ControleDocumentosPage> {
  final List<Map<String, dynamic>> _veiculos = [];
  final List<String> _documentos = [
    'CIPP', 'CIV', 'Aferição', 'Tacógrafo', 
    'AET Federal', 'AET Bahia', 'AET Goiás', 
    'AET Alagoas', 'AET Minas G'
  ];
  
  final Map<String, String> _colunasMap = {
    'CIPP': 'cipp',
    'CIV': 'civ',
    'Aferição': 'afericao',
    'Tacógrafo': 'tacografo',
    'AET Federal': 'aet_fed',
    'AET Bahia': 'aet_ba',
    'AET Goiás': 'aet_go',
    'AET Alagoas': 'aet_al',
    'AET Minas G': 'aet_mg',
  };
  
  final _buscaCtrl = TextEditingController();
  
  bool _carregando = true;
  String _filtro = '';
  
  // Controle para edição
  Map<String, dynamic>? _veiculoEditando;
  String? _campoEditando;
  final _edicaoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select()
          .order('placa');
      
      setState(() {
        _veiculos.clear();
        _veiculos.addAll(List<Map<String, dynamic>>.from(data));
      });
    } catch (e) {
      debugPrint('Erro ao carregar veículos: $e');
      _mostrarErro('Erro ao carregar dados');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarData(String placa, String doc, String valor) async {
    try {
      final coluna = _colunasMap[doc];
      if (coluna == null) return;

      // Validar formato da data
      final dataValida = _validarData(valor);
      final valorFinal = valor.trim().isEmpty || !dataValida ? null : valor;

      await Supabase.instance.client
          .from('equipamentos')
          .update({coluna: valorFinal})
          .eq('placa', placa);

      // Atualiza localmente
      final index = _veiculos.indexWhere((v) => v['placa'] == placa);
      if (index != -1) {
        setState(() {
          _veiculos[index][coluna] = valorFinal;
        });
      }

      if (dataValida || valor.trim().isEmpty) {
        _mostrarSucesso('Data atualizada');
      } else {
        _mostrarErro('Formato de data inválido (dd/mm/aaaa)');
      }
    } catch (e) {
      debugPrint('Erro ao salvar data: $e');
      _mostrarErro('Erro ao salvar dados');
    }
  }

  void _iniciarEdicao(Map<String, dynamic> veiculo, String documento) {
    final coluna = _colunasMap[documento];
    if (coluna == null) return;

    final valorAtual = veiculo[coluna] as String? ?? '';
    
    setState(() {
      _veiculoEditando = veiculo;
      _campoEditando = coluna;
      _edicaoCtrl.text = valorAtual;
    });
  }

  void _finalizarEdicao() {
    if (_veiculoEditando != null && _campoEditando != null) {
      final documento = _colunasMap.entries
          .firstWhere((entry) => entry.value == _campoEditando!)
          .key;
      
      _salvarData(
        _veiculoEditando!['placa'],
        documento,
        _edicaoCtrl.text.trim(),
      );
    }
    
    _cancelarEdicao();
  }

  void _cancelarEdicao() {
    setState(() {
      _veiculoEditando = null;
      _campoEditando = null;
      _edicaoCtrl.clear();
    });
  }

  bool _validarData(String texto) {
    if (texto.isEmpty) return true;
    
    final regex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!regex.hasMatch(texto)) return false;
    
    final partes = texto.split('/');
    if (partes.length != 3) return false;
    
    try {
      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);
      
      if (dia < 1 || dia > 31) return false;
      if (mes < 1 || mes > 12) return false;
      if (ano < 2000 || ano > 2100) return false;
      
      return true;
    } catch (_) {
      return false;
    }
  }

  String _aplicarMascara(String texto) {
    final apenasNumeros = texto.replaceAll(RegExp(r'[^\d]'), '');
    
    if (apenasNumeros.isEmpty) return '';
    
    var resultado = '';
    
    for (int i = 0; i < apenasNumeros.length && i < 8; i++) {
      if (i == 2 || i == 4) {
        resultado += '/';
      }
      resultado += apenasNumeros[i];
    }
    
    return resultado;
  }

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    
    final partes = s.split('/');
    if (partes.length != 3) return null;
    
    try {
      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);
      
      return DateTime(ano, mes, dia);
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime? d) => d == null 
      ? '' 
      : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';

  Color _cor(DateTime? d) {
    if (d == null) return Colors.grey;
    
    final dias = d.difference(DateTime.now()).inDays;
    
    if (dias < 0) return Colors.red;
    if (dias <= 30) return Colors.orange;
    if (dias <= 90) return Colors.amber[800]!;
    
    return Colors.green;
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _veiculos
        .where((v) => v['placa'].toString()
            .toLowerCase()
            .contains(_filtro))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Controle de Documentos',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                
                // Campo de busca
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar placa...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Botão atualizar
                IconButton(
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          
          // Cabeçalho da tabela
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                // Coluna Placa
                const SizedBox(
                  width: 140,
                  child: Text(
                    'PLACA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                
                // Documentos
                ..._documentos.map((doc) => Expanded(
                  child: Text(
                    doc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
            ),
          ),
          
          // Corpo da tabela
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                  )
                : filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filtro.isEmpty
                                  ? 'Nenhum veículo cadastrado'
                                  : 'Nenhum veículo encontrado',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (context, index) {
                          final veiculo = filtrados[index];
                          final placa = veiculo['placa'] as String? ?? '';
                          final isEditando = _veiculoEditando != null && 
                              _veiculoEditando!['placa'] == placa;
                          
                          return Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: index.isEven 
                                  ? Colors.white 
                                  : Colors.grey.shade50,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Placa
                                SizedBox(
                                  width: 140,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D47A1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        placa,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Documentos
                                ..._documentos.map((doc) {
                                  final coluna = _colunasMap[doc]!;
                                  final raw = veiculo[coluna] as String?;
                                  final data = _parse(raw);
                                  final cor = _cor(data);
                                  final isEsteCampoEditando = 
                                      isEditando && _campoEditando == coluna;
                                  
                                  return Expanded(
                                    child: isEsteCampoEditando
                                        ? Container(
                                            margin: const EdgeInsets.all(3),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: _edicaoCtrl,
                                                    autofocus: true,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: cor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.all(4),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                        borderSide: BorderSide(
                                                          color: cor,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                        borderSide: BorderSide(
                                                          color: cor,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                        borderSide: BorderSide(
                                                          color: cor,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      hintText: 'dd/mm/aaaa',
                                                      hintStyle: TextStyle(
                                                        color: cor.withOpacity(0.5),
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                    keyboardType: TextInputType.number,
                                                    onChanged: (texto) {
                                                      final mascara = _aplicarMascara(texto);
                                                      if (mascara != texto) {
                                                        _edicaoCtrl.value = TextEditingValue(
                                                          text: mascara,
                                                          selection: TextSelection.collapsed(
                                                            offset: mascara.length,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    onSubmitted: (_) => _finalizarEdicao(),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.check,
                                                        size: 14,
                                                        color: Colors.green,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: _finalizarEdicao,
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        size: 14,
                                                        color: Colors.red,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: _cancelarEdicao,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        : MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onDoubleTap: () => _iniciarEdicao(veiculo, doc),
                                              child: Container(
                                                margin: const EdgeInsets.all(3),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cor.withOpacity(0.1),
                                                  border: Border.all(
                                                    color: cor.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  data == null || raw == null || raw.isEmpty
                                                      ? '--'
                                                      : _fmt(data),
                                                  style: TextStyle(
                                                    color: cor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}