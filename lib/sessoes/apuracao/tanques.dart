import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';
//import 'escolherfilial.dart';

class GerenciamentoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String? filialSelecionadaId; // ← NOVO PARÂMETRO

  const GerenciamentoTanquesPage({
    super.key, 
    required this.onVoltar,
    this.filialSelecionadaId, // ← NOVO PARÂMETRO
  });

  @override
  State<GerenciamentoTanquesPage> createState() => _GerenciamentoTanquesPageState();
}

class _GerenciamentoTanquesPageState extends State<GerenciamentoTanquesPage> {
  List<Map<String, dynamic>> tanques = [];
  List<Map<String, dynamic>> produtos = [];
  bool _carregando = true;
  bool _editando = false;
  Map<String, dynamic>? _tanqueEditando;
  String? _nomeFilial; // ← PARA MOSTRAR O NOME DA FILIAL

  final List<String> _statusOptions = ['Em operação', 'Operação suspensa'];
  
  // Controladores para o formulário de edição
  final TextEditingController _referenciaController = TextEditingController();
  final TextEditingController _capacidadeController = TextEditingController();
  String? _produtoSelecionado;
  String? _statusSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;

      // Carrega produtos
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      setState(() {
        produtos = List<Map<String, dynamic>>.from(produtosResponse);
      });

      // ---------------------------
      //   BUSCAR NOME DA FILIAL (SE FOR ADMIN)
      // ---------------------------
      String? nomeFilial;
      if (usuario.nivel == 3 && widget.filialSelecionadaId != null) {
        final filialData = await supabase
            .from('filiais')
            .select('nome')
            .eq('id', widget.filialSelecionadaId!)
            .single();
        nomeFilial = filialData['nome'];
      } else if (usuario.filialId != null) {
        final filialData = await supabase
            .from('filiais')
            .select('nome')
            .eq('id', usuario.filialId!)
            .single();
        nomeFilial = filialData['nome'];
      }

      // Carrega tanques
      final PostgrestTransformBuilder<dynamic> query;
      
      // ---------------------------
      //   ADMINISTRADOR (NÍVEL 3)
      // ---------------------------
      if (usuario.nivel == 3) {
        // Verifica se tem filial selecionada
        if (widget.filialSelecionadaId == null) {
          print("ERRO: Admin não escolheu filial para visualizar tanques");
          setState(() {
            _carregando = false;
            tanques = []; // Lista vazia
            _nomeFilial = null;
          });
          return;
        }
        
        query = supabase
            .from('tanques')
            .select('''
              id,
              referencia,
              capacidade,
              status,
              id_produto,
              id_filial,
              produtos (nome),
              filiais (nome)
            ''')
            .eq('id_filial', widget.filialSelecionadaId!) // ← FILTRAR pela filial escolhida
            .order('referencia');
      } 
      // ---------------------------
      //   USUÁRIO NORMAL
      // ---------------------------
      else {
        final idFilial = usuario.filialId;
        if (idFilial == null) {
          print('Erro: ID da filial não encontrado para usuário não-admin');
          setState(() {
            _carregando = false;
            _nomeFilial = null;
          });
          return;
        }
        
        query = supabase
            .from('tanques')
            .select('''
              id,
              referencia,
              capacidade,
              status,
              id_produto,
              produtos (nome)
            ''')
            .eq('id_filial', idFilial)
            .order('referencia');
      }

      final tanquesResponse = await query;

      final List<Map<String, dynamic>> tanquesFormatados = [];
      
      for (final tanque in tanquesResponse) {
        // Corrigir o acesso ao nome da filial
        String? nomeFilial;
        if (usuario.nivel == 3) {
          // Para admin, acessa o objeto aninhado filiais
          if (tanque['filiais'] != null) {
            nomeFilial = tanque['filiais'] is Map 
                ? tanque['filiais']['nome']?.toString()
                : tanque['filiais']?.toString();
          }
        }

        tanquesFormatados.add({
          'id': tanque['id'],
          'referencia': tanque['referencia']?.toString() ?? 'SEM REFERÊNCIA',
          'produto': tanque['produtos']?['nome']?.toString() ?? 'PRODUTO NÃO INFORMADO',
          'capacidade': tanque['capacidade']?.toString() ?? '0',
          'status': tanque['status']?.toString() ?? 'Em operação',
          'id_produto': tanque['id_produto'],
          // Adicionar nome da filial se for admin
          'filial': nomeFilial,
        });
      }

      setState(() {
        tanques = tanquesFormatados;
        _carregando = false;
        _nomeFilial = nomeFilial;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _nomeFilial = null;
      });
      print('Erro ao carregar dados: $e');
    }
  }

  void _editarTanque(Map<String, dynamic> tanque) {
    setState(() {
      _editando = true;
      _tanqueEditando = tanque;
      _referenciaController.text = tanque['referencia'];
      
      // Formata a capacidade existente para o novo padrão
      final capacidade = tanque['capacidade'];
      if (capacidade != null && capacidade.isNotEmpty) {
        final valorNumerico = int.tryParse(capacidade.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        if (valorNumerico >= 1000) {
          final parteMilhar = (valorNumerico ~/ 1000).toString();
          _capacidadeController.text = '${parteMilhar}.000';
        } else {
          _capacidadeController.text = '1.000'; // Valor mínimo
        }
      } else {
        _capacidadeController.text = '1.000'; // Valor padrão
      }
      
      _produtoSelecionado = tanque['id_produto']?.toString();
      _statusSelecionado = tanque['status'];
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editando = false;
      _tanqueEditando = null;
      _referenciaController.clear();
      _capacidadeController.clear();
      _produtoSelecionado = null;
      _statusSelecionado = null;
    });
  }

  // Função para aplicar máscara no campo capacidade
  void _aplicarMascaraCapacidade(String valor) {
    // Se o texto já está formatado corretamente, não faz nada
    if (valor.endsWith('.000') && valor.length > 4) {
      return;
    }

    // Remove todos os caracteres não numéricos
    String digitsOnly = valor.replaceAll(RegExp(r'[^\d]'), '');
    
    // Se estiver vazio, define como 1.000
    if (digitsOnly.isEmpty) {
      _capacidadeController.text = '1.000';
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: 1),
      );
      return;
    }
    
    // Remove zeros à esquerda, mas garante pelo menos 1
    int valorNumerico = int.parse(digitsOnly);
    if (valorNumerico < 1) {
      valorNumerico = 1;
    }
    
    // Formata como X.000
    final parteMilhar = valorNumerico.toString();
    final novoTexto = '${parteMilhar}.000';
    
    // Só atualiza se for diferente do texto atual
    if (_capacidadeController.text != novoTexto) {
      _capacidadeController.text = novoTexto;
      
      // Posiciona o cursor antes do ponto
      final cursorPosition = parteMilhar.length;
      _capacidadeController.selection = TextSelection.fromPosition(
        TextPosition(offset: cursorPosition),
      );
    }
  }

  Future<void> _salvarTanque() async {
    // Validação do valor mínimo
    final capacidadeTexto = _capacidadeController.text.trim();
    final valorNumerico = int.tryParse(capacidadeTexto.replaceAll('.', '')) ?? 0;
    
    if (valorNumerico < 1000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('A capacidade deve ser de no mínimo 1.000 litros'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final usuario = UsuarioAtual.instance!;
      
      // Determinar id_filial para o tanque
      String? idFilial;
      if (usuario.nivel == 3) {
        // Admin usa a filial selecionada
        idFilial = widget.filialSelecionadaId;
      } else {
        // Usuário normal usa sua própria filial
        idFilial = usuario.filialId;
      }

      if (idFilial == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erro: Não foi possível determinar a filial'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final Map<String, dynamic> dadosAtualizados = {
        'referencia': _referenciaController.text.trim(),
        'capacidade': capacidadeTexto,
        'status': _statusSelecionado,
        'id_produto': _produtoSelecionado,
        'id_filial': idFilial, // ← Sempre definir a filial
      };

      if (_tanqueEditando != null) {
        // Atualizar tanque existente
        await supabase
            .from('tanques')
            .update(dadosAtualizados)
            .eq('id', _tanqueEditando!['id']);
      } else {
        // Criar novo tanque (se implementar criação futura)
        // await supabase.from('tanques').insert(dadosAtualizados);
      }

      // Recarrega os dados
      await _carregarDados();
      
      // Volta para a lista
      _cancelarEdicao();

      // Mostra mensagem de sucesso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tanque ${_tanqueEditando != null ? 'atualizado' : 'criado'} com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar tanque: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _referenciaController.dispose();
    _capacidadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: _editando ? _cancelarEdicao : widget.onVoltar,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _editando ? 'Editar Tanque' : 'Gerenciamento de Tanques',
                      style: const TextStyle(
                        fontSize: 19, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.black87
                      ),
                    ),
                    if (_nomeFilial != null && !_editando)
                      Text(
                        'Filial: $_nomeFilial',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.green.shade700, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                  ],
                ),
              ),
              if (!_editando)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                  onPressed: _carregarDados,
                  tooltip: 'Recarregar',
                ),
            ]),
          ),

          // Conteúdo
          Expanded(
            child: _editando 
                ? _buildFormularioEdicao()
                : _buildListaTanques(),
          ),
        ],
      ),
    );
  }

  Widget _buildListaTanques() {
    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0D47A1)),
            SizedBox(height: 16),
            Text('Carregando tanques...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (tanques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhum tanque encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.filialSelecionadaId != null && UsuarioAtual.instance!.nivel == 3
                ? 'Não há tanques cadastrados para esta filial'
                : 'Não há tanques cadastrados',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card de estatísticas COMPACTO
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEstatisticaCompacta('Total', tanques.length.toString(), Icons.storage),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  _buildEstatisticaCompacta(
                    'Em operação', 
                    tanques.where((t) => t['status'] == 'Em operação').length.toString(), 
                    Icons.check_circle
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  _buildEstatisticaCompacta(
                    'Suspensos', 
                    tanques.where((t) => t['status'] == 'Operação suspensa').length.toString(), 
                    Icons.pause_circle
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista de tanques
          Expanded(
            child: ListView.builder(
              itemCount: tanques.length,
              itemBuilder: (context, index) {
                final tanque = tanques[index];
                final isOperando = tanque['status'] == 'Em operação';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOperando ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOperando ? Icons.storage : Icons.pause_circle,
                        color: isOperando ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tanque['referencia'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tanque['produto'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              // Mostrar filial apenas para admin quando houver múltiplas filiais
                              if (UsuarioAtual.instance!.nivel == 3 && tanque['filial'] != null)
                                Text(
                                  'Filial: ${tanque['filial']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tag de Capacidade
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            '${tanque['capacidade']} Litros',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tag de Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOperando ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOperando ? Colors.green.shade200 : Colors.orange.shade200,
                            ),
                          ),
                          child: Text(
                            tanque['status'],
                            style: TextStyle(
                              color: isOperando ? Colors.green.shade800 : Colors.orange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botão de edição
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editarTanque(tanque),
                          color: const Color(0xFF0D47A1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    onTap: () => _editarTanque(tanque),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstatisticaCompacta(String titulo, String valor, IconData icone) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: const Color(0xFF0D47A1)),
            const SizedBox(width: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildFormularioEdicao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informações do Tanque',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mostrar filial atual (se aplicável)
                      if (_nomeFilial != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.business, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Filial: $_nomeFilial',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      if (_nomeFilial != null) const SizedBox(height: 16),

                      // Referência
                      TextFormField(
                        controller: _referenciaController,
                        decoration: const InputDecoration(
                          labelText: 'Referência *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Capacidade com máscara
                      TextFormField(
                        controller: _capacidadeController,
                        decoration: const InputDecoration(
                          labelText: 'Capacidade *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.analytics),
                          suffixText: 'Litros',
                          hintText: '1.000',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: _aplicarMascaraCapacidade,
                      ),
                      const SizedBox(height: 16),

                      // Produto
                      DropdownButtonFormField<String>(
                        value: _produtoSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Produto *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_gas_station),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Selecione um produto'),
                          ),
                          ...produtos.map((produto) {
                            return DropdownMenuItem(
                              value: produto['id']?.toString(),
                              child: Text(produto['nome']?.toString() ?? ''),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _produtoSelecionado = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status
                      DropdownButtonFormField<String>(
                        value: _statusSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Status *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info),
                        ),
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _statusSelecionado = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Botões
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancelarEdicao,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFF0D47A1)),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: Color(0xFF0D47A1)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _salvarTanque,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Salvar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}