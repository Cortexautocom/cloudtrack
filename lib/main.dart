import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_strategy/url_strategy.dart';
import 'configuracoes/escolher_senha.dart';
import 'login_page.dart';
import 'home.dart';
import 'configuracoes/esqueci_senha.dart';
import 'configuracoes/redefinir_senha.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove o # das URLs no Flutter Web
  setPathUrlStrategy();

  const String supabaseUrl = 'https://ikaxzlpaihdkqyjqrxyw.supabase.co';
  const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlrYXh6bHBhaWhka3F5anFyeHl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MjkxNzAsImV4cCI6MjA3NzEwNTE3MH0.s9bx_3YDw3M9SozXCBRu22vZe8DJoXR9p-dyVeEH5K4';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener(); // Ativa o monitor de eventos do Supabase
  }

  // Ouve eventos de autenticação (login, logout, recuperação, etc.)
  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print('🔐 Evento de autenticação detectado: $event');
      final uri = Uri.base.toString();
      final isRecoveryLink = uri.contains('type=recovery');

      // 🔸 Evita conflito de múltiplos redirecionamentos
      if (isRecoveryLink) {
        print('🟡 Modo recuperação ativo — ignorando demais eventos.');
        return;
      }

      if (event == AuthChangeEvent.passwordRecovery) {
        print('🟡 Link de recuperação detectado — indo para redefinição de senha');
        _redirectToResetPassword();
        return;
      }

      if (event == AuthChangeEvent.signedIn && session != null) {
        final fragment = Uri.base.fragment;
        if (fragment.contains('type=recovery')) {
          print('🔵 Sessão de recuperação ativa — indo para tela de redefinição.');
          _redirectToResetPassword();
          return;
        } else {
          print('🟢 Login normal — verificando senha temporária...');
          await _verificarSenhaTemporaria(session.user.id);
          return;
        }
      }

      if (event == AuthChangeEvent.signedOut) {
        print('🚪 Usuário deslogado — voltando para login.');
        _redirectToLogin();
        return;
      }
    });
  }


  // Verifica se o usuário precisa trocar uma senha temporária
  Future<void> _verificarSenhaTemporaria(String userId) async {
    final supabase = Supabase.instance.client;
    final dados = await supabase
        .from('usuarios')
        .select('senha_temporaria')
        .eq('id', userId)
        .maybeSingle();

    if (dados != null && dados['senha_temporaria'] == true) {
      print('🔐 Usuário com senha temporária — redirecionando.');
      _redirectToEscolherSenha();
    } else {
      print('✅ Senha definitiva — indo para Home.');
      _redirectToHome();
    }
  }

  void _redirectToEscolherSenha() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/escolher-senha', (route) => false);
    });
  }

  void _redirectToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    });
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    });
  }

  void _redirectToResetPassword() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/redefinir-senha', (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CloudTrack',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/esqueci-senha': (context) => const EsqueciSenhaPage(),
        '/redefinir-senha': (context) => const RedefinirSenhaPage(),
        '/escolher-senha': (context) => const EscolherSenhaPage(),
      },
    );
  }
}