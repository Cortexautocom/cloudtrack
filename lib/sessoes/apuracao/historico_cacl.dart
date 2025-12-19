import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cacl.dart';


class HistoricoCaclPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const HistoricoCaclPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<HistoricoCaclPage> createState() => _HistoricoCaclPageState();
}

class _HistoricoCaclPageState extends State<HistoricoCaclPage> {
  bool carregando = true;
  List<Map<String, dynamic>> cacles = [];

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;

      final dados = await supabase
          .from('cacl')
          .select('id, data, produto, base')
          .order('data', ascending: false);

      setState(() {
        cacles = List<Map<String, dynamic>>.from(dados);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar histórico CACL: $e');
    } finally {
      setState(() => carregando = false);
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
            const Text(
              'Histórico de CACLs',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),

        // ===== CONTEÚDO =====
        Expanded(
          child: carregando
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : cacles.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum CACL encontrado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: cacles.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cacl = cacles[index];
                        final base = cacl['base'] ?? '-';
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF2E7D32),
                          ),
                          title: Text(
                            cacl['produto'] ?? 'Produto não informado',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),                          
                          subtitle: Text(
                            'Data: ${_formatarData(cacl['data'])}'
                            '  •  $base',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () async {
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

      'medicoes': {
        // MANHÃ
        'horarioManha': cacl['horario_manha'],
        'cmManha': cacl['altura_total_cm_manha'],
        'mmManha': cacl['altura_total_mm_manha'],
        'alturaAguaManha': cacl['altura_agua_manha'],
        'volumeAguaManha': cacl['volume_agua_manha'] != null
            ? '${cacl['volume_agua_manha']} L'
            : '-',
        'alturaProdutoManha': cacl['altura_produto_manha'],
        'tempTanqueManha': cacl['temperatura_tanque_manha'],
        'densidadeManha': cacl['densidade_observada_manha'],
        'tempAmostraManha': cacl['temperatura_amostra_manha'],
        'densidade20Manha': cacl['densidade_20_manha'],
        'fatorCorrecaoManha': cacl['fator_correcao_manha'],
        'volume20Manha': cacl['volume_20_manha'] != null
            ? '${cacl['volume_20_manha']} L'
            : '-',
        'massaManha': cacl['massa_manha'],

        // TARDE
        'horarioTarde': cacl['horario_tarde'],
        'cmTarde': cacl['altura_total_cm_tarde'],
        'mmTarde': cacl['altura_total_mm_tarde'],
        'alturaAguaTarde': cacl['altura_agua_tarde'],
        'volumeAguaTarde': cacl['volume_agua_tarde'] != null
            ? '${cacl['volume_agua_tarde']} L'
            : '-',
        'alturaProdutoTarde': cacl['altura_produto_tarde'],
        'tempTanqueTarde': cacl['temperatura_tanque_tarde'],
        'densidadeTarde': cacl['densidade_observada_tarde'],
        'tempAmostraTarde': cacl['temperatura_amostra_tarde'],
        'densidade20Tarde': cacl['densidade_20_tarde'],
        'fatorCorrecaoTarde': cacl['fator_correcao_tarde'],
        'volume20Tarde': cacl['volume_20_tarde'] != null
            ? '${cacl['volume_20_tarde']} L'
            : '-',
        'massaTarde': cacl['massa_tarde'],

        // FATURAMENTO
        'faturadoTarde': cacl['faturado_tarde'],
      }
    };
  }



}
