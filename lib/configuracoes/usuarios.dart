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
  final Map<String, String> _cacheFiliais = {};

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

  void _filtrarUsuarios() {
    final termo = _controllerPesquisa.text.toLowerCase().trim();
    if (termo.isEmpty) {
      setState(() => usuariosFiltrados = usuarios);
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

  Future<String> _obterNomeFilial(String? idFilial) async {
    if (idFilial == null || idFilial.isEmpty) return 'N/A';
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

  Future<void> _carregarUsuarios() async {
    try {
      setState(() => carregando = true);

      final pendentesResponse = await supabase
          .from('cadastros_pendentes')
          .select('*')
          .order('criado_em', ascending: false);

      final pendentes = List<Map<String, dynamic>>.from(pendentesResponse);

      final usuariosResponse =
          await supabase.from('usuarios').select('*').order('nome', ascending: true);
      final listaUsuarios = List<Map<String, dynamic>>.from(usuariosResponse);

      final pendentesComFilial = await Future.wait(
        pendentes.map((p) async {
          final nomeFilial = await _obterNomeFilial(p['id_filial']?.toString());
          return {
            'id': p['id'],
            'nome': p['nome'],
            'email': p['email'],
            'status': 'pendente',
            'nivel': p['nivel'] ?? 1,
            'tabela': 'cadastros_pendentes',
            'filial_nome': nomeFilial,
            'dados': p,
          };
        }),
      );

      final usuariosComFilial = await Future.wait(
        listaUsuarios.map((u) async {
          final nomeFilial = await _obterNomeFilial(u['id_filial']?.toString());
          return {
            'id': u['id'],
            'nome': u['nome'],
            'email': u['email'],
            'status': (u['status'] ?? 'ativo').toString().toLowerCase(),
            'nivel': u['nivel'] ?? 1,
            'tabela': 'usuarios',
            'filial_nome': nomeFilial,
            'dados': u,
            'redefinicao_senha': u['redefinicao_senha'] ?? false,
          };
        }),
      );

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

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
        return Colors.green;
      case 'suspenso':
        return Colors.red;
      case 'pendente':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _textoStatus(String status, String tabela) {
    if (tabela == 'cadastros_pendentes') return 'Pendente';
    if (status.isEmpty) return 'Desconhecido';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Color _corNivel(int nivel) {
    switch (nivel) {
      case 1:
        return Colors.blueGrey;
      case 2:
        return const Color.fromARGB(255, 0, 47, 255);
      case 3:
        return const Color.fromARGB(255, 240, 184, 0);
      default:
        return Colors.grey;
    }
  }

  String _textoNivel(int nivel) {
    switch (nivel) {
      case 1:
        return "Logística / Operações";
      case 2:
        return "Gerência e supervisão";
      case 3:
        return "Diretoria e Administração";
      default:
        return "N/A";
    }
  }

  void _mostrarMenuAcoes(
      BuildContext context,
      Map<String, dynamic> usuario,
      GlobalKey key,
      ) async {
    final RenderBox button = key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final statusAtual = usuario['status'] ?? 'ativo';
    final suspenso = statusAtual == 'suspenso';

    final value = await showMenu(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: 'editar',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('Editar usuário'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'suspender_reativar',
          child: Row(
            children: [
              Icon(
                suspenso ? Icons.check_circle : Icons.block,
                color: suspenso ? Colors.green : Colors.red,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(suspenso ? 'Reativar usuário' : 'Suspender usuário'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'redefinir_senha',
          child: Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Redefinir senha'),
            ],
          ),
        ),
      ],
    );

    if (value == null) return;

    switch (value) {
      case 'editar':
        setState(() => usuarioSelecionado = usuario);
        break;
      case 'suspender_reativar':
        _alternarStatusUsuario(usuario);
        break;
      case 'redefinir_senha':
        _redefinirSenha(usuario);
        break;
    }
  }

  Future<void> _alternarStatusUsuario(Map<String, dynamic> usuario) async {
    final atual = usuario['status'] ?? 'ativo';
    final novoStatus = atual == 'suspenso' ? 'ativo' : 'suspenso';

    final confirmar = await _mostrarDialogoConfirmacao(
      titulo: novoStatus == 'ativo' ? 'Reativar Usuário' : 'Suspender Usuário',
      mensagem: novoStatus == 'ativo'
          ? 'Tem certeza que deseja reativar este usuário?'
          : 'Tem certeza que deseja suspender este usuário?',
    );

    if (!confirmar) return;

    try {
      await supabase
          .from('usuarios')
          .update({'status': novoStatus})
          .eq('id', usuario['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(novoStatus == 'ativo'
                ? '✅ Usuário reativado com sucesso.'
                : '⚠️ Usuário suspenso com sucesso.'),
          ),
        );
        _carregarUsuarios();
      }
    } catch (e) {
      debugPrint('❌ Erro ao alterar status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _redefinirSenha(Map<String, dynamic> usuario) async {
    final confirmar = await _mostrarDialogoConfirmacao(
      titulo: 'Redefinir Senha',
      mensagem:
      'Tem certeza que deseja redefinir a senha deste usuário?\n\nUma nova senha temporária aleatória será gerada e enviada para o e-mail do usuário.',
    );

    if (!confirmar) return;

    try {
      final response = await supabase.functions.invoke(
        'redefinir-senha',
        body: {'email': usuario['email']},
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Erro desconhecido');
      }


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Senha redefinida com sucesso! O usuário foi notificado por e-mail.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ Erro ao redefinir senha: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao redefinir senha: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _mostrarDialogoConfirmacao({
    required String titulo,
    required String mensagem,
  }) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_reset, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text("Redefinir Senha"),
          ],
        ),
        content: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Padding(
              padding: EdgeInsets.all(0.8),
              child: Icon(Icons.check, size: 18),
            ),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 88, 153, 69),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // 👈 aumenta só nas laterais
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    if (usuarioSelecionado != null) {
      if (usuarioSelecionado!['tabela'] == 'cadastros_pendentes') {
        return AprovarUsuarioPage(
          usuario: usuarioSelecionado!['dados'],
          onVoltar: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => usuarioSelecionado = null);
                _carregarUsuarios();
              }
            });
          },
        );
      }
      if (usuarioSelecionado!['tabela'] == 'usuarios') {
        return EditarUsuarioPage(
          usuario: usuarioSelecionado!['dados'],
          onVoltar: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => usuarioSelecionado = null);
                _carregarUsuarios();
              }
            });
          },
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
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
                        final bool pedidoSenha = u['redefinicao_senha'] == true;
                        final corStatus = _corStatus(u['status'] ?? '');
                        final textoStatus = _textoStatus(u['status'] ?? '', u['tabela'] ?? '');
                        final nivel = int.tryParse(u['nivel'].toString()) ?? 1;
                        final corNivel = _corNivel(nivel);
                        final textoNivel = _textoNivel(nivel);
                        final menuKey = GlobalKey();

                        return SizedBox(
                          height: 60,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Icon(Icons.person_outline, color: corStatus, size: 20),
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
                                  const Text("  |  ",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color.fromARGB(255, 133, 133, 133))),
                                Text(
                                  u['email'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // STATUS
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: corStatus.withOpacity(0.1),
                                    border: Border.all(color: corStatus),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    textoStatus,
                                    style: TextStyle(color: corStatus, fontSize: 10),
                                  ),
                                ),

                                const SizedBox(width: 6),

                                // NÍVEL
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: corNivel.withOpacity(0.1),
                                    border: Border.all(color: corNivel),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    textoNivel,
                                    style: TextStyle(color: corNivel, fontSize: 10),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // MENU
                                IconButton(
                                  key: menuKey,
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  color: const Color.fromARGB(255, 0, 36, 153),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                  onPressed: () => _mostrarMenuAcoes(context, u, menuKey),
                                ),

                                const SizedBox(width: 8),

                                // 🔥 ALERTA PISCANTE (AGORA DEPOIS DO MENU)
                                if (pedidoSenha)
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0.8, end: 1.0),
                                    duration: const Duration(seconds: 1),
                                    onEnd: () => setState(() {}),
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.notification_important, // 👈 ALTERE O ÍCONE AQUI
                                            color: Colors.red,
                                          ),
                                          tooltip: "Solicitação de redefinição de senha",
                                          onPressed: () => _mostrarDialogoSolicitacao(u),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),

                            onTap: () {
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
  Future<void> _mostrarDialogoSolicitacao(Map<String, dynamic> usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),

        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha título + botão X
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                const Text(
                  "Solicitação de Redefinição",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context, null),
                  child: const Icon(Icons.close, size: 22, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Icon(Icons.notifications_active, color: Colors.red, size: 48),
          ],
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "O usuário ${usuario['nome']} solicitou redefinição de senha.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),

            const SizedBox(height: 26), // 👈 espaçamento maior
          ],
        ),

        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Negar"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Redefinir",
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirmar == null) return; // X pressionado

    if (confirmar == false) {
      await supabase
          .from('usuarios')
          .update({'redefinicao_senha': false})
          .eq('id', usuario['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Redefinição negada.")),
      );

      _carregarUsuarios();
      return;
    }

    await _redefinirSenha(usuario);

    await supabase
        .from('usuarios')
        .update({'redefinicao_senha': false})
        .eq('id', usuario['id']);

    _carregarUsuarios();
  }

}
