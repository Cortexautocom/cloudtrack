import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'aprovar_usuario.dart';
import 'editar_usuario.dart';

class UsuariosPage extends StatefulWidget {
  final VoidCallback onVoltar;
  const UsuariosPage({super.key, required this.onVoltar});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  bool carregando = true;
  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> usuariosFiltrados = [];
  Map<String, dynamic>? usuarioSelecionado;
  final TextEditingController _controllerPesquisa = TextEditingController();
  final Map<String, String> _cacheFiliais = {}; // Mudado para String key (UUID)

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
    _controllerPesquisa.addListener(_filtrarUsuarios);
  }

  @override
  void dispose() {
    _controllerPesquisa.dispose();
    super.dispose();
  }

  /// 🔹 Filtra usuários baseado no texto de pesquisa
  void _filtrarUsuarios() {
    final termo = _controllerPesquisa.text.toLowerCase().trim();
    
    if (termo.isEmpty) {
      setState(() {
        usuariosFiltrados = usuarios;
      });
      return;
    }

    if (usuarios.isEmpty) {
      setState(() {
        usuariosFiltrados = [];
      });
      return;
    }

    setState(() {
      usuariosFiltrados = usuarios.where((usuario) {
        final nome = usuario['nome']?.toString().toLowerCase() ?? '';
        final email = usuario['email']?.toString().toLowerCase() ?? '';
        final filial = usuario['filial_nome']?.toString().toLowerCase() ?? '';
        
        return nome.contains(termo) || 
               email.contains(termo) || 
               filial.contains(termo);
      }).toList();
    });
  }

  /// 🔹 Busca o nome da filial pelo ID
  Future<String> _obterNomeFilial(String? idFilial) async {
    if (idFilial == null || idFilial.isEmpty) return 'N/A';
    
    // Verifica se já está em cache
    if (_cacheFiliais.containsKey(idFilial)) {
      return _cacheFiliais[idFilial]!;
    }

    try {
      final response = await supabase
          .from('filiais')
          .select('nome')
          .eq('id', idFilial)
          .single();

      final nomeFilial = response['nome']?.toString() ?? 'N/A';
      _cacheFiliais[idFilial] = nomeFilial;
      return nomeFilial;
    } catch (e) {
      debugPrint("❌ Erro ao buscar filial $idFilial: $e");
      return 'N/A';
    }
  }

  /// 🔹 Busca todos os usuários e cadastros pendentes diretamente do Supabase
  Future<void> _carregarUsuarios() async {
    try {
      setState(() => carregando = true);

      // 1️⃣ Busca cadastros pendentes
      final pendentesResponse = await supabase
          .from('cadastros_pendentes')
          .select('*')
          .order('criado_em', ascending: false);

      final List<Map<String, dynamic>> pendentes =
          List<Map<String, dynamic>>.from(pendentesResponse);

      // 2️⃣ Busca todos os usuários
      final usuariosResponse = await supabase
          .from('usuarios')
          .select('*')
          .order('nome', ascending: true);

      final List<Map<String, dynamic>> listaUsuarios =
          List<Map<String, dynamic>>.from(usuariosResponse);

      // 3️⃣ Processa pendentes com nome da filial
      final pendentesComFilial = await Future.wait(
        pendentes.map((p) async {
          final nomeFilial = await _obterNomeFilial(p['id_filial']?.toString());
          return {
            'id': p['id'],
            'nome': p['nome'],
            'email': p['email'],
            'status': 'pendente',
            'tabela': 'cadastros_pendentes',
            'filial_nome': nomeFilial,
            'dados': p,
          };
        }),
      );

      // 4️⃣ Processa usuários com nome da filial
      final usuariosComFilial = await Future.wait(
        listaUsuarios.map((u) async {
          final nomeFilial = await _obterNomeFilial(u['id_filial']?.toString());
          return {
            'id': u['id'],
            'nome': u['nome'],
            'email': u['email'],
            'status': (u['status'] ?? 'ativo').toString().toLowerCase(),
            'tabela': 'usuarios',
            'filial_nome': nomeFilial,
            'dados': u,
          };
        }),
      );

      // 5️⃣ Junta as duas listas
      final todos = <Map<String, dynamic>>[
        ...pendentesComFilial,
        ...usuariosComFilial,
      ];

      setState(() {
        usuarios = todos;
        usuariosFiltrados = todos;
      });
    } catch (e) {
      debugPrint("❌ Erro ao carregar usuários: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao carregar usuários: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  /// 🔹 Define cor de acordo com o status
  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
        return Colors.green;
      case 'suspenso':
        return Colors.red;
      case 'pendente':
        return Colors.orange;
      case 'bloqueado':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  /// 🔹 Formata texto de exibição do status (primeira letra maiúscula)
  String _textoStatus(String status, String tabela) {
    if (tabela == 'cadastros_pendentes') return 'Pendente';
    if (status.isEmpty) return 'Desconhecido';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    // 🔹 Abre a tela correspondente conforme o tipo do usuário selecionado
    if (usuarioSelecionado != null) {
      // 🟠 Caso seja um cadastro pendente → abre tela de aprovação
      if (usuarioSelecionado!['tabela'] == 'cadastros_pendentes') {
        return AprovarUsuarioPage(
          usuario: usuarioSelecionado!['dados'],
          onVoltar: () {
            setState(() => usuarioSelecionado = null);
            _carregarUsuarios(); // Atualiza lista ao voltar
          },
        );
      }

      // 🟢 Caso seja um usuário já ativo → abre tela de edição
      if (usuarioSelecionado!['tabela'] == 'usuarios') {
        return EditarUsuarioPage(
          usuario: usuarioSelecionado!['dados'],
          onVoltar: () {
            setState(() => usuarioSelecionado = null);
            _carregarUsuarios(); // Atualiza lista ao voltar
          },
        );
      }
    }

    // 🔹 Lista principal de usuários
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: widget.onVoltar,
              ),
              const Text(
                "Usuários do Sistema",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Campo de pesquisa
          Container(
            width: 700,
            height: 40,
            margin: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _controllerPesquisa,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome, email ou filial...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Lista de usuários
          Expanded(
            child: Container(
              width: 700,
              constraints: const BoxConstraints(maxWidth: 700),
              child: usuariosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        "Nenhum usuário encontrado.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: usuariosFiltrados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = usuariosFiltrados[index];
                        final cor = _corStatus(u['status'] ?? '');
                        final texto =
                            _textoStatus(u['status'] ?? '', u['tabela'] ?? '');

                        return SizedBox(
                          height: 60,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Icon(Icons.person_outline, color: cor, size: 20),
                            title: Text(
                              u['nome'] ?? 'Sem nome',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (u['filial_nome'] != null && u['filial_nome'] != 'N/A')
                                  Text(
                                    u['filial_nome']!,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (u['filial_nome'] != null && u['filial_nome'] != 'N/A')
                                  const Text("  |  ", style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 133, 133, 133))),
                                Text(
                                  u['email'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cor.withOpacity(0.1),
                                border: Border.all(color: cor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                texto,
                                style: TextStyle(color: cor, fontSize: 10),
                              ),
                            ),
                            onTap: () {
                              // Abre somente se for pendente
                              if (u['tabela'] == 'cadastros_pendentes' || u['tabela'] == 'usuarios') {
                                setState(() {
                                  usuarioSelecionado = u;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),          
        ],
      ),
    );
  }
}