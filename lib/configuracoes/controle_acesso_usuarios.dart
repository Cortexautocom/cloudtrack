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

  // 🔹 Atualiza permissão no banco em tempo real
  Future<void> _atualizarPermissao(String sessaoId, bool permitido) async {
    if (usuarioSelecionadoId == null) return;

    try {
      // Verifica se já existe permissão cadastrada
      final existente = await supabase
          .from('permissoes')
          .select('id')
          .eq('id_usuario', usuarioSelecionadoId!)
          .eq('id_sessao', sessaoId)
          .maybeSingle();

      if (permitido) {
        // Se for permitido e não existir, insere
        if (existente == null) {
          await supabase.from('permissoes').insert({
            'id_usuario': usuarioSelecionadoId!,
            'id_sessao': sessaoId,
            'permitido': true,
          });
        } else {
          // Se já existir, apenas garante o campo verdadeiro
          await supabase
              .from('permissoes')
              .update({'permitido': true})
              .eq('id', existente['id']);
        }
      } else {
        // Se desmarcou, remove a permissão
        if (existente != null) {
          await supabase
              .from('permissoes')
              .delete()
              .eq('id', existente['id']);
        }
      }
    } catch (e) {
      debugPrint("Erro ao atualizar permissão: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro ao atualizar permissão."),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  setState(() {
                    exibindoSessoes = false;
                    usuarioSelecionadoId = null;
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

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        activeColor: const Color(0xFF2E7D32),
                        value: permitido,
                        onChanged: (valor) async {
                          if (valor == null) return;
                          setState(() {
                            permissoes[s['id']] = valor;
                          });
                          await _atualizarPermissao(s['id'], valor);
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
