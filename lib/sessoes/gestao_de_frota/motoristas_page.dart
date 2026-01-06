import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MotoristasPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const MotoristasPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<MotoristasPage> createState() => _MotoristasPageState();
}

class _MotoristasPageState extends State<MotoristasPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _motoristas = [];
  bool _carregando = true;
  bool _editando = false;
  Map<String, dynamic>? _motoristaEditando;
  String? _campoEditando;
  TextEditingController _controller = TextEditingController();
  int _paginaAtual = 0;
  final int _itensPorPagina = 20;
  
  // Filtro por estado
  String? _filtroEstado;
  List<String> _estadosDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _carregarMotoristas();
  }

  Future<void> _carregarMotoristas() async {
    setState(() => _carregando = true);
    
    try {
      // Primeiro carrega os estados disponíveis (você pode precisar ajustar isso
      // dependendo de como seus dados estão estruturados)
      _carregarEstados();
      
      // Consulta inicial
      var query = _supabase
          .from('motoristas')
          .select('*')
          .order('nome', ascending: true)
          .order('nome_2', ascending: true);

      // Aplica filtro de estado se houver
      if (_filtroEstado != null) {
        // Ajuste este filtro conforme a estrutura dos seus dados
        // Se não tiver campo estado, você pode remover esta parte
        // ou usar outro campo para filtrar
      }

      final dados = await query;
      
      setState(() {
        _motoristas = List<Map<String, dynamic>>.from(dados);
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar motoristas: $e');
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar motoristas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _carregarEstados() {
    // Esta função carrega os estados disponíveis para filtro
    // Se você não tiver um campo específico para estado, pode usar
    // outro critério ou remover a filtragem por estado
    setState(() {
      _estadosDisponiveis = [
        'Todos',
        'SP',
        'RJ',
        'MG',
        // Adicione outros estados conforme necessário
      ];
    });
  }

  Future<void> _atualizarCampo(
    String motoristaId,
    String campo,
    dynamic valor,
  ) async {
    try {
      await _supabase
          .from('motoristas')
          .update({campo: valor})
          .eq('id', motoristaId);

      // Atualiza a lista local
      setState(() {
        final index = _motoristas.indexWhere((m) => m['id'] == motoristaId);
        if (index != -1) {
          _motoristas[index][campo] = valor;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campo atualizado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar campo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _iniciarEdicao(Map<String, dynamic> motorista, String campo) {
    setState(() {
      _editando = true;
      _motoristaEditando = motorista;
      _campoEditando = campo;
      _controller.text = motorista[campo]?.toString() ?? '';
    });
  }

  void _finalizarEdicao() {
    if (_motoristaEditando != null && _campoEditando != null) {
      _atualizarCampo(
        _motoristaEditando!['id'],
        _campoEditando!,
        _controller.text,
      );
    }
    
    setState(() {
      _editando = false;
      _motoristaEditando = null;
      _campoEditando = null;
    });
  }

  void _cancelarEdicao() {
    setState(() {
      _editando = false;
      _motoristaEditando = null;
      _campoEditando = null;
    });
  }

  List<Map<String, dynamic>> _getMotoristasPaginados() {
    final inicio = _paginaAtual * _itensPorPagina;
    final fim = inicio + _itensPorPagina;
    return _motoristas.sublist(
      inicio.clamp(0, _motoristas.length),
      fim.clamp(0, _motoristas.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Motoristas',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                
                // Filtro por estado
                if (_estadosDisponiveis.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filtroEstado,
                        hint: const Text('Filtrar por estado'),
                        items: _estadosDisponiveis.map((estado) {
                          return DropdownMenuItem(
                            value: estado == 'Todos' ? null : estado,
                            child: Text(estado),
                          );
                        }).toList(),
                        onChanged: (String? novoEstado) {
                          setState(() {
                            _filtroEstado = novoEstado;
                            _paginaAtual = 0;
                          });
                          _carregarMotoristas();
                        },
                      ),
                    ),
                  ),
                
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _carregarMotoristas,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Atualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Tabela
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                : _motoristas.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum motorista cadastrado',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          // Cabeçalho da tabela
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                            ),
                            child: const Row(
                              children: [
                                _CabecalhoTabela(texto: 'Nome', flex: 2),
                                _CabecalhoTabela(texto: 'Nome 2', flex: 2),
                                _CabecalhoTabela(texto: 'CPF', flex: 2),
                                _CabecalhoTabela(texto: 'CNH', flex: 2),
                                _CabecalhoTabela(texto: 'Categoria CNH', flex: 2),
                                _CabecalhoTabela(texto: 'Celular', flex: 2),
                                _CabecalhoTabela(texto: 'Celular 2', flex: 2),
                              ],
                            ),
                          ),

                          // Corpo da tabela
                          Expanded(
                            child: ListView.builder(
                              itemCount: _getMotoristasPaginados().length,
                              itemBuilder: (context, index) {
                                final motorista = _getMotoristasPaginados()[index];
                                final isEditando = _editando &&
                                    _motoristaEditando?['id'] == motorista['id'];
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: index.isEven ? Colors.white : Colors.grey.shade50,
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Nome
                                      _CelulaEditavel(
                                        valor: motorista['nome']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'nome',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'nome'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                      
                                      // Nome 2
                                      _CelulaEditavel(
                                        valor: motorista['nome_2']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'nome_2',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'nome_2'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                      
                                      // CPF
                                      _CelulaEditavel(
                                        valor: motorista['cpf']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'cpf',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'cpf'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                      
                                      // CNH
                                      _CelulaEditavel(
                                        valor: motorista['cnh']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'cnh',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'cnh'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                      
                                      // Categoria CNH
                                      _CelulaEditavel(
                                        valor: motorista['categoria']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'categoria',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'categoria'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                      
                                      // Celular
                                      _CelulaEditavel(
                                        valor: motorista['telefone']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'telefone',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'telefone'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                      
                                      // Celular 2
                                      _CelulaEditavel(
                                        valor: motorista['telefone_2']?.toString() ?? '',
                                        isEditando: isEditando && _campoEditando == 'telefone_2',
                                        onDoubleTap: () => _iniciarEdicao(motorista, 'telefone_2'),
                                        controller: _controller,
                                        onSalvar: _finalizarEdicao,
                                        onCancelar: _cancelarEdicao,
                                        flex: 2,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Paginação
                          if (_motoristas.length > _itensPorPagina)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(top: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                                    onPressed: _paginaAtual > 0
                                        ? () => setState(() => _paginaAtual--)
                                        : null,
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    'Página ${_paginaAtual + 1} de ${(_motoristas.length / _itensPorPagina).ceil()}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                                    onPressed: (_paginaAtual + 1) * _itensPorPagina < _motoristas.length
                                        ? () => setState(() => _paginaAtual++)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// Widget para cabeçalho da tabela
class _CabecalhoTabela extends StatelessWidget {
  final String texto;
  final int flex;

  const _CabecalhoTabela({
    required this.texto,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }
}

// Widget para células editáveis
class _CelulaEditavel extends StatelessWidget {
  final String valor;
  final bool isEditando;
  final VoidCallback onDoubleTap;
  final TextEditingController controller;
  final VoidCallback onSalvar;
  final VoidCallback onCancelar;
  final int flex;

  const _CelulaEditavel({
    required this.valor,
    required this.isEditando,
    required this.onDoubleTap,
    required this.controller,
    required this.onSalvar,
    required this.onCancelar,
    required this.flex,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: isEditando
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check, size: 20, color: Colors.green),
                  onPressed: onSalvar,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.red),
                  onPressed: onCancelar,
                ),
              ],
            )
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onDoubleTap: onDoubleTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    valor.isNotEmpty ? valor : '-',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
    );
  }
}