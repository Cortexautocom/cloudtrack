import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/operacao/tabelas_de_conversao/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'configuracoes/usuarios.dart';
import 'perfil.dart';
import 'sessoes/operacao/cacl.dart';
import 'sessoes/gestao_de_frota/controle_documentos.dart';
import 'sessoes/operacao/medicoes_emitir_cacl.dart';
import 'sessoes/operacao/tanques.dart';
import 'sessoes/operacao/escolher_terminal.dart';
import 'sessoes/vendas/programacao.dart';
import 'sessoes/estoques/estoque_geral.dart';
import 'sessoes/operacao/estoque_tanques_geral.dart';
import 'sessoes/operacao/historico_cacl.dart';
import 'sessoes/operacao/listar_cacls.dart';
import 'sessoes/estoques/estoque_downloads.dart';
import 'sessoes/estoques/filtro_estoque.dart';
import 'sessoes/estoques/filtro_vendas.dart';
import 'sessoes/estoques/estoque_mes.dart';
import 'sessoes/estoques/compacto_final.dart';
import 'sessoes/gestao_de_frota/motoristas_page.dart';
import 'sessoes/gestao_de_frota/veiculos.dart';
import 'sessoes/gestao_de_frota/transportadoras.dart';
import 'sessoes/circuito/acompanhamento_ordens.dart';
import 'sessoes/estoques/transferencias.dart';
import 'sessoes/operacao/listar_ordens.dart';
import 'sessoes/laboratorio/temp_dens_media.dart';
import 'sessoes/ajuda/desenvolvedor.dart';
import 'sessoes/ajuda/suporte.dart';
import 'sessoes/circuito/criar_ordem.dart';
import 'sessoes/almoxerifado/frascos_amostras.dart';
import 'sessoes/almoxerifado/filtro_estoque_frascos.dart';
import 'sessoes/operacao/estoque_produto.dart';
import 'sessoes/operacao/filtro_estoque_produto.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

@JS()
external JSFunction? atualizarApp;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  int _hoveredMenuIndex = -1;
  TextEditingController searchController = TextEditingController();

  final List<String> menuItems = [
    'Início',
    'Estoques',
    'Operação',
    'Circuito',
    'Vendas',
    'Gestão de Frota',
    'Bombeios e Cotas Contratuais',
    'Laboratório',
    'Financeiro',
    'Jurídico',
    'Gestão de contratos',
    'Gestão de Projetos',
    'Recursos Humanos',
    'Almoxerifado',
    'Manutenção e ativos',
    'Segurança & Compliance',
    'Relatórios',
    'Configurações',
    'Ajuda',
  ];

  // FLAGS GERAIS
  bool showConversaoList = false;
  bool showControleAcesso = false;
  bool showConfigList = false;
  bool carregandoSessoes = false;
  bool showUsuarios = false;
  bool _mostrarAcompanhamentoOrdens = false;
  bool _mostrarSuporte = false;
  bool _mostrarFrascosAmostra = false;
  bool _mostrarResultadoFrascos = false;
  bool _mostrarPerdasSobras = false;

  // Parâmetros de filtro para a página de resultado de frascos
  DateTime _frascosDataInicial = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _frascosDataFinal = DateTime.now();
  String _frascosTipoRelatorio = 'sintetico';

  // FLAGS PARA SESSÕES ESPECÍFICAS
  bool _mostrarCalcGerado = false;
  bool _mostrarDownloads = false;
  bool _mostrarMedicaoTanques = false;
  bool _mostrarTanques = false;
  bool _mostrarOrdensAnalise = false;
  bool _mostrarHistorico = false;
  bool _mostrarListarCacls = false;
  bool _mostrarFiltrosEstoque = false;
  bool _mostrarFiltroMovimentacoes = false;
  bool _mostrarEscolherTerminal = false;
  bool _mostrarEstoquePorEmpresa = false;
  bool _mostrarFiliaisDaEmpresa = false;
  bool _mostrarEstoquePorTanque = false;
  bool _mostrarMenuAjuda = false;
  bool _mostrarTempDensMedia = false;
  bool _mostrarEstoqueProduto = false;
  bool _mostrarCardsFilial = false;
  bool _voltarParaTanquesApoCACL = false; // ← RASTREIA SE VEIO DE TANQUES
  bool _estoquePorTanqueVemDaApuracao =
      false; // ← RASTREIA ORIGEM DO ESTOQUE POR TANQUE

  // NOVAS VARIÁVEIS PARA GESTÃO DE FROTA
  bool _mostrarVeiculos = false;
  bool _mostrarDetalhesVeiculo = false;
  Map<String, dynamic>? _veiculoSelecionado;
  bool _mostrarMotoristas = false;
  bool _mostrarTransportadoras = false;

  // FLAG UNIFICADA PARA MOSTRAR FILHOS DE QUALQUER SESSÃO
  bool _mostrarFilhosSessao = false;
  String? _sessaoAtual;
  List<Map<String, dynamic>> _filhosSessaoAtual = [];
  // Tipo do card filho selecionado (navegação por estado)
  String? _filhoSelecionadoTipo;

  // DADOS PARA NAVEGAÇÃO
  String? _filialSelecionadaNome;
  String? _usuarioFilialNome;
  String? _usuarioTerminalNome;
  Map<String, dynamic>? _dadosCalcGerado;
  String? _filialSelecionadaId;
  String? _terminalSelecionadoId;
  String _contextoEscolhaTerminal = '';
  String? _filialParaFiltroId;
  String? _filialParaFiltroNome;
  String? _empresaParaFiltroId;
  String? _empresaParaFiltroNome;
  String? _terminalParaFiltroId;
  String? _terminalParaFiltroNome;

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
    'Operação': const Color(0xFF2196F3), // Azul
    'Circuito': const Color(0xFF9C27B0), // Roxo
    'Vendas': const Color(0xFF4CAF50), // Verde
    'Gestão de Frota': const Color(0xFFF44336), // Vermelho
    'Bombeios e Cotas Contratuais': const Color(0xFF00BCD4), // Ciano
    'Laboratório': const Color(0xFF8BC34A), // Verde claro
    'Financeiro': const Color(0xFF009688), // Verde-água
    'Jurídico': const Color(0xFF3F51B5), // Índigo
    'Gestão de contratos': const Color(0xFF3949AB), // Azul escuro (perto do Jurídico)
    'Gestão de Projetos': const Color(0xFFFF5722), // Laranja profundo
    'Recursos Humanos': const Color(0xFFE91E63), // Rosa
    'Almoxerifado': const Color(0xFF9E9E9E), // Cinza
    'Manutenção e ativos': const Color(0xFF455A64), // Cinza azulado
    'Segurança & Compliance': const Color(0xFFD32F2F), // Vermelho escuro
    'Relatórios': const Color(0xFF795548), // Marrom
    'Configurações': const Color(0xFF607D8B), // Azul cinza
    'Ajuda': const Color(0xFF673AB7), // Roxo profundo
    'Perdas e Sobras': const Color(0xFF2196F3), // Azul (mesma da Operação)
  };

  @override
  void initState() {
    super.initState();
    selectedIndex = -1;
    _carregarFilialParaProgramacao();
    _carregarCardsDoBanco();
    _carregarNomeFilialUsuario();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['openSessao'] == 'Operação') {
        setState(() {
          selectedIndex = menuItems.indexOf('Operação');
        });
        _mostrarFilhosDaSessao('Operação');
      }
    });
  }

  Future<void> _carregarNomeFilialUsuario() async {
    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null) return;

      final supabase = Supabase.instance.client;

      // Nível 1 ou 2: exibir o nome do terminal vinculado ao usuário
      if (usuario.nivel == 1 || usuario.nivel == 2) {
        final terminalId = usuario.terminalId;
        if (terminalId == null || terminalId.isEmpty) {
          setState(() {
            _usuarioTerminalNome = 'Sem terminal';
            _usuarioFilialNome = null;
          });
          return;
        }

        try {
          final terminalData = await supabase
              .from('terminais')
              .select('nome')
              .eq('id', terminalId)
              .maybeSingle();

          setState(() {
            _usuarioTerminalNome =
                terminalData?['nome']?.toString() ?? 'Sem terminal';
            _usuarioFilialNome = null;
          });
        } catch (e) {
          debugPrint('Erro ao carregar nome do terminal do usuário: $e');
          setState(() {
            _usuarioTerminalNome = 'Sem terminal';
            _usuarioFilialNome = null;
          });
        }
        return;
      }

      // Nível 3: não exibe terminal nem filial no cabeçalho
      if (usuario.nivel == 3) {
        setState(() {
          _usuarioFilialNome = null;
          _usuarioTerminalNome = null;
        });
        return;
      }

      // Demais níveis: exibir nome da filial
      final filialId = usuario.filialId;
      if (filialId == null || filialId.isEmpty) {
        setState(() {
          _usuarioFilialNome = null;
          _usuarioTerminalNome = null;
        });
        return;
      }

      final filialData = await supabase
          .from('filiais')
          .select('nome')
          .eq('id', filialId)
          .maybeSingle();

      setState(() {
        _usuarioFilialNome = filialData?['nome']?.toString();
        _usuarioTerminalNome = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar nome da filial/terminal do usuário: $e');
      setState(() {
        _usuarioFilialNome = null;
        _usuarioTerminalNome = null;
      });
    }
  }

  // NOVO: Método para obter cor da sessão atual
  Color _getCorSessaoAtual() {
    return _coresSessoes[_sessaoAtual ?? ''] ?? const Color(0xFF2E7D32);
  }

  // NOVO: Método para obter cor da sessão por nome
  Color _getCorPorSessao(String sessao) {
    return _coresSessoes[sessao] ?? const Color(0xFF2E7D32);
  }

  Future<void> _toggleFavorito(String cardId, bool novoValor) async {
    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;
    try {
      if (novoValor) {
        await supabase.from('relacoes_cards_favoritos').insert({
          'usuario_id': usuario.id,
          'card_id': cardId,
          'acesso': true,
        });
      } else {
        await supabase
            .from('relacoes_cards_favoritos')
            .delete()
            .eq('usuario_id', usuario.id)
            .eq('card_id', cardId);
      }
      setState(() {
        for (final sessao in _filhosPorSessao.values) {
          for (final card in sessao) {
            if (card['id'] == cardId) {
              card['favorito'] = novoValor;
            }
          }
        }
        // Atualizar cards dinâmicos não presentes em _filhosPorSessao
        for (final card in _filhosSessaoAtual) {
          if (card['id'] == cardId) {
            card['favorito'] = novoValor;
          }
        }
        for (final card in _filiaisProgramacao) {
          if (card['id'] == cardId) {
            card['favorito'] = novoValor;
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao atualizar favorito: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar favorito.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navegarParaFavorito(Map<String, dynamic> card) {
    final sessaoPai = card['sessao_pai']?.toString() ?? '';
    final menuIndex = menuItems.indexOf(sessaoPai);
    final filhos = _filhosPorSessao[sessaoPai] ?? [];

    setState(() {
      selectedIndex = menuIndex >= 0 ? menuIndex : 0;
      _sessaoAtual = sessaoPai;
      _mostrarFilhosSessao = true;
      _filhosSessaoAtual = List.from(filhos);
      _filhoSelecionadoTipo = null;
      // Limpa todos os flags de conteúdo
      _mostrarTanques = false;
      _mostrarListarCacls = false;
      showConversaoList = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherTerminal = false;
      _mostrarEstoquePorTanque = false;
      _mostrarTempDensMedia = false;
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
      _mostrarMotoristas = false;
      _mostrarTransportadoras = false;
      _mostrarFrascosAmostra = false;
      _mostrarEstoqueProduto = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFiltroMovimentacoes = false;
      _mostrarPerdasSobras = false;
      _mostrarAcompanhamentoOrdens = false;
      _mostrarDownloads = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarMedicaoTanques = false;
      _mostrarCardsFilial = false;
    });

    _navegarParaCardFilho(card);
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

      // Buscar IDs dos cards favoritados pelo usuário atual
      final favoritosDb = await supabase
          .from('relacoes_cards_favoritos')
          .select('card_id')
          .eq('usuario_id', usuario.id)
          .eq('acesso', true);

      final favoritosIds = <String>{
        for (final f in favoritosDb) f['card_id'].toString()
      };

      final List<Map<String, dynamic>> todosCards = [];

      for (var card in cardsDb) {
        final cardId = card['id'].toString();
        final sessaoPai = card['sessao_pai']?.toString() ?? 'Geral';

        // Cards que devem ser sempre incluídos (sem filtro de permissão)
        final cardsObrigatorios = ['estoque_por_tanque'];
        final tipoRaw = card['tipo']?.toString() ?? '';
        final tipo = (tipoRaw == 'movimentaces' || tipoRaw == 'entradas_e_saidas') ? 'movimentacoes' : tipoRaw;

        // Remover card isolado de CACL: acesso passa a ser feito via Estoque por tanque
        if (tipo == 'cacl') continue;

        // Para usuários de nível 1 e 2, permitir acesso a cards de movimentacoes
        if (usuario.nivel <= 2 && tipo == 'movimentacoes') {
          todosCards.add({
            'id': cardId,
            'label': card['nome'],
            'tipo': tipo,
            'sessao_pai': sessaoPai,
            'icon': _definirIconePorTipo(tipo),
            'descricao': _definirDescricaoPorTipo(tipo),
            'favorito': favoritosIds.contains(cardId),
          });
        }
        // Para os demais casos, manter a lógica original
        else if (usuario.nivel >= 3 ||
            usuario.podeAcessarCard(cardId) ||
            cardsObrigatorios.contains(tipo)) {
          todosCards.add({
            'id': cardId,
            'label': card['nome'],
            'tipo': tipo,
            'sessao_pai': sessaoPai,
            'icon': _definirIconePorTipo(tipo),
            'descricao': _definirDescricaoPorTipo(tipo),
            'favorito': favoritosIds.contains(cardId),
          });
        }
      }

      final Map<String, List<Map<String, dynamic>>> cardsOrganizados = {};

      for (var card in todosCards) {
        var sessaoPai = card['sessao_pai'];

        // Reatribuir Estoque por tanque para Operação
        if (card['tipo']?.toString() == 'estoque_por_tanque') {
          sessaoPai = 'Operação';
        }

        // Reatribuir Movimentações para Vendas
        if (card['tipo']?.toString() == 'movimentacoes') {
          sessaoPai = 'Vendas';
        }

        cardsOrganizados.putIfAbsent(sessaoPai, () => []);
        // Inserir no início para manter a ordem da consulta reversed
        cardsOrganizados[sessaoPai]!.insert(0, card);
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
    _filhosPorSessao['Operação'] = [
      {
        'id': 'fallback-ordens',
        'icon': Icons.assignment,
        'label': 'Ordens / Análises',
        'descricao': 'Geração e gestão de ordens',
        'tipo': 'ordens_analise',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-historico',
        'icon': Icons.history,
        'label': 'Histórico de CACLs',
        'descricao': 'Consultar histórico de CACLs emitidos',
        'tipo': 'historico_cacl',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-tabelas',
        'icon': Icons.table_chart,
        'label': 'Tabelas de Conversão',
        'descricao': 'Tabelas de conversão de densidade e temperatura',
        'tipo': 'tabelas_conversao',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-tanques',
        'icon': Icons.oil_barrel,
        'label': 'Tanques',
        'descricao': 'Gerenciamento de tanques',
        'tipo': 'tanques',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-estoque-tanque',
        'icon': Icons.water_drop,
        'label': 'Estoque por tanque',
        'descricao': 'Acompanhar estoques por tanque',
        'tipo': 'estoque_por_tanque',
        'sessao_pai': 'Operação',
      },
      {
        'id': 'fallback-perdas-sobras',
        'icon': Icons.insights,
        'label': 'Gestão de perdas e sobras',
        'descricao': 'Controle de perdas e sobras operacionais',
        'tipo': 'perdas_sobras',
        'sessao_pai': 'Operação',
      },
    ];

    _filhosPorSessao['Perdas e Sobras'] = [
      {
        'id': 'perdas-sobras-dutoviario',
        'icon': Icons.blur_linear,
        'label': 'Dutoviário',
        'descricao': 'Gestão de perdas e sobras dutoviárias',
        'tipo': 'dutoviario',
        'sessao_pai': 'Perdas e Sobras',
      },
      {
        'id': 'perdas-sobras-rodoviario',
        'icon': Icons.local_shipping,
        'label': 'Rodoviário',
        'descricao': 'Gestão de perdas e sobras rodoviárias',
        'tipo': 'rodoviario',
        'sessao_pai': 'Perdas e Sobras',
      },
    ];

    _filhosPorSessao['Estoques'] = [
      {
        'id': 'fallback-geral',
        'icon': Icons.hub,
        'label': 'Estoque Geral',
        'descricao': 'Visão consolidada dos estoques da base',
        'tipo': 'estoque_geral',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-compacto-final',
        'icon': Icons.view_compact,
        'label': 'Compacto final',
        'descricao': 'Visão compacta do final do dia',
        'tipo': 'compacto_final',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-empresa',
        'icon': Icons.business,
        'label': 'Movimentação por empresa',
        'descricao': 'Movimentações por empresa',
        'tipo': 'movimentacao_por_empresa',
        'sessao_pai': 'Estoques',
      },

      {
        'id': 'fallback-transf',
        'icon': Icons.low_priority,
        'label': 'Transferências',
        'descricao': 'Gerenciar transferências entre filiais',
        'tipo': 'transferencias',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-descargas',
        'icon': Icons.swap_horizontal_circle,
        'label': 'Controle de descargas',
        'descricao': 'Controle de recebimento de produtos',
        'tipo': 'controle_descargas',
        'sessao_pai': 'Estoques',
      },
      {
        'id': 'fallback-estoque-fiscal',
        'icon': Icons.receipt_long,
        'label': 'Estoque fiscal',
        'descricao': 'Acompanhar estoque fiscal e tributário',
        'tipo': 'estoque_fiscal',
        'sessao_pai': 'Estoques',
      },
    ];

    _filhosPorSessao['Circuito'] = [
      {
        'id': 'fallback-acompanhar',
        'icon': Icons.directions_car,
        'label': 'Acompanhar ordem',
        'descricao': 'Acompanhar situação da ordem',
        'tipo': 'acompanhar_ordem',
        'sessao_pai': 'Circuito',
      },
      {
        'id': 'fallback-visao',
        'icon': Icons.dashboard,
        'label': 'Visão geral',
        'descricao': 'Panorama completo dos circuitos',
        'tipo': 'visao_geral_circuito',
        'sessao_pai': 'Circuito',
      },
      {
        'id': 'criar-ordem',
        'icon': Icons.add_circle_outline,
        'label': 'Criar Ordem',
        'descricao': 'Criar uma nova ordem',
        'tipo': 'criar_ordem',
        'sessao_pai': 'Circuito',
      },
    ];

    _filhosPorSessao['Gestão de Frota'] = [
      {
        'id': 'fallback-veiculos',
        'icon': Icons.directions_car,
        'label': 'Veículos Próprios',
        'descricao': 'Gerenciar frota de veículos próprios',
        'tipo': 'veiculos',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-transportadoras',
        'icon': Icons.local_shipping,
        'label': 'Transportadoras',
        'descricao': 'Gerenciar transportadoras',
        'tipo': 'transportadoras',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-terceiros',
        'icon': Icons.local_shipping,
        'label': 'Veículos de terceiros',
        'descricao': 'Gerenciar veículos de transportadoras',
        'tipo': 'veiculos_terceiros',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-motoristas',
        'icon': Icons.people,
        'label': 'Motoristas',
        'descricao': 'Gerenciar cadastro de motoristas',
        'tipo': 'motoristas',
        'sessao_pai': 'Gestão de Frota',
      },
      {
        'id': 'fallback-documentacao',
        'icon': Icons.description,
        'label': 'Documentação',
        'descricao': 'Controle de documentos da frota',
        'tipo': 'documentacao',
        'sessao_pai': 'Gestão de Frota',
      },
    ];

    _filhosPorSessao['Bombeios e Cotas Contratuais'] = [
      {
        'id': 'fallback-bombeios',
        'icon': Icons.invert_colors,
        'label': 'Bombeios e Cotas Contratuais',
        'descricao': 'Controle de bombeios',
        'tipo': 'bombeios',
        'sessao_pai': 'Bombeios e Cotas Contratuais',
      },
    ];

    _filhosPorSessao['Almoxerifado'] = [
      {
        'id': 'fallback-frascos-amostra',
        'icon': Icons.science_outlined,
        'label': 'Frascos de amostras',
        'descricao': 'Controle de frascos de amostras',
        'tipo': 'frascos_amostra',
        'sessao_pai': 'Almoxerifado',
      },
    ];

    _filhosPorSessao['Laboratório'] = [
      {
        'id': 'fallback-temp',
        'icon': Icons.thermostat,
        'label': 'Temperatura e Densidade média',
        'descricao': 'Cálculo de temperatura e densidade média',
        'tipo': 'temp_dens_media',
        'sessao_pai': 'Laboratório',
      },
      {
        'id': 'analise-conformidade',
        'icon': Icons.fact_check,
        'label': 'Análise de conformidade e qualidade',
        'descricao': 'Relatórios de conformidade e qualidade de produtos',
        'tipo': 'analise_conformidade',
        'sessao_pai': 'Laboratório',
      },
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
      'compacto_final': Icons.view_compact,
      'estoque_por_empresa': Icons.business,
      'estoque_por_tanque': Icons.water_drop,
      'movimentacoes': Icons.swap_horiz,
      'movimentacao_por_empresa': Icons.business,
      'movimentaces': Icons.swap_horiz,
      'transferencias': Icons.low_priority,
      'controle_descargas': Icons.swap_horizontal_circle,
      'acompanhar_ordem': Icons.directions_car,
      'visao_geral_circuito': Icons.dashboard,
      'veiculos': Icons.directions_car,
      'transportadoras': Icons.local_shipping,
      'veiculos_terceiros': Icons.local_shipping,
      'motoristas': Icons.people,
      'documentacao': Icons.description,
      'bombeios': Icons.invert_colors,
      'programacao_filial': Icons.local_gas_station,
      'criar_ordem': Icons.add_circle_outline,
      'frascos_amostra': Icons.science_outlined,
      'estoque_fiscal': Icons.receipt_long,
      'estoque_produto': Icons.opacity,
      'analise_conformidade': Icons.fact_check,
      'perdas_sobras': Icons.insights,
      'dutoviario': Icons.blur_linear,
      'rodoviario': Icons.local_shipping,
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
      'compacto_final': 'Visão compacta do final do dia',
      'estoque_por_empresa': 'Movimentações por empresa',
      'estoque_por_tanque': 'Acompanhar estoques por tanque',
      'movimentacoes': 'Relatório Entradas e Saídas',
      'movimentacao_por_empresa': 'Movimentações por empresa',
      'movimentaces': 'Relatório Entradas e Saídas',
      'transferencias': 'Gerenciar transferências entre filiais',
      'controle_descargas': 'Controle de recebimento de produtos',
      'acompanhar_ordem': 'Acompanhar situação da ordem',
      'visao_geral_circuito': 'Panorama completo dos circuitos',
      'veiculos': 'Gerenciar frota de veículos próprios',
      'transportadoras': 'Gerenciar transportadoras',
      'veiculos_terceiros': 'Gerenciar veículos de transportadoras',
      'motoristas': 'Gerenciar cadastro de motoristas',
      'documentacao': 'Controle de documentos da frota',
      'bombeios': 'Controle de bombeios',
      'programacao_filial': 'Programação de vendas por filial',
      'frascos_amostra': 'Controle de frascos de amostras',
      'estoque_fiscal': 'Acompanhar estoque fiscal e tributário',
      'estoque_produto': 'Acompanhar estoque por produto',
      'analise_conformidade': 'Análise de conformidade e qualidade',
    };
    return mapaDescricoes[tipo] ?? '';
  }

  Future<void> _carregarFilialParaProgramacao() async {
    final supabase = Supabase.instance.client;

    try {
      // Busca todas as filiais — terminal_id_1 é apenas parâmetro, não critério
      final filiaisData = await supabase
          .from('filiais')
          .select('id, nome, nome_dois, terminal_id_1')
          .order('nome');

      if (filiaisData.isEmpty) {
        setState(() {
          _filiaisProgramacao = [];
        });
        return;
      }

      final List<Map<String, dynamic>> filiaisProcessadas = [];

      for (var filial in filiaisData) {
        final filialId = filial['id'];
        final filialNome = filial['nome'] ?? 'Sem nome';
        final filialNomeDois = filial['nome_dois'] ?? filialNome;
        final terminalId = filial['terminal_id_1']; // pode ser null

        filiaisProcessadas.add({
          'id': filialId.toString(),
          'label': filialNomeDois,
          'descricao': '',
          'tipo': 'programacao_filial',
          'filial_id': filialId,
          'filial_nome': filialNome,
          'filial_nome_dois': filialNomeDois,
          'terminal_id': terminalId,
          'icon': Icons.local_gas_station,
          'sessao_pai': 'Vendas',
          'favorito': false,
        });
      }

      filiaisProcessadas.sort((a, b) {
        final nomeA = a['label']?.toString() ?? '';
        final nomeB = b['label']?.toString() ?? '';
        return nomeA.compareTo(nomeB);
      });

      setState(() {
        _filiaisProgramacao = filiaisProcessadas;
      });
    } catch (e) {
      debugPrint('❌ ERRO ao carregar filiais: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar filiais: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      setState(() {
        _filiaisProgramacao = [];
      });
    }
  }

  Future<void> _carregarEmpresas() async {
    setState(() => carregandoEmpresas = true);
    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;
    final nivelUsuario = usuario?.nivel ?? 0;

    try {
      List<Map<String, dynamic>> dados = [];

      if (nivelUsuario == 3) {
        // Nível 3: apenas a empresa do próprio usuário
        final empresaId = usuario?.empresaId ?? '';
        if (empresaId.isNotEmpty) {
          final result = await supabase
              .from('empresas')
              .select('id, nome, nome_abrev, cnpj')
              .eq('id', empresaId)
              .limit(1);
          dados = List<Map<String, dynamic>>.from(result);
        }
      } else if (nivelUsuario == 4) {
        // Nível 4: empresas que operam no terminal do usuário
        final terminalId = usuario?.terminalId ?? '';
        debugPrint('🔍 [Nível 4] terminalId=$terminalId');
        if (terminalId.isNotEmpty) {
          final relacoes = await supabase
              .from('relacoes_terminais')
              .select('empresa_id')
              .eq('terminal_id', terminalId);

          debugPrint('🔍 [Nível 4] relacoes_terminais retornou ${relacoes.length} registros');

          final empresasIds = relacoes
              .map((r) => r['empresa_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          debugPrint('🔍 [Nível 4] empresasIds=$empresasIds');

          if (empresasIds.isNotEmpty) {
            final result = await supabase
                .from('empresas')
                .select('id, nome, nome_abrev, cnpj')
                .inFilter('id', empresasIds)
                .order('nome');
            dados = List<Map<String, dynamic>>.from(result);
          }
        }
      } else {
        // Demais níveis (administradores): todas as empresas
        final result = await supabase
            .from('empresas')
            .select('id, nome, nome_abrev, cnpj')
            .order('nome');
        dados = List<Map<String, dynamic>>.from(result);
      }

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

  void _resetarFlagsTransportadoras() {
    setState(() {
      _mostrarTransportadoras = false;
    });
  }

  void _resetarTodasFlagsGestaoFrota() {
    _resetarFlagsVeiculos();
    _resetarFlagsMotoristas();
    _resetarFlagsTransportadoras();
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
      _mostrarFiltroMovimentacoes = false;      
      _mostrarFrascosAmostra = false;
      _mostrarResultadoFrascos = false;
      _mostrarEscolherTerminal = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorTanque = false;
      _mostrarTempDensMedia = false;
      _mostrarMenuAjuda = false;
      _mostrarSuporte = false;
      _mostrarEstoqueProduto = false;
      _voltarParaTanquesApoCACL = false;
      _resetarTodasFlagsGestaoFrota();
      _mostrarFilhosSessao = false;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
      _filhoSelecionadoTipo = null;
      _filialSelecionadaNome = null;
      _dadosCalcGerado = null;
      _filialSelecionadaId = null;
      _contextoEscolhaTerminal = '';
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _terminalParaFiltroId = null; // ← ADICIONAR
      _terminalParaFiltroNome = null; // ← ADICIONAR
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
    });
  }

  void _mostrarFilhosDaSessao(String nomeSessao) {
    if (nomeSessao == 'Vendas') {
      // Combinar cards do banco (ou fallback) + filiais de programação
      // Excluir programacao_filial do banco para evitar duplicação com _filiaisProgramacao
      final cardsVendas = <Map<String, dynamic>>[
        ...(_filhosPorSessao['Vendas'] ?? [
          {
            'id': 'fallback-mov',
            'icon': Icons.swap_horiz,
            'label': 'Relatório Entradas e Saídas',
            'descricao': 'Acompanhar entradas e saídas em geral',
            'tipo': 'movimentacoes',
            'sessao_pai': 'Vendas',
          },
        ]).where((c) => c['tipo'] != 'programacao_filial'),
        ..._filiaisProgramacao,
      ];

      setState(() {
        _mostrarFilhosSessao = true;
        _sessaoAtual = nomeSessao;
        _filhosSessaoAtual = List.from(cardsVendas);
      });
      return;
    }

    var filhos = _filhosPorSessao[nomeSessao] ?? [];

    if (nomeSessao == 'Gestão de Frota' &&
        !filhos.any((card) => card['tipo'] == 'transportadoras')) {
      filhos = [
        ...filhos,
        {
          'id': 'transportadoras',
          'icon': Icons.local_shipping,
          'label': 'Transportadoras',
          'descricao': 'Gerenciar transportadoras',
          'tipo': 'transportadoras',
          'sessao_pai': 'Gestão de Frota',
          'favorito': false,
        },
      ];
    }

    // Remover temp_dens_media de Operação (disponível apenas em Laboratório)
    if (nomeSessao == 'Operação') {
      filhos = filhos.where((card) => card['tipo'] != 'temp_dens_media').toList();
    }

    // ATUALIZADO: Filtrar cards de Estoques por nível
    if (nomeSessao == 'Estoques') {
      final usuario = UsuarioAtual.instance;
      if (usuario != null) {
        if (usuario.nivel <= 1) {
          // Nível 1: remover cards de empresa (empresa-level)
          filhos = filhos
              .where(
                (card) =>
                    card['tipo'] != 'estoque_por_empresa' &&
                    card['tipo'] != 'movimentacao_por_empresa',
              )
              .toList();
        } else if (usuario.nivel == 2) {
          // Nível 2: remover apenas cards de empresa, manter movimentacoes
          filhos = filhos
              .where(
                (card) =>
                    card['tipo'] != 'estoque_por_empresa' &&
                    card['tipo'] != 'movimentacao_por_empresa',
              )
              .toList();
        } else {
          // Nível 3: manter cards de empresa, remover o card genérico de movimentações
          filhos = filhos
              .where((card) => card['tipo'] != 'movimentacoes')
              .toList();
        }
      }
    }

    if (filhos.isEmpty) {
      _mostrarSemPermissao();
      return;
    }

    setState(() {
      _mostrarFilhosSessao = true;
      _sessaoAtual = nomeSessao;
      _filhosSessaoAtual = List.from(filhos);
      _filhoSelecionadoTipo = null;

      showConversaoList = false;
      _mostrarDownloads = false;
      _mostrarListarCacls = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherTerminal = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFrascosAmostra = false;
      _mostrarResultadoFrascos = false;
      _mostrarCalcGerado = false;
      _mostrarTempDensMedia = false;
      _mostrarMenuAjuda = false;
      _mostrarSuporte = false;
      _mostrarCardsFilial = false;
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
      _mostrarMotoristas = false;
      _mostrarTransportadoras = false;
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
      _filhoSelecionadoTipo = null;

      showConversaoList = false;
      _mostrarDownloads = false;
      _mostrarListarCacls = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEscolherTerminal = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarEstoquePorTanque = false;
      _mostrarFiltrosEstoque = false;
      _mostrarFrascosAmostra = false;
      _mostrarResultadoFrascos = false;
      _mostrarCalcGerado = false;
      _mostrarTempDensMedia = false;
      _mostrarEstoqueProduto = false;
      _mostrarPerdasSobras = false;
      _mostrarMenuAjuda = false;
      _mostrarCardsFilial = false;
      _resetarTodasFlagsGestaoFrota();
      _filialSelecionadaNome = null;
      _dadosCalcGerado = null;
      _filialSelecionadaId = null;
      _contextoEscolhaTerminal = '';
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _terminalParaFiltroId = null; // ← ADICIONAR
      _terminalParaFiltroNome = null; // ← ADICIONAR
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;

    return PopScope(
      canPop: false,
      child: Scaffold(
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
                          'assets/logo_top_home3.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: (usuario?.nivel == 3)
                              ? [
                                  Text(
                                    usuario?.nome ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ]
                              : [
                                  Text(
                                    usuario?.nome ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0D47A1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (usuario?.nivel == 1 || usuario?.nivel == 2)
                                        ? (_usuarioTerminalNome ??
                                              (UsuarioAtual
                                                              .instance
                                                              ?.terminalId ==
                                                          null ||
                                                      UsuarioAtual
                                                          .instance!
                                                          .terminalId!
                                                          .isEmpty
                                                  ? 'Sem terminal'
                                                  : 'Carregando...'))
                                        : (_usuarioFilialNome ??
                                              (UsuarioAtual.instance?.filialId ==
                                                          null ||
                                                      UsuarioAtual
                                                          .instance!
                                                          .filialId!
                                                          .isEmpty
                                                  ? 'Sem filial'
                                                  : 'Carregando...')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          surfaceTintColor: Colors.white,
                          color: Colors.white,
                          icon: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF0D47A1),
                            size: 30,
                          ),
                          onSelected: (value) async {
                            if (value == 'Perfil') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PerfilPage(),
                                ),
                              );
                            }

                            if (value == 'Sair') {
                              await Supabase.instance.client.auth.signOut();
                              UsuarioAtual.instance = null;
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
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
                        const SizedBox(width: 15),
                        // Lista suspensa de idiomas (agora o último objeto à direita)
                        PopupMenuButton<String>(
                          offset: const Offset(0, 40),
                          tooltip: 'Selecionar Idioma',
                          onSelected: (value) {
                            // Funcionalidade fictícia de troca de idioma
                          },
                          surfaceTintColor: Colors.white,
                          color: Colors.white,
                          elevation: 8,
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'en',
                              child: Row(
                                children: [
                                  Text('🇺🇸'),
                                  SizedBox(width: 8),
                                  Text('English (US)'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'es',
                              child: Row(
                                children: [
                                  Text('🇪🇸'),
                                  SizedBox(width: 8),
                                  Text('Español'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'pt',
                              child: Row(
                                children: [
                                  Text('🇧🇷'),
                                  SizedBox(width: 8),
                                  Text('Português (BR)'),
                                ],
                              ),
                            ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🇧🇷',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'PT-BR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
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
                              final nomeItem = menuItems[index];
                              final nomeFormatado = _formatarNomeMenu(nomeItem);

                              return MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _hoveredMenuIndex = index),
                                onExit: (_) =>
                                    setState(() => _hoveredMenuIndex = -1),
                                child: InkWell(
                                  onTap: () {
                                    _resetarTodasFlags();

                                    setState(() {
                                      selectedIndex = index;
                                    });

                                    final itemSelecionado = menuItems[index];

                                    if (itemSelecionado == 'Vendas' ||
                                        _filhosPorSessao.containsKey(
                                          itemSelecionado,
                                        )) {
                                      _mostrarFilhosDaSessao(itemSelecionado);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : (_hoveredMenuIndex == index
                                                ? const Color(0xFFFAFBFF)
                                                : const Color(0xFFF5F5F5)),
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
                                      crossAxisAlignment: CrossAxisAlignment
                                          .center, // Centraliza verticalmente
                                      children: [
                                        Icon(
                                          _getMenuIcon(nomeItem),
                                          color: isSelected
                                              ? _getCorPorSessao(nomeItem)
                                              : Colors.grey[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          // Adiciona Expanded para melhor controle
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            transform: Matrix4.translationValues(
                                              _hoveredMenuIndex == index
                                                  ? 6.0
                                                  : 0.0,
                                              0,
                                              0,
                                            ),
                                            child: AnimatedDefaultTextStyle(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              style: TextStyle(
                                                fontWeight:
                                                    (isSelected ||
                                                        _hoveredMenuIndex ==
                                                            index)
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? _getCorPorSessao(nomeItem)
                                                    : Colors.grey[800],
                                                fontSize: 13,
                                                height: 1.1,
                                              ),
                                              child: Text(
                                                nomeFormatado,
                                                maxLines: 2,
                                                overflow: TextOverflow.visible,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                    'PowerTank Terminais 2026, All rights reserved.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '© Norton Technology - 550 California St, W-325, San Francisco, CA - EUA.',
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
        if (_mostrarSuporte) {
          return _buildPaginaPadronizada(
            titulo: 'Suporte',
            conteudo: const SuportePage(),
            onVoltar: () {
              setState(() {
                _mostrarSuporte = false;
                _mostrarMenuAjuda = true;
              });
            },
          );
        }

        if (!_mostrarMenuAjuda) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _mostrarMenuAjuda = true;
            });
          });
        }

        return _buildAjudaPage();

      case 'Financeiro':
      case 'Jurídico':
      case 'Gestão de contratos':
      case 'Gestão de Projetos':
      case 'Recursos Humanos':
      case 'Segurança & Compliance':
      case 'Manutenção e ativos':
      case 'Bombeios e Cotas Contratuais':
        return _buildAreaIndisponivelPage();

      case 'Almoxerifado':
        if (_mostrarFrascosAmostra) {
          if (_mostrarResultadoFrascos) {
            return FrascosAmostraPage(
              onVoltar: () {
                setState(() {
                  _mostrarResultadoFrascos = false;
                });
              },
              terminalId: _terminalParaFiltroId,
              empresaId: _empresaParaFiltroId,
              nomeTerminal: _terminalParaFiltroNome ?? '',
              empresaNome: _empresaParaFiltroNome,
              dataInicial: _frascosDataInicial,
              dataFinal: _frascosDataFinal,
              tipoRelatorio: _frascosTipoRelatorio,
            );
          }
          return FiltroEstoqueFrascosPage(
            terminalId: _terminalParaFiltroId,
            empresaId: _empresaParaFiltroId,
            nomeTerminal: _terminalParaFiltroNome ?? '',
            empresaNome: _empresaParaFiltroNome,
            onConsultarEstoque: ({
              required String? terminalId,
              required String? empresaId,
              required String nomeTerminal,
              String? empresaNome,
              required DateTime dataInicial,
              required DateTime dataFinal,
              required String tipoRelatorio,
            }) {
              setState(() {
                _terminalParaFiltroId = terminalId;
                _empresaParaFiltroId = empresaId;
                _terminalParaFiltroNome = nomeTerminal;
                _empresaParaFiltroNome = empresaNome;
                _frascosDataInicial = dataInicial;
                _frascosDataFinal = dataFinal;
                _frascosTipoRelatorio = tipoRelatorio;
                _mostrarResultadoFrascos = true;
              });
            },
            onVoltar: () {
              setState(() {
                _mostrarFrascosAmostra = false;
                _mostrarFilhosDaSessao('Almoxerifado');
              });
            },
          );
        }
        return _buildConteudoSessoes();

      case 'Estoques':
      case 'Operação':
      case 'Circuito':
      case 'Vendas':
      case 'Gestão de Frota':
      case 'Laboratório':
        return _buildConteudoSessoes();

      default:
        return const SizedBox.shrink();
    }
  }

  // NOVO: Página padronizada para áreas indisponíveis
  Widget _buildAreaIndisponivelPage() {
    final areaAtual = menuItems[selectedIndex];

    return _buildPaginaPadronizada(
      titulo: areaAtual,
      conteudo: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.do_not_disturb, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 30), // Aumente este espaçamento
            const Text(
              'Seção não disponível no plano contratado.',
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15), // Aumente este espaçamento
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40)),
            // BOTÃO REMOVIDO - apenas mantenha a mensagem
          ],
        ),
      ),
      mostrarVoltar: false,
    );
  }

  Widget _buildAjudaPage() {
    return HomeCards(
      menuSelecionado: 'Ajuda',
      onCardSelecionado: (context, tipoCard) {
        switch (tipoCard) {
          case 'suporte':
            setState(() {
              _mostrarSuporte = true;
            });
            break;

          case 'desenvolvedor':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DesenvolvedorPage(),
              ),
            );
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
          _mostrarSuporte = false;
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
              _HoverScale(
                child: Material(
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
              ),
            ],
          ),
        ],
      ),
      mostrarVoltar: false,
    );
  }

  Widget _buildConteudoSessoes() {
    final usuario = UsuarioAtual.instance;
    
    // PRIMEIRO: Obter a sessão atual do menu lateral
    final sessaoAtual = selectedIndex >= 0 && selectedIndex < menuItems.length
        ? menuItems[selectedIndex]
        : null;

    // SEÇÃO: Ajuda (caso especial, mas ainda verifica a sessão)
    if (sessaoAtual == 'Ajuda') {
      if (_mostrarSuporte) {
        return _buildPaginaPadronizada(
          titulo: 'Suporte',
          conteudo: const SuportePage(),
          onVoltar: () {
            setState(() {
              _mostrarSuporte = false;
              _mostrarMenuAjuda = true;
            });
          },
        );
      }
      
      if (!_mostrarMenuAjuda) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _mostrarMenuAjuda = true;
          });
        });
      }
      
      return _buildAjudaPage();
    }

    // SEÇÃO: Almoxerifado
    if (sessaoAtual == 'Almoxerifado') {
      if (_mostrarFrascosAmostra) {
        if (_mostrarResultadoFrascos) {
          return FrascosAmostraPage(
            onVoltar: () {
              setState(() {
                _mostrarResultadoFrascos = false;
              });
            },
            terminalId: _terminalParaFiltroId,
            empresaId: _empresaParaFiltroId,
            nomeTerminal: _terminalParaFiltroNome ?? '',
            empresaNome: _empresaParaFiltroNome,
            dataInicial: _frascosDataInicial,
            dataFinal: _frascosDataFinal,
            tipoRelatorio: _frascosTipoRelatorio,
          );
        }
        return FiltroEstoqueFrascosPage(
          terminalId: _terminalParaFiltroId,
          empresaId: _empresaParaFiltroId,
          nomeTerminal: _terminalParaFiltroNome ?? '',
          empresaNome: _empresaParaFiltroNome,
          onConsultarEstoque: ({
            required String? terminalId,
            required String? empresaId,
            required String nomeTerminal,
            String? empresaNome,
            required DateTime dataInicial,
            required DateTime dataFinal,
            required String tipoRelatorio,
          }) {
            setState(() {
              _terminalParaFiltroId = terminalId;
              _empresaParaFiltroId = empresaId;
              _terminalParaFiltroNome = nomeTerminal;
              _empresaParaFiltroNome = empresaNome;
              _frascosDataInicial = dataInicial;
              _frascosDataFinal = dataFinal;
              _frascosTipoRelatorio = tipoRelatorio;
              _mostrarResultadoFrascos = true;
            });
          },
          onVoltar: () {
            setState(() {
              _mostrarFrascosAmostra = false;
            });
          },
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Almoxerifado') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Estoques
    if (sessaoAtual == 'Estoques') {
      if (_mostrarCardsFilial && _filialParaFiltroId != null) {
        return _buildCardsFilialPage();
      }
      
      if (_mostrarFiltrosEstoque &&
          (_filialParaFiltroId != null || _terminalParaFiltroId != null)) {
        return _buildFiltrosEstoquePage();
      }
      
      if (_mostrarDownloads) {
        return DownloadsPage(
          key: const ValueKey('downloads-page'),
          onVoltar: () {
            setState(() {
              _mostrarDownloads = false;
            });
          },
        );
      }
      
      if (_mostrarFiliaisDaEmpresa) {
        return _buildFiliaisDaEmpresaPage();
      }
      
      if (_mostrarEstoquePorEmpresa) {
        return _buildEstoquePorEmpresaPage();
      }
      
      if (_mostrarEstoquePorTanque) {
        return Container(
          margin: const EdgeInsets.only(left: 12),
          child: EstoquePorTanquePage(
            key: const ValueKey('estoque-por-tanque'),
            terminalSelecionadoId: _terminalSelecionadoId ?? _filialSelecionadaId,
            onVoltar: () {
              setState(() {
                _mostrarEstoquePorTanque = false;
                _terminalSelecionadoId = null;
                _filialSelecionadaId = null;
                
                if (_estoquePorTanqueVemDaApuracao) {
                  _estoquePorTanqueVemDaApuracao = false;
                  _mostrarFilhosDaSessao('Operação');
                } else {
                  _mostrarFilhosDaSessao('Estoques');
                }
              });
            },
          ),
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Estoques') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Operação
    if (sessaoAtual == 'Operação') {
      if (_mostrarEstoquePorTanque) {
        return Container(
          margin: const EdgeInsets.only(left: 12),
          child: EstoquePorTanquePage(
            key: const ValueKey('estoque-por-tanque'),
            terminalSelecionadoId:
                _terminalSelecionadoId ?? _filialSelecionadaId,
            onVoltar: () {
              setState(() {
                _mostrarEstoquePorTanque = false;
                _terminalSelecionadoId = null;
                _filialSelecionadaId = null;

                if (_estoquePorTanqueVemDaApuracao) {
                  _estoquePorTanqueVemDaApuracao = false;
                  _mostrarFilhosDaSessao('Operação');
                } else {
                  _mostrarFilhosDaSessao('Operação');
                }
              });
            },
          ),
        );
      }
      if (_mostrarTanques &&
          (_filialSelecionadaId != null || _terminalSelecionadoId != null)) {        
        return GerenciamentoTanquesPage(
          key: const ValueKey('gerenciamento-tanques'),
          onVoltar: () {
            final usuario = UsuarioAtual.instance;
            setState(() {
              _mostrarTanques = false;
              _filialSelecionadaId = null;
              _terminalSelecionadoId = null;
              
              if (usuario!.nivel == 3) {
                _mostrarEscolherTerminal = true;
                _contextoEscolhaTerminal = 'tanques';
              } else {
                _mostrarFilhosDaSessao('Operação');
              }
            });
          },
          terminalSelecionadoId: _terminalSelecionadoId ?? _filialSelecionadaId,
          onAbrirCACL: (terminalId) {
            setState(() {
              _voltarParaTanquesApoCACL = true;
              _mostrarTanques = false;
              _terminalSelecionadoId = terminalId;
              _filialSelecionadaId = null;
              _mostrarListarCacls = true;
            });
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
              
              if (_voltarParaTanquesApoCACL) {
                _voltarParaTanquesApoCACL = false;
                _mostrarTanques = true;
              } else {
                if (usuario!.nivel == 3) {
                  _mostrarEscolherTerminal = true;
                  _contextoEscolhaTerminal = 'cacl';
                } else {
                  _mostrarFilhosDaSessao('Operação');
                }
              }
            });
          },
          filialId: _filialSelecionadaId!,
          filialNome: _filialSelecionadaNome ?? 'Terminal',
          onIrParaEmissao: () {
            setState(() {
              _mostrarListarCacls = false;
              _mostrarMedicaoTanques = true;
            });
          },
        );
      }
      
      if (showConversaoList) {
        return TabelasDeConversao(
          key: const ValueKey('tabelas'),
          onVoltar: () {
            _mostrarFilhosDaSessao('Operação');
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
              _mostrarFilhosDaSessao('Operação');
            },
          ),
        );
      }
      
      if (_mostrarHistorico) {
        return HistoricoCaclPage(
          key: const ValueKey('historico-cacl'),
          onVoltar: () {
            _mostrarFilhosDaSessao('Operação');
          },
        );
      }
      
      if (_mostrarEscolherTerminal) {
        return EscolherTerminalPage(
          key: ValueKey('escolher-terminal-$_contextoEscolhaTerminal'),
          onVoltar: () {
            setState(() {
              _mostrarEscolherTerminal = false;
              _contextoEscolhaTerminal = '';
              _mostrarFilhosDaSessao('Operação');
            });
          },
          onSelecionarTerminal: (idTerminal) async {
            final supabase = Supabase.instance.client;
            try {
              final filialData = await supabase
                  .from('filiais')
                  .select('nome')
                  .eq('id', idTerminal)
                  .maybeSingle();
                  
              if (filialData != null) {
                setState(() {
                  _filialSelecionadaId = idTerminal;
                  _filialSelecionadaNome = filialData['nome'];
                  _terminalSelecionadoId = null;
                  _mostrarEscolherTerminal = false;
                  
                  if (_contextoEscolhaTerminal == 'cacl') {
                    _mostrarListarCacls = true;
                  } else if (_contextoEscolhaTerminal == 'tanques') {
                    _mostrarTanques = true;
                  } else if (_contextoEscolhaTerminal == 'estoque_por_tanque') {
                    _mostrarEstoquePorTanque = true;
                  }
                  
                  _contextoEscolhaTerminal = '';
                });
                return;
              }
              
              final terminalData = await supabase
                  .from('terminais')
                  .select('nome')
                  .eq('id', idTerminal)
                  .maybeSingle();
                  
              if (terminalData != null) {
                setState(() {
                  _terminalSelecionadoId = idTerminal;
                  _filialSelecionadaId = null;
                  _filialSelecionadaNome = null;
                  _mostrarEscolherTerminal = false;
                  
                  if (_contextoEscolhaTerminal == 'tanques') {
                    _mostrarTanques = true;
                  } else if (_contextoEscolhaTerminal == 'estoque_por_tanque') {
                    _mostrarEstoquePorTanque = true;
                  }
                  
                  _contextoEscolhaTerminal = '';
                });
                return;
              }
              
              setState(() {
                _filialSelecionadaId = idTerminal;
                _filialSelecionadaNome = 'Terminal';
                _mostrarEscolherTerminal = false;
                if (_contextoEscolhaTerminal == 'cacl')
                  _mostrarListarCacls = true;
                if (_contextoEscolhaTerminal == 'tanques') _mostrarTanques = true;
                if (_contextoEscolhaTerminal == 'estoque_por_tanque')
                  _mostrarEstoquePorTanque = true;
                _contextoEscolhaTerminal = '';
              });
            } catch (e) {
              setState(() {
                _filialSelecionadaId = idTerminal;
                _filialSelecionadaNome = 'Terminal';
                _mostrarEscolherTerminal = false;
                
                if (_contextoEscolhaTerminal == 'cacl') {
                  _mostrarListarCacls = true;
                }
                
                _contextoEscolhaTerminal = '';
              });
            }
          },
          titulo: _contextoEscolhaTerminal == 'cacl'
              ? 'Selecionar terminal para CACL:'
              : 'Selecionar terminal para gerenciar tanques:',
        );
      }
      
      if (_mostrarMedicaoTanques) {
        return MedicaoTanquesPage(
          key: const ValueKey('medicao-tanques'),
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
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }
      
      if (_mostrarTempDensMedia) {
        return TemperaturaDensidadeMediaPage(
          onVoltar: () {
            setState(() {
              _mostrarTempDensMedia = false;
              _mostrarFilhosDaSessao(_sessaoAtual ?? 'Operação');
            });
          },
        );
      }
      
      if (_mostrarEstoqueProduto) {
        return FiltroEstoqueProdutoPage(
          filialId: _filialParaFiltroId,
          terminalId: _terminalParaFiltroId,
          nomeFilial: _filialParaFiltroNome ?? _terminalParaFiltroNome ?? '',
          empresaId: _empresaParaFiltroId,
          empresaNome: _empresaParaFiltroNome,
          onConsultarEstoqueProduto: ({
            required String? filialId,
            required String? terminalId,
            required String nomeFilial,
            String? empresaId,
            required DateTime dataInicial,
            required DateTime dataFinal,
            required String produtoId,
            required String produtoNome,
          }) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EstoqueProdutoPage(
                  filialId: filialId,
                  terminalId: terminalId,
                  nomeFilial: nomeFilial,
                  empresaId: empresaId,
                  dataInicial: dataInicial,
                  dataFinal: dataFinal,
                  produtoId: produtoId,
                  produtoNome: produtoNome,
                ),
              ),
            );
          },
          onVoltar: () {
            setState(() {
              _mostrarEstoqueProduto = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Operação') {
        return _buildFilhosSessaoPage();
      }

      if (_mostrarPerdasSobras && _sessaoAtual == 'Perdas e Sobras') {
        return _buildPaginaPadronizada(
          titulo: 'Gestão de perdas e sobras',
          conteudo: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Wrap(
                spacing: 15,
                runSpacing: 15,
                alignment: WrapAlignment.start,
                children: _filhosSessaoAtual.map((card) {
                  return SizedBox(
                    width: 140,
                    height: 170,
                    child: _buildCardFilho(card),
                  );
                }).toList(),
              ),
            ),
          ),
          onVoltar: () {
            setState(() {
              _mostrarPerdasSobras = false;
              _mostrarFilhosDaSessao('Operação');
            });
          },
        );
      }
    }

    // SEÇÃO: Circuito
    if (sessaoAtual == 'Circuito') {
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
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Circuito') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Gestão de Frota
    if (sessaoAtual == 'Gestão de Frota') {
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
      
      if (_mostrarTransportadoras) {
        return _buildPaginaPadronizada(
          titulo: 'Transportadoras',
          conteudo: const TransportadorasPage(),
          onVoltar: () {
            setState(() {
              _mostrarTransportadoras = false;
              _mostrarFilhosDaSessao('Gestão de Frota');
            });
          },
        );
      }
      
      if (_mostrarFilhosSessao && _sessaoAtual == 'Gestão de Frota') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Vendas
    if (sessaoAtual == 'Vendas') {
      if (_mostrarFiltroMovimentacoes) {
        return FiltroVendasPage(
          filialId: _filialParaFiltroId,
          terminalId: _terminalParaFiltroId,
          nomeFilial: _filialParaFiltroNome ?? _terminalParaFiltroNome ?? '',
          empresaId: _empresaParaFiltroId,
          empresaNome: _empresaParaFiltroNome,
          onVoltar: () {
            setState(() {
              _mostrarFiltroMovimentacoes = false;
              _mostrarFilhosDaSessao('Vendas');
            });
          },
        );
      }

      if (_mostrarFilhosSessao && _sessaoAtual == 'Vendas') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Bombeios e Cotas Contratuais
    if (sessaoAtual == 'Bombeios e Cotas Contratuais') {
      if (_mostrarFilhosSessao && _sessaoAtual == 'Bombeios e Cotas Contratuais') {
        return _buildFilhosSessaoPage();
      }
    }

    // SEÇÃO: Relatórios
    if (sessaoAtual == 'Relatórios') {
      if (_mostrarDownloads) {
        return DownloadsPage(
          key: const ValueKey('downloads-page'),
          onVoltar: () {
            setState(() {
              _mostrarDownloads = false;
            });
          },
        );
      }
      
      return _buildRelatoriosPage();
    }

    // SEÇÃO: Configurações
    if (sessaoAtual == 'Configurações') {
      return _buildConfiguracoesPage(usuario);
    }

    // SEÇÃO: Laboratório
    if (sessaoAtual == 'Laboratório') {
      if (_mostrarTempDensMedia) {
        return TemperaturaDensidadeMediaPage(
          onVoltar: () {
            setState(() {
              _mostrarTempDensMedia = false;
              _mostrarFilhosDaSessao('Laboratório');
            });
          },
        );
      }
      return _buildFilhosSessaoPage();
    }

    // Páginas indisponíveis
    if (sessaoAtual == 'Financeiro' ||
        sessaoAtual == 'Jurídico' ||
        sessaoAtual == 'Gestão de contratos' ||
        sessaoAtual == 'Gestão de Projetos' ||
        sessaoAtual == 'Recursos Humanos' ||
        sessaoAtual == 'Segurança & Compliance' ||
        sessaoAtual == 'Manutenção e ativos') {
      return _buildAreaIndisponivelPage();
    }

    // FALLBACK: Se nenhuma condição for atendida
    if (_mostrarFilhosSessao && _sessaoAtual != null) {
      return _buildFilhosSessaoPage();
    }
    
    if (_mostrarFilhosSessao && _sessaoAtual == null) {
      return _buildSemPermissaoPage();
    }

    if (_carregandoCards) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    if (_mostrarCalcGerado) {
      return CalcPage(
        key: const ValueKey('calc-page'),
        dadosFormulario: _dadosCalcGerado ?? {},
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
              if (mostrarVoltar &&
                  (_mostrarDownloads ||
                      showConversaoList ||
                      _mostrarListarCacls ||
                      _mostrarOrdensAnalise ||
                      _mostrarHistorico ||
                      _mostrarEscolherTerminal ||
                      _mostrarMedicaoTanques ||
                      _mostrarTanques ||
                      _mostrarFiliaisDaEmpresa ||
                      _mostrarEstoquePorEmpresa ||
                      _mostrarEstoquePorTanque ||
                      _mostrarTempDensMedia ||
                      _mostrarCalcGerado ||
                      _mostrarVeiculos ||
                      _mostrarDetalhesVeiculo ||
                      _mostrarMotoristas ||
                      _mostrarTransportadoras ||
                      _mostrarFiltrosEstoque ||
                      _mostrarFiltroMovimentacoes ||
                      _mostrarCardsFilial ||
                      _mostrarSuporte))
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: onVoltar ?? _voltarParaCardsPai,
                  tooltip: 'Voltar',
                ),
              if (mostrarVoltar &&
                  (_mostrarDownloads ||
                      showConversaoList ||
                      _mostrarListarCacls ||
                      _mostrarOrdensAnalise ||
                      _mostrarHistorico ||
                      _mostrarEscolherTerminal ||
                      _mostrarMedicaoTanques ||
                      _mostrarTanques ||
                      _mostrarFiliaisDaEmpresa ||
                      _mostrarEstoquePorEmpresa ||
                      _mostrarEstoquePorTanque ||
                      _mostrarTempDensMedia ||
                      _mostrarCalcGerado ||
                      _mostrarVeiculos ||
                      _mostrarDetalhesVeiculo ||
                      _mostrarMotoristas ||
                      _mostrarTransportadoras ||
                      _mostrarFiltrosEstoque ||
                      _mostrarFiltroMovimentacoes ||
                      _mostrarCardsFilial))
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
          Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
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
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
    final cardsPermitidos = <Map<String, dynamic>>[];

    for (var card in _filhosSessaoAtual) {
      final cardId = card['id']?.toString();
      final tipo = card['tipo']?.toString();

      // Cards de transportadoras são sempre permitidos
      if (tipo == 'transportadoras') {
        cardsPermitidos.add(card);
        continue;
      }

      // Se não tem usuário, não permite
      if (usuario == null) continue;

      // Se não tem cardId, não permite
      if (cardId == null || cardId.isEmpty) continue;

      // Cards de venda são permitidos automaticamente
      if (tipo == 'programacao_filial') {
        cardsPermitidos.add(card);
        continue;
      }

      // Para os demais cards, verificar permissão normal
      try {
        if (usuario.podeAcessarCard(cardId)) {
          cardsPermitidos.add(card);
        }
      } catch (_) {
        // Em caso de erro, não permitir o card
      }
    }

    // Se não houver nenhum card permitido
    if (cardsPermitidos.isEmpty) {
      return _buildSemPermissaoPage();
    }

    // Se houver um card filho selecionado, exibe seu conteúdo
    if (_filhoSelecionadoTipo != null) {
      switch (_filhoSelecionadoTipo) {
        case 'criar_ordem':
          return _buildPaginaPadronizada(
            titulo: 'Criar ordem',
            conteudo: CriarOrdemPage(
              onCreated: () {
                setState(() {
                  _filhoSelecionadoTipo = null;
                  _mostrarFilhosSessao = true;
                  _sessaoAtual = 'Circuito';
                  _filhosSessaoAtual = List.from(
                    _filhosPorSessao['Circuito'] ?? [],
                  );
                });
              },
              onVoltar: () {
                setState(() {
                  _filhoSelecionadoTipo = null;
                });
              },
            ),
            mostrarVoltar: true,
            onVoltar: () {
              setState(() {
                _filhoSelecionadoTipo = null;
              });
            },
          );
        default:
          break;
      }
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
      mostrarVoltar: false,
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
              children: empresas
                  .map((empresa) => _buildCardEmpresa(empresa))
                  .toList(),
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
              childAspectRatio:
                  1.0, // AUMENTADO DE 1.1 PARA 1.0 (MAIS QUADRADO)
              padding: const EdgeInsets.only(bottom: 20),
              children: filiaisDaEmpresa
                  .map((filial) => _buildCardFilial(filial))
                  .toList(),
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
    final tipo = card['tipo']?.toString();

    if (tipo != 'transportadoras' &&
        usuario != null &&
        cardId != null &&
        !usuario.podeAcessarCard(cardId)) {
      return const SizedBox.shrink();
    }

    final corSessao = _getCorSessaoAtual();
    final isFavorito = card['favorito'] == true;
    final podeFavoritar = card.containsKey('favorito') && cardId != null;

    return _HoverScale(
      child: Stack(
        children: [
          Material(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(card['icon'], color: corSessao, size: 55),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
                      child: Center(
                        child: Text(
                          card['label'] ?? '',
                          style: TextStyle(
                            fontSize: (card['label']?.toString() ?? '').length > 25 ? 11 : 13,
                            color: const Color(0xFF0D47A1),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (podeFavoritar)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _toggleFavorito(cardId, !isFavorito),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    isFavorito ? Icons.star : Icons.star_border,
                    size: 15,
                    color: isFavorito ? Colors.amber : Colors.grey[400],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardFavoritoInicio(Map<String, dynamic> card) {
    final sessaoPai = card['sessao_pai']?.toString() ?? '';
    final corSessao = _getCorPorSessao(sessaoPai);
    final cardId = card['id']?.toString();

    return Stack(
      children: [
        _HoverScale(
          child: Material(
            elevation: 2,
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: () => _navegarParaFavorito(card),
              hoverColor: corSessao.withOpacity(0.1),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(card['icon'], color: corSessao, size: 50),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 45, maxHeight: 45),
                      child: Center(
                        child: Text(
                          card['label'] ?? '',
                          style: TextStyle(
                            fontSize: (card['label']?.toString() ?? '').length > 25 ? 10 : 12,
                            color: const Color(0xFF0D47A1),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sessaoPai,
                      style: TextStyle(
                        fontSize: 9,
                        color: corSessao.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              if (cardId != null) _toggleFavorito(cardId, false);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.star, size: 15, color: Colors.amber),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardEmpresa(Map<String, dynamic> empresa) {
    return _HoverScale(
      child: Material(
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
                  child: Center(
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
                ),
                // REMOVER A DESCRIÇÃO (CNPJ) AQUI TAMBÉM
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFilial(Map<String, dynamic> filial) {
    return _HoverScale(
      child: Material(
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
              _mostrarCardsFilial = false;

              // Direciona para o filtro correto baseado no contexto
              if (_contextoEscolhaTerminal == 'movimentacoes' ||
                  _contextoEscolhaTerminal == 'movimentaces') {
                _mostrarFiltroMovimentacoes = true;
              } else {
                _mostrarFiltrosEstoque = true;
              }
            });
          },
          hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ), // AUMENTADO DE 1 PARA 1.5
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
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 50,
                    maxHeight: 50,
                  ), // AUMENTADO DE 40 PARA 50
                  child: Center(
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
                ),
              ],
            ),
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

    if (tipo != 'transportadoras' &&
        usuario != null &&
        cardId != null &&
        !usuario.podeAcessarCard(cardId)) {
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
      case 'Operação':
        _navegarParaCardApuracao(tipo, usuario);
        break;
      case 'Perdas e Sobras':
        _navegarParaCardPerdasSobras(tipo);
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
      case 'Bombeios e Cotas Contratuais':
        _navegarParaCardBombeios(tipo);
        break;
      case 'Laboratório':
        _navegarParaCardLaboratorio(tipo);
        break;
      case 'Almoxerifado':
        _navegarParaCardAlmoxerifado(tipo);
        break;
      default:
        debugPrint('Sessão pai não reconhecida: $sessaoPai');
    }
  }

  void _navegarParaCardPerdasSobras(String tipo) {
    switch (tipo) {
      case 'dutoviario':
        // TODO: Implementar navegação para Dutoviário
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Módulo Dutoviário em desenvolvimento')),
        );
        break;
      case 'rodoviario':
        // TODO: Implementar navegação para Rodoviário
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Módulo Rodoviário em desenvolvimento')),
        );
        break;
    }
  }

  void _navegarParaCardApuracao(String tipo, UsuarioAtual? usuario) {
    switch (tipo) {
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
      case 'estoque_produto':
        setState(() {
          _mostrarEstoqueProduto = true;
        });
        break;
      case 'perdas_sobras':
        setState(() {
          _mostrarPerdasSobras = true;
          _sessaoAtual = 'Perdas e Sobras';
          _filhosSessaoAtual = List.from(_filhosPorSessao['Perdas e Sobras']!);
        });
        break;
      case 'tanques': // ADICIONADO: Caso para tanques agora em Operação
        final usuario = UsuarioAtual.instance;
        if (usuario!.nivel == 3) {
          setState(() {
            _mostrarEscolherTerminal = true;
            _contextoEscolhaTerminal = 'tanques';
          });
        } else {
          // Nível 1 e 2: vai direto para tanques usando o terminalId vinculado
          _terminalSelecionadoId = usuario.terminalId;
          setState(() {
            _mostrarTanques = true;
          });
        }
        break;
      case 'estoque_por_tanque':
        final usuario = UsuarioAtual.instance;
        if (usuario != null && usuario.nivel == 3) {
          setState(() {
            _mostrarEscolherTerminal = true;
            _contextoEscolhaTerminal = 'estoque_por_tanque';
            _estoquePorTanqueVemDaApuracao = true;
          });
        } else {
          // usuários normais vão direto para a página com sua filial
          _terminalSelecionadoId = usuario?.terminalId;
          setState(() {
            _estoquePorTanqueVemDaApuracao = true;
            _mostrarEstoquePorTanque = true;
          });
        }
        break;
    }
  }

  void _navegarParaCardEstoques(String tipo) {
    final usuario = UsuarioAtual.instance;

    switch (tipo) {
      case 'estoque_geral':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EstoqueGeralPage()),
        );
        break;

      case 'compacto_final':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompactoFinalPage()),
        );
        break;

      case 'estoque_por_empresa':
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _carregarEmpresas();
        });
        break;

      case 'movimentacao_por_empresa':
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _carregarEmpresas();
        });
        break;

      case 'estoque_por_tanque':
        final usuario = UsuarioAtual.instance;
        if (usuario != null && usuario.nivel == 3) {
          setState(() {
            _mostrarEscolherTerminal = true;
            _contextoEscolhaTerminal = 'estoque_por_tanque';
            _estoquePorTanqueVemDaApuracao = false;
          });
        } else {
          _filialSelecionadaId = usuario?.filialId;
          setState(() {
            _estoquePorTanqueVemDaApuracao = false;
            _mostrarEstoquePorTanque = true;
          });
        }
        break;

      case 'estoque_fiscal':
        // Validar se usuário tem filial OU terminal vinculado
        if (usuario == null) return;

        // Para nível 1 e 2, usar terminal_id
        if (usuario.nivel == 1 || usuario.nivel == 2) {
          if (usuario.terminalId == null || usuario.terminalId!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário sem terminal vinculado'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          setState(() {
            _terminalParaFiltroId = usuario.terminalId;
            _terminalParaFiltroNome = _usuarioTerminalNome ?? 'Seu Terminal';
            _filialParaFiltroId = null;
            _filialParaFiltroNome = null;
            _empresaParaFiltroId = null;
            _empresaParaFiltroNome = null;
            _mostrarFiltrosEstoque = true;
            _mostrarCardsFilial = false;
            _mostrarFiliaisDaEmpresa = false;
          });
          return;
        }

        // Para nível 3, usar filial_id
        if (usuario.nivel == 3) {
          if (usuario.filialId == null || usuario.filialId!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário sem filial vinculada'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          setState(() {
            _filialParaFiltroId = usuario.filialId;
            _filialParaFiltroNome = _usuarioFilialNome ?? 'Sua Filial';
            _terminalParaFiltroId = null;
            _terminalParaFiltroNome = null;
            _empresaParaFiltroId = null;
            _empresaParaFiltroNome = null;
            _mostrarFiltrosEstoque = true;
            _mostrarCardsFilial = false;
            _mostrarFiliaisDaEmpresa = false;
          });
          return;
        }

        // Para nível 4 (Master), mostrar seleção de empresa primeiro
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _contextoEscolhaTerminal = tipo;
          _carregarEmpresas();
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

      case 'controle_descargas':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Controle de descargas em desenvolvimento')),
        );
        break;

      default:
        debugPrint('Tipo de card de estoques não reconhecido: $tipo');
        break;
    }
  }

  void _navegarParaCardCircuito(String tipo) {
    switch (tipo) {
      case 'acompanhar_ordem':
        // Acompanhamento de ordens agora usa terminal_id; não exigir filial vinculada
        setState(() {
          _mostrarAcompanhamentoOrdens = true;
        });
        break;
      case 'visao_geral_circuito':
        // Adicione aqui quando criar a tela
        break;
      case 'criar_ordem':
        setState(() {
          _filhoSelecionadoTipo = 'criar_ordem';
          _mostrarFilhosSessao = true;
          _sessaoAtual = 'Circuito';
          _filhosSessaoAtual = List.from(_filhosPorSessao['Circuito'] ?? []);
        });
        break;
    }
  }
  // ...existing code...

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
      case 'transportadoras':
        setState(() {
          _mostrarTransportadoras = true;
          _mostrarVeiculos = false;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
          _mostrarMotoristas = false;
        });
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
          MaterialPageRoute(builder: (_) => const ControleDocumentosPage()),
        );
        break;
    }
  }

  void _navegarParaCardVendas(String tipo, Map<String, dynamic> card) {
    switch (tipo) {
      case 'movimentacoes':
      case 'movimentaces':
        _navegarParaMovimentacoesVendas();
        break;

      case 'programacao_filial':
        final filialId = card['filial_id'];
        final filialNome = card['filial_nome'];
        final filialNomeDois = card['filial_nome_dois'];
        final terminalId = card['terminal_id']; // NOVO: pega o terminal_id

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
              terminalId: terminalId, // NOVO: passa o terminal_id
            ),
          ),
        );
        break;
    }
  }

  void _navegarParaMovimentacoesVendas() {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    // Nível 1 e 2 (Operacional/Terminal)
    if (usuario.nivel == 1 || usuario.nivel == 2) {
      setState(() {
        _terminalParaFiltroId = usuario.terminalId;
        _terminalParaFiltroNome = _usuarioTerminalNome ?? 'Seu Terminal';
        _filialParaFiltroId = null;
        _filialParaFiltroNome = null;
        _empresaParaFiltroId = null;
        _empresaParaFiltroNome = null;
        _mostrarFiltroMovimentacoes = true;
        _mostrarCardsFilial = false;
        _mostrarFiliaisDaEmpresa = false;
      });
      return;
    }

    // Nível 3 (Gerencial/Filial)
    if (usuario.nivel == 3) {
      setState(() {
        _filialParaFiltroId = null;
        _filialParaFiltroNome = null;
        _terminalParaFiltroId = null;
        _terminalParaFiltroNome = null;
        _empresaParaFiltroId = null;
        _empresaParaFiltroNome = null;
        _mostrarFiltroMovimentacoes = true;
        _mostrarCardsFilial = false;
        _mostrarFiliaisDaEmpresa = false;
      });
      return;
    }

    // Nível 4 (Master): campos livres, vai direto para filtro
    setState(() {
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _terminalParaFiltroId = null;
      _terminalParaFiltroNome = null;
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _mostrarFiltroMovimentacoes = true;
      _mostrarCardsFilial = false;
      _mostrarFiliaisDaEmpresa = false;
    });
  }

  void _navegarParaCardBombeios(String tipo) {
    switch (tipo) {
      case 'bombeios':
        break;
    }
  }

  void _navegarParaCardAlmoxerifado(String tipo) {
    switch (tipo) {
      case 'frascos_amostra':
        setState(() {
          _mostrarFrascosAmostra = true;
        });
        break;
    }
  }

  void _navegarParaCardLaboratorio(String tipo) {
    switch (tipo) {
      case 'temp_dens_media':
        setState(() {
          _mostrarTempDensMedia = true;
        });
        break;
      case 'analise_conformidade':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Análise de conformidade em desenvolvimento...'),
          ),
        );
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
      configCards.add({
        'icon': Icons.admin_panel_settings,
        'label': 'Controle de acesso',
        'tipo': 'controle_acesso',
      });
    }

    // Cartão Usuários apenas para nível 3
    if (usuario != null && usuario.nivel >= 3) {
      configCards.add({
        'icon': Icons.people_alt,
        'label': 'Usuários',
        'tipo': 'usuarios',
      });
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
          return _HoverScale(
            child: Material(
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
      case 'Operação':
        return Icons.analytics;
      case 'Circuito':
        return Icons.route;
      case 'Vendas':
        return Icons.local_gas_station;
      case 'Gestão de Frota':
        return Icons.local_shipping;
      case 'Bombeios e Cotas Contratuais':
        return Icons.invert_colors;
      case 'Laboratório':
        return Icons.science;
      case 'Financeiro':
        return Icons.account_balance_wallet;
      case 'Jurídico':
        return Icons.gavel;
      case 'Gestão de contratos':
        return Icons.handshake;
      case 'Gestão de Projetos':
        return Icons.assignment;
      case 'Recursos Humanos':
        return Icons.people;
      case 'Almoxerifado':
        return Icons.inventory_2;
      case 'Manutenção e ativos':
        return Icons.build;
      case 'Segurança & Compliance':
        return Icons.security;
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
    final favoritos = <Map<String, dynamic>>[];
    for (final entry in _filhosPorSessao.entries) {
      for (final card in entry.value) {
        if (card['favorito'] == true) {
          favoritos.add(card);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            usuario != null
                ? 'Olá, ${usuario.nome}! Bem-vindo ao PowerTank!'
                : 'Bem-vindo ao PowerTank!',
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),
          if (favoritos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border, size: 70, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    Text(
                      'Nenhum card favorito ainda.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clique na pequena estrela no canto superior direito de qualquer card para adicioná-lo aqui.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Favoritos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: favoritos.map((card) {
                return SizedBox(
                  width: 140,
                  height: 170,
                  child: _buildCardFavoritoInicio(card),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardsFilialPage() {
    final cardsFilial = [
      {
        'id': 'movimentacoes-filial',
        'icon': Icons.swap_horiz,
        'label': 'Relatório Entradas e Saídas',
        'descricao': 'Consultar movimentações da filial',
        'tipo': 'movimentacoes',
      },
    ];

    return _buildPaginaPadronizada(
      titulo: _filialParaFiltroNome ?? 'Filial',
      conteudo: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Wrap(
            spacing: 15,
            runSpacing: 15,
            alignment: WrapAlignment.start,
            children: cardsFilial.map((card) {
              return SizedBox(
                width: 180,
                height: 180,
                child: _HoverScale(
                  child: Material(
                    elevation: 2,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        if (card['tipo'] == 'movimentacoes') {
                          if (_filialParaFiltroId == null ||
                              _filialParaFiltroId!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Filial nao informada para movimentacoes.',
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _mostrarFiltrosEstoque = true;
                            _mostrarCardsFilial = false;
                          });
                        }
                      },
                      hoverColor: _getCorPorSessao('Estoques').withOpacity(0.1),
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
                              card['icon'] as IconData,
                              color: _getCorPorSessao('Estoques'),
                              size: 55,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              card['label'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      onVoltar: () {
        setState(() {
          _mostrarCardsFilial = false;
          _mostrarFiliaisDaEmpresa = true;
        });
      },
    );
  }

  Widget _buildFiltrosEstoquePage() {
    return FiltroEstoquePage(
      key: ValueKey('filtros-${_terminalParaFiltroId ?? _filialParaFiltroId}'),
      filialId: _filialParaFiltroId,
      terminalId: _terminalParaFiltroId,
      nomeFilial: _terminalParaFiltroNome ?? _filialParaFiltroNome ?? 'Local',
      empresaId: _empresaParaFiltroId,
      empresaNome: _empresaParaFiltroNome,
      onVoltar: () {
        if (_empresaParaFiltroId != null) {
          setState(() {
            _mostrarFiltrosEstoque = false;
            _mostrarFiliaisDaEmpresa = true;
            _mostrarCardsFilial = false;
          });
        } else {
          setState(() {
            _mostrarFiltrosEstoque = false;
            _mostrarCardsFilial = false;
          });
          _mostrarFilhosDaSessao('Estoques');
        }
      },
      onConsultarEstoque:
          ({
            required String? filialId,
            required String? terminalId,
            required String nomeFilial,
            String? empresaId,
            required DateTime dataInicial,
            required DateTime dataFinal,
            String? produtoFiltro,
            required String tipoRelatorio,
          }) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EstoqueMesPage(
                  filialId: filialId,
                  terminalId: terminalId,
                  nomeFilial: nomeFilial,
                  empresaId: empresaId,
                  dataInicial: dataInicial,
                  dataFinal: dataFinal,
                  produtoFiltro: produtoFiltro,
                  tipoRelatorio: tipoRelatorio,
                ),
              ),
            );
          },
    );
  }

  // Método para adicionar quebras de linha nos nomes longos
  String _formatarNomeMenu(String nomeOriginal) {
    // Mapeia os nomes que precisam de quebra de linha
    final Map<String, String> quebras = {
      'Recursos Humanos': 'Recursos\nHumanos',
      'Gestão de Projetos': 'Gestão de\nProjetos',
      'Bombeios e Cotas Contratuais': 'Bombeios\ne Cotas Contratuais',
      'Manutenção e ativos': 'Manutenção\ne ativos',
      'Segurança & Compliance': 'Segurança &\nCompliance',
      'Configurações': 'Configurações', // Mantém igual (opcional)
    };

    return quebras[nomeOriginal] ?? nomeOriginal;
  }
}

/// Widget para exibir cards de uma sessão específica
class HomeCards extends StatelessWidget {
  final String menuSelecionado;
  final void Function(BuildContext context, String tipo) onCardSelecionado;
  final Function() onVoltar;

  const HomeCards({
    super.key,
    required this.menuSelecionado,
    required this.onCardSelecionado,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: onVoltar,
                tooltip: 'Voltar ao menu principal',
              ),
              const SizedBox(width: 10),
              Text(
                menuSelecionado,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.grey),
          const SizedBox(height: 20),

          Expanded(child: _buildCardsConteudo(context)),
        ],
      ),
    );
  }

  Widget _buildCardsConteudo(BuildContext context) {
    switch (menuSelecionado) {
      case 'Ajuda':
        return _buildCardsAjuda(context);
      default:
        return const Center(
          child: Text(
            'Conteúdo em construção...',
            style: TextStyle(color: Colors.grey),
          ),
        );
    }
  }

  Widget _buildCardsAjuda(BuildContext context) {
    final List<Map<String, dynamic>> cards = [
      {
        'titulo': 'Suporte',
        'descricao': 'Central de ajuda, FAQs e contato com suporte técnico',
        'icone': Icons.support_agent,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'suporte',
      },
      {
        'titulo': 'O Desenvolvedor',
        'descricao': 'Dê sua contribuição para o projeto',
        'icone': Icons.architecture,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'desenvolvedor',
      },
    ];

    return GridView.count(
      crossAxisCount: 7,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1,
      children: cards.map((card) => _buildCardItem(card, context)).toList(),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card, BuildContext context) {
    return _HoverScale(
      child: Material(
        elevation: 2,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => _handleCardTap(context, card['tipo']),
          hoverColor: const Color(0xFFE8F5E9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  card['icone'] as IconData,
                  color: card['cor'] as Color,
                  size: 50,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 35, maxHeight: 35),
                  child: Center(
                    child: Text(
                      card['titulo'],
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, String tipo) {
    onCardSelecionado(context, tipo);
  }
}

/// Widget privado para efeito de crescimento ao passar o mouse
class _HoverScale extends StatefulWidget {
  final Widget child;

  const _HoverScale({required this.child});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
