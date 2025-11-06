import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CadastroNovoUsuarioPage extends StatefulWidget {
  const CadastroNovoUsuarioPage({super.key});

  @override
  State<CadastroNovoUsuarioPage> createState() =>
      _CadastroNovoUsuarioPageState();
}

class _CadastroNovoUsuarioPageState extends State<CadastroNovoUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Controladores dos campos
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final celularController = TextEditingController();
  final funcaoController = TextEditingController();

  // Filiais
  List<Map<String, dynamic>> filiais = [];
  String? filialSelecionadaNome;
  String? filialSelecionadaId;
  bool carregandoFiliais = true;
  bool _salvando = false;

  // Máscara de telefone (99) 9 9999-9999
  final maskTelefone = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _carregarFiliais();
  }

  // 🔹 Carrega filiais do Supabase
  Future<void> _carregarFiliais() async {
    try {
      final response =
          await supabase.from('filiais').select('id, nome').order('nome');

      // ✅ Garante que é uma lista de mapas
      setState(() {
        filiais = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("❌ Erro ao carregar filiais: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao carregar filiais: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => carregandoFiliais = false);
    }
  }

  // 🔹 Envia a solicitação de cadastro
  Future<void> _enviarCadastro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final nome = nomeController.text.trim();
      final email = emailController.text.trim();
      final celular = celularController.text.trim();
      final funcao = funcaoController.text.trim();

      // 1️⃣ Verifica se já existe um cadastro pendente
      final existe = await supabase
          .from('cadastros_pendentes')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existe != null) {
        throw Exception(
            "Já existe uma solicitação de cadastro pendente para este e-mail.");
      }

      // 2️⃣ Insere o novo cadastro
      await supabase.from('cadastros_pendentes').insert({
        'nome': nome,
        'email': email,
        'celular': celular,
        'funcao': funcao,
        'id_filial': filialSelecionadaId,
        'status': 'pendente',
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text("Solicitação enviada"),
            content: const Text(
              "Seu cadastro foi enviado para análise.\n\n"
              "Você receberá um e-mail assim que for aprovado.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fecha o diálogo
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Erro ao enviar cadastro: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

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

          // ===== Logo (mesma posição que na página de login) =====
          Positioned(
            top: 80,
            left: 80,
            child: Image.asset('assets/logo_top_login.png'),
          ),

          // ===== Conteúdo principal =====
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Solicitação de cadastro",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A4B78),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Nome completo
                      TextFormField(
                        controller: nomeController,
                        decoration: _inputDecoration("Nome completo"),
                        validator: (v) => v == null || v.isEmpty
                            ? "Informe seu nome completo"
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // E-mail
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: _inputDecoration("E-mail"),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Informe o e-mail";
                          }
                          final emailValido =
                              RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailValido.hasMatch(v)) {
                            return "E-mail inválido";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Celular
                      TextFormField(
                        controller: celularController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [maskTelefone],
                        decoration: _inputDecoration("Celular (com WhatsApp)"),
                      ),
                      const SizedBox(height: 20),

                      // Função / Cargo
                      TextFormField(
                        controller: funcaoController,
                        decoration: _inputDecoration("Função / Cargo"),
                      ),
                      const SizedBox(height: 20),

                      // Filial (lista real)
                      if (carregandoFiliais)
                        const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF0A4B78)))
                      else
                        DropdownButtonFormField<String>(
                          value: filialSelecionadaNome,
                          decoration: _inputDecoration("Filial"),
                          items: filiais.map((f) {
                            return DropdownMenuItem<String>(
                              value: f['nome'],
                              child: Text(f['nome']),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            setState(() {
                              filialSelecionadaNome = valor;
                              filialSelecionadaId = filiais.firstWhere(
                                (f) => f['nome'] == valor,
                                orElse: () => {'id': null},
                              )['id']?.toString();
                            });
                          },
                        ),
                      const SizedBox(height: 30),

                      // Botão enviar
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _salvando ? null : _enviarCadastro,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A4B78),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _salvando
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Solicitar cadastro",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Voltar para login
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                            );
                          },
                          child: const Text(
                            "Voltar ao login",
                            style: TextStyle(color: Color(0xFF0A4B78)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===== Rodapé (mesmo que na página de login) =====
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }
}