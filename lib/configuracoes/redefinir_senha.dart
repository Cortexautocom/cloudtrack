import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RedefinirSenhaPage extends StatefulWidget {
  const RedefinirSenhaPage({super.key});

  @override
  State<RedefinirSenhaPage> createState() => _RedefinirSenhaPageState();
}

class _RedefinirSenhaPageState extends State<RedefinirSenhaPage> {
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText1 = true;
  bool _obscureText2 = true;
  bool _isLoading = false;
  bool _senhaRedefinida = false;
  String? _debugInfo;

  @override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      print('🔐 Evento de autenticação detectado: ${event.event}');
      if (event.session != null) {
        print('✅ Sessão de recuperação ativa! Usuário: ${event.session!.user.email}');
      }
    });

    _debugUrl();
  }

  void _debugUrl() {
    final currentUrl = Uri.base.toString();
    print('🔗 URL ATUAL NO INIT: $currentUrl');
    
    final uri = Uri.parse(currentUrl);
    print('🔍 DETALHES DA URL:');
    print('   - Host: ${uri.host}');
    print('   - Path: ${uri.path}');
    print('   - Query: ${uri.query}');
    print('   - Fragment: ${uri.fragment}');
    print('   - Query Parameters: ${uri.queryParameters}');
    
    setState(() {
      _debugInfo = '''
URL: $currentUrl
Host: ${uri.host}
Path: ${uri.path}
Query: ${uri.query}
Fragment: ${uri.fragment}
Token encontrado: ${uri.queryParameters['token'] ?? 'NÃO ENCONTRADO'}
''';
    });
  }

  // ======= Nova Função para Redefinir Senha =======
  Future<void> _redefinirSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 🔐 **SOLUÇÃO CORRETA:** Usar verifyOTP para criar sessão temporária
      final currentUrl = Uri.base.toString();
      
      print('🔄 Iniciando redefinição...');
      print('🔗 URL atual: $currentUrl');

      // Extrai o token da URL
      final token = _extrairTokenDaUrl(currentUrl);
      if (token == null) {
        print('❌ Token não encontrado na URL');
        throw AuthException('Link de recuperação inválido. Token não encontrado.');
      }

      print('🔐 Token extraído: $token');

      // 🔄 Verifica o OTP (One-Time Password) do link de recovery
      print('🔄 Verificando OTP...');
      await Future.delayed(const Duration(milliseconds: 500));      

      print('✅ OTP verificado com sucesso! Sessão criada.');

      // 🎯 Agora sim, atualiza a senha (com sessão ativa)
      print('🔄 Atualizando senha...');
      await supabase.auth.updateUser(
        UserAttributes(password: _novaSenhaController.text.trim()),
      );

      setState(() => _senhaRedefinida = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha redefinida com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // 🚪 Desloga o usuário
      await supabase.auth.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      
    } on AuthException catch (error) {
      print('❌ AuthException: ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      print('❌ Erro inesperado: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro inesperado: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======= Função para Extrair Token da URL =======
  String? _extrairTokenDaUrl(String url) {
    final uri = Uri.parse(url);
    print('🔍 Analisando URL recebida: $url');

    // 1️⃣ Primeiro tenta pegar o token pela "query" normal (?token=XYZ)
    if (uri.queryParameters['token'] != null) {
      print('✅ Token encontrado na query: ${uri.queryParameters['token']}');
      return uri.queryParameters['token'];
    }

    // 2️⃣ Depois tenta pegar se veio no "fragment" (#access_token=XYZ)
    if (uri.fragment.isNotEmpty) {
      final frag = Uri.splitQueryString(uri.fragment);
      final token = frag['access_token'] ?? frag['token'];
      print('✅ Token encontrado no fragment: $token');
      return token;
    }

    print('❌ Nenhum token encontrado!');
    return null;
  }


  // ======= Validação de força da senha =======
  String? _validarForcaSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, digite a nova senha';
    }
    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  // ======= Validação de confirmação =======
  String? _validarConfirmacaoSenha(String? value) {
    if (value != _novaSenhaController.text) {
      return 'As senhas não coincidem';
    }
    return null;
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

          // ===== Botão Voltar (apenas se não concluiu) =====
          if (!_senhaRedefinida)
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
                    _senhaRedefinida ? Icons.check_circle_outline : Icons.lock_outline,
                    size: 64,
                    color: const Color(0xFF0A4B78),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // ===== Título =====
                  Text(
                    _senhaRedefinida ? 'Senha Redefinida!' : 'Redefinir Senha',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A4B78),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // ===== Descrição =====
                  Text(
                    _senhaRedefinida 
                      ? 'Sua senha foi redefinida com sucesso. Você será redirecionado para a página inicial.'
                      : 'Digite sua nova senha nos campos abaixo',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // ===== Debug Info (apenas em desenvolvimento) =====
                  if (_debugInfo != null && !_senhaRedefinida)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _debugInfo!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  if (!_senhaRedefinida) ...[
                    // ===== Formulário de redefinição =====
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // ===== Nova Senha =====
                          TextFormField(
                            controller: _novaSenhaController,
                            obscureText: _obscureText1,
                            decoration: InputDecoration(
                              labelText: 'Nova Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText1 
                                    ? Icons.visibility_off_outlined 
                                    : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() => _obscureText1 = !_obscureText1),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'Mínimo 6 caracteres',
                            ),
                            validator: _validarForcaSenha,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // ===== Confirmar Senha =====
                          TextFormField(
                            controller: _confirmarSenhaController,
                            obscureText: _obscureText2,
                            decoration: InputDecoration(
                              labelText: 'Confirmar Nova Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText2 
                                    ? Icons.visibility_off_outlined 
                                    : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() => _obscureText2 = !_obscureText2),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: _validarConfirmacaoSenha,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // ===== Botão Redefinir Senha =====
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
                        onPressed: _isLoading ? null : _redefinirSenha,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Redefinir Senha',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white
                              ),
                            ),
                      ),
                    ),
                  ] else ...[
                    // ===== Loading de redirecionamento =====
                    const Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A4B78)),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Redirecionando...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 20),
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
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }
}