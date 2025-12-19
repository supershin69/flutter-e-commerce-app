import 'package:e_commerce_frontend/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mxngcloeolzkfnauioln.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14bmdjbG9lb2x6a2ZuYXVpb2xuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU5NDk2NDcsImV4cCI6MjA4MTUyNTY0N30.-4mju9Eyce84EB_SodaOhAK9vIunJbuXuvuukXfr99g',
  );

  debugPrint('Supabase initialized: '
    '${Supabase.instance.client.auth.currentSession}');


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage()
    );
  }
}

