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
    _setupAuthListener();
    _checkInitialDeepLink();
  }

  // Apenas para depuração — não obrigatório
  void _checkInitialDeepLink() {
    print('🔍 Verificando se há deep link inicial...');
  }

  // Ouve eventos de autenticação (login, logout, recuperação, etc.)
  // NO MyApp, modifique o _setupAuthListener():
  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print('🔐 Auth Event detectado: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        print('🟡 Fluxo de recuperação detectado via Supabase.');
        _redirectToResetPassword();
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        final fragment = Uri.base.fragment;
        if (fragment.contains('type=recovery')) {
          print('🔵 Sessão de recuperação ativa — indo pra tela de redefinição.');
          _redirectToResetPassword();
        } else {
          print('🟢 Login normal detectado — verificando senha temporária.');
          
          // ✅ VERIFICAR SENHA TEMPORÁRIA AQUI
          final supabase = Supabase.instance.client;
          final userData = await supabase
              .from('usuarios')
              .select('senha_temporaria')
              .eq('id', session.user.id)
              .maybeSingle();
              
          if (userData != null && userData['senha_temporaria'] == true) {
            print('🔐 Redirecionando para troca de senha');
            _redirectToEscolherSenha();
          } else {
            print('🔐 Redirecionando para home');
            _redirectToHome();
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        print('🚪 Usuário deslogado — voltando pra Login.');
        _redirectToLogin();
      }
    });
  }

  // ADICIONAR este método:
  void _redirectToEscolherSenha() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/escolher-senha', (route) => false);
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
        '/reset-password': (context) => const RedefinirSenhaPage(),
        '/escolher-senha': (context) => const EscolherSenhaPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Session? _session;
  bool _isRecoveryFlow = false;

  @override
  void initState() {
    super.initState();
    _checkUrlAndSession();
  }

  // 🔍 Verifica fragmento da URL (#access_token=...&type=recovery)
  Future<void> _checkUrlAndSession() async {
    try {
      final supabase = Supabase.instance.client;

      final currentUrl = Uri.base.toString();
      print('🔗 URL atual: $currentUrl');

      final isRecovery = currentUrl.contains('type=recovery') ||
          currentUrl.contains('/reset-password');

      setState(() {
        _isRecoveryFlow = isRecovery;
        _session = supabase.auth.currentSession;
        _isLoading = false;
      });

      // Se for um link de recuperação, redireciona
      if (isRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/redefinir-senha', (route) => false);
        });
      } else if (_session != null) {
        // ✅ NOVA VERIFICAÇÃO: Se usuário logado tem senha temporária
        await _verificarSenhaTemporaria();
      }
    } catch (error) {
      print('Erro ao verificar sessão/URL: $error');
      setState(() => _isLoading = false);
    }
  }

  // ✅ NOVO MÉTODO: Verifica se usuário precisa trocar senha
  Future<void> _verificarSenhaTemporaria() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = _session!.user.id;

      final userData = await supabase
          .from('usuarios')
          .select('senha_temporaria')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null && userData['senha_temporaria'] == true) {
        print('🔐 Usuário com senha temporária - redirecionando para troca de senha');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/escolher-senha', (route) => false);
        });
      } else {
        print('🔐 Usuário com senha definitiva - redirecionando para home');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        });
      }
    } catch (error) {
      print('❌ Erro ao verificar senha temporária: $error');
      // Em caso de erro, redireciona para home por segurança
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🚫 Se for link de recuperação, força ir pra redefinição
    if (_isRecoveryFlow) {
      return const RedefinirSenhaPage();
    }

    // 🔓 Caso normal - AuthWrapper decide baseado na verificação assíncrona
    // A navegação é tratada nos métodos acima, então mostramos loading
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Verificando acesso...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}