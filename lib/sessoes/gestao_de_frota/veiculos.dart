import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dialog_cadastro_placas.dart';
import 'editar_conjunto.dart';

// ==============================
// PÁGINA PRINCIPAL DE VEÍCULOS
// ==============================
class VeiculosPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(Map<String, dynamic>) onSelecionarVeiculo;
  
  const VeiculosPage({
    super.key,
    required this.onVoltar,
    required this.onSelecionarVeiculo,
  });

  @override
  State<VeiculosPage> createState() => _VeiculosPageState();
}

class _VeiculosPageState extends State<VeiculosPage> {
  List<Map<String, dynamic>> _veiculos = [];
  bool _carregando = true;
  String _filtroPlaca = '';
  int _abaAtual = 0; // 0 = Veículos, 1 = Conjuntos
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
          .select('''
            id,
            placa, 
            tanques,
            transportadora_id,
            transportadoras!inner(nome)
          ''')
          .order('placa');
      
      setState(() {
        _veiculos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Erro ao carregar veículos: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<int> _parsetanques(dynamic tanquesData) {
    if (tanquesData is List) return tanquesData.cast<int>();
    return [];
  }

  int _calcularTotaltanques(List<int> tanques) {
    return tanques.isNotEmpty ? tanques.reduce((a, b) => a + b) : 0;
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    if (_filtroPlaca.isEmpty) return _veiculos;
    return _veiculos.where((v) {
      final placa = v['placa']?.toString().toLowerCase() ?? '';
      final transportadora = _getNomeTransportadora(v).toLowerCase();
      return placa.contains(_filtroPlaca.toLowerCase()) ||
             transportadora.contains(_filtroPlaca.toLowerCase());
    }).toList();
  }

  void _abrirCadastroVeiculo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DialogCadastroPlacas(),
    ).then((_) => _carregarVeiculos());
  }

  Color _getCorBoca(int capacidade) {
    final cores = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
      Colors.teal, Colors.indigo, Colors.deepOrange, Colors.cyan, Colors.lime,
    ];
    return cores[capacidade % cores.length];
  }

  String _getNomeTransportadora(Map<String, dynamic> veiculo) {
    final transportadora = veiculo['transportadoras'];
    if (transportadora is Map) {
      return transportadora['nome']?.toString() ?? '--';
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _abaAtual == 0 ? FloatingActionButton(
        onPressed: _abrirCadastroVeiculo,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ) : null,
      body: Column(
        children: [
          // Cabeçalho com navegação
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
                const Text('Veículos',
                  style: TextStyle(fontSize: 20, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _carregarVeiculos,
                  icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),

          // Menu de navegação entre veículos e conjuntos
          Container(
            height: 40,
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _botaoAba("Veículos", 0),
                const SizedBox(width: 16),
                _botaoAba("Conjuntos", 1),
              ],
            ),
          ),

          // Barra de busca única para ambas as abas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: TextField(
              controller: _buscaController,
              onChanged: (value) {
                setState(() {
                  _filtroPlaca = value;
                });
              },
              decoration: InputDecoration(
                hintText: _abaAtual == 0 
                    ? 'Buscar placa ou transportadora...'
                    : 'Buscar por placa, motorista, capacidade...',
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
          ),

          // Conteúdo da aba selecionada
          Expanded(
            child: _abaAtual == 0 ? _buildVeiculosList() : ConjuntosPage(
              buscaController: _buscaController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoAba(String texto, int aba) {
    final bool selecionado = _abaAtual == aba;

    return Material(
      color: selecionado ? const Color(0xFF0D47A1) : Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: () {
          setState(() {
            _abaAtual = aba;
            _buscaController.clear();
            _filtroPlaca = '';
          });
        },
        hoverColor: const Color(0xFF0D47A1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selecionado
                  ? const Color(0xFF0D47A1)
                  : Colors.grey.shade400,
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selecionado ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVeiculosList() {
    return Column(
      children: [
        // Cabeçalho da tabela de veículos
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
                flex: 2,
                child: Text(
                  'TRANSPORTADORA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
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
        
        // Lista de veículos
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
                          const Icon(Icons.directions_car_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _filtroPlaca.isEmpty
                                ? 'Nenhum veículo cadastrado'
                                : 'Nenhum veículo encontrado',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _veiculosFiltrados.length,
                      itemBuilder: (context, index) {
                        final veiculo = _veiculosFiltrados[index];
                        final placa = veiculo['placa']?.toString() ?? '';
                        final transportadora = _getNomeTransportadora(veiculo);
                        final tanques = _parsetanques(veiculo['tanques']);
                        final totaltanques = _calcularTotaltanques(tanques);
                        return Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: index.isEven ? Colors.white : Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: InkWell(
                            onTap: () => widget.onSelecionarVeiculo({
                              'id': veiculo['id'],
                              'placa': placa,
                              'transportadora': transportadora,
                              'tanques': tanques,
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
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
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      transportadora,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: tanques.isEmpty
                                        ? Row(
                                            children: [
                                              const Icon(Icons.directions_car,
                                                  size: 16, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Cavalo',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              ...tanques
                                                  .map((capacidade) => Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 8, vertical: 3),
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
                                                      ))
                                                  .toList(),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.arrow_forward,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.blueGrey.withOpacity(0.1),
                                                  border: Border.all(
                                                    color:
                                                        Colors.blueGrey.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '$totaltanques',
                                                  style: const TextStyle(
                                                    color: Colors.blueGrey,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
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
    );
  }
}

// ==============================
// PÁGINA DE CONJUNTOS
// ==============================
class ConjuntosPage extends StatefulWidget {
  final TextEditingController buscaController;
  
  const ConjuntosPage({
    super.key,
    required this.buscaController,
  });

  @override
  State<ConjuntosPage> createState() => _ConjuntosPageState();
}

class _ConjuntosPageState extends State<ConjuntosPage> {
  List<Map<String, dynamic>> _conjuntos = [];
  List<Map<String, dynamic>> _conjuntosTemporarios = [];
  bool _carregando = true;
  final Map<String, List<String>> _placasDuplicadas = {};

  @override
  void initState() {
    super.initState();
    widget.buscaController.addListener(_onBuscaChanged);
    _carregarConjuntos();
  }

  @override
  void dispose() {
    widget.buscaController.removeListener(_onBuscaChanged);
    super.dispose();
  }

  void _onBuscaChanged() {
    setState(() {});
  }

  Future<void> _carregarConjuntos() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('conjuntos')
          .select()
          .order('id', ascending: false);
      
      // Limpar mapa de duplicadas
      _placasDuplicadas.clear();
      
      // Processar dados para encontrar duplicidades
      for (final conjunto in data) {
        final conjuntoId = conjunto['id'].toString();
        
        // Cavalo
        if (conjunto['cavalo'] != null) {
          final placa = conjunto['cavalo'].toString();
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
        
        // Reboque 1
        if (conjunto['reboque_um'] != null) {
          final placa = conjunto['reboque_um'].toString();
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
        
        // Reboque 2
        if (conjunto['reboque_dois'] != null) {
          final placa = conjunto['reboque_dois'].toString();
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
      }
      
      setState(() {
        _conjuntos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Erro ao carregar conjuntos: $e');
      setState(() {
        _conjuntos = [];
      });
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _adicionarPlacaDuplicada(String placa, String conjuntoId) {
    if (!_placasDuplicadas.containsKey(placa)) {
      _placasDuplicadas[placa] = [];
    }
    if (!_placasDuplicadas[placa]!.contains(conjuntoId)) {
      _placasDuplicadas[placa]!.add(conjuntoId);
    }
  }

  String _formatarNumero(dynamic valor) {
    if (valor == null) return '--';
    return valor.toString();
  }

  String _formatarPBT(dynamic valor) {
    if (valor == null) return '--';
    if (valor is double) {
      return '${valor.toStringAsFixed(1)} kg';
    }
    return '$valor kg';
  }

  List<Map<String, dynamic>> get _conjuntosFiltrados {
    final filtro = widget.buscaController.text.toLowerCase();
    final todosConjuntos = [..._conjuntos, ..._conjuntosTemporarios];
    
    if (filtro.isEmpty) return todosConjuntos;
    
    return todosConjuntos.where((c) {
      final cavalo = c['cavalo']?.toString().toLowerCase() ?? '';
      final reboque1 = c['reboque_um']?.toString().toLowerCase() ?? '';
      final reboque2 = c['reboque_dois']?.toString().toLowerCase() ?? '';
      final motorista = c['motorista']?.toString().toLowerCase() ?? '';
      final capac = c['capac']?.toString().toLowerCase() ?? '';
      final tanques = c['tanques']?.toString().toLowerCase() ?? '';
      final pbt = c['pbt']?.toString().toLowerCase() ?? '';
      
      return cavalo.contains(filtro) ||
             reboque1.contains(filtro) ||
             reboque2.contains(filtro) ||
             motorista.contains(filtro) ||
             capac.contains(filtro) ||
             tanques.contains(filtro) ||
             pbt.contains(filtro);
    }).toList();
  }

  void _adicionarConjuntoTemporario() {
    final novoConjunto = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'motorista': '--',
      'cavalo': null,
      'reboque_um': null,
      'reboque_dois': null,
      'capac': null,
      'tanques': null,
      'pbt': null,
      'isTemporario': true,
    };
    
    setState(() {
      _conjuntosTemporarios.add(novoConjunto);
    });
  }

  Future<void> _salvarConjuntoTemporario(Map<String, dynamic> conjunto) async {
    try {
      final dadosParaSalvar = {
        'motorista': conjunto['motorista'],
        'cavalo': conjunto['cavalo'],
        'reboque_um': conjunto['reboque_um'],
        'reboque_dois': conjunto['reboque_dois'],
        'capac': conjunto['capac'],
        'tanques': conjunto['tanques'],
        'pbt': conjunto['pbt'],
      };
      
      final resultado = await Supabase.instance.client
          .from('conjuntos')
          .insert(dadosParaSalvar)
          .select();
      
      if (resultado.isNotEmpty) {
        // Remover o temporário e adicionar o real
        setState(() {
          _conjuntosTemporarios.removeWhere((c) => c['id'] == conjunto['id']);
        });
        await _carregarConjuntos();
      }
    } catch (e) {
      print('Erro ao salvar conjunto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar conjunto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _atualizarPlacaTemporaria({
    required Map<String, dynamic> conjunto,
    required String campo,
    required String? novaPlaca,
  }) async {
    final index = _conjuntosTemporarios.indexWhere((c) => c['id'] == conjunto['id']);
    if (index != -1) {
      setState(() {
        _conjuntosTemporarios[index][campo] = novaPlaca;
      });
      
      // Se todas as placas necessárias foram preenchidas, salva no banco
      final conj = _conjuntosTemporarios[index];
      if (conj['cavalo'] != null || conj['reboque_um'] != null || conj['reboque_dois'] != null) {
        await _salvarConjuntoTemporario(conj);
      }
    }
  }

  Widget _buildPlacaWidget({
    required Map<String, dynamic> conjunto,
    required String campo,
    required bool isTemporario,
  }) {
    final placa = conjunto[campo];
    
    return PlacaClicavelWidget(
      placa: placa,
      conjuntoId: conjunto['id'],
      campoConjunto: campo,
      onAtualizado: isTemporario 
          ? () async {
              // Para conjuntos temporários, precisamos atualizar o estado
              await _carregarConjuntos();
            }
          : _carregarConjuntos,
      placasDuplicadas: _placasDuplicadas,
      isTemporario: isTemporario,
      onPlacaAtualizada: isTemporario 
          ? (novaPlaca) => _atualizarPlacaTemporaria(
                conjunto: conjunto,
                campo: campo,
                novaPlaca: novaPlaca,
              )
          : null,
    );
  }

  Widget _buildInfoChip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: cor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabeçalho da tabela de conjuntos
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'MOTORISTA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAVALO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'REBOQUE 1',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'REBOQUE 2',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAPACIDADE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TANQUES',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PBT',
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
        
        // Lista de conjuntos
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : _conjuntosFiltrados.isEmpty && widget.buscaController.text.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car_filled_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum conjunto cadastrado',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _adicionarConjuntoTemporario,
                            child: const Text(
                              'Criar primeiro conjunto',
                              style: TextStyle(color: Color(0xFF0D47A1)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _conjuntosFiltrados.length,
                      itemBuilder: (context, index) {
                        final conjunto = _conjuntosFiltrados[index];
                        final isTemporario = conjunto['isTemporario'] == true;
                        
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: isTemporario 
                                ? Colors.yellow.shade50 
                                : (index.isEven ? Colors.white : Colors.grey.shade50),
                            border: Border(
                              bottom: BorderSide(
                                color: isTemporario 
                                    ? Colors.orange.shade200 
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Motorista
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isTemporario
                                              ? Colors.orange.withOpacity(0.1)
                                              : const Color(0xFF0D47A1).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isTemporario ? Icons.add : Icons.person,
                                          size: 16,
                                          color: isTemporario ? Colors.orange : const Color(0xFF0D47A1),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          conjunto['motorista']?.toString() ?? '--',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isTemporario ? Colors.orange : Colors.black,
                                            fontStyle: isTemporario ? FontStyle.italic : FontStyle.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Cavalo
                                Expanded(
                                  child: _buildPlacaWidget(
                                    conjunto: conjunto,
                                    campo: 'cavalo',
                                    isTemporario: isTemporario,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Reboque 1
                                Expanded(
                                  child: _buildPlacaWidget(
                                    conjunto: conjunto,
                                    campo: 'reboque_um',
                                    isTemporario: isTemporario,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Reboque 2
                                Expanded(
                                  child: _buildPlacaWidget(
                                    conjunto: conjunto,
                                    campo: 'reboque_dois',
                                    isTemporario: isTemporario,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Capacidade
                                Expanded(
                                  child: _buildInfoChip(
                                    '${_formatarNumero(conjunto['capac'])} m³',
                                    isTemporario ? Colors.orange : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Tanques
                                Expanded(
                                  child: _buildInfoChip(
                                    _formatarNumero(conjunto['tanques']),
                                    isTemporario ? Colors.orange : Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // PBT
                                Expanded(
                                  child: _buildInfoChip(
                                    _formatarPBT(conjunto['pbt']),
                                    isTemporario ? Colors.orange : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        
        // Botão de adicionar conjunto (fixo no rodapé)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_conjuntosFiltrados.length} conjunto${_conjuntosFiltrados.length != 1 ? 's' : ''} encontrado${_conjuntosFiltrados.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _adicionarConjuntoTemporario,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Conjunto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CabecalhoTabela extends StatelessWidget {
  final String texto;
  final double largura;

  const _CabecalhoTabela({required this.texto, required this.largura});

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
      ),
    );
  }
}

// ==============================
// PÁGINA DE DETALHES DO VEÍCULO
// ==============================
class VeiculoDetalhesPage extends StatelessWidget {
  final String id;
  final String placa;
  final List<int> tanques;
  final String transportadora;
  final VoidCallback onVoltar;

  const VeiculoDetalhesPage({
    super.key,
    required this.id,
    required this.placa,
    required this.tanques,
    required this.transportadora,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
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
                            const Icon(Icons.fingerprint, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('ID:', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(
                              id.length > 8 ? '${id.substring(0, 8)}...' : id,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Placa:', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(placa, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.business, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Transportadora:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Text(
                              transportadora,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.local_gas_station, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text('Compartimentos:',
                                  style: TextStyle(fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: tanques.isEmpty
                                  ? const Row(
                                      children: [
                                        Icon(Icons.directions_car,
                                            size: 16, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text(
                                          'CAVALO',
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        ...tanques
                                            .map((capacidade) => Chip(
                                                  backgroundColor:
                                                      _getCorBoca(capacidade).withOpacity(0.1),
                                                  label: Text(
                                                    '$capacidade m³',
                                                    style: TextStyle(
                                                      color: _getCorBoca(capacidade),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                        Chip(
                                          backgroundColor:
                                              Colors.blueGrey.withOpacity(0.15),
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${tanques.reduce((a, b) => a + b)} m³ total',
                                                style: const TextStyle(
                                                  color: Colors.blueGrey,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _carregarDocumentos(id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
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
                                          Icon(Icons.calendar_today, size: 16, color: cor),
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
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: cor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getDiasRestantes(data),
                                                style: TextStyle(color: cor, fontSize: 11),
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

  Future<Map<String, dynamic>?> _carregarDocumentos(String id) async {
    try {
      final data = await Supabase.instance.client
          .from('equipamentos')
          .select()
          .eq('id', id)
          .maybeSingle();
      return data;
    } catch (e) {
      print('Erro ao carregar documentos: $e');
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