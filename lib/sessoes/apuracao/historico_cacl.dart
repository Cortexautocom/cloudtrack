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
  bool buscando = false;
  List<Map<String, dynamic>> cacles = [];
  List<Map<String, dynamic>> filiais = [];
  List<Map<String, dynamic>> tanquesDisponiveis = [];
  List<Map<String, dynamic>> produtosDisponiveis = [];
  
  // Controles de paginação
  int paginaAtual = 1;
  int totalPaginas = 1;
  int totalRegistros = 0;
  final int limitePorPagina = 50;
  
  // Filtros
  DateTime? dataInicio;
  DateTime? dataFim;
  String? filialSelecionadaId;
  String? tanqueSelecionado;
  String? produtoSelecionado;
  
  // Controladores para UI
  final TextEditingController dataInicioController = TextEditingController();
  final TextEditingController dataFimController = TextEditingController();

  // Para armazenar dados do usuário
  Map<String, dynamic>? _usuarioData;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<Map<String, dynamic>?> _obterDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) return null;
      
      final usuarioData = await supabase
          .from('usuarios')
          .select('id, nome, nivel, id_filial, senha_temporaria, Nome_apelido')
          .eq('id', user.id)
          .maybeSingle();
      
      return usuarioData;
    } catch (e) {
      debugPrint('❌ Erro ao obter dados do usuário: $e');
      return null;
    }
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => carregando = true);
    
    try {
      final supabase = Supabase.instance.client;
      _usuarioData = await _obterDadosUsuario();
      
      if (_usuarioData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final nivel = _usuarioData!['nivel'];
      final filialId = _usuarioData!['id_filial']?.toString();
      
      // Carregar produtos disponíveis
      final produtosResponse = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');
      setState(() {
        produtosDisponiveis = List<Map<String, dynamic>>.from(produtosResponse);
      });
      
      // Carregar filiais (apenas para nível 3)
      if (nivel == 3) {
        final filiaisResponse = await supabase
            .from('filiais')
            .select('id, nome')
            .order('nome');
        setState(() {
          filiais = List<Map<String, dynamic>>.from(filiaisResponse);
        });
      }
      
      // Carregar tanques disponíveis (de acordo com permissão)
      if (nivel == 3) {
        // Admin: todos os tanques
        final tanquesResponse = await supabase
            .from('tanques')
            .select('id, referencia, id_filial')
            .order('referencia');
        tanquesDisponiveis = List<Map<String, dynamic>>.from(tanquesResponse);
      } else if (filialId != null) {
        // Usuário normal: apenas tanques da sua filial
        final tanquesResponse = await supabase
            .from('tanques')
            .select('id, referencia')
            .eq('id_filial', filialId)
            .order('referencia');
        tanquesDisponiveis = List<Map<String, dynamic>>.from(tanquesResponse);
      }
      
      // Carregar dados iniciais
      await _aplicarFiltros();
      
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados iniciais: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  Future<void> _aplicarFiltros({bool resetarPagina = true}) async {
    if (resetarPagina) {
      paginaAtual = 1;
    }
    
    setState(() => buscando = true);
    
    try {
      final supabase = Supabase.instance.client;
      
      if (_usuarioData == null) {
        _usuarioData = await _obterDadosUsuario();
      }
      
      final nivel = _usuarioData!['nivel'];
      final filialId = _usuarioData!['id_filial']?.toString();
      
      // Construir query base
      var query = supabase
          .from('cacl')
          .select('''
            id, 
            data, 
            base, 
            produto, 
            tanque,
            filial_id,
            created_at,
            entrada_saida_20,
            faturado_final,
            diferenca_faturado,
            porcentagem_diferenca
          ''');
      
      // Aplicar filtro de nível de acesso
      if (nivel < 3 && filialId != null) {
        query = query.eq('filial_id', filialId);
      }
      
      // Aplicar filtros personalizados
      if (dataInicio != null) {
        query = query.gte('data', dataInicio!.toIso8601String().split('T')[0]);
      }
      if (dataFim != null) {
        query = query.lte('data', dataFim!.toIso8601String().split('T')[0]);
      }
      if (filialSelecionadaId != null && nivel == 3) {
        query = query.eq('filial_id', filialSelecionadaId!);
      }
      if (tanqueSelecionado != null && tanqueSelecionado!.isNotEmpty) {
        query = query.ilike('tanque', '%$tanqueSelecionado%');
      }
      if (produtoSelecionado != null && produtoSelecionado!.isNotEmpty) {
        query = query.eq('produto', produtoSelecionado!);
      }
      
      // Primeiro, contar total de registros (para paginação)
      final countQuery = query;
      final countData = await countQuery;
      final totalCount = countData.length;
      
      // Depois, buscar com paginação
      final response = await query
          .order('data', ascending: false)
          .order('created_at', ascending: false)
          .range(
            (paginaAtual - 1) * limitePorPagina,
            (paginaAtual * limitePorPagina) - 1,
          );
      
      setState(() {
        cacles = List<Map<String, dynamic>>.from(response);
        totalRegistros = totalCount;
        totalPaginas = (totalRegistros / limitePorPagina).ceil();
        if (totalPaginas == 0) totalPaginas = 1;
      });
      
    } catch (e) {
      debugPrint('❌ Erro ao buscar CACLs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na busca: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => buscando = false);
    }
  }

  void _limparFiltros() {
    setState(() {
      dataInicio = null;
      dataFim = null;
      filialSelecionadaId = null;
      tanqueSelecionado = null;
      produtoSelecionado = null;
      dataInicioController.clear();
      dataFimController.clear();
    });
    _aplicarFiltros();
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

  Widget _buildCardFiltros() {
    if (_usuarioData == null) return const SizedBox();
    
    final nivel = _usuarioData!['nivel'];
    final isAdmin = nivel == 3;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de Busca',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            
            // Linha 1: Produto, Filial (se admin) e Tanque
            Row(
              children: [
                // Produto
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: produtoSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Produto',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_gas_station, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os produtos', overflow: TextOverflow.ellipsis),
                      ),
                      ...produtosDisponiveis.map((produto) {
                        return DropdownMenuItem(
                          value: produto['nome']?.toString(),
                          child: Text(
                            produto['nome']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        produtoSelecionado = value;
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Filial (apenas para admin)
                if (isAdmin)
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: filialSelecionadaId,
                      decoration: InputDecoration(
                        labelText: 'Filial',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.business, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas as filiais', overflow: TextOverflow.ellipsis),
                        ),
                        ...filiais.map((filial) {
                          return DropdownMenuItem(
                            value: filial['id']?.toString(),
                            child: Text(
                              filial['nome']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          filialSelecionadaId = value;
                        });
                      },
                    ),
                  ),
                
                if (isAdmin) const SizedBox(width: 12),
                
                // Tanque
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: tanqueSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Tanque',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.storage, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todos os tanques', overflow: TextOverflow.ellipsis),
                      ),
                      ...tanquesDisponiveis.map((tanque) {
                        return DropdownMenuItem(
                          value: tanque['referencia']?.toString(),
                          child: Text(
                            tanque['referencia']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        tanqueSelecionado = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Linha 2: Data Início, Data Fim e Botões
            Row(
              children: [
                // Data Início
                Expanded(
                  child: TextFormField(
                    controller: dataInicioController,
                    decoration: InputDecoration(
                      labelText: 'Data Início',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() {
                            dataInicio = null;
                            dataInicioController.clear();
                          });
                        },
                      ),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (data != null) {
                        setState(() {
                          dataInicio = data;
                          dataInicioController.text = _formatarData(data);
                        });
                      }
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Data Fim
                Expanded(
                  child: TextFormField(
                    controller: dataFimController,
                    decoration: InputDecoration(
                      labelText: 'Data Fim',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() {
                            dataFim = null;
                            dataFimController.clear();
                          });
                        },
                      ),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: dataInicio ?? DateTime.now(),
                        firstDate: dataInicio ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (data != null) {
                        setState(() {
                          dataFim = data;
                          dataFimController.text = _formatarData(data);
                        });
                      }
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Botões
                SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _limparFiltros,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF0D47A1)),
                          ),
                          child: const Text(
                            'Limpar',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _aplicarFiltros(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: buscando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Buscar',
                                  style: TextStyle(fontSize: 13),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginacao() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              onPressed: paginaAtual > 1
                  ? () {
                      setState(() => paginaAtual--);
                      _aplicarFiltros(resetarPagina: false);
                    }
                  : null,
              color: paginaAtual > 1 ? const Color(0xFF0D47A1) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              'Página $paginaAtual de $totalPaginas',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(width: 12),
            Text(
              '($totalRegistros registros)',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: paginaAtual < totalPaginas
                  ? () {
                      setState(() => paginaAtual++);
                      _aplicarFiltros(resetarPagina: false);
                    }
                  : null,
              color: paginaAtual < totalPaginas ? const Color(0xFF0D47A1) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarioData == null && !carregando) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Usuário não autenticado'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    }
    
    final nivel = _usuarioData?['nivel'];
    final filialId = _usuarioData?['id_filial']?.toString();
    
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Histórico de CACLs',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (nivel != null && nivel < 3 && filialId != null)
                        FutureBuilder(
                          future: Supabase.instance.client
                              .from('filiais')
                              .select('nome')
                              .eq('id', filialId)
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final nomeFilial = snapshot.data!['nome'];
                              return Text(
                                'Filial: $nomeFilial',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                    ],
                  ),
                ),
                if (!carregando)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                    onPressed: _carregarDadosIniciais,
                    tooltip: 'Recarregar',
                  ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: carregando
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0D47A1)),
                        SizedBox(height: 16),
                        Text('Carregando histórico...'),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Filtros
                      _buildCardFiltros(),
                      
                      // Lista de resultados
                      Expanded(
                        child: cacles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Nenhum CACL encontrado',
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ajuste os filtros ou cadastre um novo cálculo',
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: cacles.length,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                itemBuilder: (context, index) {
                                  final cacl = cacles[index];
                                  final diferenca = (cacl['diferenca_faturado'] as num?)?.toDouble() ?? 0;
                                  final porcentagem = cacl['porcentagem_diferenca']?.toString() ?? '-';
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 1,
                                    color: const Color.fromARGB(255, 246, 255, 241),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: diferenca == 0 
                                            ? Colors.green.shade200 
                                            : Colors.orange.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      leading: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: diferenca == 0 
                                              ? Colors.green.shade50 
                                              : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          diferenca == 0 ? Icons.check_circle : Icons.warning,
                                          color: diferenca == 0 ? Colors.green : Colors.orange,
                                          size: 18,
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cacl['produto']?.toString() ?? 'Produto não informado',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: diferenca == 0 
                                                  ? Colors.green.shade50 
                                                  : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: diferenca == 0 
                                                    ? Colors.green.shade200 
                                                    : Colors.orange.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              diferenca == 0 ? 'OK' : '$porcentagem%',
                                              style: TextStyle(
                                                color: diferenca == 0 
                                                    ? Colors.green.shade800 
                                                    : Colors.orange.shade800,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Tanque: ${cacl['tanque']?.toString() ?? '-'}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                'Data: ${_formatarData(cacl['data'])}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            if (cacl['base'] != null)
                                              Expanded(
                                                child: Text(
                                                  'Filial: ${cacl['base']}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
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
                                    ),
                                  );
                                },
                              ),
                      ),
                      
                      // Paginação (se houver mais de uma página)
                      if (totalPaginas > 1) _buildPaginacao(),
                    ],
                  ),
          ),
        ],
      ),
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
        // MANHÃ (inicial)
        'horarioManha': cacl['horario_inicial'],
        'cmManha': cacl['altura_total_cm_inicial'],
        'mmManha': cacl['altura_total_mm_inicial'],
        'alturaAguaManha': cacl['altura_agua_inicial'],
        'volumeAguaManha': cacl['volume_agua_inicial'] != null
            ? '${cacl['volume_agua_inicial']} L'
            : '-',
        'alturaProdutoManha': cacl['altura_produto_inicial'],
        'tempTanqueManha': cacl['temperatura_tanque_inicial'],
        'densidadeManha': cacl['densidade_observada_inicial'],
        'tempAmostraManha': cacl['temperatura_amostra_inicial'],
        'densidade20Manha': cacl['densidade_20_inicial'],
        'fatorCorrecaoManha': cacl['fator_correcao_inicial'],
        'volume20Manha': cacl['volume_20_inicial'] != null
            ? '${cacl['volume_20_inicial']} L'
            : '-',
        'massaManha': cacl['massa_inicial'],

        // TARDE (final)
        'horarioTarde': cacl['horario_final'],
        'cmTarde': cacl['altura_total_cm_final'],
        'mmTarde': cacl['altura_total_mm_final'],
        'alturaAguaTarde': cacl['altura_agua_final'],
        'volumeAguaTarde': cacl['volume_agua_final'] != null
            ? '${cacl['volume_agua_final']} L'
            : '-',
        'alturaProdutoTarde': cacl['altura_produto_final'],
        'tempTanqueTarde': cacl['temperatura_tanque_final'],
        'densidadeTarde': cacl['densidade_observada_final'],
        'tempAmostraTarde': cacl['temperatura_amostra_final'],
        'densidade20Tarde': cacl['densidade_20_final'],
        'fatorCorrecaoTarde': cacl['fator_correcao_final'],
        'volume20Tarde': cacl['volume_20_final'] != null
            ? '${cacl['volume_20_final']} L'
            : '-',
        'massaTarde': cacl['massa_final'],

        // FATURAMENTO
        'faturadoTarde': cacl['faturado_final'],
      }
    };
  }

  @override
  void dispose() {
    dataInicioController.dispose();
    dataFimController.dispose();
    super.dispose();
  }
}