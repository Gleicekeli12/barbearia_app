import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AgendamentoPage extends StatefulWidget {
  final String? servicoSelecionado;
  final String? servicoIdSelecionado;

  const AgendamentoPage({
    super.key,
    this.servicoSelecionado,
    this.servicoIdSelecionado,
  });

  @override
  State<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _servicosStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _barbeirosStream;
  String? servico;
  String? servicoId;
  String? barbeiro;
  String? barbeiroId;
  DateTime? data;
  String? horario;
  double precoServico = 0;
  String pegarInicial(String nome) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) return 'B';
    return nomeLimpo[0].toUpperCase();
  }

  bool loading = false;

  Map<String, dynamic>? _configCache;

  Future<Map<String, dynamic>> getConfig() async {
    if (_configCache != null) return _configCache!;

    _configCache = await buscarConfiguracaoFuncionamento();

    return _configCache!;
  }

  @override
  void initState() {
    super.initState();

    servico = widget.servicoSelecionado;
    servicoId = widget.servicoIdSelecionado;

    _servicosStream = FirebaseFirestore.instance
        .collection('servicos')
        .where('ativo', isEqualTo: true)
        .snapshots();

    _barbeirosStream = FirebaseFirestore.instance
        .collection('barbeiros')
        .snapshots();
  }

  Widget _campoServicoPersonalizado(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docsOrdenados,
  ) {
    QueryDocumentSnapshot<Map<String, dynamic>>? docSelecionado;

    for (final doc in docsOrdenados) {
      if (doc.id == servicoId) {
        docSelecionado = doc;
        break;
      }
    }

    final dados = docSelecionado?.data();

    final nome = dados?['nome']?.toString() ?? '';
    final imagemUrl = dados?['imagemUrl']?.toString() ?? '';
    final categoriaNome = dados?['categoriaNome']?.toString() ?? '';
    final preco = ((dados?['preco'] ?? 0) as num).toDouble();
    final precoFormatado = preco.toStringAsFixed(2).replaceAll('.', ',');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _abrirSelecaoServico(docsOrdenados),
      child: InputDecorator(
        decoration: _inputDecoration(label: 'Serviço'),
        child: docSelecionado == null
            ? const Text(
                'Selecione um serviço',
                style: TextStyle(color: Colors.white54),
              )
            : Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: imagemUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(imagemUrl, fit: BoxFit.cover),
                          )
                        : Icon(
                            iconeServicoPorCategoria(categoriaNome),
                            color: Colors.amber,
                            size: 22,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'R\$ $precoFormatado',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _abrirSelecaoServico(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docsOrdenados,
  ) async {
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    grupos = {};

    for (final doc in docsOrdenados) {
      final categoria =
          doc.data()['categoriaNome']?.toString() ?? 'Sem categoria';
      grupos.putIfAbsent(categoria, () => []);
      grupos[categoria]!.add(doc);
    }

    final categoriasOrdenadas = grupos.keys.toList()..sort();

    final selecionado =
        await showModalBottomSheet<QueryDocumentSnapshot<Map<String, dynamic>>>(
          context: context,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Escolha o serviço',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...categoriasOrdenadas.expand((categoria) {
                    final lista = grupos[categoria]!
                      ..sort((a, b) {
                        final nomeA =
                            a.data()['nome']?.toString().toLowerCase() ?? '';
                        final nomeB =
                            b.data()['nome']?.toString().toLowerCase() ?? '';
                        return nomeA.compareTo(nomeB);
                      });

                    return [
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Text(
                          categoria,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...lista.map((doc) {
                        final dados = doc.data();
                        final nome = dados['nome']?.toString() ?? '';
                        final imagemUrl = dados['imagemUrl']?.toString() ?? '';
                        final categoriaNome =
                            dados['categoriaNome']?.toString() ?? '';
                        final preco = ((dados['preco'] ?? 0) as num).toDouble();
                        final precoFormatado = preco
                            .toStringAsFixed(2)
                            .replaceAll('.', ',');

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: imagemUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imagemUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    iconeServicoPorCategoria(categoriaNome),
                                    color: Colors.amber,
                                  ),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'R\$ $precoFormatado',
                            style: const TextStyle(color: Colors.amber),
                          ),
                          onTap: () => Navigator.pop(context, doc),
                        );
                      }),
                    ];
                  }),
                ],
              ),
            );
          },
        );

    if (selecionado == null) return;

    final dados = selecionado.data();
    final nome = dados['nome']?.toString() ?? '';
    final preco = ((dados['preco'] ?? 0) as num).toDouble();

    setState(() {
      servicoId = selecionado.id;
      servico = nome;
      precoServico = preco;
      horario = null;
    });
  }

  IconData iconeServicoPorCategoria(String categoriaNome) {
    final n = categoriaNome.toLowerCase();

    if (n.contains('combo')) return Icons.auto_awesome_rounded;
    if (n.contains('corte')) return Icons.content_cut_rounded;
    if (n.contains('barba')) return Icons.face_6_rounded;
    if (n.contains('sobrancelha')) return Icons.visibility_rounded;

    if (n.contains('coloracao') ||
        n.contains('coloração') ||
        n.contains('cor')) {
      return Icons.brush_rounded;
    }

    return Icons.content_cut_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Agendamento'),
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
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + teclado),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      FutureBuilder<Map<String, dynamic>>(
                        future: getConfig(),
                        builder: (_, snap) {
                          if (!snap.hasData) return const SizedBox();

                          final antecedencia =
                              snap.data?['antecedenciaHoras'] ?? 1;

                          final antecedenciaCancelar =
                              snap.data?['antecedenciaCancelarHoras'] ?? 1;

                          return Column(
                            children: [
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Os horários exibidos já respeitam o tempo mínimo de antecedência de $antecedencia hora(s) para agendamento.',
                                        style: TextStyle(
                                          color: Colors.grey.shade300,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Cancelamentos devem ser realizados com no mínimo $antecedenciaCancelar hora(s) de antecedência.',
                                        style: TextStyle(
                                          color: Colors.grey.shade300,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      _secao(
                        titulo: 'Serviço e barbeiro',
                        subtitulo: 'Selecione serviço e barbeiro.',
                        child: Column(
                          children: [
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _servicosStream,
                              builder: (_, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.amber,
                                    ),
                                  );
                                }

                                if (snap.hasError) {
                                  return const Text(
                                    'Erro ao carregar serviços',
                                    style: TextStyle(color: Colors.white),
                                  );
                                }

                                final docs = snap.data?.docs ?? [];

                                if (docs.isEmpty) {
                                  return const Text(
                                    'Nenhum serviço disponível',
                                    style: TextStyle(color: Colors.white),
                                  );
                                }

                                final docsOrdenados = [...docs];

                                docsOrdenados.sort((a, b) {
                                  final catA =
                                      a
                                          .data()['categoriaNome']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  final catB =
                                      b
                                          .data()['categoriaNome']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';

                                  final nomeA =
                                      a
                                          .data()['nome']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  final nomeB =
                                      b
                                          .data()['nome']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';

                                  final compareCat = catA.compareTo(catB);
                                  if (compareCat != 0) return compareCat;

                                  return nomeA.compareTo(nomeB);
                                });

                                final servicoExiste = docsOrdenados.any(
                                  (doc) => doc.id == servicoId,
                                );

                                if (servicoId != null && !servicoExiste) {
                                  servicoId = null;
                                  servico = null;
                                  horario = null;
                                }
                                return _campoServicoPersonalizado(
                                  docsOrdenados,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _barbeirosStream,
                              builder: (_, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.amber,
                                    ),
                                  );
                                }

                                if (snap.hasError) {
                                  return const Text(
                                    'Erro ao carregar barbeiros',
                                    style: TextStyle(color: Colors.white),
                                  );
                                }

                                final docs = snap.data?.docs ?? [];

                                if (docs.isEmpty) {
                                  return const Text(
                                    'Nenhum barbeiro disponível',
                                    style: TextStyle(color: Colors.white),
                                  );
                                }

                                final barbeiroExiste = docs.any(
                                  (doc) => doc.id == barbeiroId,
                                );

                                if (barbeiroId != null && !barbeiroExiste) {
                                  barbeiroId = null;
                                  barbeiro = null;
                                  horario = null;
                                }
                                return DropdownButtonFormField<String>(
                                  isDense: false,
                                  dropdownColor: const Color(0xFF1E1E1E),
                                  value: barbeiroId,
                                  isExpanded: true,
                                  decoration: _inputDecoration(
                                    label: 'Barbeiro',
                                  ),
                                  hint: const Text(
                                    'Selecione um barbeiro',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  items: docs.map((doc) {
                                    final nome =
                                        doc.data()['nome']?.toString() ?? '';
                                    final fotoUrl =
                                        doc.data()['fotoUrl']?.toString() ?? '';

                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 17,
                                            backgroundColor: Colors.amber,
                                            backgroundImage: fotoUrl.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    fotoUrl,
                                                  )
                                                : null,
                                            child: fotoUrl.isEmpty
                                                ? Text(
                                                    pegarInicial(nome),
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  nome.isEmpty
                                                      ? 'Sem nome'
                                                      : nome,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),

                                                if ((doc.data()['especialidade'] ??
                                                        '')
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty)
                                                  Text(
                                                    'Especialidade: ${doc.data()['especialidade']}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (id) {
                                    if (id == null) return;

                                    final doc = docs.firstWhere(
                                      (e) => e.id == id,
                                    );
                                    final nome =
                                        doc.data()['nome']?.toString() ?? '';

                                    setState(() {
                                      barbeiroId = id;
                                      barbeiro = nome;
                                      horario = null;
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _secao(
                        titulo: 'Data e horário',
                        subtitulo:
                            'Selecione a data para liberar os horários disponíveis.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: escolherData,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.amber,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.18),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_month_rounded),
                                label: Text(
                                  data == null
                                      ? 'Selecionar Data'
                                      : formatarDataExibicao(data!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _campoHorario(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : agendar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Confirmar Agendamento',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> escolherData() async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final config = await getConfig();

    final diasFuncionamento =
        (config['diasFuncionamento'] as Map<String, dynamic>?) ?? {};

    DateTime initialDate = data ?? hoje;

    while (initialDate.isBefore(DateTime(2100)) &&
        diasFuncionamento[chaveDiaSemana(initialDate)] != true) {
      initialDate = initialDate.add(const Duration(days: 1));
    }

    if (!mounted) return;

    final d = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: initialDate,
      firstDate: hoje,
      lastDate: DateTime(2100),
      selectableDayPredicate: (day) {
        final diaNormalizado = DateTime(day.year, day.month, day.day);
        if (diaNormalizado.isBefore(hoje)) return false;

        final chave = chaveDiaSemana(day);
        return diasFuncionamento[chave] == true;
      },
    );

    if (d != null) {
      setState(() {
        data = d;
        horario = null;
      });
    }
  }

  Future<Map<String, dynamic>> buscarConfiguracaoFuncionamento() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('funcionamento')
          .get();

      final data = doc.data();

      return {
        'horarioInicio': data?['horarioInicio']?.toString() ?? '09:00',
        'horarioFim': data?['horarioFim']?.toString() ?? '19:00',
        'usarIntervalo': data?['usarIntervalo'] == true,
        'intervaloInicio': data?['intervaloInicio']?.toString() ?? '',
        'intervaloFim': data?['intervaloFim']?.toString() ?? '',
        'intervaloMinutos': (data?['intervaloMinutos'] ?? 60) is num
            ? (data?['intervaloMinutos'] as num).toInt()
            : 60,
        'antecedenciaHoras': (data?['antecedenciaHoras'] ?? 1) is num
            ? (data?['antecedenciaHoras'] as num).toInt()
            : 1,
        'antecedenciaCancelarHoras':
            (data?['antecedenciaCancelarHoras'] ?? 1) is num
            ? (data?['antecedenciaCancelarHoras'] as num).toInt()
            : 1,
        'diasFuncionamento':
            (data?['diasFuncionamento'] as Map?)?.cast<String, dynamic>() ??
            {
              'segunda': true,
              'terca': true,
              'quarta': true,
              'quinta': true,
              'sexta': true,
              'sabado': true,
              'domingo': false,
            },
      };
    } catch (_) {
      return {
        'horarioInicio': '09:00',
        'horarioFim': '19:00',
        'intervaloMinutos': 60,
        'usarIntervalo': false,
        'intervaloInicio': '',
        'intervaloFim': '',
        'antecedenciaHoras': 1,
        'antecedenciaCancelarHoras': 1,
        'diasFuncionamento': {
          'segunda': true,
          'terca': true,
          'quarta': true,
          'quinta': true,
          'sexta': true,
          'sabado': true,
          'domingo': false,
        },
      };
    }
  }

  int horarioParaMinutos(String horario) {
    final partes = horario.split(':');
    final hora = int.parse(partes[0]);
    final minuto = int.parse(partes[1]);
    return (hora * 60) + minuto;
  }

  String minutosParaHorario(int totalMinutos) {
    final hora = (totalMinutos ~/ 60).toString().padLeft(2, '0');
    final minuto = (totalMinutos % 60).toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  DateTime? montarDataHora(DateTime dia, String horaTexto) {
    final partes = horaTexto.split(':');
    if (partes.length != 2) return null;

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);

    if (hora == null || minuto == null) return null;

    return DateTime(dia.year, dia.month, dia.day, hora, minuto);
  }

  String chaveDiaSemana(DateTime data) {
    switch (data.weekday) {
      case DateTime.monday:
        return 'segunda';
      case DateTime.tuesday:
        return 'terca';
      case DateTime.wednesday:
        return 'quarta';
      case DateTime.thursday:
        return 'quinta';
      case DateTime.friday:
        return 'sexta';
      case DateTime.saturday:
        return 'sabado';
      case DateTime.sunday:
        return 'domingo';
      default:
        return '';
    }
  }

  Future<List<String>> gerarHorariosConfigurados(
    DateTime dataSelecionada,
  ) async {
    final config = await getConfig();

    final diasFuncionamento =
        (config['diasFuncionamento'] as Map<String, dynamic>?) ?? {};
    final chaveDia = chaveDiaSemana(dataSelecionada);

    if (diasFuncionamento[chaveDia] != true) {
      return [];
    }

    final horarioInicio = config['horarioInicio'] as String;
    final horarioFim = config['horarioFim'] as String;
    final intervaloMinutos = config['intervaloMinutos'] as int;

    final usarIntervalo = config['usarIntervalo'] == true;
    final intervaloInicio = config['intervaloInicio'] as String? ?? '';
    final intervaloFim = config['intervaloFim'] as String? ?? '';

    final inicioMin = horarioParaMinutos(horarioInicio);
    final fimMin = horarioParaMinutos(horarioFim);

    int? intervaloInicioMin;
    int? intervaloFimMin;

    if (usarIntervalo &&
        intervaloInicio.isNotEmpty &&
        intervaloFim.isNotEmpty) {
      intervaloInicioMin = horarioParaMinutos(intervaloInicio);
      intervaloFimMin = horarioParaMinutos(intervaloFim);
    }

    if (fimMin <= inicioMin || intervaloMinutos <= 0) {
      return [];
    }

    final horarios = <String>[];

    int atual = inicioMin;

    while (atual + intervaloMinutos <= fimMin) {
      final slotInicio = atual;
      final slotFim = atual + intervaloMinutos;

      bool sobrepoeIntervalo = false;

      if (usarIntervalo &&
          intervaloInicioMin != null &&
          intervaloFimMin != null) {
        sobrepoeIntervalo =
            slotInicio < intervaloFimMin && slotFim > intervaloInicioMin;
      }

      if (!sobrepoeIntervalo) {
        horarios.add(minutosParaHorario(atual));
      }

      atual += intervaloMinutos;
    }

    return horarios;
  }

  Future<List<String>> filtrarHorariosPorAntecedencia(
    List<String> horariosBase,
    DateTime dataSelecionada,
  ) async {
    final config = await getConfig();
    final antecedenciaHoras = config['antecedenciaHoras'] as int;

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diaSelecionado = DateTime(
      dataSelecionada.year,
      dataSelecionada.month,
      dataSelecionada.day,
    );

    if (diaSelecionado.isBefore(hoje)) {
      return [];
    }

    if (diaSelecionado.isAfter(hoje)) {
      return horariosBase;
    }

    final limite = agora.add(Duration(hours: antecedenciaHoras));

    return horariosBase.where((horaTexto) {
      final horarioCompleto = montarDataHora(dataSelecionada, horaTexto);
      if (horarioCompleto == null) return false;

      return horarioCompleto.isAfter(limite);
    }).toList();
  }

  Stream<List<String>> horariosDisponiveisStream() {
    if (data == null || barbeiroId == null) {
      return Stream.value([]);
    }

    final dataDia = formatarDataDiaFirestore(data!);

    return FirebaseFirestore.instance
        .collection('agendamentos')
        .where('barbeiroId', isEqualTo: barbeiroId)
        .where('dataDia', isEqualTo: dataDia)
        .where('status', isEqualTo: 'agendado')
        .snapshots()
        .asyncMap((snap) async {
          final ocupados = snap.docs
              .map((e) => e.data()['hora']?.toString() ?? '')
              .where((hora) => hora.isNotEmpty)
              .toSet();

          final base = await gerarHorariosConfigurados(data!);
          final filtradosAntecedencia = await filtrarHorariosPorAntecedencia(
            base,
            data!,
          );

          return filtradosAntecedencia
              .where((h) => !ocupados.contains(h))
              .toList();
        });
  }

  Future<void> agendar() async {
    if (loading) return;

    if (servico == null ||
        servicoId == null ||
        barbeiro == null ||
        barbeiroId == null ||
        data == null ||
        horario == null) {
      mostrarErro('Preencha todos os campos');
      return;
    }

    final dataHoraSelecionada = montarDataHora(data!, horario!);

    if (dataHoraSelecionada == null) {
      mostrarErro('Horário inválido');
      return;
    }

    final config = await getConfig();
    final antecedenciaHoras = config['antecedenciaHoras'] as int;
    final diasFuncionamento =
        (config['diasFuncionamento'] as Map<String, dynamic>?) ?? {};

    final chaveDia = chaveDiaSemana(data!);

    if (diasFuncionamento[chaveDia] != true) {
      mostrarErro('O salão não funciona neste dia');
      return;
    }

    final agora = DateTime.now();

    if (!dataHoraSelecionada.isAfter(agora)) {
      mostrarErro('Não é possível agendar no passado');
      return;
    }

    final limiteMinimo = agora.add(Duration(hours: antecedenciaHoras));

    if (dataHoraSelecionada.isBefore(limiteMinimo)) {
      mostrarErro(
        'Agende com no mínimo $antecedenciaHoras hora(s) de antecedência',
      );
      return;
    }

    final horarioValidoPelaConfig = await horarioRespeitaConfiguracao(
      data!,
      horario!,
    );

    if (!horarioValidoPelaConfig) {
      mostrarErro('Esse horário não está mais disponível');
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Usuário não logado');
      }

      final functions = FirebaseFunctions.instance;

      final callable = functions.httpsCallable('criarAgendamento');

      await callable.call({
        'servico': servico,
        'servicoId': servicoId,
        'barbeiro': barbeiro,
        'barbeiroId': barbeiroId,
        'data': dataHoraSelecionada.toIso8601String(),
        'horario': horario,
        'preco': precoServico,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamento realizado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      String mensagem = e.message ?? 'Erro ao agendar';

      if (e.code == 'already-exists') {
        mensagem = 'Esse horário acabou de ser ocupado';
      } else if (e.code == 'failed-precondition') {
        mensagem = e.message ?? mensagem;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao agendar'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<bool> horarioRespeitaConfiguracao(
    DateTime dataSelecionada,
    String hora,
  ) async {
    final horarios = await gerarHorariosConfigurados(dataSelecionada);
    final horariosFiltrados = await filtrarHorariosPorAntecedencia(
      horarios,
      dataSelecionada,
    );

    return horariosFiltrados.contains(hora);
  }

  void mostrarErro(String mensagem) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String formatarDataDiaFirestore(DateTime data) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
  }

  String formatarDataExibicao(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade300),
      prefixIcon: icon != null ? Icon(icon, color: Colors.amber) : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.amber, width: 1.4),
      ),
    );
  }

  Widget _secao({
    required String titulo,
    required String subtitulo,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _campoHorario() {
    if (servicoId == null || barbeiroId == null || data == null) {
      return Text(
        'Selecione serviço, barbeiro e data para selecionar o horário.',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      );
    }

    return StreamBuilder<List<String>>(
      stream: horariosDisponiveisStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }

        if (snap.hasError) {
          return const Text(
            'Erro ao carregar horários',
            style: TextStyle(color: Colors.white),
          );
        }

        final lista = (snap.data ?? []).toSet().toList()..sort();

        if (lista.isEmpty) {
          return Text(
            'Sem horários disponíveis para este dia.\nEscolha outra data.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          );
        }

        final horarioSelecionado = horario != null && lista.contains(horario)
            ? horario
            : null;

        return DropdownButtonFormField<String>(
          dropdownColor: const Color(0xFF1E1E1E),
          value: horarioSelecionado,
          decoration: _inputDecoration(
            label: 'Horário',
            icon: Icons.access_time_rounded,
          ),
          style: const TextStyle(color: Colors.white),
          items: lista.map((h) {
            return DropdownMenuItem<String>(value: h, child: Text(h));
          }).toList(),
          onChanged: (value) {
            setState(() {
              horario = value;
            });
          },
        );
      },
    );
  }
}
