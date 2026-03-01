import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

class TemperaturaDensidadeMediaPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const TemperaturaDensidadeMediaPage({super.key, this.onVoltar});

  @override
  State<TemperaturaDensidadeMediaPage> createState() =>
      _TemperaturaDensidadeMediaPageState();
}

class _TemperaturaDensidadeMediaPageState
    extends State<TemperaturaDensidadeMediaPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _registros = [];
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();

  final ScrollController _verticalScrollController = ScrollController();

  // apenas o controlador vertical é necessário para a nova tabela

  @override
  void initState() {
    super.initState();

    // não são necessários listeners horizontais para a tabela simples

    _carregarDados();
  }

  @override
  void dispose() {
    // apenas dispose do controlador vertical
    _verticalScrollController.dispose();
    _dataController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados({bool carregarMais = false}) async {
    if (carregarMais) return;
    setState(() {
      _carregando = true;
      _erro = false;
      _registros = []; // Limpa registros ao recarregar
    });

    try {
      // Obter usuário atual da instância global (filial/empresa são opcionais aqui)
      final usuario = UsuarioAtual.instance;
      if (usuario == null) {
        throw Exception('Usuário não autenticado. Faça login novamente.');
      }

      final filialId = usuario.filialId;
      final empresaId = usuario.empresaId;

      debugPrint('🔍 Consultando para filial: $filialId, empresa: $empresaId');

      // Converter filtro de data
      DateTime? dataFiltro;
      if (_dataController.text.trim().isNotEmpty) {
        try {
          final partes = _dataController.text.trim().split('/');
          if (partes.length == 3) {
            dataFiltro = DateTime(
              int.parse(partes[2]),
              int.parse(partes[1]),
              int.parse(partes[0]),
            );
          } else if (_dataController.text.trim().contains('-')) {
            dataFiltro = DateTime.parse(_dataController.text.trim());
          }
        } catch (e) {
          debugPrint("Erro ao converter data: $e");
        }
      }
      
      // Se não houver filtro de data, usa data atual
      dataFiltro ??= DateTime.now();
      final dataInicio = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day);
      final dataFim = DateTime(dataFiltro.year, dataFiltro.month, dataFiltro.day, 23, 59, 59);

      debugPrint('📅 Data consulta: ${dataInicio.toIso8601String()} até ${dataFim.toIso8601String()}');

      // Consulta simplificada: buscar ordens_analises com JOIN em movimentacoes
        debugPrint('📋 Consultando ordens_analises (sem filtro de filial/empresa)');

          final resp = await _supabase
            .from('ordens_analises')
            .select('id, densidade_observada, temperatura_amostra, temperatura_ct, produto_nome, placa_cavalo, movimentacoes!inner(cliente)')
            .order('id', ascending: false)
            .limit(200);

      // resp deve ser uma lista de registros retornada pelo Supabase
      final List<dynamic> lista = resp;

      final registrosTransformados = lista.map<Map<String, dynamic>>((row) {
        String descricao = '';
        String placa = row['placa_cavalo']?.toString() ?? '';
        final movs = row['movimentacoes'] as List?;
        if (movs != null && movs.isNotEmpty) {
          final m = movs.first;
          descricao = m['cliente']?.toString() ?? '';
        }

        final produto = row['produto_nome']?.toString() ?? '';
        final densidade = row['densidade_observada'];
        final tempAmostra = row['temperatura_amostra'];
        final tempCt = row['temperatura_ct'];

        return {
          'descricao': descricao,
          'placa': placa,
          'produto': produto,
          'densidade': densidade,
          'temp_amostra': tempAmostra,
          'temp_ct': tempCt,
        };
      }).toList();

      setState(() {
        _registros = registrosTransformados;
        _carregando = false;
      });

    } catch (e, stackTrace) {
      debugPrint("❌ Erro ao carregar temperatura e densidade média: $e");
      debugPrint("📝 Stack trace: $stackTrace");
      
      setState(() {
        _erro = true;
        _mensagemErro = e.toString();
        _carregando = false;
      });
      
      if (!carregarMais && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ----------------- FILTRO -----------------

  List<Map<String, dynamic>> get _registrosFiltrados {
    final placaFiltro = _placaController.text.trim().toLowerCase();

    return _registros.where((r) {
      if (placaFiltro.isNotEmpty) {
        final placa = r['placa']?.toString().toLowerCase() ?? '';
        return placa.contains(placaFiltro);
      }
      return true;
    }).toList();
  }

  // removed layout helpers no longer used by the simplified list view

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Carregando temperatura e densidade...',
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
            onPressed: () => _carregarDados(),
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

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.thermostat_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma movimentação encontrada',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromARGB(255, 119, 119, 119),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dataController.text.isEmpty
                ? 'Para hoje'
                : 'Para a data ${_dataController.text}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------- WIDGET DE PESQUISA (IGUAL AO DA PROGRAMAÇÃO) -----------------

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: Builder(builder: (context) {
        final textoData = _dataController.text.isNotEmpty
            ? _dataController.text
            : 'Data';

        return InkWell(
          onTap: () async {
            final now = DateTime.now();
            final data = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2000),
              lastDate: DateTime(now.year + 1),
              helpText: 'Filtrar por data',
              cancelText: 'Cancelar',
              confirmText: 'Confirmar',
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF0D47A1),
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (data != null) {
              setState(() {
                _dataController.text = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
              });
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    textoData,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_dataController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF0D47A1)),
                    onPressed: () {
                      setState(() {
                        _dataController.clear();
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPlacaSearchField() {
    return Container(
      width: 200,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.directions_car, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _placaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Placa',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_placaController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                _placaController.clear();
                setState(() {});
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _registros.isEmpty) {
      return _buildCarregando();
    }

    if (_erro && _registros.isEmpty) {
      return _buildErro();
    }
    final registros = _registrosFiltrados;

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // AppBar personalizada FIXA (igual à da Programação)
          Container(
            height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
            ),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 8),
                // Título alinhado à esquerda
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Temperatura e Densidade Média',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                // Campos de busca
                Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildSearchField(),
                ),
                Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildPlacaSearchField(),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: () => _carregarDados(),
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
          // Linha divisória opcional
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          // Resto do conteúdo
          Expanded(
            child: registros.isEmpty
                ? _buildVazio()
                : _buildTable(registros),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> registros) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Cabeçalho da tabela (mesmo estilo de estoque_tanques_geral)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF222B45),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: const [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Descrição',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Placa',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Produto',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Densidade Obs.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Temp. da amostra',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Temp. do CT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            // Linhas
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Column(
                  children: List.generate(registros.length, (index) {
                    final r = registros[index];
                    final isEven = index.isEven;
                    return Container(
                      color: isEven ? const Color(0xFFF0F1F6) : const Color(0xFFF8F9FA),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['descricao']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF222B45),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['placa']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['produto']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['densidade']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['temp_amostra']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              r['temp_ct']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // funções de agrupamento e tabela antiga removidas — mantemos apenas a tabela simples
}