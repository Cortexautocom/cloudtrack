import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/apuracao/tabelas_de_conversao/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'configuracoes/usuarios.dart';
import 'perfil.dart';
import 'sessoes/apuracao/cacl.dart';
import 'sessoes/gestao_de_frota/controle_documentos.dart';
import 'sessoes/apuracao/emitir_cacl.dart';
import 'sessoes/apuracao/tanques.dart';
import 'sessoes/apuracao/escolherfilial.dart';
import 'sessoes/vendas/programacao.dart'; 
import 'sessoes/estoques/estoque_geral.dart';
import 'sessoes/apuracao/historico_cacl.dart';
import 'sessoes/apuracao/listar_cacls.dart';
import 'sessoes/estoques/estoque_downloads.dart';
import 'sessoes/estoques/filtro_estoque.dart';
import 'sessoes/estoques/estoque_mes.dart';
import 'sessoes/gestao_de_frota/motoristas_page.dart';
import 'sessoes/gestao_de_frota/veiculos.dart';
import 'sessoes/circuito/acompanhamento_ordens.dart';
import 'sessoes/estoques/transferencias.dart';
import 'sessoes/apuracao/listar_ordens.dart';
import 'sessoes/apuracao/temp_dens_media.dart';
import 'home_cards.dart';
import 'sessoes/ajuda/arquiteto.dart';
import 'sessoes/estoques/filtro_moviment.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

@JS()
external JSFunction? atualizarApp;

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  TextEditingController searchController = TextEditingController();

  final List<String> menuItems = [
    'Início',
    'Estoques',
    'Apuração',
    'Circuito',
    'Vendas',
    'Gestão de Frota',
    'Bombeios e Cotas',
    'Relatórios',
    'Configurações',
    'Ajuda'
  ];

  // FLAGS GERAIS
  bool showConversaoList = false;
  bool showControleAcesso = false;
  bool showConfigList = false;
  bool carregandoSessoes = false;
  bool showUsuarios = false;
  bool _mostrarAcompanhamentoOrdens = false;
  
  // FLAGS PARA SESSÕES ESPECÍFICAS
  bool _mostrarCalcGerado = false;
  bool _mostrarDownloads = false;
  bool _mostrarMedicaoTanques = false;
  bool _mostrarTanques = false;
  bool _mostrarOrdensAnalise = false;
  bool _mostrarHistorico = false;
  bool _mostrarListarCacls = false;
  bool _mostrarFiltrosEstoque = false;
  bool _mostrarEscolherFilial = false;
  bool _mostrarEstoquePorEmpresa = false;
  bool _mostrarFiliaisDaEmpresa = false;
  bool _mostrarFiltroMovimentacoes = false;
  bool _mostrarMenuAjuda = false;
  bool _mostrarTempDensMedia = false;
  
  // NOVAS VARIÁVEIS PARA GESTÃO DE FROTA
  bool _mostrarVeiculos = false;
  bool _mostrarDetalhesVeiculo = false;
  Map<String, dynamic>? _veiculoSelecionado;
  bool _mostrarMotoristas = false;
  
  // FLAG UNIFICADA PARA MOSTRAR FILHOS DE QUALQUER SESSÃO
  bool _mostrarFilhosSessao = false;
  String? _sessaoAtual;
  List<Map<String, dynamic>> _filhosSessaoAtual = [];
  
  // DADOS PARA NAVEGAÇÃO
  String? _filialSelecionadaNome;
  Map<String, dynamic>? _dadosCalcGerado;
  String? _filialSelecionadaId;
  String _contextoEscolhaFilial = '';
  String? _filialParaFiltroId;
  String? _filialParaFiltroNome;
  String? _empresaParaFiltroId;
  String? _empresaParaFiltroNome;
  
  // LISTAS DE DADOS
  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, dynamic>> empresas = [];
  List<Map<String, dynamic>> filiaisDaEmpresa = [];
  
  // FLAGS DE CARREGAMENTO
  bool carregandoEmpresas = false;
  bool carregandoFiliaisEmpresa = false;
  bool _carregandoCards = false;
  String? _empresaSelecionadaNome;
  String? _empresaSelecionadaId;

  // MAPA UNIFICADO DE FILHOS POR SESSÃO
  final Map<String, List<Map<String, dynamic>>> _filhosPorSessao = {};

  // NOVA LISTA PARA ARMAZENAR FILIAIS PARA PROGRAMACAO
  List<Map<String, dynamic>> _filiaisProgramacao = [];

  // NOVO: Mapa de cores por sessão
  final Map<String, Color> _coresSessoes = {
    'Estoques': const Color(0xFFFF9800), // Laranja
    'Apuração': const Color(0xFF2196F3), // Azul
    'Circuito': const Color(0xFF9C27B0), // Roxo
    'Vendas': const Color(0xFF4CAF50),   // Verde
    'Gestão de Frota': const Color(0xFFF44336), // Vermelho
    'Bombeios e Cotas': const Color(0xFF00BCD4), // Ciano
    'Relatórios': const Color(0xFF795548), // Marrom
    'Configurações': const Color(0xFF607D8B), // Azul cinza
    'Ajuda': const Color(0xFF673AB7), // Roxo profundo
  };

  @override
  void initState() {
    super.initState();
    selectedIndex = -1;
    _carregarFilialParaProgramacao();
    _carregarCardsDoBanco();
  }

  // NOVO: Método para obter cor da sessão atual
  Color _getCorSessaoAtual() {
    return _coresSessoes[_sessaoAtual ?? ''] ?? const Color(0xFF2E7D32);
  }

  // NOVO: Método para obter cor da sessão por nome
  Color _getCorPorSessao(String sessao) {
    return _coresSessoes[sessao] ?? const Color(0xFF2E7D32);
  }

  Future<void> _carregarCardsDoBanco() async {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    setState(() => _carregandoCards = true);

    try {
      final supabase = Supabase.instance.client;
      
      final cardsDb = await supabase
          .from('cards')
          .select('id, nome, tipo, sessao_pai, ordem')
          .eq('ativo', true)
          .order('sessao_pai')
          .order('ordem');

      debugPrint('✅ Cards encontrados no banco: ${cardsDb.length}');

      final List<Map<String, dynamic>> todosCards = [];
      
      for (var card in cardsDb) {
        final cardId = card['id'].toString();
        final sessaoPai = card['sessao_pai']?.toString() ?? 'Geral';
        
        if (usuario.nivel >= 3 || usuario.podeAcessarCard(cardId)) {
          todosCards.add({
            'id': cardId,
            'label': card['nome'],
            'tipo': card['tipo'],
            'sessao_pai': sessaoPai,
            'icon': _definirIconePorTipo(card['tipo']),
            'descricao': _definirDescricaoPorTipo(card['tipo']),
          });
        }
      }

      debugPrint('✅ Cards permitidos para ${usuario.nome}: ${todosCards.length}');

      final Map<String, List<Map<String, dynamic>>> cardsOrganizados = {};
      
      for (var card in todosCards) {
        final sessaoPai = card['sessao_pai'];
        cardsOrganizados.putIfAbsent(sessaoPai, () => []);
        cardsOrganizados[sessaoPai]!.add(card);
      }

      setState(() {
        _filhosPorSessao.clear();
        _filhosPorSessao.addAll(cardsOrganizados);
        _carregandoCards = false;
      });

    } catch (e) {
      debugPrint('❌ Erro ao carregar cards do banco: $e');
      setState(() => _carregandoCards = false);
      _inicializarFilhosPorSessaoFallback();
    }
  }

  void _inicializarFilhosPorSessaoFallback() {
    _filhosPorSessao['Apuração'] = [
      {'id': 'fallback-cacl', 'icon': Icons.analytics, 'label': 'CACL', 'descricao': 'Emitir CACL', 'tipo': 'cacl', 'sessao_pai': 'Apuração'},
      {'id': 'fallback-ordens', 'icon': Icons.assignment, 'label': 'Ordens / Análises', 'descricao': 'Geração e gestão de ordens', 'tipo': 'ordens_analise', 'sessao_pai': 'Apuração'},
      {'id': 'fallback-historico', 'icon': Icons.history, 'label': 'Histórico de CACLs', 'descricao': 'Consultar histórico de CACLs emitidos', 'tipo': 'historico_cacl', 'sessao_pai': 'Apuração'},
      {'id': 'fallback-tabelas', 'icon': Icons.table_chart, 'label': 'Tabelas de Conversão', 'descricao': 'Tabelas de conversão de densidade e temperatura', 'tipo': 'tabelas_conversao', 'sessao_pai': 'Apuração'},
      {'id': 'fallback-temp', 'icon': Icons.thermostat, 'label': 'Temperatura e Densidade média', 'descricao': 'Cálculo de temperatura e densidade média', 'tipo': 'temp_dens_media', 'sessao_pai': 'Apuração'},
      {'id': 'fallback-tanques', 'icon': Icons.oil_barrel, 'label': 'Tanques', 'descricao': 'Gerenciamento de tanques', 'tipo': 'tanques', 'sessao_pai': 'Apuração'}, // MOVIDO PARA APURAÇÃO
    ];

    _filhosPorSessao['Estoques'] = [
      {'id': 'fallback-geral', 'icon': Icons.hub, 'label': 'Estoque Geral', 'descricao': 'Visão consolidada dos estoques da base', 'tipo': 'estoque_geral', 'sessao_pai': 'Estoques'},
      {'id': 'fallback-empresa', 'icon': Icons.business, 'label': 'Estoque por empresa', 'descricao': 'Estoques separados por empresa', 'tipo': 'estoque_por_empresa', 'sessao_pai': 'Estoques'},
      {'id': 'fallback-mov', 'icon': Icons.swap_horiz, 'label': 'Movimentações', 'descricao': 'Acompanhar entradas e saídas em geral', 'tipo': 'movimentacoes', 'sessao_pai': 'Estoques'},
      {'id': 'fallback-transf', 'icon': Icons.compare_arrows, 'label': 'Transferências', 'descricao': 'Gerenciar transferências entre filiais', 'tipo': 'transferencias', 'sessao_pai': 'Estoques'},
    ];

    _filhosPorSessao['Circuito'] = [      
      {'id': 'fallback-acompanhar', 'icon': Icons.directions_car, 'label': 'Acompanhar ordem', 'descricao': 'Acompanhar situação da ordem', 'tipo': 'acompanhar_ordem', 'sessao_pai': 'Circuito'},
      {'id': 'fallback-visao', 'icon': Icons.dashboard, 'label': 'Visão geral', 'descricao': 'Panorama completo dos circuitos', 'tipo': 'visao_geral_circuito', 'sessao_pai': 'Circuito'},
    ];

    _filhosPorSessao['Gestão de Frota'] = [
      {'id': 'fallback-veiculos', 'icon': Icons.directions_car, 'label': 'Veículos Próprios', 'descricao': 'Gerenciar frota de veículos próprios', 'tipo': 'veiculos', 'sessao_pai': 'Gestão de Frota'},
      {'id': 'fallback-terceiros', 'icon': Icons.local_shipping, 'label': 'Veículos de terceiros', 'descricao': 'Gerenciar veículos de transportadoras', 'tipo': 'veiculos_terceiros', 'sessao_pai': 'Gestão de Frota'},
      {'id': 'fallback-motoristas', 'icon': Icons.people, 'label': 'Motoristas', 'descricao': 'Gerenciar cadastro de motoristas', 'tipo': 'motoristas', 'sessao_pai': 'Gestão de Frota'},
      {'id': 'fallback-documentacao', 'icon': Icons.description, 'label': 'Documentação', 'descricao': 'Controle de documentos da frota', 'tipo': 'documentacao', 'sessao_pai': 'Gestão de Frota'},
    ];

    _filhosPorSessao['Bombeios e Cotas'] = [
      {'id': 'fallback-bombeios', 'icon': Icons.invert_colors, 'label': 'Bombeios e Cotas', 'descricao': 'Controle de bombeios', 'tipo': 'bombeios', 'sessao_pai': 'Bombeios e Cotas'},
    ];
  }

  IconData _definirIconePorTipo(String tipo) {
    const mapaIcones = {
      'cacl': Icons.analytics,
      'ordens_analise': Icons.assignment,
      'historico_cacl': Icons.history,
      'tabelas_conversao': Icons.table_chart,
      'temp_dens_media': Icons.thermostat,
      'tanques': Icons.oil_barrel,
      'estoque_geral': Icons.hub,
      'estoque_por_empresa': Icons.business,
      'movimentacoes': Icons.swap_horiz,
      'transferencias': Icons.compare_arrows,
      'acompanhar_ordem': Icons.directions_car,
      'visao_geral_circuito': Icons.dashboard,
      'veiculos': Icons.directions_car,
      'veiculos_terceiros': Icons.local_shipping,
      'motoristas': Icons.people,
      'documentacao': Icons.description,
      'bombeios': Icons.invert_colors,
      'programacao_filial': Icons.local_gas_station,
    };
    return mapaIcones[tipo] ?? Icons.apps;
  }

  String _definirDescricaoPorTipo(String tipo) {
    const mapaDescricoes = {
      'cacl': 'Emitir CACL',
      'ordens_analise': 'Geração e gestão de ordens',
      'historico_cacl': 'Consultar histórico de CACLs emitidos',
      'tabelas_conversao': 'Tabelas de conversão de densidade e temperatura',
      'temp_dens_media': 'Cálculo de temperatura e densidade média',
      'tanques': 'Gerenciamento de tanques',
      'estoque_geral': 'Visão consolidada dos estoques da base',
      'estoque_por_empresa': 'Estoques separados por empresa',
      'movimentacoes': 'Acompanhar entradas e saídas em geral',
      'transferencias': 'Gerenciar transferências entre filiais',
      'acompanhar_ordem': 'Acompanhar situação da ordem',
      'visao_geral_circuito': 'Panorama completo dos circuitos',
      'veiculos': 'Gerenciar frota de veículos próprios',
      'veiculos_terceiros': 'Gerenciar veículos de transportadoras',
      'motoristas': 'Gerenciar cadastro de motoristas',
      'documentacao': 'Controle de documentos da frota',
      'bombeios': 'Controle de bombeios',
      'programacao_filial': 'Programação de vendas por filial',
    };
    return mapaDescricoes[tipo] ?? '';
  }

  Future<void> _carregarFilialParaProgramacao() async {
    // CRIANDO CARDS FIXOS PARA VENDAS COM OS UUIDs DAS FILIAIS
    final filiaisFixas = [
      {
        'id': '9d476aa0-11fe-4470-8881-2699cb528690',
        'nome': 'Petroserra Jequié',
        'nome_dois': 'Jequié',
      },
      {
        'id': 'b4225bea-63f1-4e0f-b04f-ae936d8ccda8',
        'nome': 'Petroserra Candeias',
        'nome_dois': 'PHL',
      },
      {
        'id': 'bcc92c8e-bd40-4d26-acb0-87acdd2ce2b7',
        'nome': 'PetroserraJanaúba',
        'nome_dois': 'Janaúba',
      },
      {
        'id': 'ff09efd0-b71f-40ce-8bbb-0fa3b738e73e',
        'nome': 'Petroserra Feira',
        'nome_dois': 'Sidel Terminais',
      }
    ];

    setState(() {
      _filiaisProgramacao = filiaisFixas.map((filial) {
        final nomeFilial = filial['nome_dois'] ?? filial['nome'];
        return {
          'id': filial['id'],
          'label': nomeFilial, // APENAS O NOME PRINCIPAL, SEM LEGENDA
          'descricao': '', // REMOVIDA A LEGENDA CONFORME SOLICITADO
          'tipo': 'programacao_filial',
          'filial_id': filial['id'],
          'filial_nome': filial['nome'],
          'filial_nome_dois': nomeFilial,
          'icon': Icons.local_gas_station,
          'sessao_pai': 'Vendas',
        };
      }).toList();
    });
    
    debugPrint("✅ Cards fixos de vendas carregados: ${_filiaisProgramacao.length} filiais");
  }

  Future<void> _carregarEmpresas() async {
    setState(() => carregandoEmpresas = true);
    final supabase = Supabase.instance.client;
    
    try {
      final dados = await supabase
          .from('empresas')
          .select('id, nome, nome_abrev, cnpj')
          .order('nome');
      
      setState(() {
        empresas = dados.map((empresa) {
          return {
            'id': empresa['id'],
            'label': empresa['nome_abrev'] ?? empresa['nome'],
            'descricao': empresa['cnpj'] ?? 'Sem CNPJ',
            'icon': Icons.business,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("❌ Erro ao carregar empresas: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro ao carregar empresas."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => carregandoEmpresas = false);
    }
  }

  Future<void> _carregarFiliaisDaEmpresa(String empresaId) async {
    setState(() {
      carregandoFiliaisEmpresa = true;
      filiaisDaEmpresa.clear();
    });
    
    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;
    
    try {
      dynamic queryResult;
      
      if (usuario != null && usuario.nivel < 3) {
        List<String> filiaisPermitidas = [];
        
        if (usuario.filialId != null) {
          filiaisPermitidas.add(usuario.filialId!);
        }
        
        if (filiaisPermitidas.isEmpty) {
          queryResult = await supabase
              .from('filiais')
              .select('id, nome, cidade, cnpj')
              .eq('empresa_id', empresaId)
              .eq('id', '00000000-0000-0000-0000-000000000000')
              .order('nome');
        } else {
          queryResult = await supabase
              .from('filiais')
              .select('id, nome, cidade, cnpj')
              .eq('empresa_id', empresaId)
              .inFilter('id', filiaisPermitidas)
              .order('nome');
        }
      } else {
        queryResult = await supabase
            .from('filiais')
            .select('id, nome, cidade, cnpj')
            .eq('empresa_id', empresaId)
            .order('nome');
      }
      
      List<Map<String, dynamic>> dados = [];
      
      if (queryResult is List) {
        for (var item in queryResult) {
          if (item is Map<String, dynamic>) {
            dados.add(item);
          } else {
            final map = Map<String, dynamic>.from(item as Map);
            dados.add(map);
          }
        }
      }
      
      setState(() {
        filiaisDaEmpresa = dados.map((filial) {
          return {
            'id': filial['id'],
            'label': filial['nome'],
            'descricao': filial['cidade'],
            'cnpj': filial['cnpj'],
            'icon': Icons.store,
          };
        }).toList();
      });
      
    } catch (e) {
      debugPrint("Erro ao carregar filiais: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao carregar filiais da empresa."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => carregandoFiliaisEmpresa = false);
    }
  }

  void _resetarFlagsVeiculos() {
    setState(() {
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
    });
  }

  void _resetarFlagsMotoristas() {
    setState(() {
      _mostrarMotoristas = false;
    });
  }

  void _resetarTodasFlagsGestaoFrota() {
    _resetarFlagsVeiculos();
    _resetarFlagsMotoristas();
    _mostrarAcompanhamentoOrdens = false;
  }

  void _resetarTodasFlags() {
    setState(() {
      selectedIndex = -1;
      showConversaoList = false;
      showControleAcesso = false;
      showConfigList = false;
      showUsuarios = false;
      _mostrarCalcGerado = false;
      _mostrarDownloads = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarListarCacls = false;
      _mostrarFiltrosEstoque = false;
      _mostrarEscolherFilial = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarFiltroMovimentacoes = false;
      _mostrarTempDensMedia = false;
      _mostrarMenuAjuda = false;
      _resetarTodasFlagsGestaoFrota();
      _mostrarFilhosSessao = false;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
      _filialSelecionadaNome = null;
      _dadosCalcGerado = null;
      _filialSelecionadaId = null;
      _contextoEscolhaFilial = '';
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
    });
  }

  void _mostrarFilhosDaSessao(String nomeSessao) {
    if (nomeSessao == 'Vendas') {
      // Usar as filiais fixas para programação
      if (_filiaisProgramacao.isEmpty) {
        _mostrarSemPermissao();
        return;
      }
      
      setState(() {
        _mostrarFilhosSessao = true;
        _sessaoAtual = nomeSessao;
        _filhosSessaoAtual = List.from(_filiaisProgramacao);
      });
      return;
    }

    final filhos = _filhosPorSessao[nomeSessao] ?? [];
    
    if (filhos.isEmpty) {
      _mostrarSemPermissao();
      return;
    }
    
    setState(() {
      _mostrarFilhosSessao = true;
      _sessaoAtual = nomeSessao;
      _filhosSessaoAtual = List.from(filhos);
      
      showConversaoList = false;
      _mostrarDownloads = false;
      _mostrarListarCacls = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherFilial = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiltrosEstoque = false;
      _mostrarCalcGerado = false;
      _mostrarTempDensMedia = false;
      _mostrarMenuAjuda = false;
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
      _mostrarMotoristas = false;
    });
  }

  // NOVO: Método para mostrar mensagem de "Sem permissão"
  void _mostrarSemPermissao() {
    setState(() {
      _mostrarFilhosSessao = true;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
    });
  }

  void _voltarParaCardsPai() {
    setState(() {
      _mostrarFilhosSessao = false;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
      
      showConversaoList = false;
      _mostrarDownloads = false;
      _mostrarListarCacls = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherFilial = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiltrosEstoque = false;
      _mostrarCalcGerado = false;
      _mostrarTempDensMedia = false;
      _mostrarMenuAjuda = false;
      _resetarTodasFlagsGestaoFrota();
      _filialSelecionadaNome = null;
      _dadosCalcGerado = null;
      _filialSelecionadaId = null;
      _contextoEscolhaFilial = '';
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: InkWell(
                    onTap: _resetarTodasFlags,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Image.asset(
                        'assets/logo_top_home.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    children: [
                      Text(
                        usuario?.nome ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.account_circle,
                          color: Color(0xFF0D47A1),
                          size: 30,
                        ),
                        onSelected: (value) async {
                          if (value == 'Perfil') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PerfilPage()),
                            );
                          }

                          if (value == 'Sair') {
                            await Supabase.instance.client.auth.signOut();
                            UsuarioAtual.instance = null;
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            }
                          }
                        },
                        itemBuilder: (context) {
                          return {'Perfil', 'Sair'}.map((choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              child: Text(choice),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Container(
                  width: 180,
                  color: const Color(0xFFF5F5F5),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: menuItems.length,
                          itemBuilder: (context, index) {
                            bool isSelected = selectedIndex == index;
                            return InkWell(
                              onTap: () {
                                _resetarTodasFlags();

                                setState(() {
                                  selectedIndex = index;
                                });

                                final itemSelecionado = menuItems[index];

                                if (itemSelecionado == 'Vendas' || 
                                    _filhosPorSessao.containsKey(itemSelecionado)) {
                                  _mostrarFilhosDaSessao(itemSelecionado);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFF5F5F5),
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF64A7FF)
                                          : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getMenuIcon(menuItems[index]),
                                      color: isSelected
                                          ? _getCorPorSessao(menuItems[index])
                                          : Colors.grey[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      menuItems[index],
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? _getCorPorSessao(menuItems[index])
                                            : Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _buildPageContent(usuario),
                  ),
                ),
              ],
            ),
          ),
          
            Container(
              height: 50,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '© Norton Tecnology - 550 California St, W-325, San Francisco, CA - EUA.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PowerTank Terminais 2026, All rights reserved.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageContent(UsuarioAtual? usuario) {
    if (selectedIndex == -1) {
      return _buildInicioPage(usuario);
    }

    switch (menuItems[selectedIndex]) {
      case 'Início':
        return _buildInicioPage(usuario);

      case 'Relatórios':
        return _buildRelatoriosPage();

      case 'Configurações':
        return _buildConfiguracoesPage(usuario);

      case 'Ajuda':
        if (!_mostrarMenuAjuda) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _mostrarMenuAjuda = true;
            });
          });
        }
        return _buildAjudaPage();

      case 'Estoques':
      case 'Apuração':
      case 'Circuito':
      case 'Vendas':
      case 'Gestão de Frota':
      case 'Bombeios e Cotas':
        return _buildConteudoSessoes();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAjudaPage() {
    return HomeCards(
      menuSelecionado: 'Ajuda',
      onCardSelecionado: (context, tipoCard) {
        switch (tipoCard) {
          case 'grande_arquiteto':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GrandeArquitetoPage(),
              ),
            );
            break;

          case 'atualizar_app':
            if (atualizarApp != null) {
              atualizarApp!.callAsFunction();
            } else {
              debugPrint('❌ atualizarApp não está disponível no JS');
            }
            break;

          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Funcionalidade $tipoCard em desenvolvimento...'),
              ),
            );
        }
      },
      onVoltar: () {
        setState(() {
          _mostrarMenuAjuda = false;
          selectedIndex = -1;
        });
      },
    );
  }

  Widget _buildRelatoriosPage() {
    return _buildPaginaPadronizada(
      titulo: "Relatórios",
      conteudo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              Material(
                elevation: 2,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _mostrarDownloads = true;
                    });
                  },
                  hoverColor: const Color(0xFFE8F5E9),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download,
                          color: _getCorPorSessao('Relatórios'),
                          size: 50,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Downloads',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0D47A1),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Baixar relatórios e dados',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      mostrarVoltar: false,
    );
  }

  Widget _buildConteudoSessoes() {
    if (_mostrarMenuAjuda) {
      return _buildAjudaPage();
    }
    
    if (_mostrarFiltrosEstoque && _filialParaFiltroId != null) {
      return _buildFiltrosEstoquePage();
    }

    if (_mostrarDownloads) {
      return DownloadsPage(
        key: const ValueKey('downloads-page'),
        onVoltar: () {
          if (selectedIndex == 1) {
            setState(() {
              _mostrarDownloads = false;
            });
          } else {
            _mostrarFilhosDaSessao('Estoques');
          }
        },
      );
    }

    if (showConversaoList) {
      return TabelasDeConversao(
        key: const ValueKey('tabelas'),
        onVoltar: () {
          _mostrarFilhosDaSessao('Apuração');
        },
      );
    }

    if (_mostrarListarCacls && _filialSelecionadaId != null) {
      return ListarCaclsPage(
        key: ValueKey('listar-cacls-$_filialSelecionadaId'),
        onVoltar: () {
          final usuario = UsuarioAtual.instance;
          setState(() {
            _mostrarListarCacls = false;
            _filialSelecionadaNome = null;

            if (usuario!.nivel == 3) {
              _mostrarEscolherFilial = true;
              _contextoEscolhaFilial = 'cacl';
            } else {
              _mostrarFilhosDaSessao('Apuração');
            }
          });
        },
        filialId: _filialSelecionadaId!,
        filialNome: _filialSelecionadaNome ?? 'Filial',
        onIrParaEmissao: () {
          setState(() {
            _mostrarListarCacls = false;
            _mostrarMedicaoTanques = true;
          });
        },
      );
    }
    
    if (_mostrarOrdensAnalise) {
      return Material(
        type: MaterialType.canvas,
        color: Colors.white,
        child: ListarOrdensAnalisesPage(
          key: const ValueKey('listar-ordens-analise'),
          onVoltar: () {
            _mostrarFilhosDaSessao('Apuração');
          },
        ),
      );
    }

    if (_mostrarHistorico) {
      return HistoricoCaclPage(
        key: const ValueKey('historico-cacl'),
        onVoltar: () {
          _mostrarFilhosDaSessao('Apuração');
        },
      );
    }

    if (_mostrarEscolherFilial) {
      return EscolherFilialPage(
        key: ValueKey('escolher-filial-$_contextoEscolhaFilial'),
        onVoltar: () {
          setState(() {
            _mostrarEscolherFilial = false;
            _contextoEscolhaFilial = '';
            _mostrarFilhosDaSessao('Apuração');
          });
        },
        onSelecionarFilial: (idFilial) async {
          try {
            final supabase = Supabase.instance.client;
            final filialData = await supabase
                .from('filiais')
                .select('nome')
                .eq('id', idFilial)
                .single();

            setState(() {
              _filialSelecionadaId = idFilial;
              _filialSelecionadaNome = filialData['nome'];
              _mostrarEscolherFilial = false;

              if (_contextoEscolhaFilial == 'cacl') {
                _mostrarListarCacls = true;
              } else if (_contextoEscolhaFilial == 'tanques') {
                _mostrarTanques = true;
              }

              _contextoEscolhaFilial = '';
            });
          } catch (e) {
            setState(() {
              _filialSelecionadaId = idFilial;
              _filialSelecionadaNome = 'Filial';
              _mostrarEscolherFilial = false;

              if (_contextoEscolhaFilial == 'cacl') {
                _mostrarListarCacls = true;
              }

              _contextoEscolhaFilial = '';
            });
          }
        },
        titulo: _contextoEscolhaFilial == 'cacl'
            ? 'Selecionar filial para CACL:'
            : 'Selecionar filial para gerenciar tanques:',
      );
    }

    if (_mostrarMedicaoTanques) {
      return MedicaoTanquesPage(
        key: const ValueKey('medicao-tanques'),
        filialSelecionadaId: _filialSelecionadaId,
        onVoltar: () {
          setState(() {
            _mostrarMedicaoTanques = false;
            _mostrarListarCacls = true;
          });
        },
        onFinalizarCACL: () {
          setState(() {
            _mostrarMedicaoTanques = false;
            _mostrarListarCacls = false;
            _mostrarFilhosDaSessao('Apuração');
          });
        },
      );
    }

    if (_mostrarTanques && _filialSelecionadaId != null) {
      return GerenciamentoTanquesPage(
        key: const ValueKey('gerenciamento-tanques'),
        onVoltar: () {
          final usuario = UsuarioAtual.instance;
          setState(() {
            _mostrarTanques = false;
            _filialSelecionadaId = null;

            if (usuario!.nivel == 3) {
              _mostrarEscolherFilial = true;
              _contextoEscolhaFilial = 'tanques';
            } else {
              _mostrarFilhosDaSessao('Apuração'); // ALTERADO: Agora volta para Apuração
            }
          });
        },
        filialSelecionadaId: _filialSelecionadaId,
      );
    }

    if (_mostrarFiliaisDaEmpresa) {
      return _buildFiliaisDaEmpresaPage();
    }

    if (_mostrarEstoquePorEmpresa) {
      return _buildEstoquePorEmpresaPage();
    }

    

    if (_mostrarAcompanhamentoOrdens) {
      return AcompanhamentoOrdensPage(
        key: const ValueKey('acompanhamento-ordens'),
        onVoltar: () {
          setState(() {
            _mostrarAcompanhamentoOrdens = false;
          });
        },
      );
    }

    if (_mostrarFiltroMovimentacoes) {
      return FiltroMovimentacoesPage(
        onVoltar: () {
          setState(() {
            _mostrarFiltroMovimentacoes = false;
            _mostrarFilhosDaSessao('Estoques');
          });
        },
      );
    }

    if (_mostrarTempDensMedia) {
      return TemperaturaDensidadeMediaPage();
    }

    if (_mostrarCalcGerado) {
      return CalcPage(
        key: const ValueKey('calc-page'),
        dadosFormulario: _dadosCalcGerado ?? {},
      );
    }

    if (_mostrarVeiculos && !_mostrarDetalhesVeiculo) {
      return VeiculosPage(
        key: const ValueKey('veiculos-page'),
        onVoltar: () {
          setState(() {
            _resetarTodasFlagsGestaoFrota();
            _mostrarFilhosDaSessao('Gestão de Frota');
          });
        },
        onSelecionarVeiculo: (veiculo) {
          setState(() {
            _veiculoSelecionado = veiculo;
            _mostrarDetalhesVeiculo = true;
          });
        },
      );
    }

    if (_mostrarDetalhesVeiculo && _veiculoSelecionado != null) {
      return VeiculoDetalhesPage(
        key: ValueKey('detalhes-${_veiculoSelecionado!['placa']}'),
        id: _veiculoSelecionado!['id'] ?? '',
        placa: _veiculoSelecionado!['placa'] ?? '',
        tanques: List<int>.from(_veiculoSelecionado!['tanques'] ?? []),
        transportadora: _veiculoSelecionado!['transportadora'] ?? '--',
        onVoltar: () {
          setState(() {
            _mostrarDetalhesVeiculo = false;
            _veiculoSelecionado = null;
          });
        },
      );
    }

    if (_mostrarMotoristas) {
      return MotoristasPage(
        key: const ValueKey('motoristas-page'),
        onVoltar: () {
          setState(() {
            _resetarTodasFlagsGestaoFrota();
            _mostrarFilhosDaSessao('Gestão de Frota');
          });
        },
      );
    }

    if (_mostrarFilhosSessao && _sessaoAtual != null) {
      return _buildFilhosSessaoPage();
    }

    if (_mostrarFilhosSessao && _sessaoAtual == null) {
      // Caso especial: quando não há permissão para nenhum card
      return _buildSemPermissaoPage();
    }

    if (_carregandoCards) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    return const SizedBox.shrink();
  }

  // NOVO: Widget padronizado para todas as páginas de cards
  Widget _buildPaginaPadronizada({
    required String titulo,
    required Widget conteudo,
    bool mostrarVoltar = true,
    VoidCallback? onVoltar,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30), // PADDING PADRONIZADO
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (mostrarVoltar && (_mostrarDownloads || showConversaoList || _mostrarListarCacls || _mostrarOrdensAnalise || 
                  _mostrarHistorico || _mostrarEscolherFilial || _mostrarMedicaoTanques || _mostrarTanques || 
                  _mostrarFiliaisDaEmpresa || _mostrarEstoquePorEmpresa || 
                  _mostrarFiltroMovimentacoes || _mostrarTempDensMedia || _mostrarCalcGerado || 
                  _mostrarVeiculos || _mostrarDetalhesVeiculo || _mostrarMotoristas || _mostrarFiltrosEstoque))
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: onVoltar ?? _voltarParaCardsPai,
                  tooltip: 'Voltar',
                ),
              if (mostrarVoltar && (_mostrarDownloads || showConversaoList || _mostrarListarCacls || _mostrarOrdensAnalise || 
                  _mostrarHistorico || _mostrarEscolherFilial || _mostrarMedicaoTanques || _mostrarTanques || 
                  _mostrarFiliaisDaEmpresa || _mostrarEstoquePorEmpresa || 
                  _mostrarFiltroMovimentacoes || _mostrarTempDensMedia || _mostrarCalcGerado || 
                  _mostrarVeiculos || _mostrarDetalhesVeiculo || _mostrarMotoristas || _mostrarFiltrosEstoque))
                const SizedBox(width: 10),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey), // BARRA SEPARADORA PADRONIZADA
          const SizedBox(height: 20),
          Expanded(child: conteudo),
        ],
      ),
    );
  }

  // NOVO: Página de "Sem permissão" padronizada
  Widget _buildSemPermissaoPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          const Text(
            'Sem permissão',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Você não tem permissão para acessar nenhum card nesta sessão.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Voltar para o menu'),
            onPressed: _voltarParaCardsPai,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilhosSessaoPage() {
    // Se não houver cards para mostrar
    if (_filhosSessaoAtual.isEmpty) {
      return _buildSemPermissaoPage();
    }

    // Filtrar apenas os cards que o usuário tem permissão
    final usuario = UsuarioAtual.instance;
    final cardsPermitidos = _filhosSessaoAtual.where((card) {
      final cardId = card['id']?.toString();
      if (usuario == null || cardId == null) return false;
      return usuario.podeAcessarCard(cardId);
    }).toList();

    // Se não houver nenhum card permitido
    if (cardsPermitidos.isEmpty) {
      return _buildPaginaPadronizada(
        titulo: _sessaoAtual ?? '',
        conteudo: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              const Text(
                'Não autorizado.',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Você não tem permissão para acessar nenhum card nesta sessão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar para o menu'),
                onPressed: _voltarParaCardsPai,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        mostrarVoltar: false, // NÃO MOSTRA SETA NA PRIMEIRA PÁGINA
      );
    }

    return _buildPaginaPadronizada(
      titulo: _sessaoAtual ?? '',
      conteudo: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Wrap(
            spacing: 15,
            runSpacing: 15,
            alignment: WrapAlignment.start,
            children: cardsPermitidos.map((card) {
              return SizedBox(
                width: 140,
                height: 170,
                child: _buildCardFilho(card),
              );
            }).toList(),
          ),
        ),
      ),
      mostrarVoltar: false, // NÃO MOSTRA SETA NA PRIMEIRA PÁGINA
    );
  }

  Widget _buildEstoquePorEmpresaPage() {
    return _buildPaginaPadronizada(
      titulo: 'Estoque por empresa',
      conteudo: carregandoEmpresas
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            )
          : empresas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma empresa encontrada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 7,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  padding: const EdgeInsets.only(bottom: 20),
                  children: empresas.map((empresa) => _buildCardEmpresa(empresa)).toList(),
                ),
      onVoltar: () => _mostrarFilhosDaSessao('Estoques'),
    );
  }

  Widget _buildFiliaisDaEmpresaPage() {
    return _buildPaginaPadronizada(
      titulo: 'Filiais - $_empresaSelecionadaNome',
      conteudo: carregandoFiliaisEmpresa
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            )
          : filiaisDaEmpresa.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma filial encontrada para esta empresa.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 6, // REDUZIDO DE 7 PARA 6 PARA DAR MAIS ESPAÇO
                  crossAxisSpacing: 18, // AUMENTADO DE 15 PARA 18
                  mainAxisSpacing: 18, // AUMENTADO DE 15 PARA 18
                  childAspectRatio: 1.0, // AUMENTADO DE 1.1 PARA 1.0 (MAIS QUADRADO)
                  padding: const EdgeInsets.only(bottom: 20),
                  children: filiaisDaEmpresa.map((filial) => _buildCardFilial(filial)).toList(),
                ),
      onVoltar: () {
        setState(() {
          _mostrarFiliaisDaEmpresa = false;
          _mostrarEstoquePorEmpresa = true;
        });
      },
    );
  }

  // NOVO: Card padronizado com solução para overflow
  Widget _buildCardFilho(Map<String, dynamic> card) {
    final usuario = UsuarioAtual.instance;
    final cardId = card['id']?.toString();
    
    if (usuario != null && cardId != null && !usuario.podeAcessarCard(cardId)) {
      return const SizedBox.shrink();
    }

    final corSessao = _getCorSessaoAtual();

    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _navegarParaCardFilho(card),
        hoverColor: corSessao.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                card['icon'],
                color: corSessao,
                size: 55,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 40,
                ),
                child: Text(
                  card['label'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF0D47A1),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A DESCRIÇÃO FOI REMOVIDA COMPLETAMENTE AQUI
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardEmpresa(Map<String, dynamic> empresa) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () async {
          final empresaId = empresa['id'];
          setState(() {
            _empresaSelecionadaId = empresaId;
            _empresaSelecionadaNome = empresa['label'];
          });
          
          await _carregarFiliaisDaEmpresa(_empresaSelecionadaId!);
          
          setState(() {
            _mostrarEstoquePorEmpresa = false;
            _mostrarFiliaisDaEmpresa = true;
          });
        },
        hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                empresa['icon'],
                color: _getCorPorSessao('Estoques'),
                size: 55,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 40),
                child: Text(
                  empresa['label'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // REMOVER A DESCRIÇÃO (CNPJ) AQUI TAMBÉM
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFilial(Map<String, dynamic> filial) {
    return Material(
      elevation: 3, // AUMENTADO DE 2 PARA 3
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          setState(() {
            _mostrarFiliaisDaEmpresa = false;
            _filialParaFiltroId = filial['id'];
            _filialParaFiltroNome = filial['label'];
            _empresaParaFiltroId = _empresaSelecionadaId;
            _empresaParaFiltroNome = _empresaSelecionadaNome;
            _mostrarFiltrosEstoque = true;
          });
        },
        hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(18), // AUMENTADO DE 15 PARA 18
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.5), // AUMENTADO DE 1 PARA 1.5
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filial['icon'],
                color: _getCorPorSessao('Estoques'),
                size: 60, // AUMENTADO DE 55 PARA 60
              ),
              const SizedBox(height: 12), // AUMENTADO DE 10 PARA 12
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 50), // AUMENTADO DE 40 PARA 50
                child: Text(
                  filial['label'],
                  style: const TextStyle(
                    fontSize: 14.5, // AUMENTADO DE 13 PARA 14.5
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navegarParaCardFilho(Map<String, dynamic> card) {
    final usuario = UsuarioAtual.instance;
    final cardId = card['id']?.toString();
    final tipo = card['tipo'];
    final sessaoPai = _sessaoAtual;

    if (usuario != null && cardId != null && !usuario.podeAcessarCard(cardId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para acessar este recurso.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    switch (sessaoPai) {
      case 'Apuração':
        _navegarParaCardApuracao(tipo, usuario);
        break;
      case 'Estoques':
        _navegarParaCardEstoques(tipo);
        break;
      case 'Circuito':
        _navegarParaCardCircuito(tipo);
        break;
      case 'Gestão de Frota':
        _navegarParaCardGestaoFrota(tipo);
        break;
      case 'Vendas':
        _navegarParaCardVendas(tipo, card);
        break;
      case 'Bombeios e Cotas':
        _navegarParaCardBombeios(tipo);
        break;
      default:
        debugPrint('Sessão pai não reconhecida: $sessaoPai');
    }
  }

  void _navegarParaCardApuracao(String tipo, UsuarioAtual? usuario) {
    switch (tipo) {
      case 'cacl':
        setState(() {
          if (usuario!.nivel == 3) {
            _mostrarEscolherFilial = true;
            _contextoEscolhaFilial = 'cacl';
          } else {
            _filialSelecionadaId = usuario.filialId;
            _filialSelecionadaNome = null;
            _mostrarListarCacls = true;
          }
        });
        break;
      case 'ordens_analise':
        setState(() {
          _mostrarOrdensAnalise = true;
        });
        break;
      case 'historico_cacl':
        setState(() {
          _mostrarHistorico = true;
        });
        break;
      case 'tabelas_conversao':
        setState(() {
          showConversaoList = true;
        });
        break;
      case 'temp_dens_media':
        setState(() {
          _mostrarTempDensMedia = true;
        });
        break;
      case 'tanques': // ADICIONADO: Caso para tanques agora em Apuração
        final usuario = UsuarioAtual.instance;
        setState(() {
          if (usuario!.nivel == 3) {
            _mostrarEscolherFilial = true;
            _contextoEscolhaFilial = 'tanques';
          } else {
            _mostrarTanques = true;
          }
        });
        break;
    }
  }

  void _navegarParaCardEstoques(String tipo) {
    switch (tipo) {
      case 'estoque_geral':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EstoqueGeralPage(),
          ),
        );
        break;
      case 'estoque_por_empresa':
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _carregarEmpresas();
        });
        break;
      case 'movimentacoes':
        setState(() {
          _mostrarFiltroMovimentacoes = true;
        });
        break;
      case 'transferencias':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransferenciasPage(
              onVoltar: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        break;
    }
  }

  void _navegarParaCardCircuito(String tipo) {
    switch (tipo) {      
      case 'acompanhar_ordem':  // ✅ MODIFICADO: Agora usa estado, não Navigator
        setState(() {
          _mostrarAcompanhamentoOrdens = true;
        });
        break;
      case 'visao_geral_circuito':
        // Adicione aqui quando criar a tela
        break;
    }
  }

  void _navegarParaCardGestaoFrota(String tipo) {
    switch (tipo) {
      case 'veiculos':
        setState(() {
          _mostrarVeiculos = true;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
          _mostrarMotoristas = false;
        });
        break;
        
      case 'veiculos_terceiros':
        debugPrint('Abrir tela de veículos de terceiros');
        break;
        
      case 'motoristas':
        setState(() {
          _mostrarMotoristas = true;
          _mostrarVeiculos = false;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
        });
        break;
        
      case 'documentacao':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ControleDocumentosPage(),
          ),
        );
        break;
    }
  }

  void _navegarParaCardVendas(String tipo, Map<String, dynamic> card) {
    switch (tipo) {
      case 'programacao_filial':
        final filialId = card['filial_id'];
        final filialNome = card['filial_nome'];
        final filialNomeDois = card['filial_nome_dois'];
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgramacaoPage(
              onVoltar: () {
                Navigator.pop(context);
              },
              filialId: filialId,
              filialNome: filialNome,
              filialNomeDois: filialNomeDois,
            ),
          ),
        );
        break;
    }
  }

  void _navegarParaCardBombeios(String tipo) {
    switch (tipo) {
      case 'bombeios':
        debugPrint('Abrir tela de bombeios');
        break;
    }
  }

  Widget _buildConfiguracoesPage(UsuarioAtual? usuario) {
    if (showUsuarios) {
      return UsuariosPage(
        key: const ValueKey('usuarios'),
        onVoltar: () => setState(() => showUsuarios = false),
      );
    }    
      
    if (showControleAcesso) {
      return ControleAcessoUsuarios(
        key: const ValueKey('controle_acesso'),
        onVoltar: () => setState(() => showControleAcesso = false),
      );
    }

    final List<Map<String, dynamic>> configCards = [];

    // Cartões disponíveis para todos os usuários
    configCards.add({
      'icon': Icons.refresh,
      'label': 'Atualizar app',
      'tipo': 'atualizar_app',
    });

    // Cartões apenas para administradores (nível >= 2)
    if (usuario != null && usuario.nivel >= 2) {
      configCards.addAll([
        {
          'icon': Icons.admin_panel_settings,
          'label': 'Controle de acesso',
          'tipo': 'controle_acesso',
        },
        {
          'icon': Icons.people_alt,
          'label': 'Usuários',
          'tipo': 'usuarios',
        },
      ]);
    }

    return _buildPaginaPadronizada(
      titulo: "Configurações do sistema",
      conteudo: GridView.count(
        crossAxisCount: 7,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
        padding: const EdgeInsets.only(bottom: 20),
        children: configCards.map((c) {
          return Material(
            color: Colors.white,
            elevation: 1,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: () {
                switch (c['tipo']) {
                  case 'atualizar_app':
                    if (atualizarApp != null) {
                      atualizarApp!.callAsFunction();
                    } else {
                      debugPrint('❌ atualizarApp não está disponível no JS');
                    }
                    break;
                  case 'controle_acesso':
                    setState(() => showControleAcesso = true);
                    break;
                  case 'usuarios':
                    setState(() => showUsuarios = true);
                    break;
                }
              },
              hoverColor: _getCorPorSessao('Configurações').withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      c['icon'],
                      color: _getCorPorSessao('Configurações'),
                      size: 55,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c['label'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      mostrarVoltar: false,
    );
  }

  IconData _getMenuIcon(String item) {
    switch (item) {
      case 'Início':
        return Icons.home;
      case 'Estoques':
        return Icons.leaderboard;
      case 'Apuração':
        return Icons.analytics;
      case 'Circuito':
        return Icons.route;
      case 'Vendas':
        return Icons.local_gas_station;
      case 'Gestão de Frota':
        return Icons.local_shipping;
      case 'Bombeios e Cotas':
        return Icons.invert_colors;
      case 'Relatórios':
        return Icons.bar_chart;
      case 'Configurações':
        return Icons.settings;
      case 'Ajuda':
        return Icons.help_outline;
      default:
        return Icons.circle;
    }
  }

  Widget _buildInicioPage(UsuarioAtual? usuario) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home,
            size: 80,
            color: Color(0xFF0D47A1),
          ),
          SizedBox(height: 20),
          Text(
            usuario != null 
              ? 'Olá, ${usuario.nome}! Bem-vindo ao VoxPower!'
              : 'Bem-vindo ao VoxPower!',
            style: TextStyle(
              fontSize: 24,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Seu ambiente moderno de gestão de estoques e logística em nuvem.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.6,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFiltrosEstoquePage() {
    return FiltroEstoquePage(
      key: ValueKey('filtros-$_filialParaFiltroId'),
      filialId: _filialParaFiltroId!,
      nomeFilial: _filialParaFiltroNome!,
      empresaId: _empresaParaFiltroId,
      empresaNome: _empresaParaFiltroNome,
      onVoltar: () {
        setState(() {
          _mostrarFiltrosEstoque = false;
          _mostrarFiliaisDaEmpresa = true;
        });
      },
      onConsultarEstoque: ({
        required String filialId,
        required String nomeFilial,
        String? empresaId,
        DateTime? mesFiltro,
        String? produtoFiltro,
        required String tipoRelatorio,
      }) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EstoqueMesPage(
              filialId: filialId,
              nomeFilial: nomeFilial,
              empresaId: empresaId,
              mesFiltro: mesFiltro,
              produtoFiltro: produtoFiltro,
              tipoRelatorio: tipoRelatorio,
            ),
          ),
        );
      },
    );
  }
}