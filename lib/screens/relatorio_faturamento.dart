import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RelatorioFaturamentoPage extends StatefulWidget {
  const RelatorioFaturamentoPage({super.key});

  @override
  State<RelatorioFaturamentoPage> createState() =>
      _RelatorioFaturamentoPageState();
}

class _RelatorioFaturamentoPageState extends State<RelatorioFaturamentoPage> {
  DateTime mesSelecionado = DateTime.now();

  String formatarPreco(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    if (mes < 1 || mes > 12) return '';
    return meses[mes - 1];
  }

  DateTime get inicioMes {
    return DateTime(mesSelecionado.year, mesSelecionado.month, 1);
  }

  DateTime get fimMes {
    return DateTime(mesSelecionado.year, mesSelecionado.month + 1, 1);
  }

  void mesAnterior() {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month - 1,
        1,
      );
    });
  }

  void proximoMes() {
    setState(() {
      mesSelecionado = DateTime(
        mesSelecionado.year,
        mesSelecionado.month + 1,
        1,
      );
    });
  }

  Widget cardResumo({
    required String titulo,
    required String valor,
    required IconData icone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icone, color: Colors.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget cardBarbeiro({
    required String nome,
    required double total,
    required int quantidade,
  }) {
    final ticketMedio = quantidade == 0 ? 0.0 : total / quantidade;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.content_cut_rounded, color: Colors.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Faturamento: R\$ ${formatarPreco(total)}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Atendimentos: $quantidade',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ticket médio: R\$ ${formatarPreco(ticketMedio)}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Faturamento'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF050505), Color(0xFF141414), Color(0xFF242424)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('agendamentos')
                  .where('status', isEqualTo: 'concluido')
                  .where(
                    'dataHora',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes),
                  )
                  .where('dataHora', isLessThan: Timestamp.fromDate(fimMes))
                  .orderBy('dataHora')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar faturamento',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                double totalMes = 0;
                int totalAtendimentos = 0;

                final Map<String, double> totalPorBarbeiro = {};
                final Map<String, int> qtdPorBarbeiro = {};

                for (final doc in docs) {
                  final data = doc.data();
                  final dataHora = data['dataHora'];
                  if (dataHora is! Timestamp) continue;

                  totalAtendimentos++;

                  final barbeiro =
                      data['barbeiro']?.toString().trim().isNotEmpty == true
                      ? data['barbeiro'].toString().trim()
                      : 'Sem barbeiro';

                  final valor = data['preco'] is num
                      ? (data['preco'] as num).toDouble()
                      : 0.0;

                  totalMes += valor;

                  totalPorBarbeiro[barbeiro] =
                      (totalPorBarbeiro[barbeiro] ?? 0) + valor;

                  qtdPorBarbeiro[barbeiro] =
                      (qtdPorBarbeiro[barbeiro] ?? 0) + 1;
                }

                final ticketMedio = totalAtendimentos == 0
                    ? 0.0
                    : totalMes / totalAtendimentos;

                final barbeirosOrdenados = totalPorBarbeiro.keys.toList()
                  ..sort((a, b) {
                    return totalPorBarbeiro[b]!.compareTo(totalPorBarbeiro[a]!);
                  });

                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: mesAnterior,
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.amber,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${nomeMes(mesSelecionado.month)} ${mesSelecionado.year}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: proximoMes,
                              icon: const Icon(
                                Icons.chevron_right,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      cardResumo(
                        titulo: 'Faturamento do mês',
                        valor: 'R\$ ${formatarPreco(totalMes)}',
                        icone: Icons.attach_money_rounded,
                      ),
                      cardResumo(
                        titulo: 'Atendimentos concluídos',
                        valor: '$totalAtendimentos',
                        icone: Icons.task_alt_rounded,
                      ),
                      cardResumo(
                        titulo: 'Ticket médio',
                        valor: 'R\$ ${formatarPreco(ticketMedio)}',
                        icone: Icons.trending_up_rounded,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Faturamento por barbeiro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (barbeirosOrdenados.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: const Text(
                            'Nenhum atendimento concluído neste mês.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else
                        ...barbeirosOrdenados.asMap().entries.map((entry) {
                          final index = entry.key;
                          final barbeiro = entry.value;

                          return Container(
                            key: ValueKey(barbeiro),
                            child: cardBarbeiro(
                              nome: '${index + 1}. $barbeiro',
                              total: totalPorBarbeiro[barbeiro] ?? 0,
                              quantidade: qtdPorBarbeiro[barbeiro] ?? 0,
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
