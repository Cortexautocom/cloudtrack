import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl.dart';
import '../../login_page.dart';
import 'emitir_cacl.dart';

class ListarCaclsPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final String filialId;
  final String filialNome;
  final VoidCallback onIrParaEmissao;
  final VoidCallback? onFinalizarCACL;

  const ListarCaclsPage({
    super.key,
    required this.onVoltar,
    required this.filialId,
    required this.filialNome,
    required this.onIrParaEmissao,
    this.onFinalizarCACL,
  });

  @override
  State<ListarCaclsPage> createState() => _ListarCaclsPageState();
}

class _ListarCaclsPageState extends State<ListarCaclsPage> {
  bool _carregando = true;
  List<Map<String, dynamic>> _cacles = [];  

  @override
  void initState() {
    super.initState();
    _carregarCacls();
  }

  Future<void> _carregarCacls() async {
    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final dataAtual = DateTime.now();
      final dataFormatada = '${dataAtual.year}-${dataAtual.month.toString().padLeft(2, '0')}-${dataAtual.day.toString().padLeft(2, '0')}';

      // Buscar CACLs do dia atual para esta filial
      final dados = await supabase
          .from('cacl')
          .select('''
            id, 
            data, 
            produto, 
            tanque,
            status,
            horario_inicial,
            horario_final,
            volume_produto_inicial,
            volume_produto_final,
            base
          ''')
          .eq('filial_id', widget.filialId)
          .eq('data', dataFormatada)
          .order('created_at', ascending: false);

      setState(() {
        _cacles = List<Map<String, dynamic>>.from(dados);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar CACLs: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  String _formatarData(dynamic data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data.toString());
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return data.toString();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'finalizado':
        return Colors.green;
      case 'aguardando':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'finalizado':
        return 'Finalizado';
      case 'aguardando':
        return 'Aguardando';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Sem status';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== CABEÇALHO =====
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Listar CACLs',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.filialNome,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [                
                const SizedBox(height: 2),                
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),

        // ===== BOTÃO EMITIR CACL =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: () {
              // Navega diretamente para MedicaoTanquesPage, passando o callback
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MedicaoTanquesPage(
                    onVoltar: () {
                      Navigator.pop(context);
                      widget.onVoltar(); // Volta para Home se necessário
                    },
                    filialSelecionadaId: widget.filialId,
                    onFinalizarCACL: widget.onFinalizarCACL, // ← PASSA O CALLBACK
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text(
                  'Emitir CACL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ===== LISTA DE CACLS =====
        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : _cacles.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum CACL encontrado para hoje',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Clique em "Emitir CACL" para criar um novo',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregarCacls,
                      color: const Color(0xFF0D47A1),
                      child: ListView.separated(
                        itemCount: _cacles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cacl = _cacles[index];
                          final status = cacl['status']?.toString();
                          final statusColor = _getStatusColor(status);
                          final statusText = _getStatusText(status);
                          final produto = cacl['produto'] ?? 'Produto não informado';
                          final tanque = cacl['tanque']?.toString() ?? '-';
                          
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.receipt_long,
                                color: statusColor,
                                size: 24,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    produto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Tanque: $tanque • '
                                  'Data: ${_formatarData(cacl['data'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (cacl['horario_inicial'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Horário: ${cacl['horario_inicial']}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: SizedBox(
                              width: 70,
                              child: Row(
                                children: [
                                  // Botão Editar (placeholder por enquanto)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Color(0xFF0D47A1),
                                    ),
                                    onPressed: () {
                                      // TODO: Implementar funcionalidade de edição
                                      print('Editar CACL ${cacl['id']}');
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () async {
                                      // Replicar comportamento do histórico
                                      final supabase = Supabase.instance.client;

                                      final caclCompleto = await supabase
                                          .from('cacl')
                                          .select('*')
                                          .eq('id', cacl['id'])
                                          .single();

                                      final dadosFormulario = _mapearCaclParaFormulario(caclCompleto);

                                      // Aqui usaria seu mecanismo de troca de páginas
                                      // Por enquanto, deixamos o mesmo comportamento do histórico
                                      if (!context.mounted) return;

                                      // Se seu sistema usa um gerenciador de páginas diferente,
                                      // ajuste esta navegação conforme necessário
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CalcPage(
                                            dadosFormulario: dadosFormulario,
                                            modo: CaclModo.visualizacao,
                                          ),
                                        ),
                                      );
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () async {
                              // Mesmo comportamento do botão de visualização acima
                              final supabase = Supabase.instance.client;

                              final caclCompleto = await supabase
                                  .from('cacl')
                                  .select('*')
                                  .eq('id', cacl['id'])
                                  .single();

                              final dadosFormulario = _mapearCaclParaFormulario(caclCompleto);

                              if (!context.mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CalcPage(
                                    dadosFormulario: dadosFormulario,
                                    modo: CaclModo.visualizacao,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Map<String, dynamic> _mapearCaclParaFormulario(Map<String, dynamic> cacl) {
    return {
      'data': cacl['data']?.toString(),
      'base': cacl['base'],
      'produto': cacl['produto'],
      'tanque': cacl['tanque'],
      'filial_id': cacl['filial_id'],
      'responsavel': UsuarioAtual.instance?.nome ?? 'Usuário',

      'medicoes': {
        // INICIAL (1ª Medição)
        'horarioInicial': cacl['horario_inicial']?.toString(),
        'cmInicial': cacl['altura_total_cm_inicial']?.toString(),
        'mmInicial': cacl['altura_total_mm_inicial']?.toString(),
        'alturaAguaInicial': cacl['altura_agua_inicial']?.toString(),
        'volumeAguaInicial': cacl['volume_agua_inicial'] != null
            ? '${cacl['volume_agua_inicial']} L'
            : '-',
        'alturaProdutoInicial': cacl['altura_produto_inicial']?.toString(),
        'tempTanqueInicial': cacl['temperatura_tanque_inicial']?.toString(),
        'densidadeInicial': cacl['densidade_observada_inicial']?.toString(),
        'tempAmostraInicial': cacl['temperatura_amostra_inicial']?.toString(),
        'densidade20Inicial': cacl['densidade_20_inicial']?.toString(),
        'fatorCorrecaoInicial': cacl['fator_correcao_inicial']?.toString(),
        'volume20Inicial': cacl['volume_20_inicial'] != null
            ? '${cacl['volume_20_inicial']} L'
            : '-',
        'massaInicial': cacl['massa_inicial']?.toString(),

        // FINAL (2ª Medição)
        'horarioFinal': cacl['horario_final']?.toString(),
        'cmFinal': cacl['altura_total_cm_final']?.toString(),
        'mmFinal': cacl['altura_total_mm_final']?.toString(),
        'alturaAguaFinal': cacl['altura_agua_final']?.toString(),
        'volumeAguaFinal': cacl['volume_agua_final'] != null
            ? '${cacl['volume_agua_final']} L'
            : '-',
        'alturaProdutoFinal': cacl['altura_produto_final']?.toString(),
        'tempTanqueFinal': cacl['temperatura_tanque_final']?.toString(),
        'densidadeFinal': cacl['densidade_observada_final']?.toString(),
        'tempAmostraFinal': cacl['temperatura_amostra_final']?.toString(),
        'densidade20Final': cacl['densidade_20_final']?.toString(),
        'fatorCorrecaoFinal': cacl['fator_correcao_final']?.toString(),
        'volume20Final': cacl['volume_20_final'] != null
            ? '${cacl['volume_20_final']} L'
            : '-',
        'massaFinal': cacl['massa_final']?.toString(),

        // FATURAMENTO
        'faturadoFinal': cacl['faturado_final']?.toString(),
      }
    };
  }
}