import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

class GerenciarServicosPage extends StatefulWidget {
  const GerenciarServicosPage({super.key});

  @override
  State<GerenciarServicosPage> createState() => _GerenciarServicosPageState();
}

class _GerenciarServicosPageState extends State<GerenciarServicosPage> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  final nomeFocus = FocusNode();
  final descricaoFocus = FocusNode();
  final precoFocus = FocusNode();

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final precoController = TextEditingController();
  XFile? imagemSelecionada;

  String? categoriaId;
  String? categoriaNome;

  bool carregando = false;

  @override
  void initState() {
    super.initState();

    _categoriasStream = FirebaseFirestore.instance
        .collection('categorias_servicos')
        .orderBy('ordem')
        .snapshots();
  }

  Future<void> adicionarServico() async {
    if (carregando) return;
    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final descricao = descricaoController.text.trim();
    final precoTexto = precoController.text.trim();

    if (nome.isEmpty ||
        descricao.isEmpty ||
        precoTexto.isEmpty ||
        categoriaId == null ||
        categoriaNome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha tudo e selecione a categoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final precoNormalizado = precoTexto
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final preco = double.tryParse(precoNormalizado);

    if (preco == null || preco <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um preço válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      final existente = await FirebaseFirestore.instance
          .collection('servicos')
          .where('categoriaId', isEqualTo: categoriaId)
          .where('nomeBusca', isEqualTo: nome.toLowerCase().trim())
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty) {
        throw Exception('Já existe um serviço com esse nome nesta categoria');
      }
      String imagemUrl = '';

      if (imagemSelecionada != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('servicos')
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

      await FirebaseFirestore.instance.collection('servicos').add({
        'nome': nome,
        'nomeBusca': nome.toLowerCase().trim(),
        'descricao': descricao,
        'preco': preco,
        'categoriaId': categoriaId,
        'categoriaNome': categoriaNome,
        'imagemUrl': imagemUrl,
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      nomeController.clear();
      descricaoController.clear();
      precoController.clear();

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();

      FocusManager.instance.primaryFocus?.unfocus();

      if (mounted) {
        setState(() {
          categoriaId = null;
          categoriaNome = null;
          imagemSelecionada = null;
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço cadastrado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao salvar serviço';

      if (e.toString().contains(
        'Já existe um serviço com esse nome nesta categoria',
      )) {
        mensagem = 'Já existe um serviço com esse nome nesta categoria';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => carregando = false);
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

  Future<void> removerServico(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Excluir serviço',
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
      ),
    );

    if (confirmar != true) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('servicos')
          .doc(id)
          .get();

      final imagemUrl = doc.data()?['imagemUrl'] ?? '';

      if (imagemUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imagemUrl).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('servicos').doc(id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço removido com sucesso'),
          backgroundColor: Colors.green,
        ),
      );

      FocusManager.instance.primaryFocus?.unfocus();

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover serviço'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editarServico(String id, Map<String, dynamic> dados) async {
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

    String? novaCategoriaId = dados['categoriaId']?.toString();
    String? novaCategoriaNome = dados['categoriaNome']?.toString();
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
                'Editar serviço',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                  Icons.content_cut,
                                  color: Colors.black,
                                  size: 28,
                                )
                              : null,
                        ),

                        // botão remover
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

                        // botão escolher imagem
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
                    const SizedBox(height: 12),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final selecionada = await selecionarCategoriaServico(
                          categoriaAtualId: novaCategoriaId,
                        );

                        if (selecionada == null) return;

                        setStateModal(() {
                          novaCategoriaId = selecionada.id;
                          novaCategoriaNome =
                              selecionada.data()['nome']?.toString() ??
                              'Categoria';
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          labelStyle: TextStyle(color: Colors.white70),
                          suffixIcon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.amber,
                          ),
                        ),
                        child: Text(
                          novaCategoriaNome?.isNotEmpty == true
                              ? novaCategoriaNome!
                              : 'Selecionar categoria',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Preço',
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

    final nome = nomeCtrl.text.trim();
    final descricao = descricaoCtrl.text.trim();
    final precoTexto = precoCtrl.text.trim();

    final precoNormalizado = precoTexto
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final preco = double.tryParse(precoNormalizado);

    if (nome.isEmpty ||
        descricao.isEmpty ||
        preco == null ||
        preco <= 0 ||
        novaCategoriaId == null ||
        novaCategoriaNome == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os dados corretamente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final existente = await FirebaseFirestore.instance
        .collection('servicos')
        .where('categoriaId', isEqualTo: novaCategoriaId)
        .where('nomeBusca', isEqualTo: nome.toLowerCase().trim())
        .limit(1)
        .get();

    final duplicado = existente.docs.any((doc) => doc.id != id);

    if (duplicado) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe um serviço com esse nome nesta categoria'),
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
            .child('servicos')
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

      await FirebaseFirestore.instance.collection('servicos').doc(id).update({
        'nome': nome,
        'nomeBusca': nome.toLowerCase().trim(),
        'descricao': descricao,
        'preco': preco,
        'categoriaId': novaCategoriaId,
        'categoriaNome': novaCategoriaNome,
        'imagemUrl': imagemFinal,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço atualizado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao atualizar serviço';

      if (e.toString().contains('permission-denied')) {
        mensagem = 'Sem permissão para editar serviço';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  selecionarCategoriaServico({String? categoriaAtualId}) async {
    final snap = await FirebaseFirestore.instance
        .collection('categorias_servicos')
        .orderBy('ordem')
        .get();

    if (!mounted) return null;

    final categorias = snap.docs;

    if (categorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma categoria cadastrada'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return showModalBottomSheet<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Selecionar categoria',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...categorias.map((doc) {
                  final nome = doc.data()['nome']?.toString() ?? 'Categoria';

                  return ListTile(
                    title: Text(
                      nome,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: doc.id == categoriaAtualId
                        ? const Icon(Icons.check, color: Colors.amber)
                        : null,
                    onTap: () => Navigator.pop(context, doc),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
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

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }
    return '0,00';
  }

  IconData iconeServicoPorCategoria(String categoriaNome) {
    final n = categoriaNome.toLowerCase();

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
    return Icons.content_cut_rounded;
  }

  @override
  void dispose() {
    nomeController.dispose();
    descricaoController.dispose();
    precoController.dispose();

    nomeFocus.dispose();
    descricaoFocus.dispose();
    precoFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Gerenciar Serviços'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF050505), Color(0xFF141414), Color(0xFF242424)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardHeight),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _categoriasStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                            ),
                          );
                        }

                        if (snap.hasError) {
                          return const Text(
                            'Erro ao carregar categorias',
                            style: TextStyle(color: Colors.white),
                          );
                        }

                        final categorias = snap.data?.docs ?? [];

                        categorias.sort((a, b) {
                          final ordemA = a.data()['ordem'];
                          final ordemB = b.data()['ordem'];

                          final valorA = ordemA is num ? ordemA : 9999;
                          final valorB = ordemB is num ? ordemB : 9999;

                          return valorA.compareTo(valorB);
                        });

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: categorias.isEmpty
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();

                                  final selecionada =
                                      await showModalBottomSheet<
                                        QueryDocumentSnapshot<
                                          Map<String, dynamic>
                                        >
                                      >(
                                        context: context,
                                        backgroundColor: const Color(
                                          0xFF1A1A1A,
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24),
                                          ),
                                        ),
                                        builder: (_) {
                                          return SafeArea(
                                            child: ListView(
                                              padding: const EdgeInsets.all(16),
                                              children: [
                                                const Text(
                                                  'Selecione a categoria',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...categorias.map((doc) {
                                                  final nome =
                                                      doc
                                                          .data()['nome']
                                                          ?.toString() ??
                                                      'Categoria';

                                                  return ListTile(
                                                    title: Text(
                                                      nome,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    trailing:
                                                        doc.id == categoriaId
                                                        ? const Icon(
                                                            Icons.check,
                                                            color: Colors.amber,
                                                          )
                                                        : null,
                                                    onTap: () => Navigator.pop(
                                                      context,
                                                      doc,
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          );
                                        },
                                      );

                                  if (selecionada == null) return;

                                  setState(() {
                                    categoriaId = selecionada.id;
                                    categoriaNome =
                                        selecionada
                                            .data()['nome']
                                            ?.toString() ??
                                        'Categoria';
                                  });
                                },
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              label: 'Categoria',
                              icon: Icons.category,
                            ),
                            child: Text(
                              categoriaNome ?? 'Selecione uma categoria',
                              style: TextStyle(
                                color: categoriaNome == null
                                    ? Colors.white54
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
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
                                    size: 28,
                                  )
                                : null,
                          ),
                        ),
                        if (imagemSelecionada != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      focusNode: nomeFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Nome do serviço',
                        icon: Icons.content_cut,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descricaoController,
                      focusNode: descricaoFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Descrição',
                        icon: Icons.description,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: precoController,
                      focusNode: precoFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        label: 'Preço',
                        icon: Icons.attach_money,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: carregando ? null : adicionarServico,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
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
                                'Adicionar Serviço',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('servicos')
                    .orderBy('nomeBusca')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    );
                  }

                  if (snap.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar serviços',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final servicos = snap.data?.docs ?? [];

                  if (servicos.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum serviço cadastrado',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final Map<
                    String,
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  >
                  grupos = {};

                  for (final doc in servicos) {
                    final categoria =
                        doc.data()['categoriaNome']?.toString() ??
                        'Sem categoria';

                    if (!grupos.containsKey(categoria)) {
                      grupos[categoria] = [];
                    }

                    grupos[categoria]!.add(doc);
                  }

                  final categoriasOrdenadas = grupos.keys.toList()..sort();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categoriasOrdenadas.map((categoria) {
                      final itens = grupos[categoria] ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Text(
                              categoria,
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...itens.map((doc) {
                            final s = doc.data();
                            final id = doc.id;

                            final nome = s['nome']?.toString() ?? 'Serviço';
                            final categoriaNome =
                                s['categoriaNome']?.toString() ?? '';
                            final icone = iconeServicoPorCategoria(
                              categoriaNome,
                            );
                            final descricao =
                                s['descricao']?.toString().trim() ?? '';
                            final imagemUrl = s['imagemUrl']?.toString() ?? '';

                            return Container(
                              key: ValueKey(id),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: imagemUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: CachedNetworkImage(
                                                imageUrl: imagemUrl,

                                                width: 46,
                                                height: 46,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child: SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.amber,
                                                            ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Icon(
                                                          icone,
                                                          color: Colors.amber,
                                                        ),
                                              ),
                                            )
                                          : Icon(icone, color: Colors.amber),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nome,
                                            softWrap: true,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.5,
                                              height: 1.25,
                                            ),
                                          ),

                                          if (descricao.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              descricao,
                                              softWrap: true,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            'R\$ ${formatarPreco(s['preco'])}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          GestureDetector(
                                            onTap: () async {
                                              final novoValor =
                                                  !(s['ativo'] ?? true);

                                              await FirebaseFirestore.instance
                                                  .collection('servicos')
                                                  .doc(id)
                                                  .update({
                                                    'ativo': novoValor,
                                                    'atualizadoEm':
                                                        FieldValue.serverTimestamp(),
                                                  });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: (s['ativo'] ?? true)
                                                    ? Colors.amber.withOpacity(
                                                        0.15,
                                                      )
                                                    : Colors.white.withOpacity(
                                                        0.06,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                border: Border.all(
                                                  color: (s['ativo'] ?? true)
                                                      ? Colors.amber
                                                            .withOpacity(0.35)
                                                      : Colors.white
                                                            .withOpacity(0.08),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    (s['ativo'] ?? true)
                                                        ? Icons
                                                              .check_circle_rounded
                                                        : Icons.block_rounded,
                                                    size: 14,
                                                    color: (s['ativo'] ?? true)
                                                        ? Colors.amber
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    (s['ativo'] ?? true)
                                                        ? 'Ativo'
                                                        : 'Inativo',
                                                    style: TextStyle(
                                                      color:
                                                          (s['ativo'] ?? true)
                                                          ? Colors.amber
                                                          : Colors.grey,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
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

                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 200,
                                                ),
                                              );

                                              if (!context.mounted) return;

                                              await editarServico(id, s);
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
                                              descricaoFocus.unfocus();
                                              precoFocus.unfocus();

                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 200,
                                                ),
                                              );

                                              if (!context.mounted) return;

                                              await removerServico(id, nome);

                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 14),
                        ],
                      );
                    }).toList(),
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
