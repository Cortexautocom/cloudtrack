import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ajuda/desenvolvedor.dart';
import 'detalhe_solic.dart';

class FilaSolicitacoesPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const FilaSolicitacoesPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<FilaSolicitacoesPage> createState() => _FilaSolicitacoesPageState();
}

class _FilaSolicitacoesPageState extends State<FilaSolicitacoesPage> {
  bool carregando = true;
  Map<String, dynamic>? solicitacaoSelecionada;
  List<Map<String, dynamic>> solicitacoes = [];

  @override
  void initState() {
    super.initState();
    _buscarSolicitacoes();
  }

  Future<void> _buscarSolicitacoes() async {
    setState(() => carregando = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('ajuda')
          .select('*, usuarios!ajuda_usuario_id_fkey(Nome_apelido)')
          .order('data_criacao', ascending: false);

      setState(() {
        solicitacoes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Erro ao buscar solicitacoes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  String _formatarData(String? data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return data;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'concluido':
        return Colors.green;
      case 'em analise':
      case 'desenvolvimento':
        return Colors.blue;
      case 'pendente':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (solicitacaoSelecionada != null) {
      return DetalheSolicitacaoPage(
        solicitacao: solicitacaoSelecionada!,
        onVoltar: () {
          setState(() {
            solicitacaoSelecionada = null;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Remove o tom de azul do Flutter no AppBar do Material 3
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: widget.onVoltar,
        ),
        title: const Text(
          'Fila de Solicitacoes',
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFEEEEEE), height: 1.0),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DesenvolvedorPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF263238),
        tooltip: 'Nova solicitacao',
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: const Text(
              'Acompanhe as solicitacoes de melhoria e novas funcionalidades.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
          ),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF263238)))
                : solicitacoes.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma solicitacao encontrada.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                        itemCount: solicitacoes.length,
                        itemBuilder: (context, index) {
                          final item = solicitacoes[index];
                          final usuario = item['usuarios']?['Nome_apelido'] ?? 'Anonimo';

                          return Container(
                            decoration: const BoxDecoration(
                              color: Colors.white, // Fundo branco explicitamente
                              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
                            ),
                            child: Material( // Garante que o efeito de clique seja branco/cinza claro
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    solicitacaoSelecionada = item;
                                  });
                                },
                                splashColor: const Color(0xFFF5F5F5),
                                highlightColor: const Color(0xFFF9F9F9),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _formatarData(item['data_criacao']),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item['titulo'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF263238),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(
                                                color: _getStatusColor(item['status']).withOpacity(0.5),
                                                width: 1,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item['status']?.toUpperCase() ?? '',
                                              style: TextStyle(
                                                color: _getStatusColor(item['status']),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey),
                                              const SizedBox(width: 4),
                                              Text(
                                                usuario,
                                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.blueGrey),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatarData(item['previsao']),
                                                style: const TextStyle(
                                                  fontSize: 12, 
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
}
