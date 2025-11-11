import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EsqueciSenhaPage extends StatefulWidget {
  const EsqueciSenhaPage({super.key});

  @override
  State<EsqueciSenhaPage> createState() => _EsqueciSenhaPageState();
}

class _EsqueciSenhaPageState extends State<EsqueciSenhaPage> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  // ======= Função de recuperação de senha =======
  Future<void> _recuperarSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      // 🔹 Chama a Edge Function personalizada para envio via Resend
      final url = Uri.parse(
        'https://ikaxzlpaihdkqyjqrxyw.functions.supabase.co/redefinir-senha',
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        setState(() => _emailSent = true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link de recuperação enviado para $email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Falha ao enviar o e-mail.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $error'),
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
          // ===== Fundo (mesmo do login) =====
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

          // ===== Botão Voltar =====
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
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
                  
                  // ===== Ícone =====
                  Icon(
                    _emailSent ? Icons.check_circle_outline : Icons.lock_reset_outlined,
                    size: 64,
                    color: const Color(0xFF0A4B78),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // ===== Título =====
                  Text(
                    _emailSent ? 'Email Enviado!' : 'Recuperar Senha',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4B78),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // ===== Descrição =====
                  Text(
                    _emailSent 
                      ? 'Enviamos um link de recuperação para seu email. Verifique sua caixa de entrada e pasta de spam.'
                      : 'Digite seu email para receber um link de recuperação de senha',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 30),

                  if (!_emailSent) ...[
                    // ===== Formulário de email =====
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, digite seu email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Digite um email válido';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 25),

                    // ===== Botão Enviar Link =====
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
                        onPressed: _isLoading ? null : _recuperarSenha,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Enviar Link de Recuperação',
                                style: TextStyle(
                                  fontSize: 16, 
                                  color: Colors.white
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    // ===== Botão Voltar para Login =====
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Voltar para Login',
                          style: TextStyle(
                            fontSize: 16, 
                            color: Colors.white
                          ),
                        ),
                      ),
                    ),

                    // ===== Botão Reenviar =====
                    const SizedBox(height: 15),
                    
                    TextButton(
                      onPressed: _isLoading ? null : _recuperarSenha,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Reenviar link',
                              style: TextStyle(
                                color: Color(0xFF0A4B78),
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  
                  // ===== Informação adicional =====
                  if (!_emailSent)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Após clicar no link do email, você será redirecionado para redefinir sua senha.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ===== Rodapé (mesmo do login) =====
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}