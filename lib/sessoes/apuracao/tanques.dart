import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  const TanquesPage({super.key, required this.onVoltar});

  @override
  State<TanquesPage> createState() => _TanquesPageState();
}

class _TanquesPageState extends State<TanquesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tanques = [];
  bool _carregando = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregarTanques();
  }

  Future<void> _carregarTanques() async {
    try {
      if (!mounted) return;
      
      setState(() {
        _carregando = true;
        _erro = false;
      });

      // 1. Pega o usuário logado
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _carregando = false;
          _erro = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado')),
        );
        return;
      }

      // 2. Busca o nível e filial do usuário
      final userResponse = await Supabase.instance.client
          .from('usuarios')
          .select('id_filial, nivel')
          .eq('id', userId)
          .single();

      // CORREÇÃO: Trata o caso onde id_filial pode ser null
      final idFilialUsuario = userResponse['id_filial']?.toString();
      final nivelUsuario = userResponse['nivel'] as int;

      // 3. Se usuário for nível 3, carrega TODOS os tanques
      if (nivelUsuario == 3) {
        final response = await Supabase.instance.client
            .from('tanques')
            .select('*')
            .order('referencia');

        if (!mounted) return;
        setState(() {
          _tanques = List<Map<String, dynamic>>.from(response);
          _carregando = false;
        });
      } else {
        // 4. Se não for nível 3 E tiver id_filial, carrega APENAS os tanques da filial
        if (idFilialUsuario == null) {
          if (!mounted) return;
          setState(() {
            _carregando = false;
            _erro = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuário não possui filial definida')),
          );
          return;
        }

        final response = await Supabase.instance.client
            .from('tanques')
            .select('*')
            .eq('id_filial', idFilialUsuario)
            .order('referencia');

        if (!mounted) return;
        setState(() {
          _tanques = List<Map<String, dynamic>>.from(response);
          _carregando = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = true;
      });
      debugPrint('Erro ao carregar tanques: $e');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar tanques: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
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
                    onPressed: widget.onVoltar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Gerenciar Tanques',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                    onPressed: _carregarTanques,
                    tooltip: 'Atualizar lista',
                  ),
                ]),
              ),

              // Conteúdo
              Expanded(
                child: _carregando
                    ? _buildCarregando()
                    : _erro
                        ? _buildErro()
                        : _tanques.isEmpty
                            ? _buildListaVazia()
                            : _buildListaTanques(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioAdicionar,
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0D47A1)),
          SizedBox(height: 16),
          Text(
            'Carregando tanques...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
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
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar tanques',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifique sua conexão e tente novamente.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _carregarTanques,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildListaVazia() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum tanque cadastrado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Clique no botão + para adicionar o primeiro tanque.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListaTanques() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da lista
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.list, color: Color(0xFF0D47A1), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tanques Cadastrados (${_tanques.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Lista de tanques
          Expanded(
            child: ListView.separated(
              itemCount: _tanques.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tanque = _tanques[index];
                return _buildCardTanque(tanque);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTanque(Map<String, dynamic> tanque) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone do tanque
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.storage,
                  color: Color(0xFF0D47A1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Informações principais
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D47A1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tanque['referencia'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tanque['produto'] ?? 'PRODUTO NÃO INFORMADO',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoItem(
                          Icons.science,
                          'Capacidade',
                          tanque['capacidade'] ?? '',
                        ),
                        const SizedBox(width: 20),
                        _buildInfoItem(
                          Icons.business,
                          'Filial',
                          _formatarFilial(tanque['id_filial']),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Ações
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  _executarAcao(value, tanque);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'excluir',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Excluir'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatarFilial(dynamic idFilial) {
    if (idFilial == null) return 'Não informada';
    final String id = idFilial.toString();
    return '${id.substring(0, 8)}...';
  }

  void _executarAcao(String acao, Map<String, dynamic> tanque) {
    switch (acao) {
      case 'editar':
        _mostrarFormularioEditar(tanque);
        break;
      case 'excluir':
        _confirmarExclusao(tanque);
        break;
    }
  }

  void _mostrarFormularioAdicionar() {
    // TODO: Implementar formulário de adição
    _mostrarSnackBar('Funcionalidade em desenvolvimento - Adicionar Tanque');
  }

  void _mostrarFormularioEditar(Map<String, dynamic> tanque) {
    // TODO: Implementar formulário de edição
    _mostrarSnackBar('Funcionalidade em desenvolvimento - Editar ${tanque['referencia']}');
  }

  void _confirmarExclusao(Map<String, dynamic> tanque) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o tanque ${tanque['referencia']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _excluirTanque(tanque);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirTanque(Map<String, dynamic> tanque) async {
    try {
      await _supabase
          .from('tanques')
          .delete()
          .eq('id', tanque['id']);

      _mostrarSnackBar('Tanque ${tanque['referencia']} excluído com sucesso!');
      _carregarTanques();
    } catch (e) {
      _mostrarSnackBar('Erro ao excluir tanque: $e', isError: true);
    }
  }

  void _mostrarSnackBar(String mensagem, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.red : const Color(0xFF0D47A1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}