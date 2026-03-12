import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home.dart';
import 'configuracoes/escolher_senha.dart';
import 'configuracoes/redefinir_senha.dart';

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

    final uri = Uri.base.toString();

    // 🧩 Se for link de recuperação (contém #access_token&type=recovery)
    if (uri.contains('type=recovery')) {
      // 🔒 Evita qualquer navegação concorrente
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RedefinirSenhaPage()),
        (route) => false,
      );
      return; // 🚫 Impede o restante do código de rodar
    }

    // 🔐 Verificação normal de sessão
    final session = supabase.auth.currentSession;

    if (session == null) {
      _irParaLogin();
      return;
    }

    // ⚙️ Tenta atualizar a sessão
    final refresh = await supabase.auth.refreshSession();

    if (refresh.session == null) {
      _irParaLogin();
      return;
    }

    // 🕒 Verifica validade da sessão (24h)
    final dataLogin = DateTime.parse(session.user.createdAt);
    final limite = DateTime.now().subtract(const Duration(hours: 24));
    if (dataLogin.isBefore(limite)) {
      await supabase.auth.signOut();
      _irParaLogin();
      return;
    }

    // 🔐 Verifica se o usuário ainda tem senha provisória
    final usuario = await supabase
        .from('usuarios')
        .select('senha_temporaria')
        .eq('email', session.user.email ?? '')
        .maybeSingle();

    if (usuario != null && usuario['senha_temporaria'] == true) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EscolherSenhaPage()),
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  void _irParaLogin() {
    if (!mounted) return;
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
          image: AssetImage('assets/logo_top_login20.png'),
          width: 200,
        ),
      ),
    );
  }
}
