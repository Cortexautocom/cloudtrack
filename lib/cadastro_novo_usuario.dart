import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';


class CadastroNovoUsuario extends StatefulWidget {
  const CadastroNovoUsuario({super.key});

  @override
  State<CadastroNovoUsuario> createState() => _CadastroNovoUsuarioState();
}

class _CadastroNovoUsuarioState extends State<CadastroNovoUsuario> {
  final _formKey = GlobalKey<FormState>();

  final nomeController = TextEditingController();
  final funcaoController = TextEditingController();
  final celularController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  final mascaraTelefone = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool carregando = false;

  @override
  void dispose() {
    nomeController.dispose();
    funcaoController.dispose();
    celularController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  // 🔹 Função temporária (por enquanto só mostra mensagem)
  void _solicitarCadastro() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Solicitação enviada! Em breve a equipe entrará em contato."),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Volta para a tela de login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🔹 Título
                  const Text(
                    "Solicitar cadastro",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4B78),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Preencha seus dados para solicitar acesso ao sistema.",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // Nome completo
                  TextFormField(
                    controller: nomeController,
                    decoration: _inputDecoration("Nome completo"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Informe o nome completo" : null,
                  ),
                  const SizedBox(height: 20),

                  // Função
                  TextFormField(
                    controller: funcaoController,
                    decoration: _inputDecoration("Função / Cargo"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Informe a função" : null,
                  ),
                  const SizedBox(height: 20),

                  // Celular
                  TextFormField(
                    controller: celularController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [mascaraTelefone], // 🔹 aplica a máscara aqui
                    decoration: _inputDecoration("Celular (com WhatsApp)"),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Informe o celular" : null,
                  ),

                  const SizedBox(height: 20),

                  // Email
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration("E-mail corporativo"),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return "Informe o e-mail";
                      }

                      // Expressão regular para validar e-mails
                      final emailValido = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

                      if (!emailValido.hasMatch(v)) {
                        return "E-mail inválido";
                      }

                      return null; // está tudo certo
                    },
                  ),
                  const SizedBox(height: 20),

                  // Senha
                  TextFormField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: _inputDecoration("Senha de acesso desejada"),
                    validator: (v) => v == null || v.length < 6
                        ? "A senha deve ter pelo menos 6 caracteres"
                        : null,
                  ),
                  const SizedBox(height: 30),

                  // Botão enviar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: carregando ? null : _solicitarCadastro,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        carregando ? "Enviando..." : "Solicitar cadastro",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Voltar
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Voltar ao login",
                      style: TextStyle(color: Color(0xFF0A4B78)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF0A4B78)),
      ),
    );
  }
}
