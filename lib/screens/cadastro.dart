import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool loadingCadastro = false;
  bool loadingGoogle = false;
  bool obscureSenha = true;
  bool obscureConfirmarSenha = true;

  bool get algumLoading => loadingCadastro || loadingGoogle;

  int get forcaSenha {
    final senha = senhaController.text;
    int forca = 0;

    if (senha.length >= 8) forca++;
    if (RegExp(r'[A-Z]').hasMatch(senha)) forca++;
    if (RegExp(r'[a-z]').hasMatch(senha)) forca++;
    if (RegExp(r'\d').hasMatch(senha)) forca++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(senha)) forca++;

    return forca;
  }

  String get textoForcaSenha {
    if (senhaController.text.isEmpty) return 'Digite uma senha';

    switch (forcaSenha) {
      case 1:
        return 'Senha fraca';
      case 2:
        return 'Senha média';
      case 3:
        return 'Senha boa';
      case 4:
        return 'Senha muito boa';
      case 5:
        return 'Senha forte';
      default:
        return 'Senha fraca';
    }
  }

  Color get corForcaSenha {
    if (senhaController.text.isEmpty) return Colors.grey;

    switch (forcaSenha) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.blue;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void mostrarMensagem(String mensagem, Color cor) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  Future<void> cadastrarComGoogle() async {
    if (algumLoading) return;

    setState(() => loadingGoogle = true);

    try {
      UserCredential userCredential;
      String emailGoogle = '';

      if (kIsWeb) {
        final provider = GoogleAuthProvider();

        provider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);

        emailGoogle = (userCredential.user?.email ?? '').trim().toLowerCase();
      } else {
        final googleSignIn = GoogleSignIn();

        await googleSignIn.signOut();
        await FirebaseAuth.instance.signOut();

        final googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          if (mounted) setState(() => loadingGoogle = false);
          return;
        }

        final googleAuth = await googleUser.authentication;

        emailGoogle = googleUser.email.trim().toLowerCase();

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final user = userCredential.user;

      if (user == null || emailGoogle.isEmpty) {
        throw Exception('Não foi possível acessar a conta Google.');
      }

      final userRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid);

      final doc = await userRef.get();

      if (doc.exists) {
        await FirebaseAuth.instance.signOut();

        try {
          await GoogleSignIn().signOut();
        } catch (_) {}

        mostrarMensagem(
          'Essa conta Google já está cadastrada. Faça login.',
          Colors.orange,
        );

        return;
      }

      final nomeGoogle = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Cliente';

      final partesNomeGoogle = nomeGoogle
          .split(' ')
          .where((parte) => parte.trim().isNotEmpty)
          .toList();

      await userRef.set({
        'nome': nomeGoogle,
        'nomeCompleto': nomeGoogle,
        'nomeBusca': nomeGoogle.toLowerCase().trim(),
        'email': emailGoogle,
        'tipo': 'cliente',
        'cadastroCompleto': partesNomeGoogle.length >= 2,
        'criadoEm': Timestamp.now(),
        'loginProvider': 'google',
      });

      await FirebaseAuth.instance.signOut();

      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      if (!mounted) return;

      mostrarMensagem(
        'Cadastro com Google realizado. Faça login.',
        Colors.green,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }

      mostrarMensagem(
        'Erro ao cadastrar com Google: ${e.message ?? e.code}',
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro ao cadastrar com Google: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => loadingGoogle = false);
      }
    }
  }

  Future<void> cadastrar() async {
    if (algumLoading) return;

    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final nomeBusca = nome.toLowerCase().trim();
    final partesNome = nome
        .split(' ')
        .where((parte) => parte.trim().isNotEmpty)
        .toList();

    if (partesNome.length < 2) {
      mostrarMensagem('Digite nome e sobrenome', Colors.red);
      return;
    }

    final email = emailController.text.trim().toLowerCase();
    final senha = senhaController.text.trim();
    final confirmarSenha = confirmarSenhaController.text.trim();

    if (nome.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      mostrarMensagem('Preencha todos os campos', Colors.red);
      return;
    }

    final regexEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    if (!regexEmail.hasMatch(email)) {
      mostrarMensagem('Digite um email válido', Colors.red);
      return;
    }

    if (senha != confirmarSenha) {
      mostrarMensagem('As senhas não coincidem', Colors.red);
      return;
    }

    final regexSenha = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$',
    );

    if (!regexSenha.hasMatch(senha)) {
      mostrarMensagem(
        'A senha deve conter:\n- mínimo 8 caracteres\n- 1 letra maiúscula\n- 1 letra minúscula\n- 1 número\n- 1 símbolo',
        Colors.red,
      );
      return;
    }

    // 🔥 VERIFICA SE EMAIL JÁ EXISTE (inclusive Google)
    final metodos = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
      email,
    );

    if (metodos.isNotEmpty) {
      mostrarMensagem('Esse email já está cadastrado. Faça login.', Colors.red);

      setState(() => loadingCadastro = false);
      return;
    }

    setState(() => loadingCadastro = true);

    User? usuarioCriado;

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: senha);

      usuarioCriado = userCredential.user;

      if (usuarioCriado == null) {
        throw Exception('Erro ao criar usuário');
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioCriado.uid)
          .set({
            'nome': nome,
            'nomeCompleto': nome,
            'nomeBusca': nomeBusca,
            'email': email,
            'tipo': 'cliente',
            'cadastroCompleto': true,
            'criadoEm': Timestamp.now(),
            'loginProvider': 'email',
          });

      await usuarioCriado.sendEmailVerification();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      mostrarMensagem(
        'Conta criada! Verifique seu email antes de entrar.',
        Colors.green,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao cadastrar';

      if (e.code == 'email-already-in-use') {
        mensagem = 'Esse email já está cadastrado. Faça login.';
      } else if (e.code == 'weak-password') {
        mensagem = 'Senha muito fraca';
      } else if (e.code == 'invalid-email') {
        mensagem = 'Email inválido';
      } else if (e.code == 'network-request-failed') {
        mensagem = 'Sem conexão com a internet';
      } else if (e.code == 'too-many-requests') {
        mensagem = 'Muitas tentativas. Tente novamente mais tarde';
      }

      mostrarMensagem(mensagem, Colors.red);
    } catch (_) {
      final uid = usuarioCriado?.uid;

      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get();

          if (doc.exists) {
            await doc.reference.delete();
          }
        } catch (_) {}
      }

      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      mostrarMensagem(
        'Não foi possível finalizar o cadastro. Verifique sua conexão e tente novamente.',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => loadingCadastro = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade300),
      prefixIcon: Icon(icon, color: Colors.amber),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 1.4),
      ),
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF1A1A1A), Color(0xFF3A3A3A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.amber,
                        size: 56,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Criar sua conta',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cadastre-se para agendar horários com praticidade',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade300,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      TextField(
                        controller: nomeController,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.next,
                        enabled: !algumLoading,
                        decoration: _inputDecoration(
                          label: 'Nome completo',
                          icon: Icons.person_outline,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        enabled: !algumLoading,
                        decoration: _inputDecoration(
                          label: 'Email',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: senhaController,
                        obscureText: obscureSenha,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        enabled: !algumLoading,
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDecoration(
                          label: 'Senha',
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            onPressed: algumLoading
                                ? null
                                : () {
                                    setState(() {
                                      obscureSenha = !obscureSenha;
                                    });
                                  },
                            icon: Icon(
                              obscureSenha
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: forcaSenha / 5,
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                corForcaSenha,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            textoForcaSenha,
                            style: TextStyle(
                              color: corForcaSenha,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use no mínimo 8 caracteres, 1 letra maiúscula, 1 letra minúscula, 1 número e 1 símbolo.',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      TextField(
                        controller: confirmarSenhaController,
                        obscureText: obscureConfirmarSenha,
                        textInputAction: TextInputAction.done,
                        enabled: !algumLoading,
                        onSubmitted: (_) {
                          if (!algumLoading) cadastrar();
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          label: 'Confirmar senha',
                          icon: Icons.lock_reset_outlined,
                          suffixIcon: IconButton(
                            onPressed: algumLoading
                                ? null
                                : () {
                                    setState(() {
                                      obscureConfirmarSenha =
                                          !obscureConfirmarSenha;
                                    });
                                  },
                            icon: Icon(
                              obscureConfirmarSenha
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: algumLoading ? null : cadastrar,
                          child: loadingCadastro
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Criar Conta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(child: Divider(color: Colors.white24)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'ou',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white24)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: algumLoading ? null : cadastrarComGoogle,
                          icon: loadingGoogle
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text(
                            'Cadastrar com Google',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: algumLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Já tem conta? Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
