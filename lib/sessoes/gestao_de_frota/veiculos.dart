import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dialog_cadastro_placas.dart';

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
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      hintText: _abaAtual == 0 
                          ? 'Buscar placa ou transportadora...'
                          : 'Buscar conjunto...',
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

          // Conteúdo da aba selecionada
          Expanded(
            child: _abaAtual == 0 ? _buildVeiculosList() : ConjuntosPage(),
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
        hoverColor: const Color(0xFF0D47A1).withOpacity(0.08), // 👈 hover instantâneo
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
  @override
  State<ConjuntosPage> createState() => _ConjuntosPageState();
}

class _ConjuntosPageState extends State<ConjuntosPage> {
  // Dados mockados para demonstração da UI
  final List<Map<String, dynamic>> _conjuntosMock = [
    {
      'id': '1',
      'nome': 'Combo 01',
      'motorista': 'João Silva',
      'motorista_id': '001',
      'placa1': 'ABC-1234',
      'placa2': 'DEF-5678',
      'placa3': 'GHI-9012',
      'status': 'ativo',
      'criado_em': '2024-01-15',
    },
    {
      'id': '2',
      'nome': 'Combo 02',
      'motorista': 'Maria Santos',
      'motorista_id': '002',
      'placa1': 'JKL-3456',
      'placa2': 'MNO-7890',
      'placa3': 'PQR-1234',
      'status': 'ativo',
      'criado_em': '2024-01-18',
    },
    {
      'id': '3',
      'nome': 'Combo 03',
      'motorista': 'Pedro Oliveira',
      'motorista_id': '003',
      'placa1': 'STU-5678',
      'placa2': 'VWX-9012',
      'placa3': 'YZA-3456',
      'status': 'inativo',
      'criado_em': '2024-01-20',
    },
    {
      'id': '4',
      'nome': 'Combo 04',
      'motorista': 'Ana Costa',
      'motorista_id': '004',
      'placa1': 'BCD-7890',
      'placa2': 'EFG-1234',
      'placa3': 'HIJ-5678',
      'status': 'ativo',
      'criado_em': '2024-01-22',
    },
  ];

  bool _carregando = false;

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
                child: Text(
                  'NOME',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
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
                  'PLACA 1',
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
                  'PLACA 2',
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
                  'PLACA 3',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 8),
              _CabecalhoTabela(texto: 'STATUS', largura: 80),
              _CabecalhoTabela(texto: 'AÇÕES', largura: 100),
            ],
          ),
        ),
        
        // Lista de conjuntos
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : _conjuntosMock.isEmpty
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
                            onPressed: () {
                              // TODO: Implementar criação de novo conjunto
                            },
                            child: const Text(
                              'Criar primeiro conjunto',
                              style: TextStyle(color: Color(0xFF0D47A1)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _conjuntosMock.length,
                      itemBuilder: (context, index) {
                        final conjunto = _conjuntosMock[index];
                        final status = conjunto['status'];
                        final isAtivo = status == 'ativo';
                        
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: index.isEven ? Colors.white : Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Nome do conjunto
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.group_work,
                                          size: 16, color: const Color(0xFF0D47A1).withOpacity(0.7)),
                                      const SizedBox(width: 8),
                                      Text(
                                        conjunto['nome'] ?? '--',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Motorista
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D47A1).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person,
                                            size: 16, color: Color(0xFF0D47A1)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              conjunto['motorista'] ?? '--',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'ID: ${conjunto['motorista_id'] ?? '--'}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Placa 1
                                Expanded(
                                  child: _buildPlacaChip(conjunto['placa1']),
                                ),
                                const SizedBox(width: 8),
                                
                                // Placa 2
                                Expanded(
                                  child: _buildPlacaChip(conjunto['placa2']),
                                ),
                                const SizedBox(width: 8),
                                
                                // Placa 3
                                Expanded(
                                  child: _buildPlacaChip(conjunto['placa3']),
                                ),
                                const SizedBox(width: 8),
                                
                                // Status
                                SizedBox(
                                  width: 80,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isAtivo
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isAtivo
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      isAtivo ? 'Ativo' : 'Inativo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isAtivo ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Ações
                                SizedBox(
                                  width: 100,
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          // TODO: Implementar edição do conjunto
                                        },
                                        icon: const Icon(Icons.edit,
                                            size: 18, color: Color(0xFF0D47A1)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: () {
                                          // TODO: Implementar exclusão do conjunto
                                        },
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: () {
                                          // TODO: Implementar visualização de detalhes
                                        },
                                        icon: const Icon(Icons.visibility,
                                            size: 18, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
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
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_conjuntosMock.length} conjunto${_conjuntosMock.length != 1 ? 's' : ''} encontrado${_conjuntosMock.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implementar criação de novo conjunto
                },
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

  Widget _buildPlacaChip(String? placa) {
    if (placa == null || placa.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          '--',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.2)),
      ),
      child: Text(
        placa,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0D47A1),
        ),
      ),
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
                                        const SizedBox(width: 6),
                                        Text(
                                          'Cavalo',
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