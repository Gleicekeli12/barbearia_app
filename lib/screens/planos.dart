import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanosPage extends StatefulWidget {
  const PlanosPage({super.key});

  @override
  State<PlanosPage> createState() => _PlanosPageState();
}

class _PlanosPageState extends State<PlanosPage> {
  String? planoCarregandoId;

  String formatarPreco(dynamic valor) {
    if (valor == null) return '0,00';

    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }

    if (valor == null) return '0,00';
    final preco = double.tryParse(valor.toString());
    if (preco == null) return '0,00';

    return preco.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> solicitarAssinatura({
    required BuildContext context,
    required String planoId,
    required Map<String, dynamic> plano,
  }) async {
    if (planoCarregandoId != null) return;

    setState(() => planoCarregandoId = planoId);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Usuário não logado');
      }

      final assinaturaSnapshot = await FirebaseFirestore.instance
          .collection('assinaturas_planos')
          .where('userId', isEqualTo: user.uid)
          .where(
            'status',
            whereIn: [
              'ativa',
              'cancelamento_agendado',
              'aguardando_confirmacao',
              'aguardando_aprovacao_admin',
            ],
          )
          .limit(1)
          .get();

      if (assinaturaSnapshot.docs.isNotEmpty) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já possui uma assinatura ativa.'),
            backgroundColor: Colors.orange,
          ),
        );

        setState(() => planoCarregandoId = null);
        return;
      }

      final linkPagamento = plano['linkPagamento']?.toString().trim() ?? '';

      if (linkPagamento.isEmpty) {
        throw Exception('Link de pagamento não configurado.');
      }

      final linkCorrigido = linkPagamento.startsWith('http')
          ? linkPagamento
          : 'https://$linkPagamento';

      final callable = FirebaseFunctions.instance.httpsCallable(
        'solicitarAssinaturaPagBank',
      );

      await callable.call({
        'planoId': planoId,
        'planoNome': plano['nome'] ?? '',
        'planoDescricao': plano['descricao'] ?? '',
        'planoPreco': plano['preco'] ?? 0,
        'linkPagamento': linkCorrigido,
      });

      final uri = Uri.parse(linkCorrigido);

      final abriu = await launchUrl(uri, mode: LaunchMode.platformDefault);

      if (!abriu) {
        throw Exception('Não foi possível abrir o link.');
      }

      if (!mounted) return;
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => planoCarregandoId = null);
      }
    }
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.18),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.amber.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.16),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.amber,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Escolha seu plano',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assinatura mensal para serviços exclusivos e descontos especiais. \n \n Cancele quando quiser.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planoCard({
    required BuildContext context,
    required String id,
    required Map<String, dynamic> plano,
    required bool bloqueadoPorAssinatura,
  }) {
    final nome = plano['nome']?.toString().trim() ?? '';
    final descricao = plano['descricao']?.toString().trim() ?? '';
    final preco = formatarPreco(plano['preco']);
    final carregando = planoCarregandoId == id;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nome.isEmpty ? 'Plano' : nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (descricao.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              descricao,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withOpacity(0.16)),
            ),
            child: Column(
              children: [
                Text(
                  'R\$ $preco',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Por mês',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: bloqueadoPorAssinatura
                  ? null
                  : planoCarregandoId == null
                  ? () {
                      solicitarAssinatura(
                        context: context,
                        planoId: id,
                        plano: plano,
                      );
                    }
                  : null,
              icon: carregando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.workspace_premium_rounded),
              label: Text(
                bloqueadoPorAssinatura
                    ? 'Plano já solicitado'
                    : carregando
                    ? 'Aguarde...'
                    : 'Assinar agora',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.amber.withOpacity(0.55),
                disabledForegroundColor: Colors.black54,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 48,
              color: Colors.amber.withOpacity(0.9),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhum plano disponível',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Os planos aparecerão aqui em breve.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Planos de Assinatura'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF141414), Color(0xFF242424)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('assinaturas_planos')
                  .where('userId', isEqualTo: user?.uid ?? '')
                  .where(
                    'status',
                    whereIn: [
                      'ativa',
                      'cancelamento_agendado',
                      'aguardando_confirmacao',
                      'aguardando_aprovacao_admin',
                    ],
                  )
                  .limit(1)
                  .snapshots(),
              builder: (context, assinaturaSnapshot) {
                final bloqueadoPorAssinatura =
                    assinaturaSnapshot.data?.docs.isNotEmpty == true;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('planos')
                      .where('ativo', isEqualTo: true)
                      .orderBy('criadoEm', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Erro ao carregar planos',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _emptyState();
                    }

                    final planos = snapshot.data!.docs;

                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: planos.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        if (index == 0) return _header();

                        final doc = planos[index - 1];

                        return Container(
                          key: ValueKey(doc.id),
                          child: _planoCard(
                            context: context,
                            id: doc.id,
                            plano: doc.data(),
                            bloqueadoPorAssinatura: bloqueadoPorAssinatura,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
