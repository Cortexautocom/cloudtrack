import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_page.dart'; // Para acessar UsuarioAtual

class ControleAcessoUsuarios extends StatefulWidget {
  final VoidCallback onVoltar; // Função para retornar à tela anterior (Configurações)

  const ControleAcessoUsuarios({super.key, required this.onVoltar});

  @override
  State<ControleAcessoUsuarios> createState() => _ControleAcessoUsuariosState();
}

class _ControleAcessoUsuariosState extends State<ControleAcessoUsuarios> {
  final supabase = Supabase.instance.client;

  bool carregando = true;
  bool exibindoSessoes = false;
  bool houveAlteracao = false;

  List<Map<String, dynamic>> usuarios = [];
  List<Map<String, dynamic>> sessoes = [];
  Map<String, bool> permissoes = {};
  String? usuarioSelecionadoId;
  String? usuarioSelecionadoNome;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  // 🔹 Carrega usuários de nível 1 da mesma filial do gerente logado
  Future<void> _carregarUsuarios() async {
    setState(() => carregando = true);
    try {
      final usuarioAtual = UsuarioAtual.instance;
      if (usuarioAtual == null) return;

      var query = supabase
          .from('usuarios')
          .select('id, nome, email, nivel')
          .eq('nivel', 1);

      // Gerente só vê usuários da mesma filial
      if (usuarioAtual.filialId != null && usuarioAtual.filialId!.isNotEmpty) {
        query = query.eq('id_filial', usuarioAtual.filialId!);
      }

      final response = await query.order('nome', ascending: true);
      setState(() {
        usuarios = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao carregar usuários: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  // 🔹 Carrega sessões e permissões do usuário selecionado
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

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    // 🔄 Alterna entre lista de usuários e lista de sessões
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: exibindoSessoes ? _buildListaSessoes() : _buildListaUsuarios(),
    );
  }

  // ============================
  // 🔹 LISTA DE USUÁRIOS
  // ============================
  Widget _buildListaUsuarios() {
    return Container(
      key: const ValueKey('lista_usuarios'),
      padding: const EdgeInsets.all(30),
      color: Colors.white,
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
                "Controle de acesso — Usuários",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const Divider(),

          // Lista
          Expanded(
            child: usuarios.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum usuário de nível 1 encontrado nesta filial.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: usuarios.length,
                    itemBuilder: (context, index) {
                      final u = usuarios[index];
                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(
                          u['nome'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(u['email']),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

  // ============================
  // 🔹 LISTA DE SESSÕES (TELA CHEIA)
  // ============================
  Widget _buildListaSessoes() {
    return Container(
      key: const ValueKey('lista_sessoes'),
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔙 Cabeçalho fixo
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: () {
                  _confirmarSaida(() {
                    setState(() {
                      exibindoSessoes = false;
                      usuarioSelecionadoId = null;
                    });
                  });
                },
              ),
              Expanded(
                child: Text(
                  "Permissões — ${usuarioSelecionadoNome ?? ''}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),

          // ===== Lista de sessões =====
          Expanded(
            child: ListView.separated(
              itemCount: sessoes.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey.shade200,
                height: 1,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final s = sessoes[index];
                final permitido = permissoes[s['id']] ?? false;

                return InkWell(
                  onTap: () {
                    setState(() {
                      permissoes[s['id']] = !permitido;
                      houveAlteracao = true;
                    });
                  },
                  hoverColor: const Color(0xFFF9F9F9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Checkbox(
                          activeColor: const Color(0xFF2E7D32),
                          value: permitido,
                          onChanged: (valor) {
                            if (valor != null) {
                              setState(() {
                                permissoes[s['id']] = valor;
                                houveAlteracao = true;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s['nome'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ===== Botão "Aplicar configurações" =====
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 5),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "Aplicar configurações",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: () async {
                  await _aplicarAlteracoes();
                  setState(() {
                    houveAlteracao = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Configurações aplicadas com sucesso!"),
                      backgroundColor: Colors.green,
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

  // ============================
  // 🔹 CONFIRMAR SAÍDA
  // ============================
  Future<void> _confirmarSaida(Function acaoSaida) async {
    if (!houveAlteracao) {
      acaoSaida();
      return;
    }

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Deseja aplicar as alterações realizadas?"),
        content: const Text(
          "Existem modificações que ainda não foram aplicadas.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context, true);
            },
            child: const Text("Aplicar", style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text("Descartar alterações",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (resultado == true) {
      await _aplicarAlteracoes();
      setState(() {
        houveAlteracao = false;
      });
      acaoSaida();
    } else if (resultado == false) {
      setState(() {
        houveAlteracao = false;
      });
      acaoSaida();
    }
  }

  // ============================
  // 🔹 APLICAR ALTERAÇÕES
  // ============================
  Future<void> _aplicarAlteracoes() async {
    if (usuarioSelecionadoId == null) return;
    try {
      await supabase
          .from('permissoes')
          .delete()
          .eq('id_usuario', usuarioSelecionadoId!);

      final novasPermissoes = permissoes.entries
          .where((p) => p.value == true)
          .map((p) => {
                'id_usuario': usuarioSelecionadoId!,
                'id_sessao': p.key,
                'permitido': true,
              })
          .toList();

      if (novasPermissoes.isNotEmpty) {
        await supabase.from('permissoes').insert(novasPermissoes);
      }
    } catch (e) {
      debugPrint("Erro ao aplicar alterações: $e");
    }
  }
}
