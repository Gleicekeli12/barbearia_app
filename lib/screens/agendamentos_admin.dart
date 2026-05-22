import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

class AgendamentosAdminPage extends StatefulWidget {
  final String? destaqueId;
  final int abaInicial;

  const AgendamentosAdminPage({
    super.key,
    this.destaqueId,
    this.abaInicial = 0,
  });

  @override
  State<AgendamentosAdminPage> createState() => _AgendamentosAdminPageState();
}

class _AgendamentosAdminPageState extends State<AgendamentosAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StreamSubscription _tempoSub;
  final Map<String, GlobalKey> cardKeys = {};

  DateTime agoraServidor = DateTime.now();

  final List<String> statusTabs = const [
    'agendado',
    'cancelado',
    'concluido',
    'nao_compareceu',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: statusTabs.length,
      vsync: this,
      initialIndex: widget.abaInicial,
    );
    _tempoSub = FirebaseFirestore.instance
        .collection('controle_tempo')
        .doc('agora')
        .snapshots()
        .listen((doc) {
          final ts = doc.data()?['dataHora'];
          if (ts is Timestamp && mounted) {
            setState(() {
              agoraServidor = ts.toDate().toLocal();
            });
          }
        });
  }

  @override
  void dispose() {
    _tempoSub.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cancelado':
        return Colors.red;
      case 'concluido':
        return Colors.green;
      case 'nao_compareceu':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'cancelado':
        return 'Cancelado';
      case 'concluido':
        return 'Concluído';
      case 'nao_compareceu':
        return 'Não compareceu';
      default:
        return 'Agendado';
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'cancelado':
        return Icons.cancel_outlined;
      case 'concluido':
        return Icons.task_alt_rounded;
      case 'nao_compareceu':
        return Icons.person_off_rounded;
      default:
        return Icons.calendar_month_rounded;
    }
  }

  String formatarData(dynamic valor) {
    if (valor is Timestamp) {
      final data = valor.toDate();
      return '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}/'
          '${data.year}';
    }
    return '--/--/----';
  }

  DateTime? montarDataHoraAgendamento(Map<String, dynamic> data) {
    final dataHoraCampo = data['dataHora'];

    if (dataHoraCampo is Timestamp) {
      return dataHoraCampo.toDate();
    }

    final dataCampo = data['data'];
    final horaCampo = data['hora']?.toString() ?? '';

    if (dataCampo is! Timestamp || horaCampo.isEmpty) return null;

    final base = dataCampo.toDate();
    final partes = horaCampo.split(':');

    if (partes.length != 2) return null;

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);

    if (hora == null || minuto == null) return null;

    return DateTime(base.year, base.month, base.day, hora, minuto);
  }

  bool podeCancelar(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'agendado') return false;

    final dataHora = montarDataHoraAgendamento(data);
    if (dataHora == null) return false;

    final agora = agoraServidor;

    // Admin só pode cancelar até 5 minutos antes do horário marcado
    final limiteCancelamento = dataHora.subtract(const Duration(minutes: 5));

    return agora.isBefore(limiteCancelamento);
  }

  bool podeConcluir(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'agendado') return false;

    final dataHora = montarDataHoraAgendamento(data);
    if (dataHora == null) return false;

    final liberarEm = dataHora.add(const Duration(minutes: 15));
    final agora = agoraServidor;

    return agora.isAfter(liberarEm) || agora.isAtSameMomentAs(liberarEm);
  }

  Future<String> buscarNomeAdminAtual() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Admin';

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final nome = doc.data()!['nome']?.toString().trim() ?? '';
        if (nome.isNotEmpty) return nome;
      }

      return 'Admin';
    } catch (_) {
      return 'Admin';
    }
  }

  Future<void> atualizarStatusPelaFunction({
    required BuildContext context,
    required String agendamentoId,
    required String acao,
    required String mensagemSucesso,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'atualizarStatusAgendamentoAdmin',
      );

      await callable.call({'agendamentoId': agendamentoId, 'acao': acao});

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemSucesso), backgroundColor: Colors.green),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Erro ao atualizar agendamento'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao atualizar agendamento'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> marcarNaoCompareceu(BuildContext context, String id) async {
    await atualizarStatusPelaFunction(
      context: context,
      agendamentoId: id,
      acao: 'nao_compareceu',
      mensagemSucesso: 'Marcado como não compareceu',
    );
  }

  Future<void> concluirAgendamento(BuildContext context, String id) async {
    await atualizarStatusPelaFunction(
      context: context,
      agendamentoId: id,
      acao: 'concluido',
      mensagemSucesso: 'Agendamento concluído',
    );
  }

  Future<void> cancelarComoAdmin(BuildContext context, String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Cancelar agendamento',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Deseja cancelar este agendamento?',
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

    await atualizarStatusPelaFunction(
      context: context,
      agendamentoId: id,
      acao: 'cancelado',
      mensagemSucesso: 'Agendamento cancelado',
    );
  }

  Widget _chipStatus(String status) {
    final cor = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(getStatusIcon(status), size: 16, color: cor),
          const SizedBox(width: 6),
          Text(
            getStatusLabel(status),
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoesAdmin(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dados = doc.data();
    final status = (dados['status'] ?? '').toString().toLowerCase();

    if (status == 'agendado') {
      final podeCancelarAgora = podeCancelar(dados);
      final podeConcluirAgora = podeConcluir(dados);

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          // 🔴 CANCELAR (somente antes do horário)
          if (podeCancelarAgora)
            OutlinedButton.icon(
              onPressed: () => cancelarComoAdmin(context, doc.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar'),
            ),

          // 🟢 CONCLUIR (após 15 min)
          if (podeConcluirAgora)
            ElevatedButton.icon(
              onPressed: () => concluirAgendamento(context, doc.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Concluir'),
            ),

          // 🟠 NÃO COMPARECEU (após 15 min)
          if (podeConcluirAgora)
            ElevatedButton.icon(
              onPressed: () => marcarNaoCompareceu(context, doc.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_off_rounded),
              label: const Text('Não compareceu'),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _cardAgendamento(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final cliente = data['cliente']?.toString().trim() ?? '---';
    final servico = data['servico']?.toString().trim() ?? '---';
    final preco = ((data['preco'] ?? 0) as num).toDouble();

    final precoFormatado = preco.toStringAsFixed(2).replaceAll('.', ',');
    final barbeiro = data['barbeiro']?.toString().trim() ?? '---';
    final hora = data['hora']?.toString().trim() ?? '--:--';
    final status = data['status']?.toString().toLowerCase() ?? 'agendado';
    final dataFormatada = formatarData(data['data']);
    final canceladoPorNome = data['canceladoPorNome']?.toString() ?? '';
    final destaque = widget.destaqueId == doc.id;

    final cardKey = cardKeys.putIfAbsent(doc.id, () => GlobalKey());

    if (destaque) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = cardKeys[doc.id]?.currentContext;
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
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: destaque
              ? [Colors.amber.withOpacity(0.22), Colors.amber.withOpacity(0.08)]
              : [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: destaque
              ? Colors.amber.withOpacity(0.75)
              : Colors.white.withOpacity(0.08),
          width: destaque ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cliente.isEmpty ? 'Cliente' : cliente,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              _chipStatus(status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Serviço: $servico • R\$ $precoFormatado',
            style: TextStyle(
              color: Colors.grey.shade200,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Barbeiro: $barbeiro',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Data: $dataFormatada',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Hora: $hora',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          ),
          if (status == 'cancelado' && canceladoPorNome.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Cancelado por: $canceladoPorNome',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
          if (status == 'agendado' && !podeConcluir(data)) ...[
            const SizedBox(height: 8),
            Text(
              'O agendamento poderá ser concluído ou marcado como não compareceu a partir de 15min após o horário marcado.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          _acoesAdmin(context, doc),
        ],
      ),
    );
  }

  Widget _listaPorStatus(String statusFiltro) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agendamentos')
          .where('status', isEqualTo: statusFiltro)
          .orderBy('dataHora')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar agendamentos',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }

        final agendamentos = snapshot.data?.docs ?? [];

        if (agendamentos.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    getStatusIcon(statusFiltro),
                    size: 42,
                    color: getStatusColor(statusFiltro),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum agendamento ${getStatusLabel(statusFiltro).toLowerCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        grupos = {};

        for (final doc in agendamentos) {
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
          padding: const EdgeInsets.all(16),
          children: barbeirosOrdenados.expand((barbeiro) {
            final listaBarbeiro = grupos[barbeiro] ?? [];

            listaBarbeiro.sort((a, b) {
              final ta = montarDataHoraAgendamento(a.data()) ?? DateTime(1900);
              final tb = montarDataHoraAgendamento(b.data()) ?? DateTime(1900);
              return ta.compareTo(tb);
            });

            return [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Text(
                  barbeiro,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...listaBarbeiro.map((doc) => _cardAgendamento(context, doc)),
              const SizedBox(height: 12),
            ];
          }).toList(),
        );
      },
    );
  }

  Widget _tabTitulo(String status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agendamentos')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        final total = snapshot.data?.docs.length ?? 0;

        return Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(getStatusLabel(status)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: getStatusColor(status).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    color: getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Agendamentos'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: statusTabs.map(_tabTitulo).toList(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF141414), Color(0xFF242424)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: statusTabs.map(_listaPorStatus).toList(),
          ),
        ),
      ),
    );
  }
}
