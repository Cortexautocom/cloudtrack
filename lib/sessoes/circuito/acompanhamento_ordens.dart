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

  // ✅ 2️⃣ CRIE estado de controle de tela
  bool _mostrarDetalhes = false;
  Map<String, dynamic>? _ordemSelecionada;

  // ✅ 2.1 MAPAS FIXOS
  static const Map<String, String> produtoColunaMap = {
    '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',
    '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada',
    'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 'd_s500',
    '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',
    '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',
    'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',
    'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',
    'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a',
    '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',
    '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',
  };  

  // ✅ CORREÇÃO: MÉTODO PARA OBTER COR DO PRODUTO BASEADO NO DetalhesOrdemView
  Color _obterCorProduto(String nomeProduto) {
    // Mapeamento direto baseado nos nomes EXATOS que vêm do banco
    final Map<String, Color> mapeamentoExato = {
      // Gasolinas
      'G. Comum': const Color(0xFFFF6B35),
      'G. Aditivada': const Color(0xFF00A8E8),
      'Gasolina A': const Color(0xFFE91E63),
      
      // Diesels
      'S500': const Color(0xFF8D6A9F),
      'S10': const Color(0xFF2E294E),
      'S500 A': const Color(0xFF9C27B0),
      'S10 A': const Color(0xFF673AB7),
      
      // Etanóis      
      'Hidratado': const Color(0xFF83B692),
      'Anidro': const Color(0xFF4CAF50),
      
      // Biodiesel
      'B100': const Color(0xFF8BC34A),
    };
    
    // Primeiro tenta match exato
    if (mapeamentoExato.containsKey(nomeProduto)) {
      return mapeamentoExato[nomeProduto]!;
    }
    
    // Se não encontrar, tenta por case insensitive
    final nomeLower = nomeProduto.toLowerCase();
    for (var entry in mapeamentoExato.entries) {
      if (entry.key.toLowerCase() == nomeLower) {
        return entry.value;
      }
    }
    
    // Fallback para cores baseadas no conteúdo do nome
    if (nomeProduto.toLowerCase().contains('comum')) {
      return const Color(0xFFFF6B35); // Laranja
    } else if (nomeProduto.toLowerCase().contains('aditivada')) {
      return const Color(0xFF00A8E8); // Azul claro
    } else if (nomeProduto.toLowerCase().contains('s500')) {
      if (nomeProduto.toLowerCase().contains(' a')) {
        return const Color(0xFF9C27B0); // Roxo vibrante
      }
      return const Color(0xFF8D6A9F); // Roxo claro
    } else if (nomeProduto.toLowerCase().contains('s10')) {
      if (nomeProduto.toLowerCase().contains(' a')) {
        return const Color(0xFF673AB7); // Roxo azulado
      }
      return const Color(0xFF2E294E); // Azul escuro
    } else if (nomeProduto.toLowerCase().contains('hidratado')) {
      return const Color(0xFF83B692); // Verde claro
    } else if (nomeProduto.toLowerCase().contains('anidro')) {
      return const Color(0xFF4CAF50); // Verde
    } else if (nomeProduto.toLowerCase().contains('b100')) {
      return const Color(0xFF8BC34A); // Verde limão
    } else if (nomeProduto.toLowerCase().contains('gasolina a')) {
      return const Color(0xFFE91E63); // Rosa
    } else if (nomeProduto.toLowerCase().contains('etanol')) {
      return const Color(0xFF83B692); // Verde claro
    }
    
    // Fallback padrão
    return Colors.grey.shade600;
  }

  // ✅ 3.1 FUNÇÃO PARA AGRUPAR PRODUTOS POR ORDEM
  Map<String, double> agruparProdutosDaOrdem(List<Map<String, dynamic>> itens) {
    final Map<String, double> resultado = {};

    for (final mov in itens) {
      final tipoOp = mov['tipo_op']?.toString().toLowerCase();
      if (tipoOp != 'venda' && tipoOp != 'transf') continue;

      final produto = mov['produtos'];
      if (produto == null) continue;

      final produtoId = produto['id']?.toString().toLowerCase();
      final nome = produto['nome_dois']?.toString();
      if (produtoId == null || nome == null) continue;

      final coluna = produtoColunaMap[produtoId];
      if (coluna == null) continue;

      final valor = mov[coluna];
      if (valor == null || valor <= 0) continue;

      resultado[nome] = (resultado[nome] ?? 0) + (valor as num).toDouble();
    }

    return resultado;
  }

  // ✅ 5.1 WIDGET PARA CONSTRUIR CHIPS DE PRODUTOS
  Widget buildChipsProdutos(Map<String, double> produtos) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: produtos.entries.map((e) {
        final cor = _obterCorProduto(e.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatarNumeroDouble(e.value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                e.key,
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ✅ 3️⃣ CRIE métodos de controle de estado
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
      debugPrint('Erro ao carregar filiais: $e');
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

      // ✅ 1.1 ALTERAR A QUERY DE DADOS
      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            placa,
            entrada_amb,
            saida_amb,
            cliente,
            status_circuito,
            data_mov,
            filial_id,
            empresa_id,
            tipo_op,
            filial_origem_id,
            filial_destino_id,
            g_comum,
            g_aditivada,
            d_s10,
            d_s500,
            etanol,
            anidro,
            b100,
            gasolina_a,
            s500_a,
            s10_a,
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

      // Agrupar movimentações por ordem_id
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

      // Criar lista de ordens resumidas
      final List<Map<String, dynamic>> ordensResumidas = [];

      for (var entry in gruposOrdens.entries) {
        final ordemId = entry.key;
        final movimentacoesOrdem = entry.value;
        
        if (movimentacoesOrdem.isEmpty) continue;

        // Obter primeira movimentação para campos básicos
        final primeiraMov = movimentacoesOrdem.first;
        
        // Coletar todas as placas distintas
        final Set<String> placasSet = {};
        for (var mov in movimentacoesOrdem) {
          final placasFormatadas = _formatarPlacas(mov['placa']);
          if (placasFormatadas.isNotEmpty && placasFormatadas != 'N/I') {
            final placasList = placasFormatadas.split(', ').map((p) => p.trim()).toList();
            placasSet.addAll(placasList.where((p) => p.isNotEmpty));
          }
        }
        
        // ✅ 4.1 ADICIONAR PRODUTOS AGRUPADOS À ORDEM
        final produtosAgrupados = agruparProdutosDaOrdem(movimentacoesOrdem);

        // Criar resumo da ordem
        final ordemResumo = {
          'ordem_id': ordemId,
          'data_mov': primeiraMov['data_mov'],
          'status_circuito': primeiraMov['status_circuito'],
          'tipo_op': primeiraMov['tipo_op'],
          'placas': placasSet.toList(),
          'quantidade_total': produtosAgrupados.values.fold<double>(0, (sum, value) => sum + value),
          'produtos_agrupados': produtosAgrupados, // ✅ ADICIONADO
          'itens': movimentacoesOrdem,
        };

        ordensResumidas.add(ordemResumo);
      }

      // Ordenar ordens por data (mais recente primeiro)
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
      debugPrint('Erro ao carregar movimentações: $e');
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
        // Verificar se algum item da ordem pertence à filial filtrada
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
        // Buscar nas placas da ordem
        final placasOrdem = (ordem['placas'] as List).map((p) => p.toString().toLowerCase()).join(' ');
        if (placasOrdem.contains(termoBusca)) return true;
        
        // Buscar na quantidade total
        final quantidadeTotal = ordem['quantidade_total'].toString();
        if (quantidadeTotal.contains(termoBusca)) return true;
        
        // Buscar no status
        final statusTexto = _obterStatusTexto(ordem['status_circuito']).toLowerCase();
        if (statusTexto.contains(termoBusca)) return true;
        
        // Buscar no tipo de operação
        final tipoOpTexto = _obterTipoOpTexto(ordem['tipo_op']?.toString() ?? '').toLowerCase();
        if (tipoOpTexto.contains(termoBusca)) return true;
        
        // Buscar nos produtos agrupados
        final produtos = ordem['produtos_agrupados'] as Map<String, double>;
        if (produtos.keys.any((nome) => nome.toLowerCase().contains(termoBusca))) {
          return true;
        }
        
        // Buscar nos itens da ordem (cliente, placa específica, etc.)
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
  
  String _obterTipoMovimentacao(Map<String, dynamic> movimentacao) {
    final entradaAmb = movimentacao['entrada_amb'];
    final saidaAmb = movimentacao['saida_amb'];
    
    if (entradaAmb != null && entradaAmb > 0) {
      return 'Entrada';
    } else if (saidaAmb != null && saidaAmb > 0) {
      return 'Saída';
    }
    return 'N/A';
  }

  String _obterStatusTexto(dynamic statusCodigo) {
    if (statusCodigo == null) return 'Sem status';
    
    final codigo = statusCodigo is int ? statusCodigo : int.tryParse(statusCodigo.toString());
    
    switch (codigo) {
      case 1: return 'Programado';
      case 2: return 'Em check-list';
      case 3: return 'Em operação';
      case 4: return 'Aguardando NF';
      case 5: return 'Expedido';
      default: return 'Sem status';
    }
  }

  Color _obterCorStatus(dynamic statusCodigo) {
    if (statusCodigo == null) return Colors.grey;
    
    final codigo = statusCodigo is int ? statusCodigo : int.tryParse(statusCodigo.toString());
    
    switch (codigo) {
      case 1: return Colors.blue.shade700;
      case 2: return Colors.orange.shade700;
      case 3: return Colors.green.shade700;
      case 4: return Colors.purple.shade700;
      case 5: return Colors.grey.shade700;
      default: return Colors.grey;
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

  Color _obterCorTipoOp(dynamic tipoOp) {
    final tipoOpStr = tipoOp?.toString() ?? 'venda';
    switch (tipoOpStr.toLowerCase()) {
      case 'usina':
        return Colors.blue.shade700;
      case 'transf':
        return Colors.purple.shade700;
      case 'venda':
        return Colors.green.shade700;
      case 'emprestimo':
        return Colors.orange.shade700;
      case 'outras_op':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
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

  String _obterDescricaoParaCard(Map<String, dynamic> ordem) {
    final itens = ordem['itens'] as List<Map<String, dynamic>>;
    if (itens.isEmpty) return 'Sem descrição';
    
    final primeiroItem = itens.first;
    final tipoOp = (primeiroItem['tipo_op']?.toString() ?? 'venda').toLowerCase();
    
    if (tipoOp == 'transf') {
      final origem = primeiroItem['filial_origem'] as Map<String, dynamic>?;
      final destino = primeiroItem['filial_destino'] as Map<String, dynamic>?;
      final origemNome = origem?['nome']?.toString() ?? 'Origem';
      final destinoNome = destino?['nome']?.toString() ?? 'Destino';
      return '$origemNome → $destinoNome';
    } else if (tipoOp == 'venda') {
      final cliente = primeiroItem['cliente']?.toString() ?? '';
      return cliente.isNotEmpty ? cliente : 'Cliente não informado';
    } else {
      final filial = primeiroItem['filiais'] as Map<String, dynamic>?;
      return filial?['nome']?.toString() ?? 'Filial não informada';
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
    final itens = ordem['itens'] as List<Map<String, dynamic>>;
    if (itens.isEmpty) return Colors.white;
    
    // Verificar se há pelo menos uma entrada
    final temEntrada = itens.any((item) => _obterTipoMovimentacao(item) == 'Entrada');
    // Verificar se há pelo menos uma saída
    final temSaida = itens.any((item) => _obterTipoMovimentacao(item) == 'Saída');
    
    if (temEntrada && temSaida) {
      return Colors.purple.shade50; // Roxo claro para ordens mistas
    } else if (temEntrada) {
      return Colors.blue.shade50; // Azul claro para ordens de entrada
    } else if (temSaida) {
      return Colors.red.shade50; // Vermelho claro para ordens de saída
    }
    
    return Colors.white; // Branco para outros casos
  }

  Widget _buildItemOrdem(Map<String, dynamic> ordem, int index) {
    final tipoOp = ordem['tipo_op']?.toString() ?? 'venda';
    final tipoOpTexto = _obterTipoOpTexto(tipoOp);
    final descricao = _obterDescricaoParaCard(ordem);
    final statusCodigo = ordem['status_circuito'];
    final statusTexto = _obterStatusTexto(statusCodigo);
    final statusCor = _obterCorStatus(statusCodigo);
    final tipoOpCor = _obterCorTipoOp(tipoOp);
    
    // Dados da segunda linha
    final placasFormatadas = _formatarPlacas(ordem['placas']);
    final dataMov = _formatarData(ordem['data_mov']?.toString());
    
    // ✅ 6️⃣ INJETAR CHIPS DE PRODUTOS NO CARD
    final produtosAgrupados = ordem['produtos_agrupados'] as Map<String, double>;

    // Cor de fundo do card baseada no tipo de movimento
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
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // ✅ 4️⃣ ALTERE o onTap do card da ordem
            onTap: () {
              _abrirDetalhesOrdem(ordem);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status (ocupando as duas linhas, 100px de largura)
                  Container(
                    width: 100,
                    height: 60, // Altura para ocupar as duas linhas
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: statusCor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusCor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          statusTexto,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusCor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PRIMEIRA LINHA: Tipo da operação e Descrição
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tipo da operação
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tipoOpCor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tipoOpCor.withOpacity(0.3)),
                              ),
                              child: Text(
                                tipoOpTexto,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tipoOpCor,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Descrição
                            Expanded(
                              child: Text(
                                descricao,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // SEGUNDA LINHA: Detalhes da ordem
                        Row(
                          children: [
                            // Data
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
                            
                            // Placas
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
                            
                            const SizedBox(width: 16),
                            
                            // ✅ 4.2 SUBSTITUIR QUANTIDADE TOTAL POR CHIPS
                            // ✅ 6️⃣ USAR WIDGET DE CHIPS
                            produtosAgrupados.isNotEmpty
                                ? Expanded(
                                    flex: 3,
                                    child: buildChipsProdutos(produtosAgrupados),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Sem produtos',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                            
                            const SizedBox(width: 12),
                            
                            // Ícone de seta
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
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

  @override
  void dispose() {
    _filtroGeralController.dispose();
    _dataFiltroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      // ✅ 5️⃣ ALTERE o AppBar
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
      // ✅ 6️⃣ ALTERE o body da página
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _mostrarDetalhes
            ? DetalhesOrdemView(
                ordem: _ordemSelecionada!,
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