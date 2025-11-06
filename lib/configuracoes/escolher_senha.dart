import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscolherSenhaPage extends StatefulWidget {
  const EscolherSenhaPage({super.key});

  @override
  State<EscolherSenhaPage> createState() => _EscolherSenhaPageState();
}

class _EscolherSenhaPageState extends State<EscolherSenhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;
  bool _senhaDefinida = false;

  Future<void> _definirSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // Atualiza a senha no Supabase
      await supabase.auth.updateUser(
        UserAttributes(password: _novaSenhaController.text.trim()),
      );

      setState(() => _senhaDefinida = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      // Aguarda um pouco e redireciona para o login
      await Future.delayed(const Duration(seconds: 2));

      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validarSenha(String? value) {
    if (value == null || value.isEmpty) return 'Digite a nova senha';
    if (value.length < 6) return 'A senha deve ter pelo menos 6 caracteres';
    return null;
  }

  String? _validarConfirmacao(String? value) {
    if (value != _novaSenhaController.text) return 'As senhas não coincidem';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo de imagem
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_login.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Logo
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo_top_login.png'),
          ),

          Center(
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
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
                  const Icon(Icons.lock_open_outlined,
                      size: 64, color: Color(0xFF0A4B78)),
                  const SizedBox(height: 15),
                  const Text(
                    'Definir Senha',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4B78),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _senhaDefinida
                        ? 'Senha definida com sucesso! Você será redirecionado.'
                        : 'Crie uma senha para sua nova conta CloudTrack',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 25),

                  if (!_senhaDefinida)
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _novaSenhaController,
                            obscureText: _obscure1,
                            decoration: InputDecoration(
                              labelText: 'Nova senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure1
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscure1 = !_obscure1),
                              ),
                            ),
                            validator: _validarSenha,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _confirmarSenhaController,
                            obscureText: _obscure2,
                            decoration: InputDecoration(
                              labelText: 'Confirmar senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure2
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscure2 = !_obscure2),
                              ),
                            ),
                            validator: _validarConfirmacao,
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : () => _definirSenha(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A4B78),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Salvar Senha',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Column(
                      children: [
                        SizedBox(height: 15),
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0A4B78)),
                        ),
                        SizedBox(height: 15),
                        Text('Redirecionando...',
                            style:
                                TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Rodapé
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
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

  @override
  void dispose() {
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }
}
