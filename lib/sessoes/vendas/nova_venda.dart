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
  final TextEditingController _produtoSearchController = TextEditingController();
  final TextEditingController _formaPagamentoController = TextEditingController();

  bool _anp = false;
  bool _carregando = false;
  bool _mostrarListaProdutos = false;
  List<Map<String, dynamic>> _produtos = [];
  String? _produtoSelecionadoId;
  
  // Lista de controladores para as placas
  final List<TextEditingController> _placasControllers = [
    TextEditingController(),
  ];

  // Focus nodes para controle do teclado
  final FocusNode _produtoFocusNode = FocusNode();
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
    _produtoSearchController.addListener(_buscarProdutoInstantaneo);
    _quantidadeController.addListener(_formatarQuantidade);
    
    // Listener para fechar a lista de produtos quando clicar fora
    _produtoFocusNode.addListener(() {
      if (!_produtoFocusNode.hasFocus && _mostrarListaProdutos) {
        setState(() {
          _mostrarListaProdutos = false;
        });
      }
    });
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

  void _buscarProdutoInstantaneo() {
    final query = _produtoSearchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _produtoSelecionadoId = null;
      });
      return;
    }

    // Busca por código (apenas números)
    if (RegExp(r'^\d+$').hasMatch(query)) {
      final produto = _produtos.firstWhere(
        (p) => p['codigo'].toString() == query,
        orElse: () => {},
      );
      
      if (produto.isNotEmpty) {
        setState(() {
          _produtoSelecionadoId = produto['id'];
          _produtoSearchController.text = '${produto['codigo']} - ${produto['nome']}';
        });
        return;
      }
    }

    // Busca por nome (primeira ocorrência que contenha o texto)
    final produtoPorNome = _produtos.firstWhere(
      (p) => p['nome'].toString().toLowerCase().contains(query.toLowerCase()),
      orElse: () => {},
    );
    
    if (produtoPorNome.isNotEmpty) {
      setState(() {
        _produtoSelecionadoId = produtoPorNome['id'];
        _produtoSearchController.text = '${produtoPorNome['codigo']} - ${produtoPorNome['nome']}';
      });
    } else {
      setState(() {
        _produtoSelecionadoId = null;
      });
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

  Future<void> _salvarVenda() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_anp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirme a ANP para continuar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      return;
    }

    setState(() => _carregando = true);
    try {
      final supabase = Supabase.instance.client;
      final usuario = Supabase.instance.client.auth.currentUser;
      
      // Remove pontos da quantidade e converte para double
      final quantidadeTexto = _quantidadeController.text.replaceAll('.', '');
      final quantidade = double.tryParse(quantidadeTexto) ?? 0;

      // Pega a primeira placa preenchida
      final placaPrincipal = placasPreenchidas.first.text;

      await supabase.from('vendas').insert({
        'placa': placaPrincipal,
        'anp': _anp,
        'cliente': _clienteController.text,
        'observacoes': _obsController.text.isEmpty ? null : _obsController.text,
        'produto_id': _produtoSelecionadoId,
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

  Widget _buildANPCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _anp ? Colors.green : Colors.grey.shade300,
          width: _anp ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _anp ? Colors.green : Colors.transparent,
                border: Border.all(
                  color: _anp ? Colors.green : Colors.grey,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _anp
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Declaração ANP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _anp ? Colors.green : Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Confirmo que todas as informações estão corretas e de acordo com a legislação da ANP',
                    style: TextStyle(
                      color: _anp ? Colors.green : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _anp,
              onChanged: (value) => setState(() => _anp = value),
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
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
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._placasControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              
              return SizedBox(
                width: 140,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40, // Altura reduzida
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 8,
                          validator: (value) {
                            if (value != null && value.isNotEmpty && value.length != 8) {
                              return 'Placa incompleta';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    if (_placasControllers.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removerPlaca(index),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                  size: 28, // Tamanho reduzido
                ),
                onPressed: _placasControllers.length < 3 ? _adicionarPlaca : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        if (_placasControllers.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Clique no + para adicionar mais placas (máximo 3)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCampoProduto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Produto',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botão de informações dos produtos
            InkWell(
              onTap: () {
                setState(() {
                  _mostrarListaProdutos = !_mostrarListaProdutos;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mostrarListaProdutos ? Icons.visibility_off : Icons.visibility,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mostrarListaProdutos ? 'Ocultar' : 'Ver Produtos',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6), // Espaço reduzido
        Stack(
          children: [
            TextFormField(
              controller: _produtoSearchController,
              focusNode: _produtoFocusNode,
              decoration: InputDecoration(
                hintText: 'Código ou nome',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: _produtoSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _produtoSearchController.clear();
                          setState(() {
                            _produtoSelecionadoId = null;
                          });
                        },
                      )
                    : null,
              ),
              validator: (value) {
                if (_produtoSelecionadoId == null) {
                  return 'Selecione um produto';
                }
                return null;
              },
            ),
            
            // Lista de produtos (overlay)
            if (_mostrarListaProdutos && _produtos.isNotEmpty)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Lista de Produtos (${_produtos.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _produtos.length,
                            itemBuilder: (context, index) {
                              final produto = _produtos[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.local_gas_station, size: 18, color: Colors.grey),
                                title: Text(
                                  produto['nome'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  'Cód: ${produto['codigo']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _produtoSelecionadoId = produto['id'];
                                    _produtoSearchController.text = '${produto['codigo']} - ${produto['nome']}';
                                    _mostrarListaProdutos = false;
                                  });
                                  _produtoFocusNode.unfocus();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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
            prefixIcon: const Icon(Icons.speed),
            suffixText: 'Litros',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Informe a quantidade';
            }
            final quantidadeTexto = value.replaceAll('.', '');
            final quantidade = double.tryParse(quantidadeTexto);
            if (quantidade == null || quantidade <= 0) {
              return 'Quantidade deve ser maior que zero';
            }
            return null;
          },
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Informe a forma de pagamento';
            }
            return null;
          },
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
      body: GestureDetector(
        onTap: () {
          // Fecha a lista de produtos quando clicar fora
          if (_mostrarListaProdutos) {
            setState(() {
              _mostrarListaProdutos = false;
            });
          }
        },
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : Align( // ← ALTERADO: Align em vez de Center
                alignment: Alignment.topLeft, // ← ALINHADO À ESQUERDA
                child: Container( // ← ALTERADO: Container com maxWidth
                  constraints: const BoxConstraints(maxWidth: 700), // ← LARGURA MÁXIMA
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 8),
                        
                        // Campo Placas
                        _buildCampoPlacas(),
                        const SizedBox(height: 16),
                        
                        // Campo Cliente
                        Text(
                          'Cliente',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6), // Espaço reduzido
                        TextFormField(
                          controller: _clienteController,
                          decoration: InputDecoration(
                            hintText: 'Nome',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLength: 35, // Aumentado para 35 caracteres
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe o nome do cliente';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12), // Espaço reduzido

                        // Campo Produto
                        _buildCampoProduto(),
                        const SizedBox(height: 16),
                        
                        // Campo Quantidade
                        _buildCampoQuantidade(),
                        const SizedBox(height: 16),
                        
                        // Forma de Pagamento
                        _buildFormaPagamento(),
                        const SizedBox(height: 16),

                        // Campo Observações
                        TextFormField(
                          controller: _obsController,
                          decoration: InputDecoration(
                            labelText: 'Observações (Opcional)',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLength: 100,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // ANP
                        _buildANPCard(),
                        const SizedBox(height: 24),

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
    _produtoSearchController.dispose();
    _formaPagamentoController.dispose();
    _produtoFocusNode.dispose();
    _quantidadeFocusNode.dispose();
    _formaPagamentoFocusNode.dispose();
    super.dispose();
  }
}