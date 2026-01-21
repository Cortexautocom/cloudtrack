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

  bool carregando = true;
  bool exibindoSessoes = false;
  bool acessoNegado = false;

  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> usuariosFiltrados = [];
  List<Map<String, dynamic>> sessoes = [];
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

  Future<void> _carregarSessoes(String usuarioId, String usuarioNome) async {
    setState(() {
      exibindoSessoes = true;
      usuarioSelecionadoId = usuarioId;
      usuarioSelecionadoNome = usuarioNome;
      carregando = true;
    });

    try {
      final sessoesData = await supabase.from('sessoes').select('id, nome');
      final permissoesData = await supabase
          .from('permissoes')
          .select('id_sessao, permitido')
          .eq('id_usuario', usuarioId);

      Map<String, bool> mapa = {};
      for (var s in sessoesData) {
        final encontrado = permissoesData.firstWhere(
          (p) => p['id_sessao'] == s['id'],
          orElse: () => {'permitido': false},
        );
        mapa[s['id']] = encontrado['permitido'] ?? false;
      }

      setState(() {
        sessoes = List<Map<String, dynamic>>.from(sessoesData);
        permissoes = mapa;
      });
    } catch (e) {
      debugPrint('Erro ao carregar sessões: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _atualizarPermissao(String sessaoId, bool permitido) async {
    if (usuarioSelecionadoId == null) return;

    try {
      final existente = await supabase
          .from('permissoes')
          .select('id')
          .eq('id_usuario', usuarioSelecionadoId!)
          .eq('id_sessao', sessaoId)
          .maybeSingle();

      if (permitido) {
        if (existente == null) {
          await supabase.from('permissoes').insert({
            'id_usuario': usuarioSelecionadoId!,
            'id_sessao': sessaoId,
            'permitido': true,
          });
        } else {
          await supabase
              .from('permissoes')
              .update({'permitido': true})
              .eq('id', existente['id']);
        }
      } else {
        if (existente != null) {
          await supabase.from('permissoes').delete().eq('id', existente['id']);
        }
      }
    } catch (e) {
      debugPrint("Erro ao atualizar permissão: $e");
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
      child: exibindoSessoes ? _buildListaSessoes() : _buildListaUsuarios(),
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
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(u['nome'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle:
                            Text("${u['email']}  •  Nível ${u['nivel']}"),
                        trailing:
                            const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () =>
                            _carregarSessoes(u['id'], u['nome']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ======================
  // LISTA DE SESSÕES
  // ======================
  Widget _buildListaSessoes() {
    return Container(
      key: const ValueKey('lista_sessoes'),
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
                  exibindoSessoes = false;
                  usuarioSelecionadoId = null;
                }),
              ),
              Text(
                "Permissões — ${usuarioSelecionadoNome ?? ''}",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1)),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft, // 🔴 AQUI FOI A CORREÇÃO
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView.separated(
                    itemCount: sessoes.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade200, height: 1),
                    itemBuilder: (context, index) {
                      final s = sessoes[index];
                      final permitido = permissoes[s['id']] ?? false;

                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          s['nome'] ?? '',
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500),
                        ),
                        value: permitido,
                        activeColor: const Color(0xFF2E7D32),
                        onChanged: (valor) async {
                          if (valor == null) return;
                          setState(() => permissoes[s['id']] = valor);
                          await _atualizarPermissao(s['id'], valor);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
