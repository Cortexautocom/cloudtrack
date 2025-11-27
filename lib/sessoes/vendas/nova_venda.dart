// vendas/nova_venda.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaVendaPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(bool sucesso)? onSalvar;

  const NovaVendaPage({
    super.key,
    required this.onVoltar,
    this.onSalvar,
  });

  @override
  State<NovaVendaPage> createState() => _NovaVendaPageState();
}

class _NovaVendaPageState extends State<NovaVendaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _formaPagamentoController = TextEditingController();

  bool _carregando = false;
  List<Map<String, dynamic>> _produtos = [];
  
  // Lista de controladores para as placas
  final List<TextEditingController> _placasControllers = [
    TextEditingController(),
  ];
  
  // Lista de produtos selecionados
  final List<String?> _produtosSelecionados = [null];

  // Focus nodes para controle do teclado
  final FocusNode _quantidadeFocusNode = FocusNode();
  final FocusNode _formaPagamentoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    // Adiciona listener para todas as placas
    for (var controller in _placasControllers) {
      controller.addListener(_formatarPlaca);
    }
    _quantidadeController.addListener(_formatarQuantidade);
  }

  void _adicionarPlaca() {
    if (_placasControllers.length < 3) {
      setState(() {
        final novoController = TextEditingController();
        novoController.addListener(_formatarPlaca);
        _placasControllers.add(novoController);
      });
    }
  }

  void _removerPlaca(int index) {
    if (_placasControllers.length > 1) {
      setState(() {
        _placasControllers[index].dispose();
        _placasControllers.removeAt(index);
      });
    }
  }

  void _adicionarProduto() {
    if (_produtosSelecionados.length < 6) {
      setState(() {
        _produtosSelecionados.add(null);
      });
    }
  }

  void _removerProduto(int index) {
    if (_produtosSelecionados.length > 1) {
      setState(() {
        _produtosSelecionados.removeAt(index);
      });
    }
  }

  void _formatarPlaca() {
    for (var controller in _placasControllers) {
      final text = controller.text.replaceAll('-', '').toUpperCase();
      
      if (text.length <= 3) {
        if (controller.text != text) {
          controller.text = text;
          controller.selection = TextSelection.collapsed(offset: text.length);
        }
      } else if (text.length <= 7) {
        final formatted = '${text.substring(0, 3)}-${text.substring(3)}';
        if (controller.text != formatted) {
          controller.text = formatted;
          controller.selection = TextSelection.collapsed(offset: formatted.length);
        }
      } else {
        // Limita a 7 caracteres + traço = 8
        controller.text = text.substring(0, 7);
        controller.text = '${text.substring(0, 3)}-${text.substring(3, 7)}';
        controller.selection = TextSelection.collapsed(offset: 8);
      }
    }
  }

  void _formatarQuantidade() {
    final text = _quantidadeController.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (text.isEmpty) {
      _quantidadeController.text = '';
      _quantidadeController.selection = TextSelection.collapsed(offset: 0);
      return;
    }

    // Formata como 123.456
    String formatted = '';
    if (text.length <= 3) {
      formatted = text;
    } else if (text.length <= 6) {
      formatted = '${text.substring(0, text.length - 3)}.${text.substring(text.length - 3)}';
    } else {
      formatted = '${text.substring(0, text.length - 3)}.${text.substring(text.length - 3, text.length)}';
    }

    if (_quantidadeController.text != formatted) {
      _quantidadeController.text = formatted;
      _quantidadeController.selection = TextSelection.collapsed(offset: formatted.length);
    }
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregando = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('produtos')
          .select('id, codigo, nome')
          .order('nome');
      
      setState(() {
        _produtos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar produtos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  bool _validarFormulario() {
    // Verifica se pelo menos uma placa foi preenchida
    final placasPreenchidas = _placasControllers.where((controller) => 
      controller.text.isNotEmpty
    ).toList();
    
    if (placasPreenchidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos uma placa'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Verifica se pelo menos um produto foi selecionado
    final produtosSelecionados = _produtosSelecionados.where((produto) => 
      produto != null
    ).toList();
    
    if (produtosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um produto'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Verifica se o cliente foi preenchido
    if (_clienteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome do cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Verifica se a quantidade foi preenchida
    if (_quantidadeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a quantidade'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Verifica se a forma de pagamento foi preenchida
    if (_formaPagamentoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe a forma de pagamento'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _salvarVenda() async {
    if (!_validarFormulario()) return;

    setState(() => _carregando = true);
    try {
      final supabase = Supabase.instance.client;
      final usuario = Supabase.instance.client.auth.currentUser;
      
      // Remove pontos da quantidade e converte para double
      final quantidadeTexto = _quantidadeController.text.replaceAll('.', '');
      final quantidade = double.tryParse(quantidadeTexto) ?? 0;

      // Pega a primeira placa preenchida
      final placaPrincipal = _placasControllers.firstWhere(
        (controller) => controller.text.isNotEmpty,
        orElse: () => _placasControllers.first,
      ).text;

      // Pega o primeiro produto selecionado
      final produtoPrincipal = _produtosSelecionados.firstWhere(
        (produto) => produto != null,
        orElse: () => null,
      );

      await supabase.from('vendas').insert({
        'placa': placaPrincipal,
        'cliente': _clienteController.text,
        'observacoes': _obsController.text.isEmpty ? null : _obsController.text,
        'produto_id': produtoPrincipal,
        'quantidade': quantidade,
        'forma_pagamento': _formaPagamentoController.text,
        'usuario_id': usuario?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venda registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (widget.onSalvar != null) {
          widget.onSalvar!(true);
        } else {
          widget.onVoltar();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar venda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Widget _buildCampoPlacas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Placa do Veículo',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._placasControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              
              return SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Placa ${index + 1}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 8,
                      ),
                    ),
                    if (_placasControllers.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removerPlaca(index),
                        iconSize: 24,
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (_placasControllers.length < 3)
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: _placasControllers.length < 3 
                      ? const Color(0xFF0D47A1) 
                      : Colors.grey[300],
                  size: 30,
                ),
                onPressed: _placasControllers.length < 3 ? _adicionarPlaca : null,
              ),
          ],
        ),
        if (_placasControllers.length == 1)
          const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCampoProdutos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Text(
          'Produtos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        
        // Lista de produtos com ícone + na mesma linha e alinhado ao centro
        ..._produtosSelecionados.asMap().entries.map((entry) {
          final index = entry.key;
          final produtoSelecionado = entry.value;
          final isLast = index == _produtosSelecionados.length - 1;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // ← ALINHAMENTO CENTRALIZADO
              children: [
                // Campo flexível que ocupa o espaço disponível
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: produtoSelecionado,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.local_gas_station),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Selecione'),
                      ),
                      ..._produtos.map((produto) {
                        return DropdownMenuItem<String?>(
                          value: produto['id']?.toString(),
                          child: Text(produto['nome']),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _produtosSelecionados[index] = value;
                      });
                    },
                  ),
                ),
                
                // Espaço entre campo e ícones
                const SizedBox(width: 8),
                
                // Ícones de remover e adicionar - CENTRALIZADOS
                if (_produtosSelecionados.length > 1) 
                  Container(
                    height: 48, // ← ALTURA FIXA PARA CENTRALIZAR
                    alignment: Alignment.center, // ← CENTRALIZA O ÍCONE
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removerProduto(index),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                
                if (isLast && _produtosSelecionados.length < 6)
                  Container(
                    height: 48, // ← MESMA ALTURA PARA CENTRALIZAR
                    alignment: Alignment.center, // ← CENTRALIZA O ÍCONE
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: const Color(0xFF0D47A1),
                        size: 32,
                      ),
                      onPressed: _adicionarProduto,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCampoQuantidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantidade (Litros)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantidadeController,
          focusNode: _quantidadeFocusNode,
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: const Icon(Icons.oil_barrel),
            suffixText: 'L',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildFormaPagamento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Forma de Pagamento',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _formaPagamentoController,
          focusNode: _formaPagamentoFocusNode,
          decoration: InputDecoration(
            hintText: 'Selecione',
            prefixIcon: const Icon(Icons.payment),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLength: 25,
        ),
      ],
    );
  }  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Nova Venda',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onVoltar,
        ),
        actions: [
          if (!_carregando)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _salvarVenda,
              tooltip: 'Salvar venda',
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Align(
                alignment: Alignment.topLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Campo Placas
                        _buildCampoPlacas(),
                        const SizedBox(height: 20),
                        
                        // Campo Cliente
                        Text(
                          'Cliente',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _clienteController,
                          decoration: InputDecoration(
                            hintText: 'Cliente',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLength: 35,
                        ),
                        const SizedBox(height: 20),

                        // Campo Produtos
                        _buildCampoProdutos(),
                        const SizedBox(height: 20),
                        
                        // Campo Quantidade
                        _buildCampoQuantidade(),
                        const SizedBox(height: 20),
                        
                        // Forma de Pagamento
                        _buildFormaPagamento(),
                        const SizedBox(height: 20),

                        // Campo Observações
                        Text(
                          'Observações (Opcional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _obsController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLength: 100,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),

                        // Botão Salvar
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _salvarVenda,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'CONFIRMAR VENDA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  @override
  void dispose() {
    for (var controller in _placasControllers) {
      controller.dispose();
    }
    _clienteController.dispose();
    _obsController.dispose();
    _quantidadeController.dispose();
    _formaPagamentoController.dispose();
    _quantidadeFocusNode.dispose();
    _formaPagamentoFocusNode.dispose();
    super.dispose();
  }
}