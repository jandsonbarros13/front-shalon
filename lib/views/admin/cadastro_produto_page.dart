import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';

class CadastroProdutoPage extends StatefulWidget {
  final Map<String, dynamic>? produtoParaEditar;

  const CadastroProdutoPage({super.key, this.produtoParaEditar});

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  final _produtoService = ProdutoService(); // <-- Chamando o Service!
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();
  final TextEditingController _estoqueController = TextEditingController();

  List<String> _fotos = [];
  String _unidadeMedida = 'Unidade';
  String _categoria = 'Montados';
  bool _isSaving = false;

  final List<String> _categorias = ['Montados', 'Combos', 'Bebidas'];
  final List<String> _unidades = ['Unidade', 'Kg', 'Grama'];

  @override
  void initState() {
    super.initState();
    if (widget.produtoParaEditar != null) {
      final p = widget.produtoParaEditar!;
      _nomeController.text = p['name'] ?? '';
      _descricaoController.text = p['description'] ?? '';
      _precoController.text = (p['price'] ?? '').toString();
      _estoqueController.text = (p['estoque'] ?? '').toString();

      String imgUrl = p['image_url'] ?? '';
      _fotos = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

      String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
      if (un == 'kg' || un == 'quilo') {
        _unidadeMedida = 'Kg';
      } else if (un == 'grama' || un == 'g') {
        _unidadeMedida = 'Grama';
      } else {
        _unidadeMedida = 'Unidade';
      }

      String cat = p['category'] ?? '';
      if (_categorias.contains(cat)) {
        _categoria = cat;
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _estoqueController.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = 'data:${pickedFile.mimeType ?? "image/jpeg"};base64,${base64Encode(bytes)}';
      setState(() {
        _fotos.add(base64Image);
      });
    }
  }

  void _removerFoto(int index) {
    setState(() {
      _fotos.removeAt(index);
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    String precoLimpo = _precoController.text.replaceAll('R\$', '').trim().replaceAll(',', '.');

    final dadosProduto = {
      if (widget.produtoParaEditar != null) 'id': widget.produtoParaEditar!['id'],
      'name': _nomeController.text.trim(),
      'description': _descricaoController.text.trim(),
      'category': _categoria,
      'unidade_medida': _unidadeMedida,
      'price': double.tryParse(precoLimpo) ?? 0.0,
      'estoque': int.tryParse(_estoqueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      'image_url': _fotos.join('|||'),
      'size': '', // O Go espera esses campos, enviando vazios para não dar pau
      'is_destaque': false,
    };

    dynamic resultado;
    
    // Agora sim! Ele manda os dados pro servidor!
    if (widget.produtoParaEditar != null) {
      resultado = await _produtoService.editarProduto(widget.produtoParaEditar!['id'], dadosProduto);
    } else {
      resultado = await _produtoService.cadastrarProduto(dadosProduto);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resultado != null && resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto salvo com sucesso!'), backgroundColor: Colors.green));
      Navigator.pop(context, true); // Retorna 'true' para atualizar a lista lá atrás!
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar o produto.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.produtoParaEditar != null;
    final corTema = const Color(0xFF4A0E4E);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: corTema,
        foregroundColor: Colors.white,
        title: Text(isEdit ? 'Editar Produto' : 'Novo Produto', style: const TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: corTema.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      isEdit ? 'Atualizar Dados do Produto' : 'Cadastrar Novo Produto',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: corTema, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome do Produto',
                        prefixIcon: Icon(Icons.shopping_bag_outlined, color: corTema),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTema, width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoria,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Categoria',
                              prefixIcon: Icon(Icons.category_outlined, color: corTema),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTema, width: 2), borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _categoria = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _unidadeMedida,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Venda por',
                              prefixIcon: Icon(Icons.scale_outlined, color: corTema),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTema, width: 2), borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (v) => setState(() => _unidadeMedida = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _descricaoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descrição do Produto',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.description_outlined, color: corTema),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTema, width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _unidadeMedida == 'Kg' 
                                  ? 'Preço por Kg (R\$)' 
                                  : _unidadeMedida == 'Grama' 
                                      ? 'Preço por Grama (R\$)' 
                                      : 'Preço Unitário (R\$)', 
                              prefixIcon: Icon(Icons.attach_money, color: corTema),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTema, width: 2), borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _estoqueController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'Estoque Disponível',
                              prefixIcon: Icon(Icons.inventory_2_outlined, color: corTema),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTema, width: 2), borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('Fotos do Produto', style: TextStyle(color: corTema, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Adicione imagens para destacar o produto na vitrine virtual.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        ..._fotos.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String foto = entry.value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: foto.startsWith('data:image')
                                      ? Image.memory(base64Decode(foto.split(',')[1]), fit: BoxFit.cover)
                                      : Image.network(foto, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey)),
                                ),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: InkWell(
                                  onTap: () => _removerFoto(idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        InkWell(
                          onTap: _escolherFoto,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: corTema.withOpacity(0.4), style: BorderStyle.solid, width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: corTema.withOpacity(0.7), size: 36),
                                const SizedBox(height: 8),
                                Text('Adicionar Foto', style: TextStyle(color: corTema.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corTema,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSaving ? null : _salvar,
                        icon: _isSaving 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                        label: Text(
                          isEdit ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR PRODUTO', 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}