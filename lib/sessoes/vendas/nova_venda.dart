import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaVendaDialog extends StatefulWidget {
  final Function(bool sucesso)? onSalvar;

  const NovaVendaDialog({
    super.key,
    this.onSalvar,
  });

  @override
  State<NovaVendaDialog> createState() => _NovaVendaDialogState();
}

class _NovaVendaDialogState extends State<NovaVendaDialog> {
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

  // Mapeamento de IDs de produtos para colunas
  static const Map<String, String> _produtoParaColuna = {
    '82c348c8-efa1-4d1a-953a-ee384d5780fc': 'g_comum',
    '93686e9d-6ef5-4f7c-a97d-b058b3c2c693': 'g_aditivada',
    '58ce20cf-f252-4291-9ef6-f4821f22c29e': 'd_s10',
    'c77a6e31-52f0-4fe1-bdc8-685dff83f3a1': 'd_s500',
    '66ca957a-5698-4a02-8c9e-987770b6a151': 'etanol',
    'cecab8eb-297a-4640-81ae-e88335b88d8b': 'anidro',
    'ecd91066-e763-42e3-8a0e-d982ea6da535': 'b100',
    'f8e95435-471a-424c-947f-def8809053a0': 'gasolina_a',
    '4da89784-301f-4abe-b97e-c48729969e3d': 's500_a',
    '3c26a7e5-8f3a-4429-a8c7-2e0e72f1b80a': 's10_a',
  };

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
      String formatted = text;

      if (text.length > 3) {
        final parte1 = text.substring(0, 3);
        final parte2 = text.substring(3, text.length > 7 ? 7 : text.length);
        formatted = '$parte1-$parte2';
      }

      // AQUI ESTÁ O SEGREDO: Só atualiza se o texto for diferente do atual
      if (controller.text != formatted) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  void _formatarQuantidade() {
    final text = _quantidadeController.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (text.isEmpty) {
      if (_quantidadeController.text != '') {
        _quantidadeController.text = '';
      }
      return;
    }

    String formatted = text;
    if (text.length > 3) {
      formatted = '${text.substring(0, text.length - 3)}.${text.substring(text.length - 3)}';
    }

    // Verifica antes de atribuir para evitar o loop
    if (_quantidadeController.text != formatted) {
      _quantidadeController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
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

      // Pega o primeiro produto selecionado
      final produtoPrincipal = _produtosSelecionados.firstWhere(
        (produto) => produto != null,
        orElse: () => null,
      );

      // Obtém a coluna correspondente ao produto
      final colunaProduto = _produtoParaColuna[produtoPrincipal];
      if (colunaProduto == null) {
        throw Exception('Produto selecionado não possui coluna correspondente');
      }

      // Prepara os dados para inserção
      final dadosVenda = {
        'placa': _placasControllers.where((c) => c.text.isNotEmpty).map((c) => c.text).toList(),
        'data_mov': DateTime.now().toIso8601String(),
        'tipo_op': 'venda',
        'tipo_mov': 'saida',
        'cliente': _clienteController.text,
        'observacoes': _obsController.text.isEmpty ? null : _obsController.text,
        'produto_id': produtoPrincipal,
        'quantidade': quantidade,
        'forma_pagamento': _formaPagamentoController.text,
        'usuario_id': usuario?.id,
        'uf': null,
        'codigo': null,
        'anp': false,
        colunaProduto: quantidade,
      };

      // Define zero nas outras colunas
      final todasColunas = [
        'g_comum', 'g_aditivada', 'd_s10', 'd_s500', 
        'etanol', 'anidro', 'b100', 'gasolina_a', 's500_a', 's10_a'
      ];
      
      for (var coluna in todasColunas) {
        if (coluna != colunaProduto) {
          dadosVenda[coluna] = 0;
        }
      }

      await supabase.from('movimentacoes').insert(dadosVenda);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venda registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (widget.onSalvar != null) {
          widget.onSalvar!(true);
        }
        Navigator.of(context).pop(true);
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                
                // Ícones de remover e adicionar
                if (_produtosSelecionados.length > 1) 
                  Container(
                    height: 48,
                    alignment: Alignment.center,
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
                    height: 48,
                    alignment: Alignment.center,
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
    return AlertDialog(
      backgroundColor: Colors.grey[50],
      insetPadding: const EdgeInsets.all(20),
      titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      contentPadding: const EdgeInsets.all(20),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'NOVA VENDA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            if (!_carregando)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(false),
              ),
          ],
        ),
      ),
      content: _carregando
          ? SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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

                      // Botões de ação
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _salvarVenda,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'SALVAR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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