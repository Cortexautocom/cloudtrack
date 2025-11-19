import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControleDocumentosPage extends StatefulWidget {
  const ControleDocumentosPage({super.key});

  @override
  State<ControleDocumentosPage> createState() => _ControleDocumentosPageState();
}

class _ControleDocumentosPageState extends State<ControleDocumentosPage> {
  final List<Map<String, dynamic>> _veiculos = [];
  
  final List<String> _documentos = [
    'CIPP',
    'CIV',
    'Afericao',
    'Tacografo',
    'AET Federal',
    'AET Bahia',
    'AET Goias',
    'AET Alagoas',
    'AET Minas G'
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
          .order('placa');

      setState(() {
        _veiculos.clear();
        _veiculos.addAll(List<Map<String, dynamic>>.from(response));
      });
      
    } catch (e) {
      _mostrarErro('Erro ao carregar dados do banco: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _adicionarVeiculo() async {
    final placa = _placaController.text.trim().toUpperCase();
    if (placa.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('documentos_equipamentos').insert({
        'placa': placa,
      });

      _placaController.clear();
      setState(() => _mostrarFormulario = false);
      await _carregarVeiculosDoBanco();
      
      _mostrarSucesso('Veículo $placa adicionado com sucesso!');
    } catch (e) {
      _mostrarErro('Erro ao adicionar veículo: $e');
    }
  }

  Future<void> _atualizarDocumento(String placa, String documento, DateTime? data) async {
    try {
      final supabase = Supabase.instance.client;
      final colunaBanco = _converterParaNomeColuna(documento);
      
      final dataFormatada = data != null ? _formatDate(data) : null;
      final updateData = {colunaBanco: dataFormatada};

      await supabase
          .from('documentos_equipamentos')
          .update(updateData)
          .eq('placa', placa);

      await _carregarVeiculosDoBanco();
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
            .eq('placa', placa);

        await _carregarVeiculosDoBanco();
        _mostrarSucesso('Veículo $placa excluído com sucesso!');
      } catch (e) {
        _mostrarErro('Erro ao excluir veículo: $e');
      }
    }
  }

  String _converterParaNomeColuna(String documento) {
    final mapping = {
      'CIPP': 'cipp',
      'CIV': 'civ',
      'Afericao': 'afericao',
      'Tacografo': 'tacografo',
      'AET Federal': 'aet_federal',
      'AET Bahia': 'aet_bahia',
      'AET Goias': 'aet_goias',
      'AET Alagoas': 'aet_alagoas',
      'AET Minas G': 'aet_minas_g',
    };
    
    return mapping[documento] ?? documento.toLowerCase();
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
    if (dateString == null || dateString.isEmpty) {
      return null;
    }
    
    try {
      final cleanDate = dateString.trim();
      
      if (cleanDate.contains('-') && cleanDate.length >= 10) {
        return DateTime.parse(cleanDate);
      }
      
      if (cleanDate.contains('/')) {
        final parts = cleanDate.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0].padLeft(2, '0'));
          final month = int.parse(parts[1].padLeft(2, '0'));
          final year = int.parse(parts[2]);
          final fullYear = year < 100 ? 2000 + year : year;
          return DateTime(fullYear, month, day);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int _diasParaVencimento(DateTime? data) {
    if (data == null) return -999;
    final hoje = DateTime.now();
    final diferenca = data.difference(hoje).inDays;
    return diferenca;
  }

  Color _getVencimentoColor(int dias) {
    if (dias == -999) return Colors.grey;
    if (dias < 0) return Colors.red;
    if (dias <= 30) return Colors.orange;
    if (dias <= 90) return Colors.yellow[700]!;
    return Colors.green;
  }

  Widget _buildDataCell(String placa, String documento) {
    final veiculoIndex = _veiculos.indexWhere((v) => v['placa'] == placa);
    if (veiculoIndex == -1) {
      return Container(child: Text('Erro'));
    }
    
    final veiculo = _veiculos[veiculoIndex];
    final colunaBanco = _converterParaNomeColuna(documento);
    final dataString = veiculo[colunaBanco];
    final data = _parseDate(dataString);
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
        padding: const EdgeInsets.all(3),
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
    int totalDocumentos = 0;

    for (var veiculo in _veiculos) {
      for (var documento in _documentos) {
        final colunaBanco = _converterParaNomeColuna(documento);
        final data = _parseDate(veiculo[colunaBanco]);
        final dias = _diasParaVencimento(data);
        
        if (data != null) {
          totalDocumentos++;
          if (dias < 0) totalVencidos++;
          else if (dias <= 30) totalUrgentes++;
          else if (dias <= 90) totalAtencao++;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildResumoItem('Total Veículos', _veiculos.length.toString(), Colors.blue),
            _buildResumoItem('Total Documentos', totalDocumentos.toString(), Colors.purple),
            _buildResumoItem('Vencidos', totalVencidos.toString(), Colors.red),
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final veiculosFiltrados = _veiculos.where((veiculo) {
      final placa = veiculo['placa']?.toString().toLowerCase() ?? '';
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
            _buildResumoVencimentos(),
            const SizedBox(height: 20),

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
                            ],
                          ),
                        )
                      : Card(
                          elevation: 3,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
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
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    ..._documentos.map((doc) => Expanded(
                                          child: Text(
                                            doc,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        )),
                                    const SizedBox(width: 40),
                                  ],
                                ),
                              ),

                              Expanded(
                                child: ListView.builder(
                                  itemCount: veiculosFiltrados.length,
                                  itemBuilder: (context, index) {
                                    final veiculo = veiculosFiltrados[index];
                                    final placa = veiculo['placa'] ?? '';

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
                                          SizedBox(
                                            width: 120,
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0D47A1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      placa,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, size: 14, color: Colors.grey),
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
                                                            Icon(Icons.delete, color: Colors.red, size: 16),
                                                            SizedBox(width: 6),
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

                                          ..._documentos.map((documento) => 
                                            Expanded(child: _buildDataCell(placa, documento))
                                          ),

                                          const SizedBox(width: 40),
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

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LEGENDA DE STATUS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      children: [
                        _buildLegendaItem(Colors.green, 'OK (>90 dias)'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}