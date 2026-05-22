import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'agendamento.dart';
import 'planos.dart';
import 'meus_agendamentos.dart';
import 'categoria_servicos_page.dart';
import 'minha_assinatura.dart';
import 'login.dart';
import '../widgets/sininho_notificacoes.dart';

class ServicosPage extends StatefulWidget {
  const ServicosPage({super.key});

  @override
  State<ServicosPage> createState() => _ServicosPageState();
}

class _ServicosPageState extends State<ServicosPage> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _appConfigStream;
  @override
  void initState() {
    super.initState();
    _appConfigStream = FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('app')
        .snapshots();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _usuarioStream = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots();

      _verificarCadastroCompleto(user.uid);
    }

    _categoriasStream = FirebaseFirestore.instance
        .collection('categorias_servicos')
        .where('ativo', isEqualTo: true)
        .orderBy('ordem')
        .snapshots();
  }

  Future<void> _verificarCadastroCompleto(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();

    final dados = doc.data() ?? {};
    final nomeCompleto = (dados['nomeCompleto'] ?? dados['nome'] ?? '')
        .toString()
        .trim();

    final partesNome = nomeCompleto
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    final cadastroCompleto = dados['cadastroCompleto'] == true;

    if (!mounted) return;

    if (!cadastroCompleto || partesNome.length < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          mostrarDialogCompletarCadastro(context);
        }
      });
    }
  }

  void mostrarDialogCompletarCadastro(BuildContext context) {
    final nomeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete seu cadastro'),
          content: TextField(
            controller: nomeController,
            decoration: const InputDecoration(labelText: 'Nome completo'),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();

                final partes = nome
                    .split(' ')
                    .where((p) => p.trim().isNotEmpty)
                    .toList();

                if (partes.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Digite nome e sobrenome'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;

                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(user!.uid)
                    .update({
                      'nome': nome,
                      'nomeCompleto': nome,
                      'nomeBusca': nome.toLowerCase(),
                      'cadastroCompleto': true,
                    });

                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _usuarioStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;
Future<void> _sair(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Sair da conta',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Deseja realmente sair?',
        style: TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );

  if (confirmar != true) return;

  try {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro ao sair: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  IconData iconeCategoriaPorNome(String nome) {
    final n = nome.toLowerCase();

    if (n.contains('corte')) {
      return Icons.content_cut_rounded; // ✂️
    }

    if (n.contains('barba')) {
      return Icons.face_6_rounded; // 👤 barba
    }

    if (n.contains('sobrancelha')) {
      return Icons.visibility_rounded; // 👁️
    }

    if (n.contains('coloracao') ||
        n.contains('coloração') ||
        n.contains('cor')) {
      return Icons.brush_rounded; //  melhor pra coloração
    }

    return Icons.content_cut_rounded;
  }

  Widget _botao({
    required BuildContext context,
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          SininhoNotificacoes(userId: user.uid),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => _sair(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _categoriasStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Erro ao carregar categorias',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            }

            final categoriasTodas = snapshot.data?.docs ?? [];

            return FutureBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>
            >(
              future: () async {
                final categoriasFiltradas =
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                for (final categoria in categoriasTodas) {
                  final possuiServicos = await FirebaseFirestore.instance
                      .collection('servicos')
                      .where('categoriaId', isEqualTo: categoria.id)
                      .where('ativo', isEqualTo: true)
                      .limit(1)
                      .get();

                  if (possuiServicos.docs.isNotEmpty) {
                    categoriasFiltradas.add(categoria);
                  }
                }

                return categoriasFiltradas;
              }(),
              builder: (context, categoriasSnapshot) {
                if (!categoriasSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                final categorias = categoriasSnapshot.data ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _usuarioStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Olá...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Olá 👋',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          final dados = snapshot.data!.data() ?? {};
                          final nome = dados['nome'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Olá, $nome 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: _appConfigStream,
                              builder: (context, snapshot) {
                                final dados = snapshot.data?.data() ?? {};
                                final logoUrl =
                                    dados['logoUrl']?.toString() ?? '';
                                final nomeBarbearia =
                                    dados['nomeBarbearia']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? dados['nomeBarbearia'].toString()
                                    : "BARBEIRO'S";

                                final subtituloBarbearia =
                                    dados['subtituloBarbearia']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? dados['subtituloBarbearia'].toString()
                                    : "BARBEARIA";

                                final sloganBarbearia =
                                    dados['sloganBarbearia']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? dados['sloganBarbearia'].toString()
                                    : 'Estilo • Confiança • Atitude';

                                return Column(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.amber.withOpacity(0.4),
                                          width: 2,
                                        ),
                                        color: Colors.amber.withOpacity(0.08),
                                      ),
                                      child: logoUrl.isNotEmpty
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: logoUrl,

                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.amber,
                                                            ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => const Icon(
                                                      Icons.content_cut_rounded,
                                                      size: 45,
                                                      color: Colors.amber,
                                                    ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.content_cut_rounded,
                                              size: 45,
                                              color: Colors.amber,
                                            ),
                                    ),

                                    const SizedBox(height: 16),
                                    Text(
                                      nomeBarbearia,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtituloBarbearia,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 16,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      sloganBarbearia,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _botao(
                        context: context,
                        icon: Icons.calendar_month_rounded,
                        titulo: 'Agendar Horário',
                        subtitulo: 'Escolha o serviço e horário',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AgendamentoPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _botao(
                        context: context,
                        icon: Icons.assignment_rounded,
                        titulo: 'Meus Agendamentos',
                        subtitulo: 'Acompanhe seus horários',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MeusAgendamentosPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _botao(
                        context: context,
                        icon: Icons.workspace_premium_rounded,
                        titulo: 'Ver Planos',
                        subtitulo: 'Conheça nossos planos',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlanosPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _botao(
                        context: context,
                        icon: Icons.workspace_premium_rounded,
                        titulo: 'Ver Minha Assinatura',
                        subtitulo: 'Gerencie seu plano',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MinhaAssinaturaPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Nossos Serviços',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (categorias.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: const Text(
                            'Nenhuma categoria encontrada',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categorias.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                          itemBuilder: (context, index) {
                            final categoriaDoc = categorias[index];
                            final dados = categoriaDoc.data();

                            final categoriaId = categoriaDoc.id;
                            final categoriaNome =
                                dados['nome']?.toString().trim().isNotEmpty ==
                                    true
                                ? dados['nome'].toString().trim()
                                : 'Categoria';
                            final imagemUrl =
                                dados['imagemUrl']?.toString() ?? '';

                            final icone = iconeCategoriaPorNome(categoriaNome);

                            return Container(
                              key: ValueKey(categoriaId),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CategoriaServicosPage(
                                        categoriaId: categoriaId,
                                        categoriaNome: categoriaNome,
                                        icone: icone,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.05),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: imagemUrl.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                child: CachedNetworkImage(
                                                  imageUrl: imagemUrl,

                                                  width: 64,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                        child: SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors
                                                                    .amber,
                                                              ),
                                                        ),
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Icon(
                                                            icone,
                                                            color: Colors.amber,
                                                            size: 36,
                                                          ),
                                                ),
                                              )
                                            : Icon(
                                                icone,
                                                color: Colors.amber,
                                                size: 36,
                                              ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        categoriaNome,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
