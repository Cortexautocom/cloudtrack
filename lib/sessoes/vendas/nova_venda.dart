// vendas/nova_venda_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaVendaPage extends StatefulWidget {
  const NovaVendaPage({super.key});

  @override
  State<NovaVendaPage> createState() => _NovaVendaPageState();
}

class _NovaVendaPageState extends State<NovaVendaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();
  final TextEditingController _produtoController = TextEditingController();

  bool _anp = false;
  List<Map<String, dynamic>> _produtos = [];
  Map<String, dynamic>? _produtoSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    _placaController.addListener(_formatarPlaca);
  }

  Future<void> _carregarProdutos() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('produtos')
        .select('id, codigo, nome')
        .order('nome');
    
    setState(() {
      _produtos = List<Map<String, dynamic>>.from(response);
    });
  }

  void _formatarPlaca() {
    final text = _placaController.text.replaceAll('-', '').toUpperCase();
    if (text.length <= 3) {
      _placaController.text = text;
      _placaController.selection = TextSelection.collapsed(offset: text.length);
    } else if (text.length <= 7) {
      _placaController.text = '${text.substring(0, 3)}-${text.substring(3)}';
      _placaController.selection = TextSelection.collapsed(offset: _placaController.text.length);
    }
  }

  void _selecionarProdutoPorCodigo(String codigo) {
    final produto = _produtos.firstWhere(
      (p) => p['codigo'].toString() == codigo,
      orElse: () => {},
    );
    
    if (produto.isNotEmpty) {
      setState(() {
        _produtoSelecionado = produto;
        _produtoController.text = produto['nome'];
      });
    }
  }

  void _salvarVenda() {
    if (_formKey.currentState!.validate()) {
      // Implementar salvamento no Supabase
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda salva com sucesso!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Venda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvarVenda,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Campo Placa
              TextFormField(
                controller: _placaController,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  hintText: 'ABC-1234',
                ),
                maxLength: 8,
                buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
                    Text('$currentLength/$maxLength'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a placa';
                  }
                  if (value.length != 8) {
                    return 'Placa incompleta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo ANP
              SwitchListTile(
                title: const Text('ANP'),
                value: _anp,
                onChanged: (value) => setState(() => _anp = value),
              ),
              const SizedBox(height: 16),

              // Campo Cliente
              TextFormField(
                controller: _clienteController,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                ),
                maxLength: 25,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o cliente';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo Código
              TextFormField(
                controller: _codigoController,
                decoration: const InputDecoration(
                  labelText: 'CÓD.',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (value) {
                  if (value.length == 6) {
                    _selecionarProdutoPorCodigo(value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Campo Observações
              TextFormField(
                controller: _obsController,
                decoration: const InputDecoration(
                  labelText: 'OBS.',
                ),
                maxLength: 100,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Campo Produto
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _produtoSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Produto',
                ),
                items: _produtos.map((produto) {
                  return DropdownMenuItem(
                    value: produto,
                    child: Text('${produto['codigo']} - ${produto['nome']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _produtoSelecionado = value;
                    _codigoController.text = value?['codigo'].toString() ?? '';
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecione um produto';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _placaController.dispose();
    _clienteController.dispose();
    _codigoController.dispose();
    _obsController.dispose();
    _produtoController.dispose();
    super.dispose();
  }
}