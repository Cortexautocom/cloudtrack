import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControleDocumentosPage extends StatefulWidget {
  const ControleDocumentosPage({super.key});

  @override
  State<ControleDocumentosPage> createState() => _ControleDocumentosPageState();
}

class _ControleDocumentosPageState extends State<ControleDocumentosPage> {
  final List<Map<String, dynamic>> _veiculos = [];
  
  // Documentos que existem na sua tabela
  final List<String> _documentos = [
    'CIPP',
    'CIV',
    'AFERIÇÃO',
    'TACOGRÁFO',
    'AET FEDERAL',
    'AET BAHIA',
    'AET GOIÁS',
    'AET ALAGOAS',
    'AET MINAS G'
  ];
  
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _carregando = true;
  bool _mostrarFormulario = false;

  @override
  void initState() {
    super.initState();
    _carregarVeiculosDoBanco();
  }

  Future<void> _carregarVeiculosDoBanco() async {
    setState(() => _carregando = true);
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('documentos_equipamentos')
          .select('*')
          .order('ID');

      setState(() {
        _veiculos.clear();
        _veiculos.addAll(List<Map<String, dynamic>>.from(response));
      });
      
    } catch (e) {
      debugPrint('❌ Erro ao carregar veículos: $e');
      _mostrarErro('Erro ao carregar dados do banco');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _adicionarVeiculo() async {
    final placa = _placaController.text.trim().toUpperCase();
    if (placa.isEmpty) return;

    // Verifica se placa já existe localmente
    if (_veiculos.any((v) => v['PLACA'] == placa)) {
      _mostrarErro('Veículo com esta placa já existe!');
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('documentos_equipamentos').insert({
        'PLACA': placa,
        // Outros campos ficam null por padrão
      });

      _placaController.clear();
      setState(() => _mostrarFormulario = false);
      await _carregarVeiculosDoBanco(); // Recarrega do banco
      
      _mostrarSucesso('Veículo $placa adicionado com sucesso!');
    } catch (e) {
      _mostrarErro('Erro ao adicionar veículo: $e');
    }
  }

  Future<void> _atualizarDocumento(String placa, String documento, DateTime? data) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Converte para o formato do banco (nome da coluna)
      final colunaBanco = _converterParaNomeColuna(documento);
      
      await supabase
          .from('documentos_equipamentos')
          .update({colunaBanco: data?.toIso8601String()})
          .eq('PLACA', placa);

      await _carregarVeiculosDoBanco(); // Recarrega do banco
      _mostrarSucesso('$documento do veículo $placa atualizado!');
    } catch (e) {
      _mostrarErro('Erro ao atualizar documento: $e');
    }
  }

  Future<void> _excluirVeiculo(String placa) async {
    final confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir o veículo $placa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('documentos_equipamentos')
            .delete()
            .eq('PLACA', placa);

        await _carregarVeiculosDoBanco(); // Recarrega do banco
        _mostrarSucesso('Veículo $placa excluído com sucesso!');
      } catch (e) {
        _mostrarErro('Erro ao excluir veículo: $e');
      }
    }
  }

  // Converte o nome amigável para o nome da coluna no banco
  String _converterParaNomeColuna(String documento) {
    switch (documento) {
      case 'CIPP': return 'CIPP';
      case 'CIV': return 'CIV';
      case 'AFERIÇÃO': return 'AFERIÇÃO';
      case 'TACOGRÁFO': return 'TACOGRÁFO';
      case 'AET FEDERAL': return 'AET FEDERAL';
      case 'AET BAHIA': return 'AET BAHIA';
      case 'AET GOIÁS': return 'AET GOIÁS';
      case 'AET ALAGOAS': return 'AET ALAGOAS';
      case 'AET MINAS G': return 'AET MINAS G';
      default: return documento;
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green,
      ),
    );
  }

  DateTime? _parseDate(String? dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int _diasParaVencimento(DateTime? data) {
    if (data == null) return -999; // Não preenchido
    final hoje = DateTime.now();
    final diferenca = data.difference(hoje).inDays;
    return diferenca;
  }

  Color _getVencimentoColor(int dias) {
    if (dias == -999) return Colors.grey; // Não preenchido
    if (dias < 0) return Colors.red;
    if (dias <= 30) return Colors.orange;
    if (dias <= 90) return Colors.yellow[700]!;
    return Colors.green;
  }

  Widget _buildDataCell(String placa, String documento) {
    final veiculo = _veiculos.firstWhere((v) => v['PLACA'] == placa);
    final colunaBanco = _converterParaNomeColuna(documento);
    final data = _parseDate(veiculo[colunaBanco]);
    final dias = _diasParaVencimento(data);
    final statusColor = _getVencimentoColor(dias);
    
    return GestureDetector(
      onTap: () async {
        final novaData = await showDatePicker(
          context: context,
          initialDate: data ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        
        if (novaData != null) {
          await _atualizarDocumento(placa, documento, novaData);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (data != null) ...[
              Text(
                _formatDate(data),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              if (dias >= 0)
                Text(
                  '$dias dias',
                  style: TextStyle(
                    fontSize: 9,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (dias < 0 && dias != -999)
                Text(
                  'VENCIDO',
                  style: TextStyle(
                    fontSize: 9,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ] else
              Column(
                children: [
                  Icon(Icons.add_circle_outline, size: 16, color: Colors.grey.shade400),
                  const SizedBox(height: 2),
                  Text(
                    'CLIQUE\nPARA\nADICIONAR',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoVencimentos() {
    int totalVencidos = 0;
    int totalUrgentes = 0;
    int totalAtencao = 0;

    for (var veiculo in _veiculos) {
      for (var documento in _documentos) {
        final colunaBanco = _converterParaNomeColuna(documento);
        final data = _parseDate(veiculo[colunaBanco]);
        final dias = _diasParaVencimento(data);
        
        if (dias < 0) totalVencidos++;
        else if (dias <= 30) totalUrgentes++;
        else if (dias <= 90) totalAtencao++;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildResumoItem('Total Veículos', _veiculos.length.toString(), Colors.blue),
            _buildResumoItem('Documentos Vencidos', totalVencidos.toString(), Colors.red),
            _buildResumoItem('Urgentes (≤30 dias)', totalUrgentes.toString(), Colors.orange),
            _buildResumoItem('Atenção (≤90 dias)', totalAtencao.toString(), Colors.yellow[700]!),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoItem(String titulo, String valor, Color cor) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final veiculosFiltrados = _veiculos.where((veiculo) {
      final placa = veiculo['PLACA']?.toString().toLowerCase() ?? '';
      final termo = _searchController.text.toLowerCase();
      return placa.contains(termo);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Controle de Documentos de Veículos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por placa...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _mostrarFormulario = true),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Veículo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Resumo de vencimentos
            _buildResumoVencimentos(),

            const SizedBox(height: 20),

            // Formulário para adicionar veículo
            if (_mostrarFormulario)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _placaController,
                          decoration: const InputDecoration(
                            labelText: 'Placa do Veículo',
                            hintText: 'ABC-1234',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onSubmitted: (_) => _adicionarVeiculo,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _adicionarVeiculo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Salvar'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _mostrarFormulario = false),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_mostrarFormulario) const SizedBox(height: 20),

            // Tabela de documentos
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : veiculosFiltrados.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.car_repair, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Nenhum veículo encontrado',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              Text(
                                'Clique em "Adicionar Veículo" para começar',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : Card(
                          elevation: 3,
                          child: Column(
                            children: [
                              // Cabeçalho da tabela
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0D47A1),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: const Text(
                                        'PLACA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    ..._documentos.map((doc) => Expanded(
                                          child: Text(
                                            doc,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        )),
                                    const SizedBox(width: 60),
                                  ],
                                ),
                              ),

                              // Corpo da tabela
                              Expanded(
                                child: ListView.builder(
                                  itemCount: veiculosFiltrados.length,
                                  itemBuilder: (context, index) {
                                    final veiculo = veiculosFiltrados[index];
                                    final placa = veiculo['PLACA'] ?? '';

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: index.isEven ? Colors.grey[50] : Colors.white,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Coluna Placa
                                          SizedBox(
                                            width: 120,
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0D47A1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      placa,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                                                    onSelected: (value) {
                                                      if (value == 'excluir') {
                                                        _excluirVeiculo(placa);
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'excluir',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.delete, color: Colors.red, size: 18),
                                                            SizedBox(width: 8),
                                                            Text('Excluir Veículo'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Colunas de documentos
                                          ..._documentos.map((documento) => 
                                            Expanded(child: _buildDataCell(placa, documento))
                                          ),

                                          const SizedBox(width: 60),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // Legenda
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LEGENDA DE STATUS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendaItem(Colors.green, 'OK (mais de 90 dias)'),
                        _buildLegendaItem(Colors.yellow[700]!, 'ATENÇÃO (31-90 dias)'),
                        _buildLegendaItem(Colors.orange, 'URGENTE (1-30 dias)'),
                        _buildLegendaItem(Colors.red, 'VENCIDO'),
                        _buildLegendaItem(Colors.grey, 'NÃO PREENCHIDO'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendaItem(Color color, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}