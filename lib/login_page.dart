import 'package:flutter/material.dart';
import 'home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🧩 Classe global que armazena dados do usuário logado
class UsuarioAtual {
  static UsuarioAtual? instance;

  final String id;
  final String nome;
  final int nivel;
  final String? filialId; // ✅ agora pode ser nulo
  final List<String> sessoesPermitidas;

  UsuarioAtual({
    required this.id,
    required this.nome,
    required this.nivel,
    this.filialId, // ✅ opcional
    required this.sessoesPermitidas,
  });

  bool temPermissao(String idSessao) {
    if (nivel >= 2) return true; // nível 2 e 3 têm acesso total
    return sessoesPermitidas.contains(idSessao);
  }
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

  // ======= Função de login com controle de acesso =======
  Future<void> loginUser() async {
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      // 🔹 1. Autentica no Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Usuário ou senha incorretos';
      }

      final userId = response.user!.id;

      // 🔹 2. Busca dados complementares do usuário
      final usuarioData = await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial')
          .eq('id', userId)
          .maybeSingle();

      if (usuarioData == null) {
        throw 'Usuário não encontrado na tabela de usuários.';
      }

      // 🔹 3. Busca permissões, apenas se nível = 1
      List<String> sessoesPermitidas = [];

      if (usuarioData['nivel'] == 1) {
        final permissoes = await supabase
            .from('permissoes')
            .select('id_sessao')
            .eq('id_usuario', usuarioData['id'])
            .eq('permitido', true);

        sessoesPermitidas =
            List<String>.from(permissoes.map((p) => p['id_sessao']));
      }

      // 🔹 4. Cria objeto do usuário (sem exigir filial)
      UsuarioAtual.instance = UsuarioAtual(
        id: usuarioData['id'],
        nome: usuarioData['nome'],
        nivel: usuarioData['nivel'],
        filialId: usuarioData['id_filial'] != null
            ? usuarioData['id_filial'].toString()
            : null, // ✅ evita erro de tipo
        sessoesPermitidas: sessoesPermitidas,
      );

      // 🔹 5. Mensagem e navegação
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fazer login: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ======= Interface de login =======
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

                  // ===== Campo de e-mail =====
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

                  // ===== Campo de senha =====
                  TextField(
                    controller: passwordController,
                    obscureText: _obscureText,
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

                  // ===== Botão Entrar =====
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

                  // ===== Esqueci senha =====
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Esqueci minha senha",
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "© 2025 CloudTrack, LLC. All rights reserved.",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "AwaySoftwares Solution - 505 North Angier Avenue, Atlanta, GA 30308, EUA.",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
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
