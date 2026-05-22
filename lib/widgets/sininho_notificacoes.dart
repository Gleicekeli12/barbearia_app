import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/notificacoes.dart';

class SininhoNotificacoes extends StatefulWidget {
  final String userId;
  final bool admin;

  const SininhoNotificacoes({
    super.key,
    required this.userId,
    this.admin = false,
  });

  @override
  State<SininhoNotificacoes> createState() => _SininhoNotificacoesState();
}

class _SininhoNotificacoesState extends State<SininhoNotificacoes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;
  late Animation<double> _scale;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  int totalNaoLidas = 0;
  bool primeiraLeitura = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.55), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.55, end: 0.55), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.55, end: -0.35), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.35, end: 0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _escutarNotificacoes();
  }

  void _escutarNotificacoes() {
    _subscription = FirebaseFirestore.instance
        .collection('notificacoes')
        .where('userId', isEqualTo: widget.userId)
        .where('lida', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          final novoTotal = snapshot.docs.length;
          final totalAnterior = totalNaoLidas;

          if (mounted) {
            setState(() => totalNaoLidas = novoTotal);
          }

          if (primeiraLeitura) {
            primeiraLeitura = false;
            return;
          }

          if (novoTotal > totalAnterior) {
            _avisarNovaNotificacao();
          }
        });
  }

  void _avisarNovaNotificacao() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: Transform.rotate(angle: _rotation.value, child: child),
              );
            },
            child: Icon(
              totalNaoLidas > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              color: Colors.amber,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificacoesPage(admin: widget.admin),
              ),
            );
          },
        ),
        if (totalNaoLidas > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                totalNaoLidas > 9 ? '9+' : '$totalNaoLidas',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
