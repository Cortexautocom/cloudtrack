import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstoqueMesPage extends StatefulWidget {
  final String filialId;
  final String nomeFilial;
  final String? empresaId;
  final DateTime? mesFiltro;
  final String? produtoFiltro;
  final String tipoRelatorio;

  const EstoqueMesPage({
    super.key,
    required this.filialId,
    required this.nomeFilial,
    this.empresaId,
    this.mesFiltro,
    this.produtoFiltro,
    required this.tipoRelatorio,
  });

  @override
  State<EstoqueMesPage> createState() => _EstoqueMesPageState();
}

class _EstoqueMesPageState extends State<EstoqueMesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _movimentacoes = [];
  List<Map<String, dynamic>> _movimentacoesOrdenadas = [];
  String? _empresaId;
  bool _carregando = true;
  bool _erro = false;
  String _mensagemErro = '';
  String? _nomeProdutoSelecionado;
  
  // ScrollControllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  
  // Constantes de layout
  static const double _larguraTabela = 1260; // Largura total da tabela
  static const double _alturaCabecalho = 40;
  static const double _alturaLinha = 40;
  static const double _alturaRodape = 32;
  
  // Larguras das colunas
  static const double _larguraData = 120;
  static const double _larguraProduto = 180;
  static const double _larguraDescricao = 240;
  static const double _larguraNumerica = 120;
  
  Color _getCorFundoEntrada() {
    return Colors.green.shade50.withOpacity(0.3);
  }

  Color _getCorFundoSaida() {
    return Colors.red.shade50.withOpacity(0.3);
  }

  String _colunaOrdenacao = 'data_mov';
  bool _ordenacaoAscendente = true;
  bool _baixandoExcel = false;

  @override
  void initState() {
    super.initState();
    _setupScrollControllers();
    _carregarDados();
  }
  
  void _setupScrollControllers() {
    _horizontalHeaderController.addListener(() {
      if (_horizontalBodyController.hasClients &&
          _horizontalBodyController.offset != _horizontalHeaderController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });

    _horizontalBodyController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalBodyController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      if (widget.empresaId == null) {
        final filialData = await _supabase
            .from('filiais')
            .select('empresa_id')
            .eq('id', widget.filialId)
            .single();

        _empresaId = filialData['empresa_id']?.toString();
      } else {
        _empresaId = widget.empresaId;
      }

      if (_empresaId == null || _empresaId!.isEmpty) {
        throw Exception('Não foi possível identificar a empresa da filial');
      }

      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        final produtoData = await _supabase
            .from('produtos')
            .select('nome')
            .eq('id', widget.produtoFiltro!)
            .maybeSingle();
        
        _nomeProdutoSelecionado = produtoData?['nome']?.toString();
      }

      // Se for relatório sintético, carregar dados agrupados por data
      if (widget.tipoRelatorio == 'sintetico') {
        await _carregarDadosSintetico();
      } else {
        // Relatório analítico (mantém a lógica original)
        await _carregarDadosAnalitico();
      }
      
      if (mounted) {
        setState(() {
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

  Future<void> _carregarDadosAnalitico() async {
    var query = _supabase
        .from('movimentacoes')
        .select('''
          id,
          data_mov,
          descricao,
          entrada_amb,
          entrada_vinte,
          saida_amb,
          saida_vinte,
          produto_id,
          produtos!movimentacoes_produto_id_fkey1(
            id,
            nome
          )
        ''')
        .eq('filial_id', widget.filialId)
        .eq('empresa_id', _empresaId!);

    if (widget.mesFiltro != null) {
      final primeiroDia = DateTime(widget.mesFiltro!.year, widget.mesFiltro!.month, 1);
      final ultimoDia = DateTime(widget.mesFiltro!.year, widget.mesFiltro!.month + 1, 0);
      
      query = query
          .gte('data_mov', primeiroDia.toIso8601String())
          .lte('data_mov', ultimoDia.toIso8601String());
    }

    if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
      query = query.eq('produto_id', widget.produtoFiltro!);
    }

    final dados = await query.order('data_mov', ascending: true);

    List<Map<String, dynamic>> movimentacoesComSaldo = [];
    num saldoAmbAcumulado = 0;
    num saldoVinteAcumulado = 0;

    for (var item in dados) {
      final entradaAmb = item['entrada_amb'] ?? 0;
      final entradaVinte = item['entrada_vinte'] ?? 0;
      final saidaAmb = item['saida_amb'] ?? 0;
      final saidaVinte = item['saida_vinte'] ?? 0;
      
      final produto = item['produtos'] as Map<String, dynamic>?;
      final produtoNome = produto?['nome']?.toString() ?? '';

      saldoAmbAcumulado += entradaAmb - saidaAmb;
      saldoVinteAcumulado += entradaVinte - saidaVinte;

      movimentacoesComSaldo.add({
        ...item,
        'produto_nome': produtoNome,
        'produto_id': item['produto_id'],
        'saldo_amb': saldoAmbAcumulado,
        'saldo_vinte': saldoVinteAcumulado,
      });
    }

    _ordenarDados(movimentacoesComSaldo, 'data_mov', true);
  }

  Future<void> _carregarDadosSintetico() async {
    // Primeiro, obter todas as datas únicas com movimentações
    // Buscar por filial_id OU filial_destino_id (para transferências)
    var queryDatas = _supabase
        .from('movimentacoes')
        .select('data_mov')
        .or('filial_id.eq.${widget.filialId},filial_destino_id.eq.${widget.filialId}')
        .eq('empresa_id', _empresaId!);

    if (widget.mesFiltro != null) {
      final primeiroDia = DateTime(widget.mesFiltro!.year, widget.mesFiltro!.month, 1);
      final ultimoDia = DateTime(widget.mesFiltro!.year, widget.mesFiltro!.month + 1, 0);
      
      queryDatas = queryDatas
          .gte('data_mov', primeiroDia.toIso8601String())
          .lte('data_mov', ultimoDia.toIso8601String());
    }

    if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
      queryDatas = queryDatas.eq('produto_id', widget.produtoFiltro!);
    }

    final dadosDatas = await queryDatas.order('data_mov', ascending: true);

    // Extrair datas únicas
    final datasUnicas = <String>[];
    for (var item in dadosDatas) {
      final dataStr = item['data_mov'] as String;
      if (!datasUnicas.contains(dataStr)) {
        datasUnicas.add(dataStr);
      }
    }

    List<Map<String, dynamic>> movimentacoesSinteticas = [];

    // Para cada data única, calcular totais
    for (var dataStr in datasUnicas) {
      // Buscar movimentações onde:
      // 1. filial_id = filial do parâmetro (movimentações normais)
      // 2. OU filial_destino_id = filial do parâmetro E tipo_mov_dest = 'entrada' (transferências entrando)
      var queryDia = _supabase
          .from('movimentacoes')
          .select('''
            id,
            data_mov,
            descricao,
            entrada_amb,
            entrada_vinte,
            saida_amb,
            saida_vinte,
            produto_id,
            tipo_op,
            cacl_id,
            tipo_mov_orig,
            g_comum,
            g_aditivada,
            d_s10,
            d_s500,
            etanol,
            anidro,
            b100,
            gasolina_a,
            s500_a,
            s10_a,
            g_comum_vinte,
            g_aditivada_vinte,
            d_s10_vinte,
            d_s500_vinte,
            etanol_vinte,
            anidro_vinte,
            b100_vinte,
            gasolina_a_vinte,
            s500_a_vinte,
            s10_a_vinte,
            filial_id,
            filial_destino_id,
            tipo_mov_dest,
            produtos!movimentacoes_produto_id_fkey1(
              id,
              nome
            )
          ''')
          .eq('empresa_id', _empresaId!)
          .eq('data_mov', dataStr)
          .or('filial_id.eq.${widget.filialId},and(filial_destino_id.eq.${widget.filialId},tipo_mov_dest.eq.entrada)');

      if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
        queryDia = queryDia.eq('produto_id', widget.produtoFiltro!);
      }

      final movimentacoesDia = await queryDia;

      // DEBUG: Verificar o que foi retornado
      debugPrint('DEBUG Data $dataStr: ${movimentacoesDia.length} movimentações');
      for (var i = 0; i < movimentacoesDia.length; i++) {
        final mov = movimentacoesDia[i];
        debugPrint('  Mov $i: id=${mov['id']}, tipo_op=${mov['tipo_op']}, '
            'filial_id=${mov['filial_id']}, '
            'filial_destino_id=${mov['filial_destino_id']}, '
            'tipo_mov_dest=${mov['tipo_mov_dest']}');
      }

      // Inicializar totais
      num totalEntradaAmb = 0;
      num totalEntradaVinte = 0;
      num totalSaidaAmb = 0;
      num totalSaidaVinte = 0;

      // Para operações cacl, precisamos verificar o tipo no cacl
      final idsCaclParaVerificar = <String>[];
      final mapMovimentacoesCacl = <String, Map<String, dynamic>>{};
      
      for (var mov in movimentacoesDia) {
        final tipoOp = mov['tipo_op']?.toString() ?? '';
        final caclId = mov['cacl_id']?.toString();
        final filialId = mov['filial_id']?.toString();
        final filialDestinoId = mov['filial_destino_id']?.toString();
        final tipoMovDest = mov['tipo_mov_dest']?.toString();
        
        // DEBUG
        debugPrint('Processando mov ${mov['id']}: tipo_op=$tipoOp, '
            'filial_id=$filialId, filial_destino_id=$filialDestinoId, '
            'tipo_mov_dest=$tipoMovDest');
        
        if (tipoOp == 'cacl' && caclId != null && caclId.isNotEmpty) {
          idsCaclParaVerificar.add(caclId);
          mapMovimentacoesCacl[caclId] = mov;
        } else if (tipoOp == 'transf') {
          // PARA TRANSFERÊNCIAS:
          // Se filial_destino_id = filial do parâmetro E tipo_mov_dest = 'entrada'
          // Então é uma ENTRADA nesta filial
          if (filialDestinoId == widget.filialId && tipoMovDest == 'entrada') {
            debugPrint('  -> Transferência ENTRADA detectada!');
            
            // Somar TODAS as colunas específicas para entrada_amb
            num totalEntradaAmbTransf = 0;
            num totalEntradaVinteTransf = 0;
            
            // Campos ambiente
            totalEntradaAmbTransf += (mov['g_comum'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['g_aditivada'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['d_s10'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['d_s500'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['etanol'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['anidro'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['b100'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['gasolina_a'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['s500_a'] ?? 0) as num;
            totalEntradaAmbTransf += (mov['s10_a'] ?? 0) as num;
            
            // Campos 20ºC
            totalEntradaVinteTransf += (mov['g_comum_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['g_aditivada_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['d_s10_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['d_s500_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['etanol_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['anidro_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['b100_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['gasolina_a_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['s500_a_vinte'] ?? 0) as num;
            totalEntradaVinteTransf += (mov['s10_a_vinte'] ?? 0) as num;
            
            debugPrint('  -> Total entrada ambiente: $totalEntradaAmbTransf');
            debugPrint('  -> Total entrada 20ºC: $totalEntradaVinteTransf');
            
            // Adicionar os totais
            totalEntradaAmb += totalEntradaAmbTransf;
            totalEntradaVinte += totalEntradaVinteTransf;
          } else {
            // Para outras transferências (não entrada nesta filial), tratar como saída
            // Isso inclui transferências saindo desta filial ou entrando em outra
            debugPrint('  -> Transferência SAÍDA ou entrada em outra filial');
            
            // Somar TODAS as colunas específicas para saida_amb
            num totalSaidaAmbTransf = 0;
            num totalSaidaVinteTransf = 0;
            
            // Campos ambiente
            totalSaidaAmbTransf += (mov['g_comum'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['g_aditivada'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['d_s10'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['d_s500'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['etanol'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['anidro'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['b100'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['gasolina_a'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['s500_a'] ?? 0) as num;
            totalSaidaAmbTransf += (mov['s10_a'] ?? 0) as num;
            
            // Campos 20ºC
            totalSaidaVinteTransf += (mov['g_comum_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['g_aditivada_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['d_s10_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['d_s500_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['etanol_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['anidro_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['b100_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['gasolina_a_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['s500_a_vinte'] ?? 0) as num;
            totalSaidaVinteTransf += (mov['s10_a_vinte'] ?? 0) as num;
            
            debugPrint('  -> Total saída ambiente: $totalSaidaAmbTransf');
            debugPrint('  -> Total saída 20ºC: $totalSaidaVinteTransf');
            
            // Adicionar os totais
            totalSaidaAmb += totalSaidaAmbTransf;
            totalSaidaVinte += totalSaidaVinteTransf;
          }
        } else if (tipoOp == 'venda') {
          // Para vendas, somar TODAS as colunas específicas e colocar o total em saida_amb
          num totalVendaAmb = 0;
          num totalVendaVinte = 0;
          
          // Campos ambiente
          totalVendaAmb += (mov['g_comum'] ?? 0) as num;
          totalVendaAmb += (mov['g_aditivada'] ?? 0) as num;
          totalVendaAmb += (mov['d_s10'] ?? 0) as num;
          totalVendaAmb += (mov['d_s500'] ?? 0) as num;
          totalVendaAmb += (mov['etanol'] ?? 0) as num;
          totalVendaAmb += (mov['anidro'] ?? 0) as num;
          totalVendaAmb += (mov['b100'] ?? 0) as num;
          totalVendaAmb += (mov['gasolina_a'] ?? 0) as num;
          totalVendaAmb += (mov['s500_a'] ?? 0) as num;
          totalVendaAmb += (mov['s10_a'] ?? 0) as num;
          
          // Campos 20ºC
          totalVendaVinte += (mov['g_comum_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['g_aditivada_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['d_s10_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['d_s500_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['etanol_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['anidro_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['b100_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['gasolina_a_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['s500_a_vinte'] ?? 0) as num;
          totalVendaVinte += (mov['s10_a_vinte'] ?? 0) as num;
          
          debugPrint('  -> Venda detectada, total ambiente: $totalVendaAmb');
          debugPrint('  -> Venda detectada, total 20ºC: $totalVendaVinte');
          
          // Adicionar os totais
          totalSaidaAmb += totalVendaAmb;
          totalSaidaVinte += totalVendaVinte;
        } else if (tipoOp == 'outro') {
          // Para outros tipos (não cacl, não venda, não transf), somar normalmente
          totalEntradaAmb += (mov['entrada_amb'] ?? 0) as num;
          totalEntradaVinte += (mov['entrada_vinte'] ?? 0) as num;
          totalSaidaAmb += (mov['saida_amb'] ?? 0) as num;
          totalSaidaVinte += (mov['saida_vinte'] ?? 0) as num;
          
          debugPrint('  -> Outro tipo: entrada_amb=${mov['entrada_amb']}, saida_amb=${mov['saida_amb']}');
        }
      }

      // Verificar tipos dos cacl se houver algum
      if (idsCaclParaVerificar.isNotEmpty) {
        debugPrint('  Verificando ${idsCaclParaVerificar.length} registros cacl...');
        
        // Método correto para filtrar com IN
        final caclQuery = _supabase
            .from('cacl')
            .select('id, tipo')
            .inFilter('id', idsCaclParaVerificar);
        
        final caclResults = await caclQuery;
        
        // Converter para mapa para fácil acesso
        final mapTiposCacl = <String, String>{};
        for (var cacl in caclResults) {
          final id = cacl['id']?.toString();
          final tipo = cacl['tipo']?.toString();
          if (id != null && tipo != null) {
            mapTiposCacl[id] = tipo;
          }
        }
        
        // Agora processar as movimentações cacl
        for (var caclId in idsCaclParaVerificar) {
          final mov = mapMovimentacoesCacl[caclId];
          final tipoCacl = mapTiposCacl[caclId];
          
          if (mov != null && tipoCacl == 'movimentacao') {
            debugPrint('  -> Cacl movimentacao detectado (id: $caclId)');
            
            // Para CACL "movimentacao", sempre é ENTRADA (conforme informado)
            // Somar todos os campos específicos para entrada
            
            num totalCaclAmb = 0;
            num totalCaclVinte = 0;
            
            // Campos ambiente para entrada
            totalCaclAmb += (mov['g_comum'] ?? 0) as num;
            totalCaclAmb += (mov['g_aditivada'] ?? 0) as num;
            totalCaclAmb += (mov['d_s10'] ?? 0) as num;
            totalCaclAmb += (mov['d_s500'] ?? 0) as num;
            totalCaclAmb += (mov['etanol'] ?? 0) as num;
            totalCaclAmb += (mov['anidro'] ?? 0) as num;
            totalCaclAmb += (mov['b100'] ?? 0) as num;
            totalCaclAmb += (mov['gasolina_a'] ?? 0) as num;
            totalCaclAmb += (mov['s500_a'] ?? 0) as num;
            totalCaclAmb += (mov['s10_a'] ?? 0) as num;
            
            // Campos 20ºC para entrada
            totalCaclVinte += (mov['g_comum_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['g_aditivada_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['d_s10_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['d_s500_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['etanol_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['anidro_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['b100_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['gasolina_a_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['s500_a_vinte'] ?? 0) as num;
            totalCaclVinte += (mov['s10_a_vinte'] ?? 0) as num;
            
            debugPrint('    Total CACL ambiente: $totalCaclAmb');
            debugPrint('    Total CACL 20ºC: $totalCaclVinte');
            
            // Adicionar como ENTRADA (sempre para CACL "movimentacao")
            totalEntradaAmb += totalCaclAmb;
            totalEntradaVinte += totalCaclVinte;
            
          } else if (mov != null) {
            debugPrint('  -> Cacl tipo $tipoCacl ignorado (não é "movimentacao")');
          }
        }
      }

      // Obter nome do produto (ou "Todos" se for todos os produtos)
      String produtoNome;
      if (widget.produtoFiltro == null || widget.produtoFiltro == 'todos') {
        produtoNome = 'Todos';
      } else {
        produtoNome = _nomeProdutoSelecionado ?? 'Produto Selecionado';
      }

      // Adicionar linha sintética para o dia
      movimentacoesSinteticas.add({
        'id': 'sintetico_$dataStr',
        'data_mov': dataStr,
        'descricao': 'Resumo do dia',
        'entrada_amb': totalEntradaAmb,
        'entrada_vinte': totalEntradaVinte,
        'saida_amb': totalSaidaAmb,
        'saida_vinte': totalSaidaVinte,
        'produto_nome': produtoNome,
        'produto_id': widget.produtoFiltro,
      });
      
      debugPrint('  TOTAIS do dia $dataStr: entrada_amb=$totalEntradaAmb, entrada_vinte=$totalEntradaVinte, saida_amb=$totalSaidaAmb, saida_vinte=$totalSaidaVinte');
    }

    // Calcular saldos acumulados
    List<Map<String, dynamic>> movimentacoesComSaldo = [];
    num saldoAmbAcumulado = 0;
    num saldoVinteAcumulado = 0;

    for (var item in movimentacoesSinteticas) {
      final entradaAmb = item['entrada_amb'] ?? 0;
      final entradaVinte = item['entrada_vinte'] ?? 0;
      final saidaAmb = item['saida_amb'] ?? 0;
      final saidaVinte = item['saida_vinte'] ?? 0;

      saldoAmbAcumulado += entradaAmb - saidaAmb;
      saldoVinteAcumulado += entradaVinte - saidaVinte;

      movimentacoesComSaldo.add({
        ...item,
        'saldo_amb': saldoAmbAcumulado,
        'saldo_vinte': saldoVinteAcumulado,
      });
    }

    _ordenarDados(movimentacoesComSaldo, 'data_mov', true);
  }

  Future<void> _baixarExcel() async {
    if (_movimentacoesOrdenadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há dados para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.mesFiltro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário selecionar um mês para exportar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _baixandoExcel = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Gerando relatório Excel...'),
          duration: Duration(seconds: 5),
        ),
      );

      final requestData = {
        'filialId': widget.filialId,
        'nomeFilial': widget.nomeFilial,
        'empresaId': widget.empresaId,
        'mesFiltro': widget.mesFiltro!.toIso8601String(),
        'produtoFiltro': widget.produtoFiltro,
        'tipoRelatorio': widget.tipoRelatorio, // Adicionado tipo de relatório
      };

      debugPrint('Enviando para Edge Function: $requestData');

      final response = await _chamarEdgeFunctionBinaria(requestData);
      
      if (response.statusCode != 200) {
        final errorBody = await response.body;
        throw Exception('Erro ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Falha na Edge Function"}');
      }

      final bytes = response.bodyBytes;
      
      if (bytes.isEmpty) {
        throw Exception('Arquivo vazio recebido da Edge Function');
      }

      debugPrint('Arquivo XLSX recebido: ${bytes.length} bytes');

      final blob = html.Blob(
        [bytes], 
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final mes = widget.mesFiltro!.month.toString().padLeft(2, '0');
      final ano = widget.mesFiltro!.year.toString();
      final nomeFormatado = widget.nomeFilial
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w_]'), '');
      final fileName = 'movimentacoes_${nomeFormatado}_${mes}_${ano}.xlsx';
      
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      html.Url.revokeObjectUrl(url);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Download do Excel iniciado! Verifique sua pasta de downloads.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

    } catch (e) {
      debugPrint('Erro detalhado ao baixar relatório: $e');
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _baixandoExcel = false;
        });
      }
    }
  }

  Future<http.Response> _chamarEdgeFunctionBinaria(Map<String, dynamic> requestData) async {
    try {
      const supabaseUrl = 'https://ikaxzlpaihdkqyjqrxyw.supabase.co';
      
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null || session.accessToken.isEmpty) {
        throw Exception('Sessão inválida. Faça login novamente.');
      }

      return await _fazerRequisicao(
        supabaseUrl,
        session.accessToken,
        requestData,
      );
      
    } catch (e) {
      debugPrint('Erro detalhado ao chamar Edge Function: $e');
      rethrow;
    }
  }

  Future<http.Response> _fazerRequisicao(
    String supabaseUrl, 
    String accessToken, 
    Map<String, dynamic> requestData
  ) async {
    final functionUrl = '$supabaseUrl/functions/v1/down_excel_estoques';
    
    debugPrint('URL: $functionUrl');
    debugPrint('Token (início): ${accessToken.substring(0, 20)}...');
    debugPrint('Dados: ${jsonEncode(requestData)}');
    
    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
      body: jsonEncode(requestData),
    );
    
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Tamanho resposta: ${response.bodyBytes.length} bytes');
    
    return response;
  }

  void _ordenarDados(
    List<Map<String, dynamic>> dados, 
    String coluna, 
    bool ascendente
  ) {
    List<Map<String, dynamic>> dadosOrdenados = List.from(dados);
    
    dadosOrdenados.sort((a, b) {
      dynamic valorA;
      dynamic valorB;
      
      switch (coluna) {
        case 'data_mov':
          valorA = DateTime.parse(a['data_mov']);
          valorB = DateTime.parse(b['data_mov']);
          break;
        case 'descricao':
          valorA = (a['descricao'] ?? '').toString().toLowerCase();
          valorB = (b['descricao'] ?? '').toString().toLowerCase();
          break;
        case 'produto_nome':
          valorA = (a['produto_nome'] ?? '').toString().toLowerCase();
          valorB = (b['produto_nome'] ?? '').toString().toLowerCase();
          break;
        case 'entrada_amb':
        case 'entrada_vinte':
        case 'saida_amb':
        case 'saida_vinte':
        case 'saldo_amb':
        case 'saldo_vinte':
          valorA = a[coluna] ?? 0;
          valorB = b[coluna] ?? 0;
          break;
        default:
          return 0;
      }
      
      if (valorA is DateTime && valorB is DateTime) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      } else if (valorA is num && valorB is num) {
        return ascendente 
            ? (valorA - valorB).toInt()
            : (valorB - valorA).toInt();
      } else if (valorA is String && valorB is String) {
        return ascendente 
            ? valorA.compareTo(valorB)
            : valorB.compareTo(valorA);
      }
      
      return 0;
    });
    
    setState(() {
      _movimentacoes = dados;
      _movimentacoesOrdenadas = dadosOrdenados;
      _colunaOrdenacao = coluna;
      _ordenacaoAscendente = ascendente;
    });
  }

  void _onSort(String coluna) {
    bool ascendente = true;
    
    if (_colunaOrdenacao == coluna) {
      ascendente = !_ordenacaoAscendente;
    } else {
      ascendente = coluna == 'data_mov' ? true : true;
    }
    
    _ordenarDados(_movimentacoes, coluna, ascendente);
  }

  String _getSubtitleFiltros() {
    List<String> filtros = [];
    
    if (widget.mesFiltro != null) {
      filtros.add('Mês: ${widget.mesFiltro!.month.toString().padLeft(2, '0')}/${widget.mesFiltro!.year}');
    }
    
    if (widget.produtoFiltro != null && widget.produtoFiltro != 'todos') {
      filtros.add('Produto: ${_nomeProdutoSelecionado ?? widget.produtoFiltro}');
    } else if (widget.produtoFiltro == 'todos') {
      filtros.add('Produto: Todos os produtos');
    }
    
    filtros.add('Relatório: ${widget.tipoRelatorio == 'sintetico' ? 'Sintético' : 'Analítico'}');
    
    return filtros.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estoque – ${widget.nomeFilial}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.mesFiltro != null || widget.produtoFiltro != null)
              Text(
                _getSubtitleFiltros(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_carregando && !_erro && _movimentacoesOrdenadas.isNotEmpty)
            _baixandoExcel
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: _baixarExcel,
                    tooltip: 'Baixar relatório Excel (XLSX)',
                  ),
          
          if (!_carregando && (widget.mesFiltro != null || widget.produtoFiltro != null))
            IconButton(
              icon: const Icon(Icons.filter_alt),
              tooltip: 'Alterar filtros',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          
          if (!_carregando && !_erro && _movimentacoes.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por',
              onSelected: (value) {
                _onSort(value);
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    value: 'data_mov',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'data_mov' 
                      ? 'Data (mais antigo primeiro)' 
                      : 'Data (mais recente primeiro)'),
                  ),
                  if (widget.produtoFiltro == null || widget.produtoFiltro == 'todos')
                    PopupMenuItem<String>(
                      value: 'produto_nome',
                      child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'produto_nome'
                        ? 'Produto (Z-A)'
                        : 'Produto (A-Z)'),
                    ),
                  PopupMenuItem<String>(
                    value: 'entrada_amb',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'entrada_amb'
                      ? 'Entrada Ambiente (menor-maior)'
                      : 'Entrada Ambiente (maior-menor)'),
                  ),
                  PopupMenuItem<String>(
                    value: 'saldo_amb',
                    child: Text(_ordenacaoAscendente && _colunaOrdenacao == 'saldo_amb'
                      ? 'Saldo Ambiente (menor-maior)'
                      : 'Saldo Ambiente (maior-menor)'),
                  ),
                ];
              },
            ),
          
          if (!_carregando && !_erro)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDados,
              tooltip: 'Atualizar dados',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _carregando
            ? _buildCarregando()
            : _erro
                ? _buildErro()
                : _movimentacoes.isEmpty
                    ? _buildSemDados()
                    : Column(
                        children: [
                          if (widget.mesFiltro != null || widget.produtoFiltro != null)
                            _buildIndicadorFiltros(),
                          const SizedBox(height: 16),
                          Expanded(child: _buildTabela()),
                        ],
                      ),
      ),
    );
  }

  Widget _buildIndicadorFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: Color(0xFF0D47A1), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getSubtitleFiltros(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Alterar',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
            'Carregando dados das movimentações...',
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
            Icons.inventory_2_outlined,
            color: Colors.grey,
            size: 60,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum registro encontrado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.mesFiltro != null || widget.produtoFiltro != null
                ? 'Não há movimentações para os filtros aplicados.'
                : 'Não há movimentações para esta filial.',
            style: const TextStyle(color: Colors.grey),
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
          if (widget.mesFiltro != null || widget.produtoFiltro != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Alterar filtros',
                  style: TextStyle(color: Color(0xFF0D47A1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatarNumero(num? valor) {
    if (valor == null) return '0';
    
    if (valor == 0) return '0';
    
    bool isNegativo = valor < 0;
    
    String valorString = valor.abs().toStringAsFixed(0);
    
    String resultado = '';
    int contador = 0;
    
    for (int i = valorString.length - 1; i >= 0; i--) {
      contador++;
      resultado = valorString[i] + resultado;
      
      if (contador % 3 == 0 && i > 0) {
        resultado = '.$resultado';
      }
    }
    
    if (isNegativo) {
      resultado = '-$resultado';
    }
    
    return resultado;
  }

  // Método para formatar data
  String _formatarData(String dataString) {
    try {
      final data = DateTime.parse(dataString);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) {
      return dataString;
    }
  }

  // Método principal da tabela
  Widget _buildTabela() {
    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _buildTabelaCabecalho(),
              _buildTabelaCorpo(),
              _buildContadorResultados(),
            ],
          ),
        ),
      ),
    );
  }

  // Cabeçalho da tabela com scroll horizontal
  Widget _buildTabelaCabecalho() {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    
    return Scrollbar(
      controller: _horizontalHeaderController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalHeaderController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _larguraTabela,
          child: Container(
            height: _alturaCabecalho,
            color: const Color(0xFF0D47A1),
            child: Row(
              children: [
                _th('Data', _larguraData, onTap: () => _onSort('data_mov')),
                if (mostrarColunaProduto) 
                  _th('Produto', _larguraProduto, onTap: () => _onSort('produto_nome')),
                _th('Descrição', _larguraDescricao, onTap: () => _onSort('descricao')),
                _th('Entrada (Amb)', _larguraNumerica, onTap: () => _onSort('entrada_amb')),
                _th('Entrada (20ºC)', _larguraNumerica, onTap: () => _onSort('entrada_vinte')),
                _th('Saída (Amb)', _larguraNumerica, onTap: () => _onSort('saida_amb')),
                _th('Saída (20ºC)', _larguraNumerica, onTap: () => _onSort('saida_vinte')),
                _th('Saldo (Amb)', _larguraNumerica, onTap: () => _onSort('saldo_amb')),
                _th('Saldo (20ºC)', _larguraNumerica, onTap: () => _onSort('saldo_vinte')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Célula de cabeçalho
  Widget _th(String texto, double largura, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: largura,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: SelectableText(
          texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            overflow: TextOverflow.ellipsis,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ),
    );
  }

  // Corpo da tabela com scroll horizontal sincronizado
  Widget _buildTabelaCorpo() {
    bool mostrarColunaProduto = widget.produtoFiltro == null || widget.produtoFiltro == 'todos';
    
    return Scrollbar(
      controller: _horizontalBodyController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalBodyController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _larguraTabela,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movimentacoesOrdenadas.length,
            itemBuilder: (context, index) {
              final e = _movimentacoesOrdenadas[index];
              final saldoAmb = e['saldo_amb'] ?? 0;
              final saldoVinte = e['saldo_vinte'] ?? 0;

              return Container(
                height: _alturaLinha,
                decoration: BoxDecoration(
                  color: index % 2 == 0
                      ? Colors.grey.shade50
                      : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _cell(_formatarData(e['data_mov']), _larguraData),
                    if (mostrarColunaProduto)
                      _cell(e['produto_nome'] ?? '-', _larguraProduto),
                    _cell(e['descricao'] ?? '-', _larguraDescricao),
                    _cell(_formatarNumero(e['entrada_amb']), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['entrada_vinte']), _larguraNumerica, 
                          fundo: _getCorFundoEntrada(), isNumber: true),
                    _cell(_formatarNumero(e['saida_amb']), _larguraNumerica, 
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(_formatarNumero(e['saida_vinte']), _larguraNumerica, 
                          fundo: _getCorFundoSaida(), isNumber: true),
                    _cell(
                      _formatarNumero(saldoAmb),
                      _larguraNumerica,
                      cor: saldoAmb < 0 ? Colors.red : Colors.black,
                      isNumber: true,
                    ),
                    _cell(
                      _formatarNumero(saldoVinte),
                      _larguraNumerica,
                      cor: saldoVinte < 0 ? Colors.red : Colors.black,
                      isNumber: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Célula genérica para o corpo da tabela
  Widget _cell(
    String texto,
    double largura, {
    Color? fundo,
    Color? cor,
    bool isNumber = false,
  }) {
    return Container(
      width: largura,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      color: fundo,
      child: SelectableText(
        texto.isNotEmpty ? texto : '-',
        style: TextStyle(
          fontSize: 12,
          color: cor ?? Colors.grey.shade700,
          fontWeight: isNumber ? FontWeight.w600 : FontWeight.normal,
          overflow: TextOverflow.ellipsis,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
      ),
    );
  }

  // Rodapé com contador de resultados
  Widget _buildContadorResultados() {
    return Container(
      height: _alturaRodape,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        '${_movimentacoesOrdenadas.length} ${widget.tipoRelatorio == 'sintetico' ? 'dias' : 'movimentação(ões)'}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}