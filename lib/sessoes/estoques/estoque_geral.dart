import 'package:cloudtrack/login_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ===============================
/// MODELO DE DADOS DO ESTOQUE
/// ===============================
class EstoqueProduto {
  final String nome;
  final double abertura;
  final double entradaDescarga;
  final double entradaBombeio;
  final double saida;
  final double transito;
  final double capacidadeTotal;
  final int posicao;

  EstoqueProduto({
    required this.nome,
    required this.abertura,
    required this.entradaDescarga,
    required this.entradaBombeio,
    required this.saida,
    required this.transito,
    required this.capacidadeTotal,
    required this.posicao,
  });

  double get entradasTotais => entradaDescarga + entradaBombeio;
  double get tanque => abertura + entradasTotais - saida;
  double get finalDoDia => tanque + transito;
  double get espaco => capacidadeTotal - finalDoDia;
}

/// ===============================
/// LINHA COMPACTA DE ESTOQUE
/// ===============================
class EstoqueLinha extends StatelessWidget {
  final EstoqueProduto produto;

  const EstoqueLinha({super.key, required this.produto});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          // PRODUTO
          SizedBox(
            width: 130,
            child: Text(
              produto.nome,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),

          _miniBox("Abertura", produto.abertura, const Color.fromARGB(255, 87, 87, 87)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("+", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _miniBox("Entradas", produto.entradasTotais, Colors.indigo),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("-", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _miniBox("Saídas", produto.saida, Colors.red),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("=", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _miniBox("Final", produto.finalDoDia, const Color.fromARGB(255, 87, 87, 87)),
          
          const SizedBox(width: 30),
          // LINHA DIVISORA SUTIL
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(width: 30),

          _miniBox(
            "Espaço Disp.",
            produto.espaco,
            produto.espaco >= 0 ? Colors.grey.shade800 : Colors.red.shade900,
          ),
        ],
      ),
    );
  }

  Widget _miniBox(String label, double value, Color color) {
    return Container(
      width: 90, // Largura suficiente para 3 dígitos + ponto (ex: 1.200) em fonte 12
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              NumberFormat.decimalPattern('pt_BR').format(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// PÁGINA DE ESTOQUE GERAL (COMPACTA)
/// ===============================
class EstoqueGeralPage extends StatefulWidget {
  const EstoqueGeralPage({super.key});

  @override
  State<EstoqueGeralPage> createState() => _EstoqueGeralPageState();
}

class _EstoqueGeralPageState extends State<EstoqueGeralPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _terminais = [];
  String? _terminalSelecionadoId;
  bool _carregando = true;
  List<EstoqueProduto> _produtos = [];

  @override
  void initState() {
    super.initState();
    _carregarTerminais();
  }

  Future<void> _carregarTerminais() async {
    final empresaId = UsuarioAtual.instance?.empresaId;
    if (empresaId == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }

    try {
      final resp = await _supabase
          .from('relacoes_terminais')
          .select('terminal_id, terminais(id, nome)')
          .eq('empresa_id', empresaId)
          .not('terminal_id', 'is', null);

      final lista = <Map<String, dynamic>>[];
      final vistos = <String>{};

      for (final row in List<Map<String, dynamic>>.from(resp)) {
        final terminal = row['terminais'] as Map<String, dynamic>?;
        if (terminal == null) continue;
        final id = terminal['id']?.toString() ?? '';
        if (id.isEmpty || vistos.contains(id)) continue;
        vistos.add(id);
        lista.add({'id': id, 'nome': terminal['nome']?.toString() ?? id});
      }

      lista.sort((a, b) => a['nome'].compareTo(b['nome']));

      if (mounted) {
        setState(() {
          _terminais = lista;
          _terminalSelecionadoId = lista.isNotEmpty ? lista.first['id'] : null;
          _carregando = false;
        });
        
        // Carregar produtos do terminal selecionado
        if (_terminalSelecionadoId != null) {
          await _carregarProdutosDoTerminal();
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar terminais: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarProdutosDoTerminal() async {
    if (_terminalSelecionadoId == null) {
      debugPrint('⚠️ _carregarProdutosDoTerminal: terminalSelecionadoId é null');
      return;
    }

    debugPrint('🔍 Iniciando carga de produtos para terminal ID: $_terminalSelecionadoId');
    setState(() => _carregando = true);

    try {
      // Buscar tanques do terminal selecionado
      debugPrint('📦 Buscando tanques do terminal...');
      final tanques = await _supabase
          .from('tanques')
          .select('''
            id,
            referencia,
            capacidade,
            id_produto,
            status,
            terminal_id
          ''')
          .eq('terminal_id', _terminalSelecionadoId!)
          .eq('status', 'Em operação');

      debugPrint('📊 Tanques encontrados: ${tanques.length}');
      debugPrint('📋 Dados brutos dos tanques: $tanques');

      if (tanques.isEmpty) {
        debugPrint('⚠️ Nenhum tanque encontrado para o terminal $_terminalSelecionadoId');
        setState(() {
          _produtos = [];
          _carregando = false;
        });
        return;
      }

      // Coletar IDs dos produtos únicos
      final Set<String> produtosIds = {};
      for (final tanque in tanques) {
        final produtoId = tanque['id_produto'];
        debugPrint('🔍 Tanque ID: ${tanque['id']}, Produto ID: $produtoId, Status: ${tanque['status']}');
        if (produtoId != null) {
          produtosIds.add(produtoId.toString());
        } else {
          debugPrint('⚠️ Tanque ${tanque['id']} não tem produto associado (id_produto = null)');
        }
      }

      debugPrint('🆔 IDs de produtos únicos encontrados: $produtosIds');

      if (produtosIds.isEmpty) {
        debugPrint('⚠️ Nenhum ID de produto válido encontrado nos tanques');
        setState(() {
          _produtos = [];
          _carregando = false;
        });
        return;
      }

      // Buscar dados dos produtos
      debugPrint('🔍 Buscando dados dos produtos na tabela produtos...');
      final produtos = await _supabase
          .from('produtos')
          .select('id, nome, posicao')
          .inFilter('id', produtosIds.toList());

      debugPrint('📦 Produtos encontrados na tabela: ${produtos.length}');
      debugPrint('📋 Dados dos produtos: $produtos');

      // Criar um mapa para fácil acesso aos dados do produto
      final Map<String, Map<String, dynamic>> produtosMap = {};
      for (final produto in produtos) {
        produtosMap[produto['id'].toString()] = produto;
        debugPrint('✅ Produto mapeado: ID=${produto['id']}, Nome=${produto['nome']}');
      }

      // Verificar se todos os produtos IDs foram encontrados
      for (final produtoId in produtosIds) {
        if (!produtosMap.containsKey(produtoId)) {
          debugPrint('⚠️ Produto ID $produtoId não encontrado na tabela produtos');
        }
      }

      // Agrupar tanques por produto e calcular capacidade total por produto
      final Map<String, double> capacidadePorProduto = {};
      final Map<String, List<Map<String, dynamic>>> tanquesPorProduto = {};

      for (final tanque in tanques) {
        final produtoId = tanque['id_produto']?.toString();
        if (produtoId == null) continue;

        final capacidade = (tanque['capacidade'] as num?)?.toDouble() ?? 0.0;
        debugPrint('📊 Tanque ${tanque['id']}: Produto=$produtoId, Capacidade=$capacidade');

        capacidadePorProduto[produtoId] = 
            (capacidadePorProduto[produtoId] ?? 0.0) + capacidade;
        
        tanquesPorProduto.putIfAbsent(produtoId, () => []).add(tanque);
      }

      debugPrint('📊 Capacidade por produto: $capacidadePorProduto');

      // Criar objetos EstoqueProduto para cada produto encontrado
      final List<EstoqueProduto> produtosEstoque = [];

      for (final entry in capacidadePorProduto.entries) {
        final produtoId = entry.key;
        final capacidadeTotal = entry.value;
        final produtoData = produtosMap[produtoId];
        
        if (produtoData == null) {
          debugPrint('⚠️ Pulando produto ID $produtoId - dados não encontrados');
          continue;
        }

        final nomeProduto = produtoData['nome']?.toString() ?? 'Produto Desconhecido';
        final posicao = int.tryParse(produtoData['posicao']?.toString() ?? '0') ?? 0;
        debugPrint('✅ Criando EstoqueProduto: $nomeProduto, Capacidade Total: $capacidadeTotal, Posição: $posicao');
        
        // TODO: Buscar valores reais de abertura, entradas, saídas e trânsito
        // Por enquanto, usando valores de exemplo
        
        produtosEstoque.add(EstoqueProduto(
          nome: nomeProduto,
          abertura: 0.0, // Buscar do saldo inicial do dia
          entradaDescarga: 0.0, // Buscar das movimentações de descarga
          entradaBombeio: 0.0, // Buscar das movimentações de bombeio
          saida: 0.0, // Buscar das movimentações de saída
          transito: 0.0, // Buscar do trânsito
          capacidadeTotal: capacidadeTotal,
          posicao: posicao,
        ));
      }

      // Ordenar produtos por posição de forma ascendente
      produtosEstoque.sort((a, b) => a.posicao.compareTo(b.posicao));

      debugPrint('🔍 PRODUTOS ORDENADOS:');
      for (var p in produtosEstoque) {
        debugPrint('   - ${p.nome}: Posição ${p.posicao}');
      }

      debugPrint('✅ Total de produtos criados: ${produtosEstoque.length}');
      
      if (produtosEstoque.isEmpty) {
        debugPrint('⚠️ Nenhum produto foi criado - verificando possíveis causas:');
        debugPrint('   - produtosIds: $produtosIds');
        debugPrint('   - produtosMap keys: ${produtosMap.keys}');
        debugPrint('   - capacidadePorProduto keys: ${capacidadePorProduto.keys}');
      } else {
        for (final produto in produtosEstoque) {
          debugPrint('📦 Produto final: ${produto.nome} - Capacidade: ${produto.capacidadeTotal}');
        }
      }

      setState(() {
        _produtos = produtosEstoque;
        _carregando = false;
      });

    } catch (e, stackTrace) {
      debugPrint('❌ ERRO ao carregar produtos do terminal: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _produtos = [];
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Estoque Geral',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // NAVEGAÇÃO POR TERMINAIS
            if (_carregando && _terminais.isEmpty)
              const SizedBox(
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_terminais.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _terminais.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final terminal = _terminais[index];
                    final selecionado = terminal['id'] == _terminalSelecionadoId;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() => _terminalSelecionadoId = terminal['id']);
                          await _carregarProdutosDoTerminal();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: selecionado
                                ? const Color(0xFF0D47A1).withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF0D47A1),
                              width: selecionado ? 1.5 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              terminal['nome'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selecionado
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: const Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // LISTA DE PRODUTOS
            if (_carregando && _produtos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_produtos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Nenhum produto encontrado para este terminal',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: _produtos
                    .map((p) => EstoqueLinha(produto: p))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}