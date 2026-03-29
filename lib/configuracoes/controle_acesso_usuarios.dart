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
  List<Map<String, dynamic>> cards = [];
  List<Map<String, dynamic>> cardsFiltrados = [];
  Map<String, bool> permissoes = {};
  String? usuarioSelecionadoId;
  String? usuarioSelecionadoNome;

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

  // Filtrar cards por nome
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
            return nome.toLowerCase().contains(queryLower);
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

  // Carregar todos os cards ativos e permissões do usuário
  Future<void> _carregarCards(String usuarioId, String usuarioNome) async {
    setState(() {
      exibindoCards = true;
      usuarioSelecionadoId = usuarioId;
      usuarioSelecionadoNome = usuarioNome;
      carregandoCards = true;
    });

    try {
      // 1. Carregar todos os cards ativos do banco (apenas id e nome)
      final cardsData = await supabase
          .from('cards')
          .select('id, nome')
          .eq('ativo', true)
          .order('nome');

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

      // 4. Preparar lista de cards
      List<Map<String, dynamic>> listaCards = [];

      for (var card in cardsData) {
        final cardId = card['id'].toString();
        listaCards.add({
          'id': cardId,
          'nome': card['nome'],
          'permitido': mapaPermissoes[cardId] ?? false,
        });
      }

      // 5. Ordenar de A a Z de forma insensível a maiúsculas e minúsculas
      listaCards.sort((a, b) => (a['nome'] as String).toLowerCase().compareTo((b['nome'] as String).toLowerCase()));

      setState(() {
        cards = listaCards;
        cardsFiltrados = listaCards;
        permissoes = mapaPermissoes;
      });

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

  // Atualizar permissão de um card específico
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
        } else {
          // Atualizar permissão existente
          await supabase
              .from('permissoes')
              .update({'permitido': true})
              .eq('id', existente['id']);
        }
      } else {
        // Se precisa REMOVER permissão
        if (existente != null) {
          await supabase.from('permissoes').delete().eq('id', existente['id']);
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
  // LISTA DE CARDS
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
                }),
              ),
              Expanded(
                child: Text(
                  "Permissões — ${usuarioSelecionadoNome ?? ''}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1)),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _buscaCardsController,
                  onChanged: _filtrarCards,
                  decoration: InputDecoration(
                    hintText: "Buscar por nome do card...",
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
            child: _buildConteudoCards(),
          ),
        ],
      ),
    );
  }

  // Conteúdo dos cards (lista simples por nome)
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

    final totalPermitidos = cardsFiltrados.where((c) => c['permitido'] == true).length;
    final totalCards = cardsFiltrados.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '$totalPermitidos de $totalCards cards permitidos',
            style: TextStyle(
              fontSize: 13,
              color: totalPermitidos == totalCards
                  ? Colors.green
                  : totalPermitidos == 0
                      ? Colors.red
                      : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: cardsFiltrados.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey.shade200, height: 1),
            itemBuilder: (context, index) {
              final card = cardsFiltrados[index];
              return _buildCardItem(card);
            },
          ),
        ),
      ],
    );
  }

  // Widget para item individual do card
  Widget _buildCardItem(Map<String, dynamic> card) {
    final permitido = card['permitido'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: permitido ? Colors.green.shade50 : Colors.white,
      child: Row(
        children: [
          // Indicador visual
          Container(
            width: 3,
            height: 32,
            color: permitido ? Colors.green : Colors.grey.shade300,
          ),
          const SizedBox(width: 12),

          // Nome do card
          Expanded(
            child: Text(
              card['nome'] ?? 'Sem nome',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: permitido
                    ? const Color(0xFF2E7D32)
                    : Colors.grey.shade800,
              ),
            ),
          ),

          // Checkbox de permissão
          Transform.scale(
            scale: 0.9,
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

}