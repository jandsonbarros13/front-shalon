import 'package:flutter/material.dart';
import 'package:acaiteria_front/views/cliente/catalogo_cliente_page.dart';
import 'package:acaiteria_front/views/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Açaiteria Shalom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';

        if (name.startsWith('/catalogo/')) {
          final partes = name.split('/');
          if (partes.length >= 3 && partes[2].isNotEmpty) {
            final chaveUrl = Uri.decodeComponent(partes[2]);
            return MaterialPageRoute(
              builder: (context) => CatalogoClientePage(chaveUrl: chaveUrl),
              settings: settings,
            );
          }
        }
        
        return MaterialPageRoute(
          builder: (context) => LoginScreen(),
          settings: settings,
        );
      },
    );
  }
}