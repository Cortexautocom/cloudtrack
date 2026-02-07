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
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _accent = Color(0xFF1B6A6F);
  static const Color _line = Color(0xFFE6DCCB);
  static const Color _muted = Color(0xFF5A6B7A);
  static const Color _warn = Color(0xFFC17D2D);

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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line, width: 1)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: _ink),
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
                        color: _ink
                      ),
                    ),
                    if (_nomeFilial != null && !_editando)
                      Text(
                        'Filial: $_nomeFilial',
                        style: TextStyle(
                          fontSize: 12, 
                          color: _accent, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                  ],
                ),
              ),
              if (!_editando)
                IconButton(
                  icon: const Icon(Icons.refresh, color: _ink),
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
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 16),
            Text('Carregando tanques...', style: TextStyle(fontSize: 16, color: _ink)),
          ],
        ),
      );
    }

    if (tanques.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 64, color: _muted),
            const SizedBox(height: 16),
            Text(
              'Nenhum tanque encontrado',
              style: const TextStyle(fontSize: 16, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              widget.filialSelecionadaId != null && UsuarioAtual.instance!.nivel == 3
                ? 'Não há tanques cadastrados para esta filial'
                : 'Não há tanques cadastrados',
              style: const TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.storage, color: _accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Painel de Tanques',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Visao geral e acesso rapido aos dados do tanque.',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withOpacity(0.6), width: 1.2),
                  ),
                  child: Text(
                    '${tanques.length} registros',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEstatisticaCompacta('Total', tanques.length.toString(), Icons.storage),
                Container(height: 36, width: 1.2, color: _line),
                _buildEstatisticaCompacta(
                  'Em operacao',
                  tanques.where((t) => t['status'] == 'Em operação').length.toString(),
                  Icons.check_circle,
                ),
                Container(height: 36, width: 1.2, color: _line),
                _buildEstatisticaCompacta(
                  'Suspensos',
                  tanques.where((t) => t['status'] == 'Operação suspensa').length.toString(),
                  Icons.pause_circle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: tanques.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tanque = tanques[index];
                final isOperando = tanque['status'] == 'Em operação';
                final statusColor = isOperando ? _accent : _warn;

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _editarTanque(tanque),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 56,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tanque['referencia'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tanque['produto'],
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                ),
                              ),
                              if (UsuarioAtual.instance!.nivel == 3 && tanque['filial'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Filial: ${tanque['filial']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _line, width: 1.2),
                              ),
                              child: Text(
                                '${tanque['capacidade']} Litros',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: statusColor, width: 1.2),
                              ),
                              child: Text(
                                tanque['status'],
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editarTanque(tanque),
                          color: _ink,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
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
            Icon(icone, size: 16, color: _accent),
            const SizedBox(width: 4),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          titulo,
          style: const TextStyle(fontSize: 11, color: _muted),
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
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final fieldWidth = isWide
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.tune, color: _accent),
                            SizedBox(width: 8),
                            Text(
                              'Editar Tanque',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Atualize os dados operacionais do tanque.',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 18),

                        if (_nomeFilial != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _accent.withOpacity(0.6), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 16, color: _accent),
                                const SizedBox(width: 8),
                                Text(
                                  'Filial: $_nomeFilial',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_nomeFilial != null) const SizedBox(height: 18),

                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _referenciaController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Referência *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.tag, color: _accent),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: _capacidadeController,
                                decoration: const InputDecoration(
                                  labelText: 'Capacidade *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.analytics, color: _accent),
                                  suffixText: 'Litros',
                                  hintText: '1.000',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: _aplicarMascaraCapacidade,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                value: _produtoSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Produto *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.local_gas_station, color: _accent),
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
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: DropdownButtonFormField<String>(
                                value: _statusSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Status *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.info, color: _accent),
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelarEdicao,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: _accent, width: 1.4),
                                  foregroundColor: _accent,
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _salvarTanque,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ink,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Salvar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}