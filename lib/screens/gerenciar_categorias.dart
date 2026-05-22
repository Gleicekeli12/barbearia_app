import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

class GerenciarCategoriasPage extends StatefulWidget {
  const GerenciarCategoriasPage({super.key});

  @override
  State<GerenciarCategoriasPage> createState() =>
      _GerenciarCategoriasPageState();
}

class _GerenciarCategoriasPageState extends State<GerenciarCategoriasPage> {
  final nomeFocus = FocusNode();
  final nomeController = TextEditingController();
  XFile? imagemSelecionada;
  bool carregando = false;

  Future<void> adicionarCategoria() async {
    if (carregando) return;
    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o nome da categoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => carregando = true);
    String imagemUrl = '';

    if (imagemSelecionada != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('categorias')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (kIsWeb) {
        final bytes = await imagemSelecionada!.readAsBytes();

        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(
          File(imagemSelecionada!.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      imagemUrl = await ref.getDownloadURL();
    }

    try {
      final existente = await FirebaseFirestore.instance
          .collection('categorias_servicos')
          .where('nomeBusca', isEqualTo: nome.toLowerCase())
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty) {
        throw Exception('Já existe uma categoria com esse nome');
      }
      final ultimaCategoria = await FirebaseFirestore.instance
          .collection('categorias_servicos')
          .orderBy('ordem', descending: true)
          .limit(1)
          .get();

      int proximaOrdem = 1;

      if (ultimaCategoria.docs.isNotEmpty) {
        final ultimaOrdem = ultimaCategoria.docs.first.data()['ordem'];

        if (ultimaOrdem is num) {
          proximaOrdem = ultimaOrdem.toInt() + 1;
        }
      }

      await FirebaseFirestore.instance.collection('categorias_servicos').add({
        'nome': nome,
        'nomeBusca': nome.toLowerCase(),
        'imagemUrl': imagemUrl,
        'ordem': proximaOrdem,
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      nomeController.clear();
      nomeFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoria criada com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao criar categoria';

      if (e.toString().contains('Já existe uma categoria com esse nome')) {
        mensagem = 'Já existe uma categoria com esse nome';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
          imagemSelecionada = null;
        });
      }
    }
  }

  Future<void> escolherImagem() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 900,
    );

    if (picked == null) return;

    setState(() {
      imagemSelecionada = picked;
    });
  }

  Future<void> removerCategoria(String id) async {
    try {
      final possuiServicos = await FirebaseFirestore.instance
          .collection('servicos')
          .where('categoriaId', isEqualTo: id)
          .limit(1)
          .get();

      if (possuiServicos.docs.isNotEmpty) {
        throw Exception('Remova os serviços desta categoria primeiro');
      }
      final categoriaDoc = await FirebaseFirestore.instance
          .collection('categorias_servicos')
          .doc(id)
          .get();

      final imagemUrl = categoriaDoc.data()?['imagemUrl'] ?? '';

      if (imagemUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imagemUrl).delete();
        } catch (_) {}
      }

      await FirebaseFirestore.instance
          .collection('categorias_servicos')
          .doc(id)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoria removida com sucesso'),
          backgroundColor: Colors.green,
        ),
      );

      FocusManager.instance.primaryFocus?.unfocus();
      nomeFocus.unfocus();
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao remover categoria';

      if (e.toString().contains(
        'Remova os serviços desta categoria primeiro',
      )) {
        mensagem = 'Remova os serviços desta categoria primeiro';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> confirmarRemocao(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Excluir categoria',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await removerCategoria(id);
    }
  }

  Future<void> editarCategoria(String id, Map<String, dynamic> dados) async {
    FocusScope.of(context).unfocus();
    final nomeCtrl = TextEditingController(
      text: dados['nome']?.toString() ?? '',
    );
    XFile? novaImagem;
    String imagemAtual = dados['imagemUrl']?.toString() ?? '';
    bool removerImagem = false;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Editar categoria',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 IMAGEM
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.amber,
                          backgroundImage: novaImagem != null && !kIsWeb
                              ? FileImage(File(novaImagem!.path))
                              : (!removerImagem && imagemAtual.isNotEmpty)
                              ? CachedNetworkImageProvider(imagemAtual)
                              : null,
                          child:
                              novaImagem == null &&
                                  (removerImagem || imagemAtual.isEmpty)
                              ? const Icon(
                                  Icons.category_outlined,
                                  color: Colors.black,
                                )
                              : null,
                        ),

                        if (novaImagem != null || imagemAtual.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setStateModal(() {
                                  novaImagem = null;
                                  removerImagem = true;
                                });
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),

                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 75,
                                maxWidth: 900,
                              );

                              if (picked == null) return;

                              setStateModal(() {
                                novaImagem = picked;
                                removerImagem = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🔤 NOME
                    TextField(
                      controller: nomeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nome da categoria',
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
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (salvar != true) return;

    final novoNome = nomeCtrl.text.trim();

    if (novoNome.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite o nome da categoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final existente = await FirebaseFirestore.instance
        .collection('categorias_servicos')
        .where('nomeBusca', isEqualTo: novoNome.toLowerCase())
        .limit(1)
        .get();

    if (existente.docs.isNotEmpty && existente.docs.first.id != id) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe uma categoria com esse nome'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String imagemFinal = imagemAtual;

      if (removerImagem) {
        imagemFinal = '';
      }

      if (novaImagem != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('categorias')
            .child('$id.jpg');

        if (kIsWeb) {
          final bytes = await novaImagem!.readAsBytes();

          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await ref.putFile(
            File(novaImagem!.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
        imagemFinal = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('categorias_servicos')
          .doc(id)
          .update({
            'nome': novoNome,
            'nomeBusca': novoNome.toLowerCase().trim(),
            'imagemUrl': imagemFinal,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });

      final servicosDaCategoria = await FirebaseFirestore.instance
          .collection('servicos')
          .where('categoriaId', isEqualTo: id)
          .get();

      for (final servico in servicosDaCategoria.docs) {
        await servico.reference.update({'categoriaNome': novoNome});
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categoria atualizada com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao atualizar categoria';

      if (e.toString().contains('permission-denied')) {
        mensagem = 'Sem permissão para editar categoria';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
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

  IconData iconeCategoriaPorNome(String nome) {
    final n = nome.toLowerCase();

    // COMBOS
    if (n.contains('combo')) {
      return Icons.auto_awesome_rounded;
    }

    // CORTE
    if (n.contains('corte')) {
      return Icons.content_cut_rounded;
    }

    // BARBA
    if (n.contains('barba')) {
      return Icons.face_6_rounded;
    }

    // SOBRANCELHA
    if (n.contains('sobrancelha')) {
      return Icons.visibility_rounded;
    }

    // COLORAÇÃO
    if (n.contains('coloracao') ||
        n.contains('coloração') ||
        n.contains('cor')) {
      return Icons.brush_rounded;
    }

    // PADRÃO
    return Icons.category_outlined;
  }

  @override
  void dispose() {
    nomeController.dispose();
    nomeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Gerenciar Categorias'),
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
              MediaQuery.of(context).viewInsets.bottom + 20,
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
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        GestureDetector(
                          onTap: carregando ? null : escolherImagem,
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.amber,
                            backgroundImage:
                                imagemSelecionada != null && !kIsWeb
                                ? FileImage(File(imagemSelecionada!.path))
                                : null,
                            child: imagemSelecionada == null
                                ? const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                  )
                                : null,
                          ),
                        ),
                        if (imagemSelecionada != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: carregando
                                  ? null
                                  : () {
                                      setState(() {
                                        imagemSelecionada = null;
                                      });
                                    },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      imagemSelecionada == null
                          ? 'Adicionar imagem opcional'
                          : 'Imagem selecionada',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      focusNode: nomeFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!carregando) {
                          adicionarCategoria();
                        }
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Nome da categoria',
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: carregando ? null : adicionarCategoria,
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
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Adicionar Categoria',
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
                    .collection('categorias_servicos')
                    .orderBy('nomeBusca')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar categorias',
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

                  final categorias = snapshot.data?.docs ?? [];

                  if (categorias.isEmpty) {
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
                              Icons.category_outlined,
                              size: 42,
                              color: Colors.amber.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhuma categoria cadastrada',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Adicione uma categoria para começar',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categorias.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = categorias[index];
                      final categoria = doc.data();

                      final nome =
                          categoria['nome']?.toString().trim() ?? 'Categoria';
                      final imagemUrl =
                          categoria['imagemUrl']?.toString() ?? '';
                      final icone = iconeCategoriaPorNome(nome);

                      return Container(
                        key: ValueKey(doc.id),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: imagemUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: imagemUrl,

                                        fit: BoxFit.cover,
                                        width: 54,
                                        height: 54,
                                        placeholder: (context, url) =>
                                            const Center(
                                              child: SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.amber,
                                                    ),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Icon(icone, color: Colors.amber),
                                      ),
                                    )
                                  : Icon(icone, color: Colors.amber),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                nome,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
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

                                      await Future.delayed(
                                        const Duration(milliseconds: 200),
                                      );

                                      if (!context.mounted) return;
                                      await editarCategoria(doc.id, categoria);
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
                                    iconSize: 18,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      nomeFocus.unfocus();

                                      await Future.delayed(
                                        const Duration(milliseconds: 200),
                                      );

                                      if (!context.mounted) return;
                                      await confirmarRemocao(doc.id, nome);

                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      nomeFocus.unfocus();
                                    },
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
