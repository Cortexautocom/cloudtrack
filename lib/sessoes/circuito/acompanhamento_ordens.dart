import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
import 'detalhes_ordem.dart';

class AcompanhamentoOrdensPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const AcompanhamentoOrdensPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<AcompanhamentoOrdensPage> createState() => _AcompanhamentoOrdensPageState();
}

class _AcompanhamentoOrdensPageState extends State<AcompanhamentoOrdensPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _ordens = [];
  List<Map<String, dynamic>> _ordensFiltradas = [];
  List<Map<String, dynamic>> _filiais = [];
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _empresaId;
  
  final TextEditingController _filtroGeralController = TextEditingController();
  final TextEditingController _dataFiltroController = TextEditingController();
  String? _filialFiltroId;

  bool _mostrarDetalhes = false;
  Map<String, dynamic>? _ordemSelecionada;

  Color _obterCorProduto(String nomeProduto) {
    final Map<String, Color> mapeamentoExato = {
      'G. Comum': const Color(0xFFFF6B35),
      'G. Aditivada': const Color(0xFF00A8E8),
      'Gasolina A': const Color(0xFFE91E63),
      'S500': const Color(0xFF8D6A9F),
      'S10': const Color(0xFF2E294E),
      'S500 A': const Color(0xFF9C27B0),
      'S10 A': const Color(0xFF673AB7),
      'Hidratado': const Color(0xFF83B692),
      'Anidro': const Color(0xFF4CAF50),
      'B100': const Color(0xFF8BC34A),
    };
    
    if (mapeamentoExato.containsKey(nomeProduto)) {
      return mapeamentoExato[nomeProduto]!;
    }
    
    final nomeLower = nomeProduto.toLowerCase();
    for (var entry in mapeamentoExato.entries) {
      if (entry.key.toLowerCase() == nomeLower) {
        return entry.value;
      }
    }
    
    if (nomeProduto.toLowerCase().contains('comum')) {
      return const Color(0xFFFF6B35);
    } else if (nomeProduto.toLowerCase().contains('aditivada')) {
      return const Color(0xFF00A8E8);
    } else if (nomeProduto.toLowerCase().contains('s500')) {
      if (nomeProduto.toLowerCase().contains(' a')) {
        return const Color(0xFF9C27B0);
      }
      return const Color(0xFF8D6A9F);
    } else if (nomeProduto.toLowerCase().contains('s10')) {
      if (nomeProduto.toLowerCase().contains(' a')) {
        return const Color(0xFF673AB7);
      }
      return const Color(0xFF2E294E);
    } else if (nomeProduto.toLowerCase().contains('hidratado')) {
      return const Color(0xFF83B692);
    } else if (nomeProduto.toLowerCase().contains('anidro')) {
      return const Color(0xFF4CAF50);
    } else if (nomeProduto.toLowerCase().contains('b100')) {
      return const Color(0xFF8BC34A);
    } else if (nomeProduto.toLowerCase().contains('gasolina a')) {
      return const Color(0xFFE91E63);
    } else if (nomeProduto.toLowerCase().contains('etanol')) {
      return const Color(0xFF83B692);
    }
    
    return Colors.grey.shade600;
  }

  Map<String, double> agruparProdutosDaOrdem(List<Map<String, dynamic>> itens) {
    final Map<String, double> resultado = {};
    final filialAtualId = _filialAtualId;

    for (final mov in itens) {
      final produto = mov['produtos'];
      if (produto == null) continue;

      final nome = produto['nome_dois']?.toString();
      if (nome == null) continue;

      final filialDestinoId = mov['filial_destino_id']?.toString();
      final filialOrigemId = mov['filial_origem_id']?.toString();
      final filialId = mov['filial_id']?.toString();

      final entradaAmb = (mov['entrada_amb'] ?? 0) as num;
      final saidaAmb = (mov['saida_amb'] ?? 0) as num;

      num quantidade = 0;
      if (filialAtualId.isNotEmpty && filialDestinoId == filialAtualId) {
        quantidade = entradaAmb;
      } else if (filialAtualId.isNotEmpty &&
          (filialOrigemId == filialAtualId || filialId == filialAtualId)) {
        quantidade = saidaAmb;
      } else {
        quantidade = saidaAmb > 0 ? saidaAmb : entradaAmb;
      }

      if (quantidade <= 0) continue;

      resultado[nome] = (resultado[nome] ?? 0) + quantidade.toDouble();
    }

    return resultado;
  }

  void _abrirDetalhesOrdem(Map<String, dynamic> ordem) {
    setState(() {
      _ordemSelecionada = ordem;
      _mostrarDetalhes = true;
    });
  }

  void _voltarParaLista() {
    setState(() {
      _ordemSelecionada = null;
      _mostrarDetalhes = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _filtroGeralController.addListener(_aplicarFiltros);
    _dataFiltroController.addListener(_aplicarFiltros);
  }

  Future<void> _carregarFiliais() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      if (usuario.nivel == 3) {
        final dados = await _supabase
            .from('filiais')
            .select('id, nome')
            .eq('empresa_id', _empresaId!)
            .order('nome');

        setState(() {
          _filiais = List<Map<String, dynamic>>.from(dados);
          if (_filialFiltroId == null && _filiais.isNotEmpty) {
            _filialFiltroId = _filiais.first['id'].toString();
          }
        });
      } else if (usuario.filialId != null) {
        final filialData = await _supabase
            .from('filiais')
            .select('id, nome')
            .eq('id', usuario.filialId!)
            .single();

        setState(() {
          _filiais = [filialData];
          _filialFiltroId = usuario.filialId;
        });
      }
    } catch (e) {
      // Erro silencioso
    }
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        throw Exception('Usuário não autenticado');
      }

      _empresaId = usuario.empresaId;

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Não foi possível identificar a empresa do usuário');
      }

      await _carregarFiliais();

      final String? filialUsuario = usuario.nivel == 3 
          ? _filialFiltroId
          : usuario.filialId;

      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            placa,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            cliente,
            descricao,
            status_circuito_orig,
            status_circuito_dest,
            data_mov,
            filial_id,
            empresa_id,
            tipo_op,
            filial_origem_id,
            filial_destino_id,
            produtos!produto_id(id, nome_dois),
            filiais!estoques_filial_id_fkey(id, nome),
            filial_origem:filiais!movimentacoes_filial_origem_id_fkey(id, nome),
            filial_destino:filiais!movimentacoes_filial_destino_id_fkey(id, nome),
            ordem_id
          ''')
          .eq('empresa_id', _empresaId!)
          .order('data_mov', ascending: false);

      final dados = await query;
      List<Map<String, dynamic>> movimentacoesFiltradas = [];

      if (usuario.nivel < 3) {
        if (filialUsuario != null) {
          movimentacoesFiltradas = dados.where((item) {
            final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
            final filialId = item['filial_id']?.toString();
            final filialOrigemId = item['filial_origem_id']?.toString();
            final filialDestinoId = item['filial_destino_id']?.toString();
            
            if (tipoOp == 'usina') {
              return filialDestinoId == filialUsuario;
            } else if (tipoOp == 'transf') {
              return filialOrigemId == filialUsuario || filialDestinoId == filialUsuario;
            } else if (tipoOp == 'venda') {
              return filialId == filialUsuario;
            }
            return false;
          }).toList();
        }
      } else if (usuario.nivel == 3) {
        if (_filialFiltroId != null && _filialFiltroId!.isNotEmpty) {
          movimentacoesFiltradas = dados.where((item) {
            final tipoOp = (item['tipo_op']?.toString() ?? 'venda');
            final filialId = item['filial_id']?.toString();
            final filialOrigemId = item['filial_origem_id']?.toString();
            final filialDestinoId = item['filial_destino_id']?.toString();
            
            if (tipoOp == 'usina') {
              return filialDestinoId == _filialFiltroId;
            } else if (tipoOp == 'transf') {
              return filialOrigemId == _filialFiltroId || filialDestinoId == _filialFiltroId;
            } else if (tipoOp == 'venda') {
              return filialId == _filialFiltroId;
            }
            return false;
          }).toList();
        } else {
          movimentacoesFiltradas = List<Map<String, dynamic>>.from(dados);
        }
      }

      final Map<String, List<Map<String, dynamic>>> gruposOrdens = {};
      
      for (var movimentacao in movimentacoesFiltradas) {
        final ordemId = movimentacao['ordem_id']?.toString();
        if (ordemId != null && ordemId.isNotEmpty) {
          if (!gruposOrdens.containsKey(ordemId)) {
            gruposOrdens[ordemId] = [];
          }
          gruposOrdens[ordemId]!.add(movimentacao);
        }
      }

      final List<Map<String, dynamic>> ordensResumidas = [];

      for (var entry in gruposOrdens.entries) {
        final ordemId = entry.key;
        final movimentacoesOrdem = entry.value;
        
        if (movimentacoesOrdem.isEmpty) continue;

        final primeiraMov = movimentacoesOrdem.first;
        
        final Set<String> placasSet = {};
        for (var mov in movimentacoesOrdem) {
          final placasFormatadas = _formatarPlacas(mov['placa']);
          if (placasFormatadas.isNotEmpty && placasFormatadas != 'N/I') {
            final placasList = placasFormatadas.split(', ').map((p) => p.trim()).toList();
            placasSet.addAll(placasList.where((p) => p.isNotEmpty));
          }
        }
        
        final produtosAgrupados = agruparProdutosDaOrdem(movimentacoesOrdem);

        final ordemResumo = {
          'ordem_id': ordemId,
          'data_mov': primeiraMov['data_mov'],
          'status_circuito_orig': primeiraMov['status_circuito_orig'],
          'status_circuito_dest': primeiraMov['status_circuito_dest'],
          'tipo_op': primeiraMov['tipo_op'],
          'filial_origem_id': primeiraMov['filial_origem_id'],
          'filial_destino_id': primeiraMov['filial_destino_id'],
          'placas': placasSet.toList(),
          'quantidade_total': produtosAgrupados.values.fold<double>(0, (sum, value) => sum + value),
          'produtos_agrupados': produtosAgrupados,
          'itens': movimentacoesOrdem,
        };

        ordensResumidas.add(ordemResumo);
      }

      ordensResumidas.sort((a, b) {
        final dataA = a['data_mov']?.toString() ?? '';
        final dataB = b['data_mov']?.toString() ?? '';
        return dataB.compareTo(dataA);
      });

      if (mounted) {
        setState(() {
          _ordens = ordensResumidas;
          _ordensFiltradas = List.from(ordensResumidas);
          _carregando = false;
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = true;
          _mensagemErro = e.toString();
        });
      }
    }
  }

  void _aplicarFiltros() {
    final termoBusca = _filtroGeralController.text.toLowerCase().trim();
    final dataFiltro = _dataFiltroController.text.trim();
    
    List<Map<String, dynamic>> resultado = List.from(_ordens);

    if (_filialFiltroId != null) {
      resultado = resultado.where((ordem) {
        return ordem['itens'].any((item) {
          final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
          
          if (tipoOp == 'usina') {
            return item['filial_destino_id'] == _filialFiltroId;
          } else if (tipoOp == 'transf') {
            return item['filial_origem_id'] == _filialFiltroId || 
                   item['filial_destino_id'] == _filialFiltroId;
          } else {
            return item['filial_id'] == _filialFiltroId;
          }
        });
      }).toList();
    }

    if (dataFiltro.isNotEmpty) {
      resultado = resultado.where((ordem) {
        final dataMov = ordem['data_mov']?.toString() ?? '';
        if (dataMov.isEmpty) return false;
        
        try {
          final data = DateTime.parse(dataMov);
          final dataFormatada = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
          return dataFormatada.contains(dataFiltro);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    if (termoBusca.isNotEmpty) {
      resultado = resultado.where((ordem) {
        final placasOrdem = (ordem['placas'] as List).map((p) => p.toString().toLowerCase()).join(' ');
        if (placasOrdem.contains(termoBusca)) return true;
        
        final quantidadeTotal = ordem['quantidade_total'].toString();
        if (quantidadeTotal.contains(termoBusca)) return true;
        
        final statusTexto = _obterStatusTexto(ordem, null).toLowerCase();
        if (statusTexto.contains(termoBusca)) return true;
        
        final tipoOpTexto = _obterTipoOpTexto(ordem['tipo_op']?.toString() ?? '').toLowerCase();
        if (tipoOpTexto.contains(termoBusca)) return true;
        
        final produtos = ordem['produtos_agrupados'] as Map<String, double>;
        if (produtos.keys.any((nome) => nome.toLowerCase().contains(termoBusca))) {
          return true;
        }
        
        return ordem['itens'].any((item) {
          final cliente = (item['cliente'] ?? '').toString().toLowerCase();
          final placaItem = _formatarPlacaParaBusca(item['placa']).toLowerCase();
          final filial = _obterNomeFilialParaBusca(item).toLowerCase();
          
          return cliente.contains(termoBusca) ||
                 placaItem.contains(termoBusca) ||
                 filial.contains(termoBusca);
        });
      }).toList();
    }

    setState(() {
      _ordensFiltradas = resultado;
    });
  }

  String _obterNomeFilialParaBusca(Map<String, dynamic> item) {
    final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
    
    if (tipoOp == 'usina') {
      final filialDestino = item['filial_destino'] as Map<String, dynamic>?;
      return filialDestino?['nome']?.toString() ?? '';
    } else if (tipoOp == 'transf') {
      final filialOrigem = item['filial_origem'] as Map<String, dynamic>?;
      final filialDestino = item['filial_destino'] as Map<String, dynamic>?;
      final origemNome = filialOrigem?['nome']?.toString() ?? '';
      final destinoNome = filialDestino?['nome']?.toString() ?? '';
      return '$origemNome $destinoNome';
    } else {
      final filial = item['filiais'] as Map<String, dynamic>?;
      return filial?['nome']?.toString() ?? '';
    }
  }

  String _formatarPlacaParaBusca(dynamic placaData) {
    if (placaData == null) return '';
    
    if (placaData is List) {
      return placaData.join(', ');
    } else if (placaData is String) {
      try {
        if (placaData.startsWith('{') && placaData.endsWith('}')) {
          final limpo = placaData.substring(1, placaData.length - 1);
          return limpo.split(',').map((p) => p.trim()).join(', ');
        }
        return placaData;
      } catch (e) {
        return placaData.toString();
      }
    }
    return placaData.toString();
  }
  
  String _formatarNumero(int valor) {
    if (valor == 0) return '0';
    
    String valorString = valor.toString();
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    return resultado;
  }

  String _formatarNumeroDouble(double valor) {
    final valorInt = valor.toInt();
    return _formatarNumero(valorInt);
  }

  // MÉTODO CORRIGIDO: Determina qual status usar baseado no tipo de operação e filial
  String _obterStatusTexto(Map<String, dynamic> ordem, Map<String, dynamic>? movimentacao) {
    final item = movimentacao ?? (ordem['itens'] as List<Map<String, dynamic>>).firstOrNull;
    
    if (item == null) return 'Sem status';
    
    final tipoOp = item['tipo_op']?.toString() ?? 'venda';
    final filialOrigemId = item['filial_origem_id']?.toString();
    final filialDestinoId = item['filial_destino_id']?.toString();
    
    // Obter a filial atual do usuário
    final usuario = UsuarioAtual.instance;
    String? filialAtual;
    
    if (usuario?.nivel == 3) {
      filialAtual = _filialFiltroId;
    } else {
      filialAtual = usuario?.filialId;
    }
    
    dynamic statusCodigo;
    
    // Lógica para determinar qual status usar
    if (tipoOp == 'transf') {
      // Para transferências, verifica se a filial atual é origem ou destino
      if (filialAtual == filialOrigemId) {
        // Filial é ORIGEM da transferência (SAÍDA) -> usa status_circuito_orig
        statusCodigo = item['status_circuito_orig'];
      } else if (filialAtual == filialDestinoId) {
        // Filial é DESTINO da transferência (ENTRADA) -> usa status_circuito_dest
        statusCodigo = item['status_circuito_dest'];
      } else {
        // Fallback: tenta usar qualquer um disponível
        statusCodigo = item['status_circuito_orig'] ?? item['status_circuito_dest'];
      }
    } else if (tipoOp == 'usina') {
      // Para usina, a filial atual sempre é destino (ENTRADA)
      statusCodigo = item['status_circuito_dest'];
    } else {
      // Para vendas e outros tipos, usa o status da filial local (SAÍDA)
      statusCodigo = item['status_circuito_orig'];
    }
    
    if (statusCodigo == null) return 'Sem status';
    
    final codigo = statusCodigo is int ? statusCodigo : int.tryParse(statusCodigo.toString());
    
    switch (codigo) {
      case 1: return 'Programado';
      case 15: return 'Aguardando';
      case 2: return 'Check-list';
      case 3: return 'Em operação';
      case 4: return 'Emissão NF';
      case 5: return 'Liberado';
      default: return 'Sem status';
    }
  }  

  String _obterTipoOpTexto(dynamic tipoOp) {
    final tipoOpStr = tipoOp?.toString() ?? 'venda';
    switch (tipoOpStr.toLowerCase()) {
      case 'transf':
        return 'Transferência';
      case 'venda':
        return 'Venda';
      case 'emprestimo':
        return 'Empréstimo';
      case 'outras_op':
        return 'Outras Op.';
      default:
        return tipoOpStr;
    }
  }
  
  String _formatarPlacas(dynamic placasData) {
    if (placasData == null) return 'N/I';
    
    if (placasData is List) {
      return placasData.where((p) => p != null && p.toString().isNotEmpty)
                      .map((p) => p.toString())
                      .join(', ');
    } else if (placasData is String) {
      try {
        if (placasData.startsWith('{') && placasData.endsWith('}')) {
          final limpo = placasData.substring(1, placasData.length - 1);
          final placas = limpo.split(',')
                              .map((p) => p.trim())
                              .where((p) => p.isNotEmpty && p != 'null')
                              .toList();
          return placas.join(', ');
        }
        return placasData;
      } catch (e) {
        return placasData;
      }
    }
    return placasData.toString();
  }

  String _formatarData(String? dataString) {
    if (dataString == null) return 'Data não informada';
    
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }  

  Widget _buildFiltros() {
    final usuario = UsuarioAtual.instance;
    final mostraFiltroFilial = usuario?.nivel == 3;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (mostraFiltroFilial) ...[
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _filialFiltroId,
                  decoration: InputDecoration(
                    labelText: 'Filial *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    suffixIcon: _filialFiltroId == null 
                        ? Icon(Icons.error, color: Colors.orange, size: 20)
                        : null,
                  ),
                  items: _filiais.map((filial) {
                    return DropdownMenuItem(
                      value: filial['id'].toString(),
                      child: Text(filial['nome'].toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filialFiltroId = value;
                    });
                    _carregarDados();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecione uma filial';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            Expanded(
              flex: 2,
              child: TextField(
                controller: _dataFiltroController,
                decoration: InputDecoration(
                  labelText: 'Data (DD/MM)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              flex: 3,
              child: TextField(
                controller: _filtroGeralController,
                decoration: InputDecoration(
                  labelText: 'Buscar (placa, cliente, status...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            'Carregando ordens...',
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
            Icons.list_alt_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma ordem encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Não há ordens registradas no momento.',
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

  Color _obterCorFundoCard(Map<String, dynamic> ordem) {
    // Cards agora sempre têm fundo branco; indicação de entrada/saída
    // será feita por um ícone no final do card.
    return Colors.white;
  }

  Widget _buildItemOrdem(Map<String, dynamic> ordem, int index) {
    final tipoOp = ordem['tipo_op']?.toString() ?? 'venda';
    final tipoOpTexto = _obterTipoOpTexto(tipoOp);
    final statusTexto = _obterStatusTexto(ordem, null);
    
    final statusCor = _obterCorStatusTimeline(ordem, null);
    
    final placasFormatadas = _formatarPlacas(ordem['placas']);
    final dataMov = _formatarData(ordem['data_mov']?.toString());
    
    final produtosAgrupados = ordem['produtos_agrupados'] as Map<String, double>;

    final Map<String, List<String>> informacoesPorProduto = {};
    final itens = ordem['itens'] as List<Map<String, dynamic>>;
    
    for (final item in itens) {
      final produto = item['produtos'];
      if (produto == null) continue;
      
      final nomeProduto = produto['nome_dois']?.toString();
      if (nomeProduto == null || nomeProduto.isEmpty) continue;
      
      if (!informacoesPorProduto.containsKey(nomeProduto)) {
        informacoesPorProduto[nomeProduto] = [];
      }
      
      String informacao;
      if (tipoOp == 'transf') {
        informacao = (item['descricao'] as String?)?.trim() ?? '';
        if (informacao.isEmpty) {
          final origem = item['filial_origem'] as Map<String, dynamic>?;
          final destino = item['filial_destino'] as Map<String, dynamic>?;
          if (origem != null && destino != null) {
            final origemNome = origem['nome']?.toString() ?? 'Origem';
            final destinoNome = destino['nome']?.toString() ?? 'Destino';
            informacao = '$origemNome → $destinoNome';
          } else {
            informacao = 'Transferência';
          }
        }
      } else {
        informacao = (item['cliente'] as String?)?.trim() ?? '';
      }
      
      if (informacao.isNotEmpty && !informacoesPorProduto[nomeProduto]!.contains(informacao)) {
        informacoesPorProduto[nomeProduto]!.add(informacao);
      }
    }

    final corFundoCard = _obterCorFundoCard(ordem);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: corFundoCard,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _abrirDetalhesOrdem(ordem);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícone de direção (entrada/saída) no início do card
                  // Ícone de direção (origem/destino da filial do usuário)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Builder(builder: (context) {
                      final usuario = UsuarioAtual.instance;
                      final filialAtual = usuario?.nivel == 3 ? _filialFiltroId : usuario?.filialId;

                      final itensLocal = ordem['itens'] as List<dynamic>;

                      final ehOrigem = itensLocal.any((item) =>
                          item['filial_origem_id']?.toString() == filialAtual);

                      final ehDestino = itensLocal.any((item) =>
                          item['filial_destino_id']?.toString() == filialAtual);

                      if (ehDestino && !ehOrigem) {
                        return Icon(Icons.arrow_circle_down, size: 30, color: Colors.green.shade700);
                      } else if (ehOrigem && !ehDestino) {
                        return Icon(Icons.arrow_circle_up, size: 30, color: Colors.red.shade700);
                      } else if (ehOrigem && ehDestino) {
                        return Icon(Icons.sync, size: 30, color: Colors.purple.shade400);
                      }

                      return Icon(Icons.remove_circle_outline, size: 26, color: Colors.grey.shade400);
                    }),
                  ),

                  Container(
                    width: tipoOpTexto == 'Transferência' ? 95 : 85,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusCor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusCor.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          statusTexto,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusCor,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusCor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: statusCor.withOpacity(0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tipoOpTexto,
                            style: TextStyle(
                              fontSize: tipoOpTexto == 'Transferência' ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 121, 121, 121),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dataMov,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(width: 16),
                            
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.directions_car,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      placasFormatadas,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        
                        if (produtosAgrupados.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: produtosAgrupados.entries.map((produtoEntry) {
                              final nomeProduto = produtoEntry.key;
                              final quantidade = produtoEntry.value;
                              final cor = _obterCorProduto(nomeProduto);
                              
                              final informacoesDoProduto = informacoesPorProduto[nomeProduto] ?? [];
                              final textoInfo = informacoesDoProduto.isNotEmpty
                                  ? informacoesDoProduto.first
                                  : (tipoOp == 'transf' ? 'Sem descrição' : 'N/I');
                              final temMaisInfo = informacoesDoProduto.length > 1;
                              
                              return Container(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cor,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          bottomLeft: Radius.circular(4),
                                        ),
                                      ),
                                      child: Text(
                                        _formatarNumeroDouble(quantidade),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cor.withOpacity(0.08),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(4),
                                          bottomRight: Radius.circular(4),
                                        ),
                                        border: Border.all(
                                          color: cor.withOpacity(0.15),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _abreviarTexto(nomeProduto, 15),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: cor,
                                            ),
                                          ),
                                          
                                          Text(
                                            _abreviarTexto(textoInfo, 20),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          
                                          if (temMaisInfo)
                                            Text(
                                              '+${informacoesDoProduto.length - 1}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        
                        if (produtosAgrupados.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'Sem produtos',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
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
        ),
      ),
    );
  }

  String _abreviarTexto(String texto, int maxLength) {
    if (texto.length <= maxLength) return texto;
    return '${texto.substring(0, maxLength)}...';
  }

  Color _obterCorStatusTimeline(Map<String, dynamic> ordem, Map<String, dynamic>? movimentacao) {
    final statusTexto = _obterStatusTexto(ordem, movimentacao);
    
    switch (statusTexto) {
      case 'Programado': return const Color.fromARGB(255, 61, 160, 206);
      case 'Aguardando': return const Color.fromARGB(255, 5, 151, 0);
      case 'Check-list': return const Color(0xFFF57C00);
      case 'Em operação': return const Color(0xFF7B1FA2);
      case 'Emissão NF': return const Color(0xFFC2185B);
      case 'Liberado': return const Color.fromARGB(255, 42, 199, 50);
      default: return Colors.grey;
    }
  }  

  @override
  void dispose() {
    _filtroGeralController.dispose();
    _dataFiltroController.dispose();
    super.dispose();
  }

  String get _filialAtualId {
    final usuario = UsuarioAtual.instance;
    
    if (usuario == null) {
      return '';
    }
    
    String filialId;
    
    if (usuario.nivel == 3) {
      filialId = _filialFiltroId ?? '';
      
      if (filialId.isEmpty && _filiais.isNotEmpty) {
        filialId = _filiais.first['id'].toString();
        _filialFiltroId = filialId;
      }
    } else {
      filialId = usuario.filialId ?? '';
    }
    
    return filialId;
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
          _mostrarDetalhes ? 'Detalhes da Ordem' : 'Acompanhamento de Ordens',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_mostrarDetalhes) {
              _voltarParaLista();
            } else {
              widget.onVoltar();
            }
          },
        ),
        actions: [
          if (!_carregando && !_erro && !_mostrarDetalhes)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDados,
              tooltip: 'Atualizar ordens',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _mostrarDetalhes
            ? DetalhesOrdemView(
                ordem: _ordemSelecionada!,
                filialAtualId: _filialAtualId,
              )
            : Column(
                children: [
                  _buildFiltros(),
                  Expanded(
                    child: _carregando
                        ? _buildCarregando()
                        : _erro
                            ? _buildErro()
                            : _ordensFiltradas.isEmpty
                                ? _buildSemDados()
                                : ListView.builder(
                                    itemCount: _ordensFiltradas.length,
                                    itemBuilder: (context, index) {
                                      return _buildItemOrdem(
                                        _ordensFiltradas[index],
                                        index,
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
      ),
    );
  }
}