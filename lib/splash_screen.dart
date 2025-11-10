import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home.dart';
import 'configuracoes/escolher_senha.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    await Future.delayed(const Duration(seconds: 2)); // efeito visual do splash

    final session = supabase.auth.currentSession;

    if (session == null) {
      // Nenhuma sessão salva → login obrigatório
      _irParaLogin();
      return;
    }

    // ⚙️ Verifica se a sessão é válida no servidor
    final refresh = await supabase.auth.refreshSession();

    // Se falhou ou expirou → login obrigatório
    if (refresh.session == null) {
      _irParaLogin();
      return;
    }

    // 🕒 Verifica se o login tem mais de 1 dia
    final dataLogin = DateTime.parse(session.user.createdAt);
    final limite = DateTime.now().subtract(const Duration(hours: 24));
    if (dataLogin.isBefore(limite)) {
      await supabase.auth.signOut(); // força novo login
      _irParaLogin();
      return;
    }

    // 🔐 Se ainda tem senha provisória, obriga definir nova
    final usuario = await supabase
        .from('usuarios')
        .select('senha_temporaria')
        .eq('id', session.user.id)
        .maybeSingle();

    if (usuario != null && usuario['senha_temporaria'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EscolherSenhaPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  void _irParaLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(
          image: AssetImage('assets/logo_top_login.png'),
          width: 200,
        ),
      ),
    );
  }
}
