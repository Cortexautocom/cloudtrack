import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstoqueMesPage extends StatefulWidget {
  final String filialId;
  final String nomeFilial;
  final String? empresaId;

  const EstoqueMesPage({
    super.key,
    required this.filialId,
    required this.nomeFilial,
    this.empresaId,
  });

  @override
  State<EstoqueMesPage> createState() => _EstoqueMesPageState();
}

class _EstoqueMesPageState extends State<EstoqueMesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _estoques = [];
  List<Map<String, dynamic>> _estoquesOrdenados = [];
  String? _empresaId;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  
  // Variáveis para ordenação
  String _colunaOrdenacao = 'data_mov';
  bool _ordenacaoAscendente = true; // false = mais recente primeiro

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      // Se empresaId não foi passado, buscar da filial
      if (widget.empresaId == null) {
        final filialData = await _supabase
            .from('filiais')
            .select('empresa_id')
            .eq('id', widget.filialId)
            .single();

        _empresaId = filialData['empresa_id']?.toString();
      } else {
        _empresaId = widget.empresaId;
      }

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Não foi possível identificar a empresa da filial');
      }

      // Buscar dados da tabela estoques - ordenado por data do mais antigo para cálculo
      final dados = await _supabase
          .from('estoques')
          .select('''
            id,
            data_mov,
            descricao,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            created_at
          ''')
          .eq('filial_id', widget.filialId)
          .eq('empresa_id', _empresaId!)
          .order('data_mov', ascending: true); // Ordenar por data_mov ASC para cálculo

      // Calcular saldos acumulados
      List<Map<String, dynamic>> estoquesComSaldo = [];
      num saldoAmbAcumulado = 0;
      num saldoVinteAcumulado = 0;

      for (var item in dados) {
        final entradaAmb = item['entrada_amb'] ?? 0;
        final entradaVinte = item['entrada_vinte'] ?? 0;
        final saidaAmb = item['saida_amb'] ?? 0;
        final saidaVinte = item['saida_vinte'] ?? 0;

        saldoAmbAcumulado += entradaAmb - saidaAmb;
        saldoVinteAcumulado += entradaVinte - saidaVinte;

        estoquesComSaldo.add({
          ...item,
          'saldo_amb': saldoAmbAcumulado,
          'saldo_vinte': saldoVinteAcumulado,
        });
      }

      // Ordenar inicialmente pela data (mais recente primeiro)
      _ordenarDados(estoquesComSaldo, 'data_mov', true);
    } catch (e) {
      debugPrint('❌ Erro ao carregar estoques: $e');
      setState(() {
        _carregando = false;
        _erro = true;
        _mensagemErro = e.toString();
      });
    }
  }

  void _ordenarDados(
    List<Map<String, dynamic>> dados, 
    String coluna, 
    bool ascendente
  ) {
    List<Map<String, dynamic>> dadosOrdenados = List.from(dados);
    
    dadosOrdenados.sort((a, b) {
      dynamic valorA;
      dynamic valorB;
      
      switch (coluna) {
        case 'data_mov':
          valorA = DateTime.parse(a['data_mov']);
          valorB = DateTime.parse(b['data_mov']);
          break;
        case 'descricao':
          valorA = (a['descricao'] ?? '').toString().toLowerCase();
          valorB = (b['descricao'] ?? '').toString().toLowerCase();
          break;
        case 'entrada_amb':
        case 'entrada_vinte':
        case 'saida_amb':
        case 'saida_vinte':
        case 'saldo_amb':
        case 'saldo_vinte':
          valorA = a[coluna] ?? 0;
          valorB = b[coluna] ?? 0;
          break;
        default:
          return 0;
      }
      
      // Comparação
      if (valorA is DateTime && valorB is DateTime) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      } else if (valorA is num && valorB is num) {
        return ascendente 
            ? (valorA - valorB).toInt()
            : (valorB - valorA).toInt();
      } else if (valorA is String && valorB is String) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      }
      
      return 0;
    });
    
    setState(() {
      _estoques = dados;
      _estoquesOrdenados = dadosOrdenados;
      _colunaOrdenacao = coluna;
      _ordenacaoAscendente = ascendente;
      _carregando = false;
    });
  }

  void _onSort(String coluna) {
    bool ascendente = true;
    
    if (_colunaOrdenacao == coluna) {
      ascendente = !_ordenacaoAscendente;
    } else {
      ascendente = coluna == 'data_mov' ? true : false;
    }
    
    _ordenarDados(_estoques, coluna, ascendente);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Text(
          'Estoque mensal – ${widget.nomeFilial}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_carregando && !_erro && _estoques.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por',
              onSelected: (value) {
                _onSort(value);
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'data_mov',
                    child: Text('Data (mais recente primeiro)'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'data_mov_asc',
                    child: Text('Data (mais antigo primeiro)'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'entrada_amb',
                    child: Text('Entrada Ambiente'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'saldo_amb',
                    child: Text('Saldo Ambiente'),
                  ),
                ];
              },
            ),
          if (!_carregando && !_erro)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDados,
              tooltip: 'Atualizar dados',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? _buildCarregando()
            : _erro
                ? _buildErro()
                : _estoques.isEmpty
                    ? _buildSemDados()
                    : _buildTabela(),
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando dados do estoque...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSemDados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum registro encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Não há movimentações de estoque para esta filial.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabela() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          sortColumnIndex: _getSortColumnIndex(),
          sortAscending: _ordenacaoAscendente,
          headingRowHeight: 48,
          dataRowHeight: 44,
          columnSpacing: 24,
          headingRowColor: MaterialStateProperty.all(
            Colors.grey.shade100,
          ),
          columns: [
            DataColumn(
              label: const Text(
                'Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) {
                _onSort('data_mov');
              },
            ),
            DataColumn(
              label: const Text(
                'Descrição',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) {
                _onSort('descricao');
              },
            ),
            DataColumn(
              label: const Text(
                'Entrada (Amb.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('entrada_amb');
              },
            ),
            DataColumn(
              label: const Text(
                'Entrada (20ºC)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('entrada_vinte');
              },
            ),
            DataColumn(
              label: const Text(
                'Saída (Amb.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saida_amb');
              },
            ),
            DataColumn(
              label: const Text(
                'Saída (20ºC)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saida_vinte');
              },
            ),
            DataColumn(
              label: const Text(
                'Saldo (Amb.)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saldo_amb');
              },
            ),
            DataColumn(
              label: const Text(
                'Saldo (20ºC)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
              onSort: (columnIndex, ascending) {
                _onSort('saldo_vinte');
              },
            ),
          ],
          rows: _estoquesOrdenados.map((estoque) {
            final dataMov = estoque['data_mov']?.toString() ?? '';
            final descricao = estoque['descricao']?.toString() ?? '';
            final entradaAmb = estoque['entrada_amb'] ?? 0;
            final entradaVinte = estoque['entrada_vinte'] ?? 0;
            final saidaAmb = estoque['saida_amb'] ?? 0;
            final saidaVinte = estoque['saida_vinte'] ?? 0;
            final saldoAmb = estoque['saldo_amb'] ?? 0;
            final saldoVinte = estoque['saldo_vinte'] ?? 0;

            return DataRow(
              cells: [
                DataCell(Text(
                  _formatarData(dataMov),
                  style: const TextStyle(fontSize: 13),
                )),
                DataCell(Text(
                  descricao.isNotEmpty ? descricao : '-',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )),
                DataCell(_buildNumero(entradaAmb)),
                DataCell(_buildNumero(entradaVinte)),
                DataCell(_buildNumero(saidaAmb)),
                DataCell(_buildNumero(saidaVinte)),
                DataCell(
                  _buildNumero(saldoAmb, corDiferente: true),
                ),
                DataCell(
                  _buildNumero(saldoVinte, corDiferente: true),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  int? _getSortColumnIndex() {
    switch (_colunaOrdenacao) {
      case 'data_mov':
        return 0;
      case 'descricao':
        return 1;
      case 'entrada_amb':
        return 2;
      case 'entrada_vinte':
        return 3;
      case 'saida_amb':
        return 4;
      case 'saida_vinte':
        return 5;
      case 'saldo_amb':
        return 6;
      case 'saldo_vinte':
        return 7;
      default:
        return 0;
    }
  }

  Widget _buildNumero(num valor, {bool corDiferente = false}) {
    Color cor = Colors.black;
    if (corDiferente) {
      cor = valor >= 0 ? Colors.green : Colors.red;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        valor.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 13,
          color: cor,
          fontWeight: corDiferente ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  String _formatarData(String dataString) {
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }
}