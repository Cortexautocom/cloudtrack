import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'aprovar_usuario.dart';

class UsuariosPage extends StatefulWidget {
  final VoidCallback onVoltar;
  const UsuariosPage({super.key, required this.onVoltar});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  bool carregando = true;
  List<Map<String, dynamic>> usuarios = [];
  Map<String, dynamic>? usuarioSelecionado;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  /// 🔹 Busca todos os usuários e cadastros pendentes diretamente do Supabase
  Future<void> _carregarUsuarios() async {
    try {
      setState(() => carregando = true);

      // 1️⃣ Busca cadastros pendentes
      final pendentesResponse = await supabase
          .from('cadastros_pendentes')
          .select('id, nome, email, status, funcao, celular, id_filial')
          .order('id', ascending: false);

      final List<Map<String, dynamic>> pendentes =
          List<Map<String, dynamic>>.from(pendentesResponse);

      // 2️⃣ Busca todos os usuários com seus respectivos status
      final usuariosResponse = await supabase
          .from('usuarios')
          .select('id, nome, email, nivel, status')
          .order('id', ascending: false);

      final List<Map<String, dynamic>> listaUsuarios =
          List<Map<String, dynamic>>.from(usuariosResponse);

      // 3️⃣ Junta as duas listas (pendentes + usuários)
      final todos = <Map<String, dynamic>>[
        ...pendentes.map((p) => {
              'id': p['id'],
              'nome': p['nome'],
              'email': p['email'],
              'status': 'pendente', // forçado para diferenciar na UI
              'tabela': 'cadastros_pendentes',
              'dados': p,
            }),
        ...listaUsuarios.map((u) => {
              'id': u['id'],
              'nome': u['nome'],
              'email': u['email'],
              'status': (u['status'] ?? '').toString().toLowerCase(),
              'tabela': 'usuarios',
              'dados': u,
            }),
      ];

      setState(() {
        usuarios = todos;
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

    // 🔹 Se o usuário clicou em um item PENDENTE, abre o form de aprovação
    if (usuarioSelecionado != null &&
        usuarioSelecionado!['tabela'] == 'cadastros_pendentes') {
      return AprovarUsuarioPage(
        usuario: usuarioSelecionado!['dados'],
        onVoltar: () {
          setState(() => usuarioSelecionado = null);
          _carregarUsuarios(); // Atualiza lista ao voltar
        },
      );
    }

    // 🔹 Lista principal de usuários
    return Padding(
      padding: const EdgeInsets.all(30),
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
          const SizedBox(height: 20),

          Expanded(
            child: usuarios.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum usuário encontrado.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: usuarios.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final u = usuarios[index];
                      final cor = _corStatus(u['status'] ?? '');
                      final texto =
                          _textoStatus(u['status'] ?? '', u['tabela'] ?? '');

                      return ListTile(
                        leading: Icon(Icons.person_outline, color: cor),
                        title: Text(u['nome'] ?? 'Sem nome'),
                        subtitle: Text(u['email'] ?? ''),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.1),
                            border: Border.all(color: cor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            texto,
                            style: TextStyle(color: cor, fontSize: 12),
                          ),
                        ),
                        onTap: () {
                          // Abre somente se for pendente
                          if (u['tabela'] == 'cadastros_pendentes') {
                            setState(() {
                              usuarioSelecionado = u;
                            });
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
