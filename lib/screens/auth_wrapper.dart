import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login.dart';
import 'servicos.dart';
import 'admin.dart';
import '../main.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<Widget> _proximaTela;

  @override
  void initState() {
    super.initState();
    _proximaTela = _verificarUsuario();
  }

  Widget _loading() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.amber)),
    );
  }

  Future<Widget> _verificarUsuario() async {
    try {
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;

      if (user == null) {
        return const LoginPage();
      }

      await user.reload();
      user = auth.currentUser;

      if (user == null) {
        return const LoginPage();
      }

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await auth.signOut();
        return const LoginPage();
      }

      final dados = doc.data()!;
      final tipo = (dados['tipo'] ?? 'cliente').toString().trim().toLowerCase();

      if (tipo == 'admin') {
        try {
          await configurarPushNotifications();
        } catch (_) {}
        return const AdminPage();
      }

      if (!user.emailVerified) {
        await auth.signOut();
        return const LoginPage(
          mensagemInicial: 'Verifique seu e-mail antes de entrar.',
        );
      }

      try {
        await configurarPushNotifications();
      } catch (_) {}

      return const ServicosPage();
    } catch (e) {
      final erro = e.toString().toLowerCase();

      final semInternet =
          erro.contains('network') ||
          erro.contains('unavailable') ||
          erro.contains('host') ||
          erro.contains('socket') ||
          erro.contains('internet') ||
          erro.contains('offline');

      if (semInternet) {
        return const LoginPage(
          mensagemInicial:
              'Sem conexão com a internet. Conecte-se para entrar no aplicativo.',
        );
      }

      await FirebaseAuth.instance.signOut();

      return const LoginPage(
        mensagemInicial: 'Erro ao verificar usuário. Tente entrar novamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _proximaTela,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const LoginPage();
        }

        return snapshot.data!;
      },
    );
  }
}
