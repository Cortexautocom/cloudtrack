import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Credenciais embutidas (apenas para desenvolvimento)
  const String embeddedSupabaseUrl =
      'https://ikaxzlpaihdkqyjqrxyw.supabase.co';
  const String embeddedSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlrYXh6bHBhaWhka3F5anFyeHl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MjkxNzAsImV4cCI6MjA3NzEwNTE3MH0.s9bx_3YDw3M9SozXCBRu22vZe8DJoXR9p-dyVeEH5K4';

  late final String supabaseUrl;
  late final String supabaseAnonKey;

  if (kIsWeb) {
    // 🌐 Web → usa as credenciais embutidas
    supabaseUrl = embeddedSupabaseUrl;
    supabaseAnonKey = embeddedSupabaseAnonKey;
  } else {
    // 📱 Mobile/Desktop → tenta carregar .env, senão usa embutido
    await dotenv.load(fileName: ".env");
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? embeddedSupabaseUrl;
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? embeddedSupabaseAnonKey;
  }
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CloudTrack',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }
}
