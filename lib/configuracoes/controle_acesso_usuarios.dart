import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_page.dart'; // Para acessar UsuarioAtual

class ControleAcessoUsuarios extends StatefulWidget {
  final VoidCallback onVoltar;

  const ControleAcessoUsuarios({super.key, required this.onVoltar});

  @override
  State<ControleAcessoUsuarios> createState() => _ControleAcessoUsuariosState();
}

class _ControleAcessoUsuariosState extends State<ControleAcessoUsuarios> {
  final supabase = Supabase.instance.client;
  final TextEditingController _buscaController = TextEditingController();
  final TextEditingController _buscaCardsController = TextEditingController();

  bool carregando = true;
  bool exibindoCards = false;
  bool acessoNegado = false;
  bool carregandoCards = false;

  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> usuariosFiltrados = [];
  List<Map<String, dynamic>> cards = []; // NOVO: Agora carrega cards, não sessoes
  List<Map<String, dynamic>> cardsFiltrados = []; // NOVO: Cards filtrados
  Map<String, bool> permissoes = {};
  String? usuarioSelecionadoId;
  String? usuarioSelecionadoNome;
  String? sessaoSelecionada; // NOVO: Para agrupar cards por sessão

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  void _filtrarUsuarios(String query) {
    setState(() {
      if (query.isEmpty) {
        usuariosFiltrados = usuarios;
        return;
      }

      final nivelBusca = int.tryParse(query);

      if (nivelBusca != null && (nivelBusca >= 1 && nivelBusca <= 3)) {
        usuariosFiltrados =
            usuarios.where((u) => u['nivel'].toString() == query).toList();
      } else {
        usuariosFiltrados = usuarios
            .where((u) =>
                u['nome']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                u['email']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // NOVO: Filtrar cards por nome
  void _filtrarCards(String query) {
    setState(() {
      if (query.isEmpty) {
        cardsFiltrados = cards;
        return;
      }

      final queryLower = query.toLowerCase();
      
      cardsFiltrados = cards
          .where((card) {
            final nome = card['nome']?.toString() ?? '';
            final sessaoPai = card['sessao_pai']?.toString() ?? '';
            
            return nome.toLowerCase().contains(queryLower) ||
                  sessaoPai.toLowerCase().contains(queryLower);
          })
          .toList();
    });
  }

  Future<void> _carregarUsuarios() async {
    setState(() {
      carregando = true;
      acessoNegado = false;
    });

    try {
      final usuarioAtual = UsuarioAtual.instance;
      if (usuarioAtual == null) {
        acessoNegado = true;
        return;
      }

      final nivel = usuarioAtual.nivel;
      final filialId = usuarioAtual.filialId;

      if (nivel == 1) {
        acessoNegado = true;
        return;
      }

      var query = supabase.from('usuarios').select('id, nome, email, nivel');

      if (nivel == 2) {
        if (filialId == null || filialId.isEmpty) {
          acessoNegado = true;
          return;
        }
        query = query.eq('nivel', 1).eq('id_filial', filialId);
      }

      final response = await query.order('nome', ascending: true);

      setState(() {
        usuarios = List<Map<String, dynamic>>.from(response);
        usuariosFiltrados = usuarios;
      });
    } catch (e) {
      debugPrint('Erro ao carregar usuários: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  // NOVO: Carregar cards da tabela 'cards' ao invés de 'sessoes'
  Future<void> _carregarCards(String usuarioId, String usuarioNome) async {
    setState(() {
      exibindoCards = true;
      usuarioSelecionadoId = usuarioId;
      usuarioSelecionadoNome = usuarioNome;
      carregandoCards = true;
    });

    try {
      // 1. Carregar todos os cards ativos do banco
      final cardsData = await supabase
          .from('cards')
          .select('id, nome, tipo, sessao_pai, ordem')
          .eq('ativo', true)
          .order('sessao_pai')
          .order('ordem');

      debugPrint('✅ Cards encontrados: ${cardsData.length}');

      // 2. Carregar permissões deste usuário
      final permissoesData = await supabase
          .from('permissoes')
          .select('id_sessao, permitido')
          .eq('id_usuario', usuarioId);

      // 3. Criar mapa de permissões (id_card → permitido)
      Map<String, bool> mapaPermissoes = {};
      for (var card in cardsData) {
        final cardId = card['id'].toString();
        final permissaoEncontrada = permissoesData.firstWhere(
          (p) => p['id_sessao'] == cardId,
          orElse: () => {'permitido': false},
        );
        mapaPermissoes[cardId] = permissaoEncontrada['permitido'] ?? false;
      }

      // 4. Preparar lista de cards com informações completas
      List<Map<String, dynamic>> listaCards = [];
      for (var card in cardsData) {
        listaCards.add({
          'id': card['id'].toString(),
          'nome': card['nome'],
          'tipo': card['tipo'],
          'sessao_pai': card['sessao_pai'],
          'ordem': card['ordem'] ?? 0,
          'permitido': mapaPermissoes[card['id'].toString()] ?? false,
        });
      }

      setState(() {
        cards = listaCards;
        cardsFiltrados = listaCards;
        permissoes = mapaPermissoes;
        sessaoSelecionada = null; // Resetar sessão selecionada
      });

      debugPrint('✅ Permissões carregadas para $usuarioNome: ${permissoes.length} cards');
      
    } catch (e) {
      debugPrint('❌ Erro ao carregar cards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => carregandoCards = false);
    }
  }

  // NOVO: Atualizar permissão de um card específico
  Future<void> _atualizarPermissaoCard(String cardId, bool permitido) async {
    if (usuarioSelecionadoId == null) return;

    try {
      // Verificar se já existe uma permissão para este card e usuário
      final existente = await supabase
          .from('permissoes')
          .select('id')
          .eq('id_usuario', usuarioSelecionadoId!)
          .eq('id_sessao', cardId)
          .maybeSingle();

      if (permitido) {
        // Se precisa dar permissão
        if (existente == null) {
          // Inserir nova permissão
          await supabase.from('permissoes').insert({
            'id_usuario': usuarioSelecionadoId!,
            'id_sessao': cardId,
            'permitido': true,
          });
          debugPrint('✅ Permissão INSERT para card $cardId');
        } else {
          // Atualizar permissão existente
          await supabase
              .from('permissoes')
              .update({'permitido': true})
              .eq('id', existente['id']);
          debugPrint('✅ Permissão UPDATE para card $cardId');
        }
      } else {
        // Se precisa REMOVER permissão
        if (existente != null) {
          await supabase.from('permissoes').delete().eq('id', existente['id']);
          debugPrint('✅ Permissão DELETE para card $cardId');
        }
      }

      // Atualizar estado local
      setState(() {
        permissoes[cardId] = permitido;
        
        // Atualizar também no array de cards
        final index = cards.indexWhere((c) => c['id'] == cardId);
        if (index != -1) {
          cards[index]['permitido'] = permitido;
        }
        
        // Atualizar cards filtrados
        final filtradoIndex = cardsFiltrados.indexWhere((c) => c['id'] == cardId);
        if (filtradoIndex != -1) {
          cardsFiltrados[filtradoIndex]['permitido'] = permitido;
        }
      });

      // Feedback visual
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permitido 
              ? 'Permissão concedida!' 
              : 'Permissão revogada!',
          ),
          backgroundColor: permitido ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );

    } catch (e) {
      debugPrint("❌ Erro ao atualizar permissão do card: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar permissão: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Reverter mudança no estado em caso de erro
      setState(() {
        permissoes[cardId] = !permitido;
      });
    }
  }

  // NOVO: Método para conceder/tirar permissão de TODOS os cards de uma sessão
  Future<void> _alternarPermissaoSessao(String sessaoPai, bool conceder) async {
    if (usuarioSelecionadoId == null) return;

    try {
      // Filtrar cards da sessão
      final cardsDaSessao = cards.where((c) => c['sessao_pai'] == sessaoPai).toList();
      
      for (var card in cardsDaSessao) {
        final cardId = card['id'];
        
        // Apenas atualizar se o estado for diferente
        if ((permissoes[cardId] ?? false) != conceder) {
          await _atualizarPermissaoCard(cardId, conceder);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conceder 
              ? 'Todos os cards de "$sessaoPai" foram permitidos!' 
              : 'Permissão removida de todos os cards de "$sessaoPai"!',
          ),
          backgroundColor: conceder ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      debugPrint('❌ Erro ao alternar permissão da sessão: $e');
    }
  }

  // NOVO: Obter lista de sessões únicas dos cards
  List<String> _obterSessoesUnicas() {
    final sessoes = cards.map((c) => c['sessao_pai']?.toString() ?? 'Geral').toSet();
    return sessoes.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0D47A1)));
    }

    if (acessoNegado) {
      return const Center(
        child: Text("Você não tem permissão para acessar esta tela.",
            style: TextStyle(fontSize: 16, color: Colors.red)),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: exibindoCards ? _buildListaCards() : _buildListaUsuarios(),
    );
  }

  // ======================
  // LISTA DE USUÁRIOS
  // ======================
  Widget _buildListaUsuarios() {
    return Container(
      key: const ValueKey('lista_usuarios'),
      padding: const EdgeInsets.all(30),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
              ),
              const Text(
                "Controle de acesso — Usuários",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1)),
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _buscaController,
                  onChanged: _filtrarUsuarios,
                  decoration: InputDecoration(
                    hintText: "Nome, e-mail ou nível (1,2,3)...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: usuariosFiltrados.isEmpty
                ? const Center(
                    child: Text('Nenhum usuário encontrado.',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: usuariosFiltrados.length,
                    itemBuilder: (context, index) {
                      final u = usuariosFiltrados[index];
                      return ListTile(
                        leading: Icon(
                          Icons.person,
                          color: u['nivel'] == 3 
                            ? Colors.red 
                            : u['nivel'] == 2 
                              ? Colors.orange 
                              : Colors.blue,
                        ),
                        title: Text(u['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['email'] ?? 'Sem e-mail'),
                            Text(
                              'Nível ${u['nivel']} - ${_getNivelDescricao(u['nivel'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () =>
                            _carregarCards(u['id'], u['nome']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getNivelDescricao(int nivel) {
    switch (nivel) {
      case 1:
        return 'Operador';
      case 2:
        return 'Supervisor';
      case 3:
        return 'Administrador';
      default:
        return 'Desconhecido';
    }
  }

  // ======================
  // LISTA DE CARDS (substitui lista de sessões)
  // ======================
  Widget _buildListaCards() {
    if (carregandoCards) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    return Container(
      key: const ValueKey('lista_cards'),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: () => setState(() {
                  exibindoCards = false;
                  usuarioSelecionadoId = null;
                  sessaoSelecionada = null;
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Permissões — ${usuarioSelecionadoNome ?? ''}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1)),
                    ),
                    if (usuarioSelecionadoNome != null)
                      Text(
                        "Controle de acesso aos cards individuais",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _buscaCardsController,
                  onChanged: _filtrarCards,
                  decoration: InputDecoration(
                    hintText: "Buscar por card ou sessão...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          
          // NOVO: Seção de ações em lote
          if (cards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterChip(
                    label: const Text('Mostrar apenas permitidos'),
                    selected: false,
                    onSelected: (_) {
                      setState(() {
                        cardsFiltrados = cards.where((c) => c['permitido'] == true).toList();
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Mostrar apenas negados'),
                    selected: false,
                    onSelected: (_) {
                      setState(() {
                        cardsFiltrados = cards.where((c) => c['permitido'] != true).toList();
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Mostrar todos'),
                    selected: true,
                    onSelected: (_) {
                      setState(() {
                        cardsFiltrados = cards;
                      });
                    },
                  ),
                  if (sessaoSelecionada != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Permitir todos desta sessão'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _alternarPermissaoSessao(sessaoSelecionada!, true),
                    ),
                  if (sessaoSelecionada != null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Negar todos desta sessão'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _alternarPermissaoSessao(sessaoSelecionada!, false),
                    ),
                ],
              ),
            ),
          
          Expanded(
            child: _buildConteudoCards(),
          ),
        ],
      ),
    );
  }

  // NOVO: Conteúdo dos cards (agrupado por sessão ou lista simples)
  Widget _buildConteudoCards() {
    if (cardsFiltrados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'Nenhum card encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              'Tente outra busca ou remova os filtros',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Se estiver buscando, mostrar lista simples
    if (_buscaCardsController.text.isNotEmpty) {
      return ListView.separated(
        itemCount: cardsFiltrados.length,
        separatorBuilder: (context, index) =>
            Divider(color: Colors.grey.shade200, height: 1),
        itemBuilder: (context, index) {
          final card = cardsFiltrados[index];
          return _buildCardItem(card);
        },
      );
    }

    // Senão, agrupar por sessão
    final sessoes = _obterSessoesUnicas();
    return ListView.builder(
      itemCount: sessoes.length,
      itemBuilder: (context, index) {
        final sessao = sessoes[index];
        final cardsDaSessao = cardsFiltrados
            .where((c) => c['sessao_pai'] == sessao)
            .toList()
          ..sort((a, b) => (a['ordem'] ?? 0).compareTo(b['ordem'] ?? 0));
        
        final totalPermitidos = cardsDaSessao.where((c) => c['permitido'] == true).length;
        final totalCards = cardsDaSessao.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 2,
          child: ExpansionTile(
            key: ValueKey(sessao),
            initiallyExpanded: sessaoSelecionada == sessao,
            onExpansionChanged: (expanded) {
              setState(() {
                sessaoSelecionada = expanded ? sessao : null;
              });
            },
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Text(
                sessao.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              sessao,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
            subtitle: Text(
              '$totalPermitidos de $totalCards cards permitidos',
              style: TextStyle(
                fontSize: 12,
                color: totalPermitidos == totalCards 
                  ? Colors.green 
                  : totalPermitidos == 0 
                    ? Colors.red 
                    : Colors.orange,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totalPermitidos > 0 && totalPermitidos < totalCards)
                  Chip(
                    label: Text('$totalPermitidos/$totalCards'),
                    backgroundColor: Colors.orange.shade100,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(width: 8),
                Icon(
                  sessaoSelecionada == sessao 
                    ? Icons.expand_less 
                    : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
            children: cardsDaSessao.map((card) => _buildCardItem(card)).toList(),
          ),
        );
      },
    );
  }

  // NOVO: Widget para item individual do card
  Widget _buildCardItem(Map<String, dynamic> card) {
    final permitido = card['permitido'] ?? false;
    final sessaoPai = card['sessao_pai'] ?? 'Geral';
    final tipo = card['tipo'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: permitido ? Colors.green.shade50 : Colors.white,
      child: Row(
        children: [
          // Indicador visual
          Container(
            width: 4,
            height: 40,
            color: permitido ? Colors.green : Colors.grey.shade300,
          ),
          const SizedBox(width: 12),
          
          // Ícone baseado no tipo
          Icon(
            _getIconePorTipo(tipo),
            color: permitido ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          
          // Informações do card
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card['nome'] ?? 'Sem nome',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: permitido ? Colors.green.shade800 : Colors.grey.shade800,
                  ),
                ),
                if (sessaoPai.isNotEmpty && sessaoPai != 'Geral')
                  Text(
                    'Sessão: $sessaoPai',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          
          // Checkbox de permissão
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: permitido,
              activeColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (valor) async {
                if (valor == null) return;
                await _atualizarPermissaoCard(card['id'], valor);
              },
            ),
          ),
        ],
      ),
    );
  }

  // NOVO: Mapeamento tipo → ícone (consistente com HomePage)
  IconData _getIconePorTipo(String tipo) {
    const mapaIcones = {
      'cacl': Icons.analytics,
      'ordens_analise': Icons.assignment,
      'historico_cacl': Icons.history,
      'tabelas_conversao': Icons.table_chart,
      'temp_dens_media': Icons.thermostat,
      'tanques': Icons.oil_barrel,
      'estoque_geral': Icons.hub,
      'estoque_por_empresa': Icons.business,
      'movimentacoes': Icons.swap_horiz,
      'transferencias': Icons.compare_arrows,
      'iniciar_circuito': Icons.play_arrow,
      'acompanhar_ordem': Icons.directions_car,
      'visao_geral_circuito': Icons.dashboard,
      'veiculos': Icons.directions_car,
      'veiculos_terceiros': Icons.local_shipping,
      'motoristas': Icons.people,
      'documentacao': Icons.description,
      'bombeios': Icons.invert_colors,
      'programacao_filial': Icons.local_gas_station,
    };
    return mapaIcones[tipo] ?? Icons.apps;
  }
}