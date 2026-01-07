// sessoes/gestao_de_frota/veiculos.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==============================
// PÁGINA PRINCIPAL DE VEÍCULOS
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
  bool _erroCarregamento = false;
  String _filtroPlaca = '';
  final TextEditingController _buscaController = TextEditingController();

  // Mapeamento de cores para valores de boca (mantém consistência)
  static final Map<int, Color> _coresBocas = {
    5: Colors.blue,
    8: Colors.green,
    10: Colors.orange,
    15: Colors.purple,
    20: Colors.red,
    25: Colors.teal,
    30: Colors.indigo,
    35: Colors.deepOrange,
    40: Colors.cyan,
    45: Colors.lime,
    50: Colors.pink,
  };

  // Cor padrão para valores não mapeados
  static Color _corPadraoBoca(int valor) {
    final hash = valor % 12;
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
      Colors.pink,
      Colors.amber,
    ];
    return cores[hash];
  }

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  Future<void> _carregarVeiculos() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = false;
    });

    try {
      final client = Supabase.instance.client;
      
      // Buscar apenas placa e bocas (array integer[])
      final data = await client
          .from('equipamentos_3')
          .select('placa, bocas')
          .order('placa');
      
      setState(() {
        _veiculos = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Erro ao carregar veículos: $e');
      setState(() => _erroCarregamento = true);
    } finally {
      setState(() => _carregando = false);
    }
  }

  // Método para parsear o array de bocas (integer[])
  List<int> _parseBocas(dynamic bocasData) {
    if (bocasData == null) return [];
    
    try {
      // Se for uma lista (array do PostgreSQL)
      if (bocasData is List) {
        return bocasData.map((item) {
          if (item is int) return item;
          if (item is double) return item.toInt();
          if (item is String) return int.tryParse(item) ?? 0;
          return 0;
        }).where((valor) => valor > 0).toList();
      }
      
      // Se ainda for string (backward compatibility)
      if (bocasData is String) {
        final limpo = bocasData.replaceAll(RegExp(r'[{}]'), '').trim();
        if (limpo.isEmpty) return [];
        
        return limpo.split(',').map((s) {
          final valor = int.tryParse(s.trim());
          return valor ?? 0;
        }).where((valor) => valor > 0).toList();
      }
    } catch (e) {
      debugPrint('Erro ao parsear bocas: $e');
    }
    
    return [];
  }

  List<Map<String, dynamic>> get _veiculosFiltrados {
    if (_filtroPlaca.isEmpty) return _veiculos;
    
    return _veiculos.where((veiculo) {
      final placa = veiculo['placa']?.toString().toLowerCase() ?? '';
      return placa.contains(_filtroPlaca.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        title: const Text('Veículos'),
        actions: [
          SizedBox(
            width: 250,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _buscaController,
                decoration: InputDecoration(
                  hintText: 'Buscar placa...',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) {
                  setState(() => _filtroPlaca = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarVeiculos,
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erroCarregamento
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Erro ao carregar veículos',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _carregarVeiculos,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _veiculosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _filtroPlaca.isEmpty
                                ? 'Nenhum veículo cadastrado'
                                : 'Nenhum veículo encontrado',
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          if (_filtroPlaca.isNotEmpty)
                            Text(
                              'Filtro: "$_filtroPlaca"',
                              style: const TextStyle(color: Colors.blueGrey),
                            ),
                        ],
                      ),
                    )
                  : _buildListaVeiculos(),
    );
  }

  Widget _buildListaVeiculos() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Cabeçalho da tabela
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'PLACA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'BOCAS (mil litros)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de veículos
          Expanded(
            child: ListView.separated(
              itemCount: _veiculosFiltrados.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey[300],
              ),
              itemBuilder: (context, index) {
                final veiculo = _veiculosFiltrados[index];
                final placa = veiculo['placa']?.toString() ?? 'N/A';
                final bocas = _parseBocas(veiculo['bocas']);
                
                return Material(
                  color: index.isEven ? Colors.white : Colors.grey[50],
                  child: InkWell(
                    onTap: () {
                      widget.onSelecionarVeiculo({
                        'placa': placa,
                        'bocas': bocas,
                      });
                    },
                    hoverColor: const Color(0xFFE3F2FD),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        children: [
                          // Coluna PLACA
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D47A1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                placa,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Coluna BOCAS (com chips coloridos)
                          Expanded(
                            flex: 3,
                            child: bocas.isEmpty
                                ? const Text(
                                    'Sem bocas definidas',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: bocas.map((capacidade) {
                                      final cor = _coresBocas[capacidade] ?? 
                                                 _corPadraoBoca(capacidade);
                                      
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cor.withOpacity(0.1),
                                          border: Border.all(color: cor.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.local_gas_station,
                                              size: 14,
                                              color: cor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$capacidade',
                                              style: TextStyle(
                                                color: cor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'm³',
                                              style: TextStyle(
                                                color: cor.withOpacity(0.7),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
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
}

// ==============================
// PÁGINA DE DETALHES DO VEÍCULO
// ==============================
class VeiculoDetalhesPage extends StatefulWidget {
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
  State<VeiculoDetalhesPage> createState() => _VeiculoDetalhesPageState();
}

class _VeiculoDetalhesPageState extends State<VeiculoDetalhesPage> {
  Map<String, dynamic>? _dadosVeiculo;
  bool _carregando = true;
  bool _erroCarregamento = false;

  // Mapeamento de nomes amigáveis para colunas
  static final Map<String, String> _nomesDocumentos = {
    'afericao': 'Aferição',
    'cipp': 'CIPP',
    'civ': 'CIV',
    'tacografo': 'Tacógrafo',
    'aet_fed': 'AET Federal',
    'aet_ba': 'AET Bahia',
    'aet_go': 'AET Goiás',
    'aet_al': 'AET Alagoas',
    'aet_mg': 'AET Minas Gerais',
  };

  @override
  void initState() {
    super.initState();
    _carregarDetalhesVeiculo();
  }

  Future<void> _carregarDetalhesVeiculo() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = false;
    });

    try {
      final client = Supabase.instance.client;
      
      // Buscar todos os dados do veículo
      final data = await client
          .from('equipamentos_3')
          .select()
          .eq('placa', widget.placa)
          .maybeSingle();
      
      if (data == null) {
        throw Exception('Veículo não encontrado');
      }
      
      setState(() {
        _dadosVeiculo = Map<String, dynamic>.from(data as Map);
      });
    } catch (e) {
      debugPrint('Erro ao carregar detalhes do veículo: $e');
      setState(() => _erroCarregamento = true);
    } finally {
      setState(() => _carregando = false);
    }
  }

  // Parsear data no formato DD/MM/YYYY
  DateTime? _parseData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return null;
    
    try {
      final partes = dataStr.split('/');
      if (partes.length != 3) return null;
      
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final ano = int.tryParse(partes[2]);
      
      if (dia == null || mes == null || ano == null) return null;
      
      final anoCompleto = ano < 100 ? 2000 + ano : ano;
      return DateTime(anoCompleto, mes, dia);
    } catch (e) {
      return null;
    }
  }

  // Calcular status da data
  Color _corStatusData(DateTime? data) {
    if (data == null) return Colors.grey;
    
    final diasRestantes = data.difference(DateTime.now()).inDays;
    
    if (diasRestantes < 0) return Colors.red; // Vencido
    if (diasRestantes <= 30) return Colors.orange; // A vencer (30 dias)
    if (diasRestantes <= 90) return Colors.amber[800]!; // Atenção (90 dias)
    return Colors.green; // OK
  }

  // Formatar data para exibição
  String _formatarData(DateTime? data) {
    if (data == null) return 'Não informado';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  // Calcular dias restantes
  String _diasRestantes(DateTime? data) {
    if (data == null) return '';
    
    final dias = data.difference(DateTime.now()).inDays;
    
    if (dias < 0) {
      return 'Vencido há ${dias.abs()} dias';
    } else if (dias == 0) {
      return 'Vence hoje';
    } else if (dias == 1) {
      return 'Vence amanhã';
    } else {
      return 'Vence em $dias dias';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        title: Text('Veículo ${widget.placa}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDetalhesVeiculo,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erroCarregamento
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Erro ao carregar detalhes',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _carregarDetalhesVeiculo,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card de informações básicas
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informações do Veículo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Placa
                              Row(
                                children: [
                                  const Icon(
                                    Icons.confirmation_number,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Placa:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D47A1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.placa,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Bocas
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.local_gas_station,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Bocas:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: widget.bocas.isEmpty
                                        ? const Text(
                                            'Não definidas',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: widget.bocas.map((capacidade) {
                                              return Chip(
                                                backgroundColor: Colors.grey[100],
                                                label: Text(
                                                  '$capacidade m³',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Card de documentação
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Documentação',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Datas de vencimento dos documentos',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Lista de documentos
                              ..._nomesDocumentos.entries.map((entry) {
                                final coluna = entry.key;
                                final nomeAmigavel = entry.value;
                                final dataStr = _dadosVeiculo?[coluna] as String?;
                                final data = _parseData(dataStr);
                                final corStatus = _corStatusData(data);
                                final diasRestantes = _diasRestantes(data);
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nomeAmigavel,
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
                                            color: corStatus,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            data == null 
                                                ? 'Não informado'
                                                : _formatarData(data),
                                            style: TextStyle(
                                              color: corStatus,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          
                                          if (diasRestantes.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: corStatus.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                diasRestantes,
                                                style: TextStyle(
                                                  color: corStatus,
                                                  fontSize: 12,
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
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}