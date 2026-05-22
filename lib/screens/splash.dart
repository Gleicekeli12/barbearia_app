import 'package:flutter/material.dart';
import 'auth_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  bool _navegou = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _iniciar();
  }

  Future<void> _iniciar() async {
    await _controller.forward();

    // 🔥 tempo mínimo de splash para dar tempo do Firebase responder
    await Future.delayed(const Duration(milliseconds: 1000));

    _irProximo();
  }

  void _irProximo() {
    if (!mounted || _navegou) return;

    _navegou = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget linhaDecorativa() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.amber.withOpacity(0.25)),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.star_rounded,
          color: Colors.amber.withOpacity(0.85),
          size: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: Colors.amber.withOpacity(0.25)),
        ),
      ],
    );
  }

  Widget logoDinamica({required String logoUrl}) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
      ),
      child: logoUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: logoUrl,

                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    strokeCap: StrokeCap.round,
                    color: Colors.amber,
                    strokeWidth: 2,
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.content_cut,
                  size: 70,
                  color: Colors.amber,
                ),
              ),
            )
          : const Icon(Icons.content_cut, size: 70, color: Colors.amber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF050505),
              Color(0xFF111111),
              Color(0xFF1B1B1B),
              Color(0xFF262626),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('configuracoes')
                          .doc('app')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final dados = snapshot.data?.data() ?? {};

                        final logoUrl = dados['logoUrl']?.toString() ?? '';

                        return logoDinamica(logoUrl: logoUrl);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
