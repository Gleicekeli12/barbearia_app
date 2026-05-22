import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GerenciarPlanosPage extends StatefulWidget {
  const GerenciarPlanosPage({super.key});

  @override
  State<GerenciarPlanosPage> createState() => _GerenciarPlanosPageState();
}

class _GerenciarPlanosPageState extends State<GerenciarPlanosPage> {
  final nomeFocus = FocusNode();
  final descricaoFocus = FocusNode();
  final precoFocus = FocusNode();
  final linkPagamentoFocus = FocusNode();

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final precoController = TextEditingController();
  final linkPagamentoController = TextEditingController();

  bool carregando = false;

  String normalizarNome(String nome) {
    return nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  double? converterPreco(String valor) {
    final normalizado = valor.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalizado);
  }

  void mostrarMensagem(String mensagem, Color cor) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  Future<void> adicionarPlano() async {
    if (carregando) return;

    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final descricao = descricaoController.text.trim();
    final precoTexto = precoController.text.trim();
    final preco = converterPreco(precoTexto);
    final linkPagamento = linkPagamentoController.text.trim();

    if (nome.isEmpty || descricao.isEmpty || linkPagamento.isEmpty) {
      mostrarMensagem('Preencha todos os campos', Colors.red);
      return;
    }

    if (preco == null || preco <= 0) {
      mostrarMensagem('Digite um preço válido maior que zero', Colors.red);
      return;
    }

    setState(() => carregando = true);

    try {
      final nomeBusca = normalizarNome(nome);

      final planoExistente = await FirebaseFirestore.instance
          .collection('planos')
          .where('nomeBusca', isEqualTo: nomeBusca)
          .limit(1)
          .get();

      if (planoExistente.docs.isNotEmpty) {
        mostrarMensagem('Já existe um plano com esse nome', Colors.red);

        setState(() => carregando = false);

        return;
      }

      await FirebaseFirestore.instance.collection('planos').add({
        'nome': nome,
        'nomeBusca': nomeBusca,
        'descricao': descricao,
        'preco': preco,
        'ativo': true,
        'periodo': 'mensal',
        'versao': 1,
        'gateway': 'pagbank',
        'linkPagamento': linkPagamento,
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      nomeController.clear();
      descricaoController.clear();
      precoController.clear();
      linkPagamentoController.clear();

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();
      linkPagamentoFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();

      mostrarMensagem('Plano cadastrado com sucesso', Colors.green);
    } catch (e) {
      mostrarMensagem('Erro ao salvar plano', Colors.red);
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> alterarStatusPlano({
    required String id,
    required String nome,
    required bool ativoAtual,
  }) async {
    final novoStatus = !ativoAtual;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            novoStatus ? 'Reativar plano' : 'Desativar plano',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            novoStatus
                ? 'Deseja reativar "$nome"? Ele voltará a aparecer para os clientes.'
                : 'Deseja desativar "$nome"? Ele não aparecerá mais para novos clientes.',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: novoStatus ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(novoStatus ? 'Reativar' : 'Desativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('planos').doc(id).update({
        'ativo': novoStatus,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      mostrarMensagem(
        novoStatus ? 'Plano reativado' : 'Plano desativado',
        novoStatus ? Colors.green : Colors.orange,
      );
    } catch (_) {
      mostrarMensagem('Erro ao alterar status do plano', Colors.red);
    }
  }

  Future<void> excluirPlanoDesativado(
    String id,
    String nome,
    bool ativo,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (ativo) {
      mostrarMensagem('Desative o plano antes de excluir', Colors.orange);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Excluir plano',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja realmente excluir "$nome"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('planos').doc(id).delete();

      mostrarMensagem('Plano excluído com sucesso', Colors.green);

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();
      linkPagamentoFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      mostrarMensagem('Erro ao excluir plano', Colors.red);
    }
  }

  Future<void> editarPlano(String id, Map<String, dynamic> dados) async {
    FocusScope.of(context).unfocus();
    final nomeCtrl = TextEditingController(
      text: dados['nome']?.toString() ?? '',
    );
    final descricaoCtrl = TextEditingController(
      text: dados['descricao']?.toString() ?? '',
    );
    final precoCtrl = TextEditingController(
      text: formatarPreco(dados['preco']),
    );
    final linkPagamentoCtrl = TextEditingController(
      text: dados['linkPagamento']?.toString() ?? '',
    );

    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Editar plano',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descricaoCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Preço',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: linkPagamentoCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Link PagBank',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (salvar != true) return;

    final nome = nomeCtrl.text.trim();
    final descricao = descricaoCtrl.text.trim();
    final preco = converterPreco(precoCtrl.text);
    final linkPagamento = linkPagamentoCtrl.text.trim();

    if (nome.isEmpty ||
        descricao.isEmpty ||
        linkPagamento.isEmpty ||
        preco == null ||
        preco <= 0) {
      mostrarMensagem('Preencha todos os dados corretamente', Colors.red);
      return;
    }

    try {
      final nomeBusca = normalizarNome(nome);

      final existente = await FirebaseFirestore.instance
          .collection('planos')
          .where('nomeBusca', isEqualTo: nomeBusca)
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty && existente.docs.first.id != id) {
        mostrarMensagem('Já existe um plano com esse nome', Colors.red);
        return;
      }

      await FirebaseFirestore.instance.collection('planos').doc(id).update({
        'nome': nome,
        'nomeBusca': nomeBusca,
        'descricao': descricao,
        'preco': preco,
        'linkPagamento': linkPagamento,
        'versao': FieldValue.increment(1),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      mostrarMensagem('Plano atualizado com sucesso', Colors.green);
    } catch (e) {
      mostrarMensagem('Erro ao atualizar plano', Colors.red);
    }
  }

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }

    return '0,00';
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade300),
      prefixIcon: Icon(icon, color: Colors.amber),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 1.4),
      ),
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    descricaoController.dispose();
    precoController.dispose();

    nomeFocus.dispose();
    descricaoFocus.dispose();
    precoFocus.dispose();
    linkPagamentoController.dispose();
    linkPagamentoFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Gerenciar Planos'),
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
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: nomeController,
                      focusNode: nomeFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Nome do plano',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descricaoController,
                      focusNode: descricaoFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Descrição',
                        icon: Icons.description_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: precoController,
                      focusNode: precoFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!carregando) adicionarPlano();
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Preço',
                        icon: Icons.attach_money_rounded,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: linkPagamentoController,
                      focusNode: linkPagamentoFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Link PagBank',
                        icon: Icons.link_rounded,
                      ),
                    ),

                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: carregando ? null : adicionarPlano,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: carregando
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Salvar Plano',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('planos')
                    .orderBy('nomeBusca')
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

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (snapshot.data?.docs.isEmpty ?? true)) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 42,
                              color: Colors.amber.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum plano cadastrado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Adicione um plano para começar',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final planos = snapshot.data!.docs;

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: planos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = planos[index];
                      final plano = doc.data();

                      final nome = plano['nome']?.toString().trim() ?? '';
                      final descricao =
                          plano['descricao']?.toString().trim() ?? '';
                      final preco = formatarPreco(plano['preco']);
                      final ativo = plano['ativo'] ?? true;

                      return Container(
                        key: ValueKey(doc.id),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.09),
                              Colors.white.withOpacity(0.035),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Colors.amber,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nome.isEmpty ? 'Plano sem nome' : nome,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (descricao.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          descricao,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 18,
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.amber,
                                        ),
                                        onPressed: () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          nomeFocus.unfocus();
                                          descricaoFocus.unfocus();
                                          precoFocus.unfocus();
                                          linkPagamentoFocus.unfocus();

                                          await Future.delayed(
                                            const Duration(milliseconds: 200),
                                          );

                                          if (!context.mounted) return;
                                          await editarPlano(doc.id, plano);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 25,
                                        icon: Icon(
                                          ativo
                                              ? Icons.toggle_off_rounded
                                              : Icons.toggle_on_rounded,
                                          color: ativo
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        onPressed: () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          nomeFocus.unfocus();
                                          descricaoFocus.unfocus();
                                          precoFocus.unfocus();
                                          linkPagamentoFocus.unfocus();

                                          await Future.delayed(
                                            const Duration(milliseconds: 200),
                                          );

                                          if (!context.mounted) return;
                                          await alterarStatusPlano(
                                            id: doc.id,
                                            nome: nome,
                                            ativoAtual: ativo,
                                          );
                                        },
                                      ),
                                    ),
                                    if (!ativo) ...[
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 34,
                                        height: 34,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          iconSize: 18,
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () async {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            nomeFocus.unfocus();
                                            descricaoFocus.unfocus();
                                            precoFocus.unfocus();
                                            linkPagamentoFocus.unfocus();

                                            await Future.delayed(
                                              const Duration(milliseconds: 200),
                                            );

                                            if (!context.mounted) return;
                                            await excluirPlanoDesativado(
                                              doc.id,
                                              nome,
                                              ativo,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'R\$ $preco',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Mensal',
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ativo
                                        ? Colors.green.withOpacity(0.18)
                                        : Colors.red.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    ativo ? 'ATIVO' : 'DESATIVADO',
                                    style: TextStyle(
                                      color: ativo
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
