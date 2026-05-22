import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfiguracaoFuncionamentoPage extends StatefulWidget {
  const ConfiguracaoFuncionamentoPage({super.key});

  @override
  State<ConfiguracaoFuncionamentoPage> createState() =>
      _ConfiguracaoFuncionamentoPageState();
}

class _ConfiguracaoFuncionamentoPageState
    extends State<ConfiguracaoFuncionamentoPage> {
  String horarioInicio = '09:00';
  String horarioFim = '19:00';
  String intervaloInicio = '12:00';
  String intervaloFim = '13:00';

  int intervaloMinutos = 60;
  int antecedenciaHoras = 1;
  int antecedenciaCancelarHoras = 1;

  bool carregandoDados = false;
  bool salvando = false;
  bool usarIntervalo = false;

  Map<String, bool> diasFuncionamento = {
    'segunda': true,
    'terca': true,
    'quarta': true,
    'quinta': true,
    'sexta': true,
    'sabado': true,
    'domingo': false,
  };

  final List<String> horarios = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
  ];

  final List<int> opcoesAntecedencia = [0, 1, 2, 3, 4, 6, 12, 24];

  @override
  void initState() {
    super.initState();
    carregarConfiguracao();
  }

  Future<void> carregarConfiguracao() async {
    setState(() => carregandoDados = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('funcionamento')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        horarioInicio = data['horarioInicio']?.toString() ?? '09:00';
        horarioFim = data['horarioFim']?.toString() ?? '19:00';

        final intervaloSalvo = data['intervaloMinutos'];
        if (intervaloSalvo == 15 ||
            intervaloSalvo == 30 ||
            intervaloSalvo == 60) {
          intervaloMinutos = intervaloSalvo;
        }

        final ant = data['antecedenciaHoras'];
        if (ant is num) antecedenciaHoras = ant.toInt();

        final antCancel = data['antecedenciaCancelarHoras'];
        if (antCancel is num) antecedenciaCancelarHoras = antCancel.toInt();

        usarIntervalo = data['usarIntervalo'] == true;
        intervaloInicio = data['intervaloInicio']?.toString().isNotEmpty == true
            ? data['intervaloInicio'].toString()
            : '12:00';
        intervaloFim = data['intervaloFim']?.toString().isNotEmpty == true
            ? data['intervaloFim'].toString()
            : '13:00';

        final dias = data['diasFuncionamento'];
        if (dias is Map) {
          diasFuncionamento = {
            'segunda': dias['segunda'] == true,
            'terca': dias['terca'] == true,
            'quarta': dias['quarta'] == true,
            'quinta': dias['quinta'] == true,
            'sexta': dias['sexta'] == true,
            'sabado': dias['sabado'] == true,
            'domingo': dias['domingo'] == true,
          };
        }
      }
    } catch (_) {
      mostrarErro('Erro ao carregar configuração');
    } finally {
      if (mounted) setState(() => carregandoDados = false);
    }
  }

  int converterHorarioParaMinutos(String horario) {
    if (!horario.contains(':')) return 0;
    final partes = horario.split(':');
    final hora = int.parse(partes[0]);
    final minuto = int.parse(partes[1]);
    return hora * 60 + minuto;
  }

  Future<void> salvarConfiguracao() async {
    if (salvando) return;

    final inicioMin = converterHorarioParaMinutos(horarioInicio);
    final fimMin = converterHorarioParaMinutos(horarioFim);

    if (fimMin <= inicioMin) {
      mostrarErro('O horário de término deve ser maior que o início');
      return;
    }

    if (!diasFuncionamento.containsValue(true)) {
      mostrarErro('Selecione pelo menos um dia de funcionamento');
      return;
    }

    if (usarIntervalo) {
      final pausaInicio = converterHorarioParaMinutos(intervaloInicio);
      final pausaFim = converterHorarioParaMinutos(intervaloFim);

      if (pausaFim <= pausaInicio) {
        mostrarErro('O fim da pausa deve ser maior que o início');
        return;
      }

      if (pausaInicio < inicioMin || pausaFim > fimMin) {
        mostrarErro('A pausa precisa estar dentro do horário de funcionamento');
        return;
      }
    }

    setState(() => salvando = true);

    try {
      await FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('funcionamento')
          .set({
            'horarioInicio': horarioInicio,
            'horarioFim': horarioFim,
            'horarioInicioMin': converterHorarioParaMinutos(horarioInicio),
            'horarioFimMin': converterHorarioParaMinutos(horarioFim),
            'intervaloMinutos': intervaloMinutos,
            'antecedenciaHoras': antecedenciaHoras,
            'antecedenciaCancelarHoras': antecedenciaCancelarHoras,
            'diasFuncionamento': diasFuncionamento,
            'usarIntervalo': usarIntervalo,
            'intervaloInicio': usarIntervalo ? intervaloInicio : '',
            'intervaloFim': usarIntervalo ? intervaloFim : '',
            'intervaloInicioMin': usarIntervalo
                ? converterHorarioParaMinutos(intervaloInicio)
                : null,
            'intervaloFimMin': usarIntervalo
                ? converterHorarioParaMinutos(intervaloFim)
                : null,

            'atualizadoEm': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração salva com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String mensagem = 'Erro ao salvar configuração';

      if (e.toString().contains('permission-denied')) {
        mensagem = 'Sem permissão para salvar configuração';
      }

      mostrarErro(mensagem);
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  void mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  InputDecoration decoracao(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade300),
      prefixIcon: Icon(icon, color: Colors.amber),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber),
      ),
    );
  }

  Widget card({
    required String titulo,
    required String subtitulo,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitulo,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget dropdownHorario({
    required String label,
    required IconData icon,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: horarios.contains(value) ? value : horarios.first,
      dropdownColor: const Color(0xFF1E1E1E),
      decoration: decoracao(label, icon),
      style: const TextStyle(color: Colors.white),
      items: horarios.map((h) {
        return DropdownMenuItem<String>(value: h, child: Text(h));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget dropdownInteiro({
    required String label,
    required IconData icon,
    required int value,
    required List<int> opcoes,
    required String Function(int) texto,
    required ValueChanged<int?> onChanged,
  }) {
    final valorSeguro = opcoes.contains(value) ? value : opcoes.first;

    return DropdownButtonFormField<int>(
      value: valorSeguro,
      dropdownColor: const Color(0xFF1E1E1E),
      decoration: decoracao(label, icon),
      style: const TextStyle(color: Colors.white),
      items: opcoes.map((v) {
        return DropdownMenuItem<int>(value: v, child: Text(texto(v)));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget itemDia(String chave, String label) {
    final ativo = diasFuncionamento[chave] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ativo
            ? Colors.amber.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ativo
              ? Colors.amber.withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: SwitchListTile(
        value: ativo,
        onChanged: (value) {
          setState(() {
            diasFuncionamento[chave] = value;
          });
        },
        activeColor: Colors.amber,
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          ativo ? 'Aberto para agendamentos' : 'Fechado',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Funcionamento'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
          child: carregandoDados
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              : SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + teclado),
                  child: Column(
                    children: [
                      card(
                        titulo: 'Horário de funcionamento',
                        subtitulo:
                            'Defina em quais horários a barbearia pode receber agendamentos.',
                        child: Column(
                          children: [
                            dropdownHorario(
                              label: 'Horário de abertura',
                              icon: Icons.schedule_rounded,
                              value: horarioInicio,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => horarioInicio = v);
                              },
                            ),
                            const SizedBox(height: 14),
                            dropdownHorario(
                              label: 'Horário de fechamento',
                              icon: Icons.schedule_send_rounded,
                              value: horarioFim,
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => horarioFim = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      card(
                        titulo: 'Intervalo dos horários',
                        subtitulo:
                            'Escolha de quanto em quanto tempo os horários aparecem para o cliente.',
                        child: dropdownInteiro(
                          label: 'Horários de',
                          icon: Icons.timelapse_rounded,
                          value: intervaloMinutos,
                          opcoes: const [15, 30, 60],
                          texto: (v) => '$v minutos',
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => intervaloMinutos = v);
                          },
                        ),
                      ),
                      card(
                        titulo: 'Regras para o cliente',
                        subtitulo:
                            'Essas regras controlam quando o cliente pode agendar e cancelar.',
                        child: Column(
                          children: [
                            dropdownInteiro(
                              label: 'Agendar com antecedência mínima',
                              icon: Icons.hourglass_bottom_rounded,
                              value: antecedenciaHoras,
                              opcoes: opcoesAntecedencia,
                              texto: (v) => v == 0
                                  ? 'Sem antecedência'
                                  : '$v hora(s) antes',
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => antecedenciaHoras = v);
                              },
                            ),
                            const SizedBox(height: 14),
                            dropdownInteiro(
                              label: 'Cancelar com antecedência mínima',
                              icon: Icons.event_busy_rounded,
                              value: antecedenciaCancelarHoras,
                              opcoes: opcoesAntecedencia,
                              texto: (v) => v == 0
                                  ? 'Pode cancelar a qualquer momento'
                                  : '$v hora(s) antes',
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => antecedenciaCancelarHoras = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      card(
                        titulo: 'Pausa / intervalo',
                        subtitulo:
                            'Use para almoço ou descanso. Esse período não aparece para o cliente.',
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: usarIntervalo,
                              onChanged: (v) {
                                setState(() => usarIntervalo = v);
                              },
                              activeColor: Colors.amber,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Usar pausa',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            if (usarIntervalo) ...[
                              const SizedBox(height: 14),
                              dropdownHorario(
                                label: 'Início da pausa',
                                icon: Icons.pause_circle_outline_rounded,
                                value: intervaloInicio,
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => intervaloInicio = v);
                                },
                              ),
                              const SizedBox(height: 14),
                              dropdownHorario(
                                label: 'Fim da pausa',
                                icon: Icons.play_circle_outline_rounded,
                                value: intervaloFim,
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => intervaloFim = v);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      card(
                        titulo: 'Dias de funcionamento',
                        subtitulo:
                            'Escolha em quais dias o cliente poderá agendar.',
                        child: Column(
                          children: [
                            itemDia('segunda', 'Segunda-feira'),
                            itemDia('terca', 'Terça-feira'),
                            itemDia('quarta', 'Quarta-feira'),
                            itemDia('quinta', 'Quinta-feira'),
                            itemDia('sexta', 'Sexta-feira'),
                            itemDia('sabado', 'Sábado'),
                            itemDia('domingo', 'Domingo'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: salvando ? null : salvarConfiguracao,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: salvando
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Salvar Configuração',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
