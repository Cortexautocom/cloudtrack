import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Pequeno delay para mostrar o splash
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    
    if (!mounted) return;
    
    if (session != null) {
      // ✅ Usuário JÁ ESTÁ LOGADO - Verifica se precisa trocar senha
      await _verificarSenhaTemporaria(session.user.id);
    } else {
      // ❌ Usuário NÃO LOGADO - Vai para login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ✅ NOVO: Verifica se usuário precisa trocar senha
  Future<void> _verificarSenhaTemporaria(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      final userData = await supabase
          .from('usuarios')
          .select('senha_temporaria')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null && userData['senha_temporaria'] == true) {
        // 🔐 PRECISA TROCAR SENHA
        Navigator.pushReplacementNamed(context, '/escolher-senha');
      } else {
        // 🏠 PODE IR PARA HOME
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (error) {
      // ⚠️ EM CASO DE ERRO, VAI PARA HOME POR SEGURANÇA
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo_top_login.png', width: 200),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A4B78)),
            ),
            const SizedBox(height: 20),
            const Text(
              'CloudTrack',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A4B78),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Carregando...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}