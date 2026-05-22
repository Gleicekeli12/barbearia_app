import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeusAgendamentosPage extends StatefulWidget {
  final String? destaqueId;
  final int abaInicial;

  const MeusAgendamentosPage({super.key, this.destaqueId, this.abaInicial = 0});

  @override
  State<MeusAgendamentosPage> createState() => _MeusAgendamentosPageState();
}

class _MeusAgendamentosPageState extends State<MeusAgendamentosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, GlobalKey> cardKeys = {};

  int antecedenciaCancelarHoras = 2;
  bool carregandoConfig = true;

  User? get user => FirebaseAuth.instance.currentUser;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.abaInicial,
    );
    carregarAntecedenciaCancelamento();
  }

  Future<void> carregarAntecedenciaCancelamento() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('funcionamento')
          .get();

      final data = doc.data();

      if (data != null && data['antecedenciaCancelarHoras'] is num) {
        antecedenciaCancelarHoras = (data['antecedenciaCancelarHoras'] as num)
            .toInt();
      }
    } catch (_) {
      antecedenciaCancelarHoras = 2;
    } finally {
      if (mounted) {
        setState(() => carregandoConfig = false);
      }
    }
  }

  String formatarData(dynamic data) {
    if (data is! Timestamp) return '--/--/----';
    final d = data.toDate();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Color getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'concluido':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'nao_compareceu':
        return Colors.orange;
      case 'agendado':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String getTextoStatus(String status) {
    switch (status.toLowerCase()) {
      case 'concluido':
        return 'Concluído';
      case 'cancelado':
        return 'Cancelado';
      case 'nao_compareceu':
        return 'Não compareceu';
      case 'agendado':
        return 'Agendado';
      default:
        return 'Status';
    }
  }

  DateTime? montarDataHoraAgendamento(Map<String, dynamic> data) {
    final dataHoraCampo = data['dataHora'];

    if (dataHoraCampo is Timestamp) {
      return dataHoraCampo.toDate().toLocal();
    }

    final dataCampo = data['data'];
    final horaCampo = data['hora']?.toString() ?? '';

    if (dataCampo is! Timestamp || horaCampo.isEmpty) return null;

    final base = dataCampo.toDate().toLocal();
    final partes = horaCampo.split(':');

    if (partes.length != 2) return null;

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);

    if (hora == null || minuto == null) return null;

    return DateTime(base.year, base.month, base.day, hora, minuto);
  }

  bool podeCancelarComHoras(Map<String, dynamic> data, int antecedenciaHoras) {
    final horario = montarDataHoraAgendamento(data);
    if (horario == null) return false;

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'agendado') return false;

    final limiteParaCancelar = horario.subtract(
      Duration(hours: antecedenciaHoras),
    );

    final agora = DateTime.now();

    return agora.isBefore(limiteParaCancelar) ||
        agora.isAtSameMomentAs(limiteParaCancelar);
  }

  String montarTextoCanceladoPor(Map<String, dynamic> data) {
    final canceladoPor = data['canceladoPor']?.toString() ?? '';
    final canceladoPorNome = data['canceladoPorNome']?.toString() ?? '';

    if (canceladoPorNome.isNotEmpty) {
      return 'Cancelado por: $canceladoPorNome';
    }

    if (canceladoPor == 'cliente') return 'Cancelado por: Cliente';
    if (canceladoPor == 'admin') return 'Cancelado por: Admin';

    return 'Cancelado';
  }

  Future<String> buscarNomeClienteAtual() async {
    try {
      final usuarioAtual = user;
      if (usuarioAtual == null) return 'Cliente';

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioAtual.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final nome = data['nome']?.toString().trim() ?? '';
        if (nome.isNotEmpty) return nome;
      }

      return 'Cliente';
    } catch (_) {
      return 'Cliente';
    }
  }

  Future<void> cancelarAgendamento(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Cancelar agendamento',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja cancelar?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final nomeCliente = await buscarNomeClienteAtual();

      final agendamentoDoc = await FirebaseFirestore.instance
          .collection('agendamentos')
          .doc(id)
          .get();

      final dadosAgendamento = agendamentoDoc.data() ?? {};

      final barbeiroCancelado = dadosAgendamento['barbeiro']?.toString() ?? '';
      final horaCancelada = dadosAgendamento['hora']?.toString() ?? '';
      final dataCancelada =
          dadosAgendamento['dataHora'] ?? dadosAgendamento['data'];

      final dataFormatada = dataCancelada is Timestamp
          ? '${dataCancelada.toDate().day.toString().padLeft(2, '0')}/'
                '${dataCancelada.toDate().month.toString().padLeft(2, '0')}/'
                '${dataCancelada.toDate().year}'
          : '';

      await FirebaseFirestore.instance
          .collection('agendamentos')
          .doc(id)
          .update({
            'status': 'cancelado',
            'canceladoPor': 'cliente',
            'canceladoPorNome': nomeCliente,
            'canceladoEm': FieldValue.serverTimestamp(),
            'atualizadoEm': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance.collection('notificacoes').add({
        'userId': 'admin',
        'tipo': 'cliente_cancelou',
        'destino': 'agendamentos_admin',
        'titulo': 'Agendamento cancelado',
        'mensagem':
            '$nomeCliente cancelou com $barbeiroCancelado às $horaCancelada no dia $dataFormatada.',
        'referenciaId': id,
        'lida': false,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento cancelado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao cancelar agendamento';

      if (e.toString().contains('permission-denied')) {
        mensagem = 'Sem permissão para cancelar este agendamento';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
  }

  Widget cardAgendamento(Map<String, dynamic> data, String id) {
    final status = (data['status'] ?? 'agendado').toString();
    final statusLower = status.toLowerCase();
    final servico = data['servico']?.toString().trim() ?? '';
    final barbeiro = data['barbeiro']?.toString().trim() ?? '';
    final hora = data['hora']?.toString().trim() ?? '';
    final preco = ((data['preco'] ?? 0) as num).toDouble();

    final precoFormatado = preco.toStringAsFixed(2).replaceAll('.', ',');
    final destaque = widget.destaqueId == id;

    final cardKey = cardKeys.putIfAbsent(id, () => GlobalKey());

    if (destaque) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = cardKeys[id]?.currentContext;
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destaque
            ? Colors.amber.withOpacity(0.18)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: destaque
              ? Colors.amber.withOpacity(0.75)
              : Colors.white.withOpacity(0.08),
          width: destaque ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            servico.isEmpty
                ? 'Serviço não informado'
                : '$servico • R\$ $precoFormatado',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Barbeiro: ${barbeiro.isEmpty ? 'Não informado' : barbeiro}',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          Text(
            'Data: ${formatarData(data['dataHora'] ?? data['data'])}',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          Text(
            'Hora: ${hora.isEmpty ? '--:--' : hora}',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: getCorStatus(status).withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: getCorStatus(status).withOpacity(0.35)),
            ),
            child: Text(
              getTextoStatus(status),
              style: TextStyle(
                color: getCorStatus(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (statusLower == 'cancelado') ...[
            const SizedBox(height: 10),
            Text(
              montarTextoCanceladoPor(data),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
          if (statusLower == 'agendado') ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final podeCancelar = podeCancelarComHoras(
                  data,
                  antecedenciaCancelarHoras,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atenção: cancelamentos devem ser realizados com no mínimo $antecedenciaCancelarHoras hora(s) de antecedência.',
                      style: TextStyle(
                        color: Colors.amber.shade300,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: podeCancelar
                            ? () => cancelarAgendamento(id)
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: podeCancelar
                              ? Colors.redAccent
                              : Colors.grey,
                          side: BorderSide(
                            color: podeCancelar
                                ? Colors.redAccent
                                : Colors.grey,
                          ),
                        ),
                        child: Text(
                          podeCancelar
                              ? 'Cancelar'
                              : 'Cancelamento indisponível',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget listaAgendamentos(bool somenteAtivos) {
    final usuarioAtual = user;

    if (usuarioAtual == null) {
      return const Center(
        child: Text(
          'Usuário não logado',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agendamentos')
          .where('userId', isEqualTo: usuarioAtual.uid)
          .where(
            'status',
            whereIn: somenteAtivos
                ? ['agendado']
                : ['cancelado', 'concluido', 'nao_compareceu'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar dados',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }

        final lista = snapshot.data?.docs ?? [];

        lista.sort((a, b) {
          final da = montarDataHoraAgendamento(a.data()) ?? DateTime(1900);
          final db = montarDataHoraAgendamento(b.data()) ?? DateTime(1900);
          return somenteAtivos ? da.compareTo(db) : db.compareTo(da);
        });

        if (lista.isEmpty) {
          return Center(
            child: Text(
              somenteAtivos ? 'Nenhum agendamento futuro' : 'Nenhum histórico',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        grupos = {};

        for (final doc in lista) {
          final dados = doc.data();

          final barbeiro =
              dados['barbeiro']?.toString().trim().isNotEmpty == true
              ? dados['barbeiro'].toString().trim()
              : 'Sem barbeiro';

          grupos.putIfAbsent(barbeiro, () => []);
          grupos[barbeiro]!.add(doc);
        }

        final barbeirosOrdenados = grupos.keys.toList()..sort();

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: barbeirosOrdenados.expand((barbeiro) {
            final listaBarbeiro = grupos[barbeiro] ?? [];

            listaBarbeiro.sort((a, b) {
              final da = montarDataHoraAgendamento(a.data()) ?? DateTime(1900);
              final db = montarDataHoraAgendamento(b.data()) ?? DateTime(1900);
              return somenteAtivos ? da.compareTo(db) : db.compareTo(da);
            });

            return [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Text(
                  barbeiro,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...listaBarbeiro.map(
                (doc) => cardAgendamento(doc.data(), doc.id),
              ),
              const SizedBox(height: 12),
            ];
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (carregandoConfig) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Agendamentos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Próximos'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF111111),
        child: TabBarView(
          controller: _tabController,
          children: [listaAgendamentos(true), listaAgendamentos(false)],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
