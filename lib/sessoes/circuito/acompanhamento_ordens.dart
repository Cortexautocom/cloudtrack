import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class AcompanhamentoOrdensPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const AcompanhamentoOrdensPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<AcompanhamentoOrdensPage> createState() => _AcompanhamentoOrdensPageState();
}

class _AcompanhamentoOrdensPageState extends State<AcompanhamentoOrdensPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesFiltradas = [];
  List<Map<String, dynamic>> _filiais = [];
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _empresaId;
  
  final TextEditingController _filtroGeralController = TextEditingController();
  final TextEditingController _dataFiltroController = TextEditingController();
  String? _filialFiltroId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _filtroGeralController.addListener(_aplicarFiltros);
    _dataFiltroController.addListener(_aplicarFiltros);
  }

  Future<void> _carregarFiliais() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      if (usuario.nivel == 3) {
        final dados = await _supabase
            .from('filiais')
            .select('id, nome')
            .eq('empresa_id', _empresaId!)
            .order('nome');

        setState(() {
          _filiais = List<Map<String, dynamic>>.from(dados);
          if (_filialFiltroId == null && _filiais.isNotEmpty) {
            _filialFiltroId = _filiais.first['id'].toString();
          }
        });
      } else if (usuario.filialId != null) {
        final filialData = await _supabase
            .from('filiais')
            .select('id, nome')
            .eq('id', usuario.filialId!)
            .single();

        setState(() {
          _filiais = [filialData];
          _filialFiltroId = usuario.filialId;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar filiais: $e');
    }
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        throw Exception('Usuário não autenticado');
      }

      _empresaId = usuario.empresaId;

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Não foi possível identificar a empresa do usuário');
      }

      await _carregarFiliais();

      final String? filialUsuario = usuario.nivel == 3 
          ? _filialFiltroId
          : usuario.filialId;

      var query = _supabase
          .from('movimentacoes')
          .select('''
            id,
            placa,
            entrada_amb,
            saida_amb,
            cliente,
            status_circuito,
            data_mov,
            filial_id,
            empresa_id,
            tipo_op,
            filial_origem_id,
            filial_destino_id,
            produtos!produto_id(nome),
            filiais!estoques_filial_id_fkey(id, nome),
            filial_origem:filiais!movimentacoes_filial_origem_id_fkey(id, nome),
            filial_destino:filiais!movimentacoes_filial_destino_id_fkey(id, nome)
          ''')
          .eq('empresa_id', _empresaId!)
          .order('data_mov', ascending: false);

      final dados = await query;
      List<Map<String, dynamic>> movimentacoesFiltradas = [];

      if (usuario.nivel < 3) {
        if (filialUsuario != null) {
          movimentacoesFiltradas = dados.where((item) {
            final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
            final filialId = item['filial_id']?.toString();
            final filialOrigemId = item['filial_origem_id']?.toString();
            final filialDestinoId = item['filial_destino_id']?.toString();
            
            if (tipoOp == 'usina') {
              return filialDestinoId == filialUsuario;
            } else if (tipoOp == 'transf') {
              return filialOrigemId == filialUsuario || filialDestinoId == filialUsuario;
            } else if (tipoOp == 'venda') {
              return filialId == filialUsuario;
            }
            return false;
          }).toList();
        }
      } else if (usuario.nivel == 3) {
        if (_filialFiltroId != null && _filialFiltroId!.isNotEmpty) {
          movimentacoesFiltradas = dados.where((item) {
            final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
            final filialId = item['filial_id']?.toString();
            final filialOrigemId = item['filial_origem_id']?.toString();
            final filialDestinoId = item['filial_destino_id']?.toString();
            
            if (tipoOp == 'usina') {
              return filialDestinoId == _filialFiltroId;
            } else if (tipoOp == 'transf') {
              return filialOrigemId == _filialFiltroId || filialDestinoId == _filialFiltroId;
            } else if (tipoOp == 'venda') {
              return filialId == _filialFiltroId;
            }
            return false;
          }).toList();
        } else {
          movimentacoesFiltradas = List<Map<String, dynamic>>.from(dados);
        }
      }

      if (mounted) {
        setState(() {
          _movimentacoes = movimentacoesFiltradas;
          _movimentacoesFiltradas = List.from(movimentacoesFiltradas);
          _carregando = false;
        });
      }
      
    } catch (e) {
      debugPrint('Erro ao carregar movimentações: $e');
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = true;
          _mensagemErro = e.toString();
        });
      }
    }
  }

  void _aplicarFiltros() {
    final termoBusca = _filtroGeralController.text.toLowerCase().trim();
    final dataFiltro = _dataFiltroController.text.trim();
    
    List<Map<String, dynamic>> resultado = List.from(_movimentacoes);

    if (_filialFiltroId != null) {
      resultado = resultado.where((item) {
        final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
        
        if (tipoOp == 'usina') {
          return item['filial_destino_id'] == _filialFiltroId;
        } else if (tipoOp == 'transf') {
          return item['filial_origem_id'] == _filialFiltroId || 
                 item['filial_destino_id'] == _filialFiltroId;
        } else {
          return item['filial_id'] == _filialFiltroId;
        }
      }).toList();
    }

    if (dataFiltro.isNotEmpty) {
      resultado = resultado.where((item) {
        final dataMov = item['data_mov']?.toString() ?? '';
        if (dataMov.isEmpty) return false;
        
        try {
          final data = DateTime.parse(dataMov);
          final dataFormatada = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
          return dataFormatada.contains(dataFiltro);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    if (termoBusca.isNotEmpty) {
      resultado = resultado.where((item) {
        final placa = _formatarPlacaParaBusca(item['placa'] ?? '');
        final cliente = (item['cliente'] ?? '').toString().toLowerCase();
        final quantidade = _obterQuantidade(item).toString();
        final filial = _obterNomeFilialParaBusca(item).toLowerCase();
        final status = _obterStatusTexto(item['status_circuito']).toLowerCase();
        final tipoOp = (item['tipo_op'] ?? '').toString().toLowerCase();

        return placa.toLowerCase().contains(termoBusca) ||
               cliente.contains(termoBusca) ||
               quantidade.contains(termoBusca) ||
               filial.contains(termoBusca) ||
               status.contains(termoBusca) ||
               tipoOp.contains(termoBusca);
      }).toList();
    }

    setState(() {
      _movimentacoesFiltradas = resultado;
    });
  }

  String _obterNomeFilialParaBusca(Map<String, dynamic> item) {
    final tipoOp = (item['tipo_op']?.toString() ?? 'venda').toLowerCase();
    
    if (tipoOp == 'usina') {
      final filialDestino = item['filial_destino'] as Map<String, dynamic>?;
      return filialDestino?['nome']?.toString() ?? '';
    } else if (tipoOp == 'transf') {
      final filialOrigem = item['filial_origem'] as Map<String, dynamic>?;
      final filialDestino = item['filial_destino'] as Map<String, dynamic>?;
      final origemNome = filialOrigem?['nome']?.toString() ?? '';
      final destinoNome = filialDestino?['nome']?.toString() ?? '';
      return '$origemNome $destinoNome';
    } else {
      final filial = item['filiais'] as Map<String, dynamic>?;
      return filial?['nome']?.toString() ?? '';
    }
  }

  String _formatarPlacaParaBusca(dynamic placaData) {
    if (placaData == null) return '';
    
    if (placaData is List) {
      return placaData.join(', ');
    } else if (placaData is String) {
      try {
        if (placaData.startsWith('{') && placaData.endsWith('}')) {
          final limpo = placaData.substring(1, placaData.length - 1);
          return limpo.split(',').map((p) => p.trim()).join(', ');
        }
        return placaData;
      } catch (e) {
        return placaData.toString();
      }
    }
    return placaData.toString();
  }

  String _obterQuantidadeFormatada(Map<String, dynamic> movimentacao) {
    final quantidade = _obterQuantidade(movimentacao);
    return _formatarNumero(quantidade);
  }

  String _formatarNumero(int valor) {
    if (valor == 0) return '0';
    
    String valorString = valor.toString();
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    return resultado;
  }

  int _obterQuantidade(Map<String, dynamic> movimentacao) {
    final entradaAmb = movimentacao['entrada_amb'];
    final saidaAmb = movimentacao['saida_amb'];
    
    if (entradaAmb != null && entradaAmb > 0) {
      return entradaAmb as int;
    } else if (saidaAmb != null && saidaAmb > 0) {
      return saidaAmb as int;
    }
    return 0;
  }

  String _obterTipoMovimentacao(Map<String, dynamic> movimentacao) {
    final entradaAmb = movimentacao['entrada_amb'];
    final saidaAmb = movimentacao['saida_amb'];
    
    if (entradaAmb != null && entradaAmb > 0) {
      return 'Entrada';
    } else if (saidaAmb != null && saidaAmb > 0) {
      return 'Saída';
    }
    return 'N/A';
  }

  String _obterStatusTexto(dynamic statusCodigo) {
    if (statusCodigo == null) return 'Sem status';
    
    final codigo = statusCodigo is int ? statusCodigo : int.tryParse(statusCodigo.toString());
    
    switch (codigo) {
      case 1: return 'Programado';
      case 2: return 'Em check-list';
      case 3: return 'Em operação';
      case 4: return 'Aguardando NF';
      case 5: return 'Expedido';
      default: return 'Sem status';
    }
  }

  Color _obterCorStatus(dynamic statusCodigo) {
    if (statusCodigo == null) return Colors.grey;
    
    final codigo = statusCodigo is int ? statusCodigo : int.tryParse(statusCodigo.toString());
    
    switch (codigo) {
      case 1: return Colors.blue.shade700;
      case 2: return Colors.orange.shade700;
      case 3: return Colors.green.shade700;
      case 4: return Colors.purple.shade700;
      case 5: return Colors.grey.shade700;
      default: return Colors.grey;
    }
  }

  String _obterTipoOpTexto(String tipoOp) {
    switch (tipoOp.toLowerCase()) {
      case 'transf':
        return 'Transferência';
      case 'venda':
        return 'Venda';
      case 'emprestimo':
        return 'Empréstimo';
      case 'outras_op':
        return 'Outras Op.';
      default:
        return tipoOp;
    }
  }

  Color _obterCorTipoOp(String tipoOp) {
    switch (tipoOp.toLowerCase()) {
      case 'usina':
        return Colors.blue.shade700;
      case 'transf':
        return Colors.purple.shade700;
      case 'venda':
        return Colors.green.shade700;
      case 'emprestimo':
        return Colors.orange.shade700;
      case 'outras_op':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatarPlacas(dynamic placaData) {
    if (placaData == null) return 'N/I';
    
    if (placaData is List) {
      return placaData.where((p) => p != null && p.toString().isNotEmpty)
                      .map((p) => p.toString())
                      .join(', ');
    } else if (placaData is String) {
      try {
        if (placaData.startsWith('{') && placaData.endsWith('}')) {
          final limpo = placaData.substring(1, placaData.length - 1);
          final placas = limpo.split(',')
                              .map((p) => p.trim())
                              .where((p) => p.isNotEmpty && p != 'null')
                              .toList();
          return placas.join(', ');
        }
        return placaData;
      } catch (e) {
        return placaData;
      }
    }
    return placaData.toString();
  }

  String _formatarData(String? dataString) {
    if (dataString == null) return 'Data não informada';
    
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }

  String _obterDescricaoParaCard(Map<String, dynamic> movimentacao) {
    final tipoOp = (movimentacao['tipo_op']?.toString() ?? 'venda').toLowerCase();
    
    if (tipoOp == 'transf') {
      final origem = movimentacao['filial_origem'] as Map<String, dynamic>?;
      final destino = movimentacao['filial_destino'] as Map<String, dynamic>?;
      final origemNome = origem?['nome']?.toString() ?? 'Origem';
      final destinoNome = destino?['nome']?.toString() ?? 'Destino';
      return '$origemNome → $destinoNome';
    } else if (tipoOp == 'venda') {
      final cliente = movimentacao['cliente']?.toString() ?? '';
      return cliente.isNotEmpty ? cliente : 'Cliente não informado';
    } else {
      // Para outros tipos, você pode adicionar lógica específica se necessário
      final filial = movimentacao['filiais'] as Map<String, dynamic>?;
      return filial?['nome']?.toString() ?? 'Filial não informada';
    }
  }

  Widget _buildFiltros() {
    final usuario = UsuarioAtual.instance;
    final mostraFiltroFilial = usuario?.nivel == 3;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (mostraFiltroFilial) ...[
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _filialFiltroId,
                  decoration: InputDecoration(
                    labelText: 'Filial *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    suffixIcon: _filialFiltroId == null 
                        ? Icon(Icons.error, color: Colors.orange, size: 20)
                        : null,
                  ),
                  items: _filiais.map((filial) {
                    return DropdownMenuItem(
                      value: filial['id'].toString(),
                      child: Text(filial['nome'].toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filialFiltroId = value;
                    });
                    _carregarDados();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecione uma filial';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            Expanded(
              flex: 2,
              child: TextField(
                controller: _dataFiltroController,
                decoration: InputDecoration(
                  labelText: 'Data (DD/MM)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              flex: 3,
              child: TextField(
                controller: _filtroGeralController,
                decoration: InputDecoration(
                  labelText: 'Buscar (placa, cliente, status...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 20),
          Text(
            'Carregando ordens...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _mensagemErro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSemDados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.list_alt_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma ordem encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Não há movimentações registradas no momento.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarDados,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Color _obterCorFundoCard(Map<String, dynamic> movimentacao) {
    final tipoMovimentacao = _obterTipoMovimentacao(movimentacao);
    
    if (tipoMovimentacao == 'Entrada') {
      return Colors.blue.shade50; // Azul claro para entrada
    } else if (tipoMovimentacao == 'Saída') {
      return Colors.red.shade50; // Vermelho claro para saída
    }
    
    return Colors.white; // Branco para outros casos
  }

  Widget _buildItemOrdem(Map<String, dynamic> movimentacao, int index) {
    final tipoOp = movimentacao['tipo_op']?.toString() ?? 'venda';
    final tipoOpTexto = _obterTipoOpTexto(tipoOp);
    final descricao = _obterDescricaoParaCard(movimentacao);
    final statusCodigo = movimentacao['status_circuito'];
    final statusTexto = _obterStatusTexto(statusCodigo);
    final statusCor = _obterCorStatus(statusCodigo);
    final tipoOpCor = _obterCorTipoOp(tipoOp);
    
    // Dados da segunda linha
    final placasFormatadas = _formatarPlacas(movimentacao['placa']);
    final quantidadeFormatada = _obterQuantidadeFormatada(movimentacao);
    final dataMov = _formatarData(movimentacao['data_mov']?.toString());
    
    // Cor de fundo do card baseada no tipo de movimento
    final corFundoCard = _obterCorFundoCard(movimentacao);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: corFundoCard,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              debugPrint('Clicou na ordem: ${movimentacao['id']} (tipo: $tipoOp)');
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status (ocupando as duas linhas, 100px de largura)
                  Container(
                    width: 100,
                    height: 60, // Altura para ocupar as duas linhas
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: statusCor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusCor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          statusTexto,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusCor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PRIMEIRA LINHA: Tipo da operação e Descrição
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tipo da operação
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tipoOpCor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tipoOpCor.withOpacity(0.3)),
                              ),
                              child: Text(
                                tipoOpTexto,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tipoOpCor,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Descrição
                            Expanded(
                              child: Text(
                                descricao,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // SEGUNDA LINHA: Detalhes da ordem
                        Row(
                          children: [
                            // Data
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dataMov,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Placas
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.directions_car,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      placasFormatadas,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Quantidade (alinhada à esquerda)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$quantidadeFormatada Amb.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Ícone de seta
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
    _filtroGeralController.dispose();
    _dataFiltroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acompanhamento de Ordens',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Circuito > Ordens',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVoltar,
        ),
        actions: [
          if (!_carregando && !_erro)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDados,
              tooltip: 'Atualizar ordens',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltros(),
            
            Expanded(
              child: _carregando
                  ? _buildCarregando()
                  : _erro
                      ? _buildErro()
                      : _movimentacoesFiltradas.isEmpty
                          ? _buildSemDados()
                          : ListView.builder(
                              itemCount: _movimentacoesFiltradas.length,
                              itemBuilder: (context, index) {
                                return _buildItemOrdem(
                                  _movimentacoesFiltradas[index],
                                  index,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _determinarEntradaSaida(Map<String, dynamic> movimentacao, {String? filialEspecifica}) {
    final tipoOp = (movimentacao['tipo_op']?.toString() ?? 'venda').toLowerCase();
    final filialOrigemId = movimentacao['filial_origem_id']?.toString();
    final filialDestinoId = movimentacao['filial_destino_id']?.toString();
    
    final usuario = UsuarioAtual.instance;
    final filialParaComparar = filialEspecifica ?? usuario?.filialId;
    
    if (tipoOp == 'usina') {
      return 'Entrada';
    } else if (tipoOp == 'transf') {
      if (filialParaComparar != null) {
        if (filialOrigemId == filialParaComparar) {
          return 'Saída';
        } else if (filialDestinoId == filialParaComparar) {
          return 'Entrada';
        }
      }
      return 'Transferência';
    } else if (tipoOp == 'venda') {
      return 'Saída';
    }
    
    return 'Indefinido';
  }

  Color _obterCorEntradaSaida(String tipo) {
    switch (tipo) {
      case 'Entrada':
        return Colors.green.shade700;
      case 'Saída':
        return Colors.red.shade700;
      case 'Transferência':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}