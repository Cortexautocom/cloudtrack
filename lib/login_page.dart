import 'package:flutter/material.dart';
import 'home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'configuracoes/cadastro_novo_usuario.dart';
import 'configuracoes/esqueci_senha.dart';
import 'configuracoes/escolher_senha.dart';

/// 🧩 Classe global que armazena dados do usuário logado
class UsuarioAtual {
  static UsuarioAtual? instance;

  final String id;
  final String nome;
  final int nivel;

  /// IDs SEMPRE String (Flutter Web safe)
  final String? filialId;
  final String? empresaId;

  /// CONTROLE REAL DE ACESSO (CARD-CENTRIC)
  final List<String> cardsPermitidosIds;
  final bool senhaTemporaria;

  UsuarioAtual({
    required this.id,
    required this.nome,
    required this.nivel,
    required this.filialId,
    required this.empresaId,
    required this.cardsPermitidosIds,
    required this.senhaTemporaria,
  });

  /// Fonte única de permissão
  bool podeAcessarCard(String cardId) {
    if (nivel >= 3) return true;
    return cardsPermitidosIds.contains(cardId);
  }

  bool get precisaTrocarSenha => senhaTemporaria;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;

  /// 🔐 Carrega permissões de CARDS
  Future<List<String>> _carregarPermissoesCards(String usuarioId) async {
    try {
      final supabase = Supabase.instance.client;

      final permissoes = await supabase
          .from('permissoes')
          .select('id_sessao')
          .eq('id_usuario', usuarioId)
          .eq('permitido', true);

      return permissoes
          .map((p) => p['id_sessao']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('❌ Erro ao carregar permissões de cards: $e');
      return [];
    }
  }

  /// 🔑 LOGIN
  Future<void> loginUser() async {
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha e-mail e senha.'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      /// 1️⃣ Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw Exception('Falha na autenticação.');

      /// 2️⃣ Dados do usuário
      final raw = await supabase
          .from('usuarios')
          .select('''
            id,
            nome,
            Nome_apelido,
            nivel,
            id_filial,
            empresa_id,
            senha_temporaria
          ''')
          .eq('id', user.id)
          .maybeSingle();

      if (raw == null) {
        throw Exception('Usuário não encontrado.');
      }

      final usuarioData = Map<String, dynamic>.from(raw as Map);

      final int nivel = usuarioData['nivel'] as int;
      final String? filialId = usuarioData['id_filial']?.toString();
      final String? empresaId = usuarioData['empresa_id']?.toString();

      /// 3️⃣ Permissões reais (cards)
      final cardsPermitidosIds = await _carregarPermissoesCards(user.id);

      /// 4️⃣ Validação: usuário sem nenhum card
      if (nivel < 3 && cardsPermitidosIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Você não tem permissão para acessar nenhuma funcionalidade.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        await supabase.auth.signOut();
        UsuarioAtual.instance = null;
        setState(() => _isLoading = false);
        return;
      }

      /// 5️⃣ Instância global
      UsuarioAtual.instance = UsuarioAtual(
        id: usuarioData['id'].toString(),
        nome: (usuarioData['Nome_apelido'] ?? usuarioData['nome']).toString(),
        nivel: nivel,
        filialId: filialId,
        empresaId: empresaId,
        cardsPermitidosIds: cardsPermitidosIds,
        senhaTemporaria: usuarioData['senha_temporaria'] == true,
      );

      /// 6️⃣ Troca de senha
      if (UsuarioAtual.instance!.precisaTrocarSenha) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Defina uma nova senha para continuar.'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EscolherSenhaPage()),
        );
        return;
      }

      /// 7️⃣ Sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login realizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (error) {
      String mensagemErro = 'Erro ao fazer login.';

      if (error is AuthException) {
        final msg = error.message.toLowerCase();
        if (msg.contains('invalid')) {
          mensagemErro = 'E-mail ou senha incorretos.';
        } else if (msg.contains('email not confirmed')) {
          mensagemErro = 'E-mail não confirmado.';
        }
      }

      debugPrint('❌ Erro de login: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemErro),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🖥️ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_login9.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo_top_login3.png'),
          ),
          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Entre com suas credenciais",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: _obscureText,
                    onSubmitted: (_) => _isLoading ? null : loginUser(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4B78),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : loginUser,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Entrar',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EsqueciSenhaPage()),
                      );
                    },
                    child: const Text(
                      "Esqueci minha senha",
                      style: TextStyle(color: Color(0xFF0A4B78)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const CadastroNovoUsuarioPage()),
                      );
                    },
                    child: const Text(
                      "Me cadastrar",
                      style: TextStyle(color: Color(0xFF0A4B78)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
