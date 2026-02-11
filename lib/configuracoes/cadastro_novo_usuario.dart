import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_page.dart';
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

  // Controladores dos campos - INICIALIZADOS DIRETAMENTE
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController nomeApelidoController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController funcaoController = TextEditingController();

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

  @override
  void dispose() {
    // 🔹 IMPORTANTE: Limpar todos os controladores
    nomeController.dispose();
    nomeApelidoController.dispose();
    emailController.dispose();
    celularController.dispose();
    funcaoController.dispose();
    super.dispose();
  }

  // 🔹 Carrega filiais do Supabase
  Future<void> _carregarFiliais() async {
    try {
      final response =
          await supabase.from('filiais').select('id, nome').order('nome');

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

  // 🔹 Envia a solicitação de cadastro - CÓDIGO CORRIGIDO
  Future<void> _enviarCadastro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      // 🔹 CAPTURA OS VALORES DE FORMA SEGURA
      final nome = nomeController.text.trim();
      final nomeApelido = nomeApelidoController.text.trim();
      final email = emailController.text.trim();
      final celular = celularController.text.trim();
      final funcao = funcaoController.text.trim();

      debugPrint("📝 Dados capturados:");
      debugPrint("Nome: $nome");
      debugPrint("Nome Apelido: $nomeApelido");
      debugPrint("Email: $email");
      debugPrint("Celular: $celular");
      debugPrint("Função: $funcao");
      debugPrint("Filial ID: $filialSelecionadaId");

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

      // 2️⃣ Prepara os dados para inserção
      final dadosCadastro = {
        'nome': nome,
        'email': email,
        'celular': celular,
        'funcao': funcao,
        'id_filial': filialSelecionadaId,
        'status': 'pendente',
      };

      // ✅ Adiciona nome_apelido apenas se não estiver vazio
      if (nomeApelido.isNotEmpty) {
        dadosCadastro['nome_apelido'] = nomeApelido;
      }

      // 3️⃣ Insere o novo cadastro
      await supabase.from('cadastros_pendentes').insert(dadosCadastro);

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
                  Navigator.pop(context);
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

          // ===== Logo =====
          Positioned(
            top: 80,
            left: 80,
            child: InkWell(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: Image.asset('assets/logo_top_login.png'),
            ),
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
                      const SizedBox(height: 16),

                      // Como gostaria de ser chamado? (NOVO CAMPO)
                      TextFormField(
                        controller: nomeApelidoController,
                        decoration: _inputDecoration("Como gostaria de ser chamado?")                            
                      ),
                      const SizedBox(height: 16),

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
                      const SizedBox(height: 16),

                      // Celular
                      TextFormField(
                        controller: celularController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [maskTelefone],
                        decoration: _inputDecoration("Celular (com WhatsApp)"),
                      ),
                      const SizedBox(height: 16),

                      // Função / Cargo
                      TextFormField(
                        controller: funcaoController,
                        decoration: _inputDecoration("Função / Cargo"),
                      ),
                      const SizedBox(height: 16),

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
                      const SizedBox(height: 25),

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
                      const SizedBox(height: 16),

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
                    'PowerTank Terminais 2026, All rights reserved.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© Norton Tecnology - 550 California St, W-325, San Francisco, CA - EUA.',
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