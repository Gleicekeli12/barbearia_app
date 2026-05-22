import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AssinaturasPlanosAdminPage extends StatefulWidget {
  final String? destaqueId;
  final int abaInicial;

  const AssinaturasPlanosAdminPage({
    super.key,
    this.destaqueId,
    this.abaInicial = 0,
  });

  @override
  State<AssinaturasPlanosAdminPage> createState() =>
      _AssinaturasPlanosAdminPageState();
}

class _AssinaturasPlanosAdminPageState extends State<AssinaturasPlanosAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, GlobalKey> cardKeys = {};

  final tabs = ['Pendentes', 'Ativas', 'Cancelamento agendado', 'Canceladas'];

  @override
  void initState() {
    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: widget.abaInicial,
    );
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color corStatus(String status) {
    switch (status) {
      case 'aguardando_aprovacao_admin':
        return Colors.amber;

      case 'ativa':
        return Colors.green;

      case 'cancelamento_agendado':
        return Colors.orange;

      case 'cancelada':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  String formatarData(Timestamp? data) {
    if (data == null) return '-';
    final d = data.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }
    return '0,00';
  }

  bool filtrarPorTab(int index, String status) {
    if (index == 0) {
      return status == 'aguardando_aprovacao_admin';
    }

    if (index == 1) {
      return status == 'ativa';
    }

    if (index == 2) {
      return status == 'cancelamento_agendado';
    }

    if (index == 3) {
      return status == 'cancelada';
    }

    return false;
  }

  Widget cardAssinatura(String docId, Map<String, dynamic> dados) {
    final nome = dados['cliente']?.toString() ?? '';
    final plano = dados['planoNome']?.toString() ?? '';
    final preco = dados['planoPreco'] ?? 0;
    final status = dados['status']?.toString() ?? '';
    final email = dados['email']?.toString() ?? '';
    final ativadoEm = dados['ativadoEm'] as Timestamp?;
    final reativadoEm = dados['reativadoEm'] as Timestamp?;
    final beneficioTexto = dados['beneficioAteTexto']?.toString() ?? '';

    final expiraEm =
        dados['proximaCobrancaEm'] as Timestamp? ??
        (beneficioTexto.isNotEmpty
            ? Timestamp.fromDate(
                DateTime.tryParse(beneficioTexto) ?? DateTime.now(),
              )
            : null);
    final destaque = widget.destaqueId == docId;

    final cardKey = cardKeys.putIfAbsent(docId, () => GlobalKey());

    if (destaque) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = cardKeys[docId]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.15,
          );
        }
      });
    }

    return Container(
      key: cardKey,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destaque ? Colors.amber.withOpacity(0.18) : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: destaque
              ? Colors.amber.withOpacity(0.7)
              : Colors.white.withOpacity(0.06),
          width: destaque ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome + status
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: corStatus(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status == 'aguardando_aprovacao_admin'
                      ? 'PENDENTE'
                      : status == 'ativa'
                      ? 'ATIVA'
                      : status == 'cancelamento_agendado'
                      ? 'CANCELAMENTO AGENDADO'
                      : 'CANCELADA',
                  style: TextStyle(
                    color: corStatus(status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            email.isEmpty ? 'E-mail não informado' : email,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),

          const SizedBox(height: 6),

          Text(plano, style: const TextStyle(color: Colors.white70)),

          const SizedBox(height: 6),

          Text(
            'R\$ ${formatarPreco(preco)}',
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Divider(height: 20),

          Text(
            status == 'aguardando_aprovacao_admin'
                ? 'Cliente informou pagamento. Verifique no PagBank antes de ativar.'
                : status == 'ativa'
                ? 'Pagamento aprovado'
                : status == 'cancelamento_agendado'
                ? 'Renovação cancelada (ativo até o vencimento)'
                : 'Cancelado',
            style: TextStyle(
              color: status == 'ativa' ? Colors.green : Colors.white70,
            ),
          ),

          const SizedBox(height: 4),

          if (status == 'ativa') ...[
            Text(
              'Ativa em: ${formatarData(ativadoEm)}',
              style: const TextStyle(color: Colors.grey),
            ),

            if (reativadoEm != null)
              Text(
                'Reativada em: ${formatarData(reativadoEm)}',
                style: const TextStyle(color: Colors.grey),
              ),

            Text(
              'Próxima cobrança: ${formatarData(expiraEm)}',
              style: const TextStyle(color: Colors.orange),
            ),
          ] else if (status == 'cancelamento_agendado') ...[
            Text(
              'Cancelamento solicitado em: ${formatarData(dados['canceladoEm'])}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Ativo até: ${formatarData(expiraEm)}',
              style: const TextStyle(color: Colors.orange),
            ),
          ] else if (status == 'cancelada') ...[
            Text(
              'Encerrado em: ${formatarData(dados['encerradoEm'] ?? dados['canceladoEm'])}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        if (status == 'aguardando_aprovacao_admin') ...[
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final callable = FirebaseFunctions.instance.httpsCallable(
                      'ativarAssinaturaPagBankAdmin',
                    );

                    await callable.call({'assinaturaId': docId});

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assinatura ativada com sucesso'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } on FirebaseFunctionsException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.message ?? 'Erro ao ativar assinatura',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao ativar assinatura: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('ATIVAR ASSINATURA'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Assinaturas'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) {
            return Tab(child: Text(t, style: const TextStyle(fontSize: 13)));
          }).toList(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('assinaturas_planos')
            .orderBy('criadoEm', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return TabBarView(
            controller: _tabController,
            children: List.generate(tabs.length, (index) {
              final filtrados = docs.where((doc) {
                final status = doc.data()['status']?.toString() ?? '';
                return filtrarPorTab(index, status);
              }).toList();

              if (filtrados.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma assinatura',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtrados.length,
                itemBuilder: (context, i) {
                  return cardAssinatura(filtrados[i].id, filtrados[i].data());
                },
              );
            }),
          );
        },
      ),
    );
  }
}
