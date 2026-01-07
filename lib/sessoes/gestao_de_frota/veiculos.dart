import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==============================
// PÁGINA PRINCIPAL DE VEÍCULOS (VERSÃO COMPACTA)
// ==============================
class VeiculosPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelecionarVeiculo;
  final VoidCallback onVoltar;
  
  const VeiculosPage({
    super.key,
    required this.onSelecionarVeiculo,
    required this.onVoltar,
  });

  @override
  State<VeiculosPage> createState() => _VeiculosPageState();
}

class _VeiculosPageState extends State<VeiculosPage> {
  List<Map<String, dynamic>> _veiculos = [];
  bool _carregando = true;
  String _filtroPlaca = '';
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select('placa, bocas')
          .order('placa');
      
      setState(() {
        _veiculos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Erro ao carregar veículos: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<int> _parseBocas(dynamic bocasData) {
    if (bocasData is List) return bocasData.cast<int>();
    return [];
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    if (_filtroPlaca.isEmpty) return _veiculos;
    
    return _veiculos.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      return placa.contains(_filtroPlaca.toLowerCase());
    }).toList();
  }

  void _abrirCadastroVeiculo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DialogCadastroVeiculo(),
    ).then((_) => _carregarVeiculos());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirCadastroVeiculo,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
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
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Veículos',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                
                // Busca
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _buscaController,
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
                    onChanged: (v) => setState(() => _filtroPlaca = v),
                  ),
                ),
                
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _carregarVeiculos,
                  icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          
          // Cabeçalho da tabela
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const Row(
              children: [
                _CabecalhoTabela(texto: 'PLACA', largura: 120),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'COMPARTIMENTOS (m³)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Corpo da tabela
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                  )
                : _veiculosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_car_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filtroPlaca.isEmpty
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
                        itemCount: _veiculosFiltrados.length,
                        itemBuilder: (context, index) {
                          final veiculo = _veiculosFiltrados[index];
                          final placa = veiculo['placa']?.toString() ?? '';
                          final bocas = _parseBocas(veiculo['bocas']);
                          
                          return Container(
                            height: 48, // Altura reduzida
                            decoration: BoxDecoration(
                              color: index.isEven 
                                  ? Colors.white 
                                  : Colors.grey.shade50,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: InkWell(
                              onTap: () => widget.onSelecionarVeiculo({
                                'placa': placa,
                                'bocas': bocas,
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    // Placa (sem fundo azul)
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        placa,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0D47A1),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 8),
                                    
                                    // Bocas
                                    Expanded(
                                      child: bocas.isEmpty
                                          ? const Text(
                                              '--',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic,
                                                fontSize: 12,
                                              ),
                                            )
                                          : Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: bocas.map((capacidade) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _getCorBoca(capacidade)
                                                        .withOpacity(0.1),
                                                    border: Border.all(
                                                      color: _getCorBoca(capacidade)
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '$capacidade',
                                                    style: TextStyle(
                                                      color: _getCorBoca(capacidade),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getCorBoca(int capacidade) {
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.cyan,
      Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }
}

class _CabecalhoTabela extends StatelessWidget {
  final String texto;
  final double largura;

  const _CabecalhoTabela({
    required this.texto,
    required this.largura,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
          fontSize: 12,
        ),
      )
    );
  }
}

// ==============================
// DIÁLOGO DE CADASTRO DE VEÍCULO
// ==============================
class DialogCadastroVeiculo extends StatefulWidget {
  const DialogCadastroVeiculo({super.key});

  @override
  State<DialogCadastroVeiculo> createState() => _DialogCadastroVeiculoState();
}

class _DialogCadastroVeiculoState extends State<DialogCadastroVeiculo> {
  final List<PlacaController> _placasControllers = [];
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
  
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _adicionarPlaca();
  }

  void _adicionarPlaca() {
    setState(() {
      _placasControllers.add(PlacaController());
    });
  }

  void _removerPlaca(int index) {
    if (_placasControllers.length > 1) {
      setState(() {
        _placasControllers.removeAt(index);
      });
    }
  }

  String _aplicarMascaraData(String texto) {
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

  Future<void> _salvarCadastro() async {
    if (_salvando) return;

    // Validar placas
    for (final controller in _placasControllers) {
      final placa = controller.placaController.text.trim().toUpperCase();
      if (placa.isEmpty) {
        _mostrarErro('Informe a placa do veículo');
        return;
      }
      if (placa.length < 7) {
        _mostrarErro('Placa inválida: $placa');
        return;
      }
    }

    // Validar datas
    for (final controller in _placasControllers) {
      for (final doc in _documentos) {
        final dataCtrl = controller.documentosControllers[doc];
        if (dataCtrl != null && dataCtrl.text.isNotEmpty) {
          if (!_validarData(dataCtrl.text)) {
            _mostrarErro('Data inválida no documento $doc: ${dataCtrl.text}');
            return;
          }
        }
      }
    }

    setState(() => _salvando = true);

    try {
      final client = Supabase.instance.client;

      for (final controller in _placasControllers) {
        final placa = controller.placaController.text.trim().toUpperCase();
        final dados = <String, dynamic>{
          'placa': placa,
        };

        // Adicionar bocas se existirem
        final bocasValidas = <int>[];
        for (int i = 0; i < controller.bocasValues.length; i++) {
          final valor = controller.bocasValues[i];
          if (valor != null && valor > 0) {
            bocasValidas.add(valor);
          }
        }
        
        if (bocasValidas.isNotEmpty) {
          dados['bocas'] = bocasValidas;
        }

        // Adicionar documentos
        for (final doc in _documentos) {
          final dataCtrl = controller.documentosControllers[doc];
          if (dataCtrl != null && dataCtrl.text.isNotEmpty) {
            final coluna = _colunasMap[doc];
            if (coluna != null) {
              dados[coluna] = dataCtrl.text.trim();
            }
          }
        }

        await client.from('equipamentos').upsert(dados);
      }

      _mostrarSucesso('Veículos cadastrados com sucesso!');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Erro ao cadastrar veículos: $e');
      _mostrarErro('Erro ao cadastrar: ${e.toString()}');
    } finally {
      setState(() => _salvando = false);
    }
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _placasControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Cadastrar Novo Veículo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lista de placas
                    ..._placasControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      
                      // Garantir que temos controllers para todas as bocas
                      while (controller.bocasControllers.length < controller.numeroBocas) {
                        controller.bocasControllers.add(TextEditingController());
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller.placaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Placa (ex: ABC-1234)',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (_placasControllers.length > 1) ...[
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () => _removerPlaca(index),
                                  ),
                                ],
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Seção de Bocas
                            const Text(
                              'Compartimentos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Row(
                              children: [
                                // Dropdown para número de bocas
                                Container(
                                  width: 100,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: controller.numeroBocas == 0 ? null : controller.numeroBocas,
                                      isExpanded: true,
                                      hint: const Text('Selecione'),
                                      items: List.generate(10, (i) => i + 1)
                                          .map((valor) => DropdownMenuItem<int>(
                                                value: valor,
                                                child: Text('$valor'),
                                              ))
                                          .toList(),
                                      onChanged: (valor) {
                                        setState(() {
                                          if (valor != null) {
                                            controller.numeroBocas = valor;
                                            // Limpar controllers antigos
                                            for (final ctrl in controller.bocasControllers) {
                                              ctrl.dispose();
                                            }
                                            controller.bocasControllers.clear();
                                            
                                            // Inicializar novos valores
                                            controller.bocasValues = List<int?>.filled(
                                              valor,
                                              null,
                                            );
                                            
                                            // Criar novos controllers
                                            for (int i = 0; i < valor; i++) {
                                              controller.bocasControllers.add(
                                                TextEditingController(),
                                              );
                                            }
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                const Text('bocas'),
                              ],
                            ),
                            
                            if (controller.numeroBocas > 0) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: List.generate(
                                  controller.numeroBocas,
                                  (bocaIndex) {
                                    // Garantir que temos um controller para esta boca
                                    if (bocaIndex >= controller.bocasControllers.length) {
                                      controller.bocasControllers.add(
                                        TextEditingController(),
                                      );
                                    }
                                    
                                    return SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: controller.bocasControllers[bocaIndex],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Boca ${bocaIndex + 1}',
                                          border: const OutlineInputBorder(),
                                          suffixText: 'm³',
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          final num = int.tryParse(value);
                                          controller.bocasValues[bocaIndex] = num;
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 16),
                            
                            // Seção de Documentos
                            const Text(
                              'Documentos (opcional)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: _documentos.map((doc) => SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: controller.documentosControllers[doc],
                                  decoration: InputDecoration(
                                    labelText: doc,
                                    border: const OutlineInputBorder(),
                                    hintText: 'dd/mm/aaaa',
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (texto) {
                                    final mascara = _aplicarMascaraData(texto);
                                    if (mascara != texto) {
                                      controller.documentosControllers[doc]?.value =
                                          TextEditingValue(
                                        text: mascara,
                                        selection: TextSelection.collapsed(
                                          offset: mascara.length,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              )).toList(),
                            ),
                            
                            if (index < _placasControllers.length - 1)
                              const Divider(
                                height: 24,
                                thickness: 1,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    // Botão para adicionar mais placas
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _adicionarPlaca,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar outra placa'),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Botões de ação
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvarCadastro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Concluir Cadastro'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlacaController {
  final TextEditingController placaController = TextEditingController();
  int numeroBocas = 0;
  final List<TextEditingController> bocasControllers = [];
  List<int?> bocasValues = [];
  final Map<String, TextEditingController> documentosControllers = {};

  PlacaController() {
    // Inicializar controllers dos documentos
    final documentos = [
      'CIPP', 'CIV', 'Aferição', 'Tacógrafo', 
      'AET Federal', 'AET Bahia', 'AET Goiás', 
      'AET Alagoas', 'AET Minas G'
    ];
    
    for (final doc in documentos) {
      documentosControllers[doc] = TextEditingController();
    }
  }

  void dispose() {
    placaController.dispose();
    for (final controller in bocasControllers) {
      controller.dispose();
    }
    for (final controller in documentosControllers.values) {
      controller.dispose();
    }
  }
}

// ==============================
// PÁGINA DE DETALHES DO VEÍCULO (Versão Compacta)
// ==============================
class VeiculoDetalhesPage extends StatelessWidget {
  final String placa;
  final List<int> bocas;
  final VoidCallback onVoltar;

  const VeiculoDetalhesPage({
    super.key,
    required this.placa,
    required this.bocas,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
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
                  onPressed: onVoltar,
                ),
                const SizedBox(width: 8),
                Text(
                  'Veículo $placa',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informações básicas
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informações do Veículo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number, 
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Placa:', 
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(placa, 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.local_gas_station, 
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text('Compartimentos:', 
                                  style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: bocas.isEmpty
                                  ? const Text('--', 
                                      style: TextStyle(fontStyle: FontStyle.italic))
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: bocas.map((capacidade) => Chip(
                                        backgroundColor: _getCorBoca(capacidade)
                                            .withOpacity(0.1),
                                        label: Text(
                                          '$capacidade m³',
                                          style: TextStyle(
                                            color: _getCorBoca(capacidade),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )).toList(),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Documentação
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Documentação',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Aqui você pode carregar e exibir os documentos
                        // do banco de dados usando um FutureBuilder
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _carregarDocumentos(placa),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            
                            if (snapshot.hasError || snapshot.data == null) {
                              return const Text('Erro ao carregar documentos');
                            }
                            
                            final dados = snapshot.data!;
                            final documentos = [
                              {'nome': 'CIPP', 'coluna': 'cipp'},
                              {'nome': 'CIV', 'coluna': 'civ'},
                              {'nome': 'Aferição', 'coluna': 'afericao'},
                              {'nome': 'Tacógrafo', 'coluna': 'tacografo'},
                              {'nome': 'AET Federal', 'coluna': 'aet_fed'},
                              {'nome': 'AET Bahia', 'coluna': 'aet_ba'},
                              {'nome': 'AET Goiás', 'coluna': 'aet_go'},
                              {'nome': 'AET Alagoas', 'coluna': 'aet_al'},
                              {'nome': 'AET Minas G', 'coluna': 'aet_mg'},
                            ];
                            
                            return Column(
                              children: documentos.map((doc) {
                                final dataStr = dados[doc['coluna']] as String?;
                                final data = _parseData(dataStr);
                                final cor = _getCorStatusData(data);
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['nome']!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: cor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            data == null ? '--' : _formatarData(data),
                                            style: TextStyle(
                                              color: cor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (data != null) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: cor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getDiasRestantes(data),
                                                style: TextStyle(
                                                  color: cor,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
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

  Future<Map<String, dynamic>?> _carregarDocumentos(String placa) async {
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select()
          .eq('placa', placa)
          .maybeSingle();
      
      return data;
    } catch (e) {
      debugPrint('Erro ao carregar documentos: $e');
      return null;
    }
  }

  DateTime? _parseData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return null;
    
    try {
      final partes = dataStr.split('/');
      if (partes.length != 3) return null;
      
      final dia = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final ano = int.parse(partes[2]);
      
      final anoCompleto = ano < 100 ? 2000 + ano : ano;
      return DateTime(anoCompleto, mes, dia);
    } catch (_) {
      return null;
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
           '${data.month.toString().padLeft(2, '0')}/'
           '${data.year}';
  }

  Color _getCorStatusData(DateTime? data) {
    if (data == null) return Colors.grey;
    
    final dias = data.difference(DateTime.now()).inDays;
    
    if (dias < 0) return Colors.red;
    if (dias <= 30) return Colors.orange;
    if (dias <= 90) return Colors.amber[800]!;
    
    return Colors.green;
  }

  String _getDiasRestantes(DateTime data) {
    final dias = data.difference(DateTime.now()).inDays;
    
    if (dias < 0) return 'Vencido há ${dias.abs()} dias';
    if (dias == 0) return 'Vence hoje';
    if (dias == 1) return 'Vence amanhã';
    return 'Vence em $dias dias';
  }

  Color _getCorBoca(int capacidade) {
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.cyan,
      Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }
}