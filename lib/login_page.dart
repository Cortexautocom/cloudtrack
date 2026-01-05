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

  final List<String> sessoesPermitidas;
  final bool senhaTemporaria;

  UsuarioAtual({
    required this.id,
    required this.nome,
    required this.nivel,
    required this.filialId,
    required this.empresaId,
    required this.sessoesPermitidas,
    required this.senhaTemporaria,
  });

  bool temPermissao(String idSessao) {
    if (nivel >= 2) return true;
    return sessoesPermitidas.contains(idSessao);
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

  // ======= Função de login =======
  Future<void> loginUser() async {
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, preencha e-mail e senha.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 🔹 1. Autenticação
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Falha na autenticação.');
      }

      final userId = response.user!.id;

      // 🔹 2. Busca dados do usuário (empresa_id incluído)
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
          .eq('id', userId)
          .maybeSingle();

      if (raw == null) {
        throw Exception('Usuário não encontrado na tabela de usuários.');
      }

      /// 🔹 3. Conversão EXPLÍCITA (obrigatória no Flutter Web)
      final Map<String, dynamic> usuarioData =
          Map<String, dynamic>.from(raw as Map);

      final String? filialId = usuarioData['id_filial'] != null
          ? usuarioData['id_filial'].toString()
          : null;

      final String? empresaId = usuarioData['empresa_id'] != null
          ? usuarioData['empresa_id'].toString()
          : null;

      // 🔹 4. Cria objeto global do usuário
      UsuarioAtual.instance = UsuarioAtual(
        id: usuarioData['id'].toString(),
        nome: (usuarioData['Nome_apelido'] ?? usuarioData['nome']).toString(),
        nivel: usuarioData['nivel'] as int,
        filialId: filialId,
        empresaId: empresaId,
        sessoesPermitidas: <String>[],
        senhaTemporaria: usuarioData['senha_temporaria'] == true,
      );

      // 🔹 5. Verifica troca de senha
      if (UsuarioAtual.instance!.precisaTrocarSenha) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, defina uma nova senha para sua conta.'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EscolherSenhaPage()),
        );
      } else {
        if (!mounted) return;

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
      }
    } catch (error) {
      if (!mounted) return;

      String mensagemErro = 'Erro ao fazer login.';

      if (error is AuthException) {
        final msg = error.message.toLowerCase();
        if (msg.contains('invalid')) {
          mensagemErro = 'E-mail ou senha incorretos.';
        } else if (msg.contains('email not confirmed')) {
          mensagemErro = 'E-mail não confirmado.';
        }
      }

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

  // ======= Interface =======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ===== Fundo =====
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_login.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ===== Logo =====
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo_top_login.png'),
          ),

          // ===== Caixa principal =====
          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
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
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
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

          // ===== Rodapé =====
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "© 2025 CloudTrack, LLC. All rights reserved.",
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "AwaySoftwares Solution - 505 North Angier Avenue, Atlanta, GA 30308, EUA.",
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
