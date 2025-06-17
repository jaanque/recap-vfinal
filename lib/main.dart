import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar Supabase - Reemplaza con tus credenciales
  await Supabase.initialize(
    url: 'https://xbuwjnamosymttdzdnrw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhidXdqbmFtb3N5bXR0ZHpkbnJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNjM1ODQsImV4cCI6MjA2NTczOTU4NH0.Fp2D2TJ-iN24cHALAsyeurAxhWMp9T21imirhIWhjHI',
  );
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
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

  @override
  void initState() {
    super.initState();
    _getInitialSession();
    _listenToAuthChanges();
  }

  void _getInitialSession() {
    setState(() {
      _session = Supabase.instance.client.auth.currentSession;
      _isLoading = false;
    });
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _session = data.session;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _session != null ? const HomeScreen() : const AuthScreen();
  }
}