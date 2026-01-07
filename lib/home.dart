import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/tabelas_de_conversao/tabelasdeconversao.dart';
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
import 'sessoes/apuracao/certificado_analise.dart';
import 'sessoes/estoques/estoque_geral.dart';
import 'sessoes/apuracao/historico_cacl.dart';
import 'sessoes/apuracao/listar_cacls.dart';
import 'sessoes/estoques/estoque_downloads.dart';
import 'sessoes/estoques/filtro_estoque.dart';
import 'sessoes/estoques/estoque_mes.dart';
import 'sessoes/circuito/gerenciar_circuito.dart';
import 'sessoes/gestao_de_frota/motoristas_page.dart';
import 'sessoes/gestao_de_frota/veiculos.dart';

// NOVO: Importar páginas para as novas sessões
// import 'sessoes/bombeios/bombeios_page.dart'; // Descomente quando criar

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  TextEditingController searchController = TextEditingController();

  final List<String> menuItems = [
    'Sessões',
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
  bool _mostrarIniciarCircuito = false;
  
  // NOVAS VARIÁVEIS PARA GESTÃO DE FROTA
  bool _mostrarVeiculos = false;
  bool _mostrarDetalhesVeiculo = false;
  Map<String, dynamic>? _veiculoSelecionado;
  bool _mostrarMotoristas = false;
  //bool _mostrarControleDocumentos = false;
  
  // FLAG UNIFICADA PARA MOSTRAR FILHOS DE QUALQUER SESSÃO
  bool _mostrarFilhosSessao = false;
  String? _sessaoAtual; // Nome da sessão pai atual
  List<Map<String, dynamic>> _filhosSessaoAtual = []; // Filhos da sessão atual
  
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
  String? _empresaSelecionadaNome;
  String? _empresaSelecionadaId;

  // NOVO: MAPA UNIFICADO DE FILHOS POR SESSÃO
  final Map<String, List<Map<String, dynamic>>> _filhosPorSessao = {};

  @override
  void initState() {
    super.initState();
    _inicializarFilhosPorSessao(); // NOVO: Inicializar todos os filhos de uma vez
    selectedIndex = -1;
  }

  // NOVO: Método unificado para inicializar todos os filhos
  void _inicializarFilhosPorSessao() {
    // Filhos para "Apuração"
    _filhosPorSessao['Apuração'] = [
      {
        'icon': Icons.analytics,
        'label': 'CACL',
        'descricao': 'Emitir CACL',
        'tipo': 'cacl',
      },      
      {
        'icon': Icons.oil_barrel,
        'label': 'Tanques',
        'descricao': 'Gerenciamento de tanques',
        'tipo': 'tanques',
      },
      {
        'icon': Icons.assignment,
        'label': 'Ordens / Análise',
        'descricao': 'Geração e gestão de ordens',
        'tipo': 'ordens_analise',
      },
      {
        'icon': Icons.history,
        'label': 'Histórico de CACLs',
        'descricao': 'Consultar histórico de CACLs emitidos',
        'tipo': 'historico_cacl',
      },
      {
        'icon': Icons.table_chart,
        'label': 'Tabelas de Conversão',
        'descricao': 'Tabelas de conversão de densidade e temperatura',
        'tipo': 'tabelas_conversao',
      },
    ];

    // Filhos para "Estoques"
    _filhosPorSessao['Estoques'] = [
      {
        'icon': Icons.hub,
        'label': 'Estoque Geral',
        'descricao': 'Visão consolidada dos estoques da base',
        'tipo': 'estoque_geral',
      },
      {
        'icon': Icons.business,
        'label': 'Estoque por empresa',
        'descricao': 'Estoques separados por empresa',
        'tipo': 'estoque_por_empresa',
      },
      {
        'icon': Icons.swap_horiz,
        'label': 'Movimentações',
        'descricao': 'Acompanhar entradas e saídas em geral',
        'tipo': 'movimentacoes',
      },
      {
        'icon': Icons.download,
        'label': 'Downloads',
        'descricao': 'Baixar relatórios e dados',
        'tipo': 'downloads',
      },
    ];

    // Filhos para "Circuito"
    _filhosPorSessao['Circuito'] = [
      {
        'icon': Icons.play_arrow,
        'label': 'Iniciar Circuito',
        'descricao': 'Iniciar novo fluxo de carga/descarga',
        'tipo': 'iniciar_circuito',
      },
      {
        'icon': Icons.directions_car,
        'label': 'Acompanhar veículo',
        'descricao': 'Monitorar veículo em trânsito',
        'tipo': 'acompanhar_veiculo',
      },
      {
        'icon': Icons.dashboard,
        'label': 'Visão geral',
        'descricao': 'Panorama completo dos circuitos',
        'tipo': 'visao_geral_circuito',
      },
    ];

    // Filhos para "Gestão de Frota"
    _filhosPorSessao['Gestão de Frota'] = [
      {
        'icon': Icons.directions_car,
        'label': 'Veículos',
        'descricao': 'Gerenciar frota de veículos',
        'tipo': 'veiculos',
      },
      {
        'icon': Icons.people,
        'label': 'Motoristas',
        'descricao': 'Gerenciar cadastro de motoristas',
        'tipo': 'motoristas',
      },
      {
        'icon': Icons.description,
        'label': 'Documentação',
        'descricao': 'Controle de documentos da frota',
        'tipo': 'documentacao',
      },
    ];

    // Filhos para "Vendas" (se necessário)
    _filhosPorSessao['Vendas'] = [
      {
        'icon': Icons.local_gas_station,
        'label': 'Programação',
        'descricao': 'Programação de vendas',
        'tipo': 'programacao_vendas',
      },
    ];

    // Filhos para "Bombeios" (se necessário)
    _filhosPorSessao['Bombeios'] = [
      {
        'icon': Icons.invert_colors,
        'label': 'Bombeios',
        'descricao': 'Controle de bombeios',
        'tipo': 'bombeios',
      },
    ];
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
      
      debugPrint('Usuário: ${usuario?.nome}, Nível: ${usuario?.nivel}');
      debugPrint('Filial do usuário: ${usuario?.filialId}');
      debugPrint('Filiais carregadas: ${dados.length}');
      
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
      debugPrint("Tipo do erro: ${e.runtimeType}");
      
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

  Future<void> _carregarSessoesDoBanco() async {
    setState(() => carregandoSessoes = true);
    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;

    try {
      final dados = await supabase.from('sessoes').select('id, nome');

      List<Map<String, dynamic>> filtradas = [];
      for (var s in dados) {
        final idSessao = s['id'].toString();
        final nome = s['nome'] ?? 'Sem nome';
        
        // "Tabelas de conversão" não aparece como card pai, apenas como filho
        if (nome == 'Tabelas de conversão') {
          continue;
        }
        
        if (usuario != null) {
          if (usuario.nivel >= 2 || usuario.temPermissao(idSessao)) {
            filtradas.add({
              'id': idSessao,
              'label': nome,
              'icon': _definirIcone(nome),
            });
          }
        }
      }

      setState(() {
        sessoes = filtradas;
      });
    } catch (e) {
      debugPrint("Erro ao carregar sessões: $e");
    } finally {
      setState(() => carregandoSessoes = false);
    }
  }

  Future<void> _verificarPermissoesUsuario() async {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    try {
      final supabase = Supabase.instance.client;

      if (usuario.nivel >= 2) {
        UsuarioAtual.instance = UsuarioAtual(
          id: usuario.id,
          nome: usuario.nome,
          empresaId: usuario.empresaId,
          nivel: usuario.nivel,
          filialId: usuario.filialId,
          sessoesPermitidas: [],
          senhaTemporaria: usuario.senhaTemporaria,
        );
        await _carregarSessoesDoBanco();
        return;
      }

      final permissoes = await supabase
          .from('permissoes')
          .select('id_sessao, permitido')
          .eq('id_usuario', usuario.id);

      final sessoesPermitidas = List<String>.from(
        permissoes
            .where((p) => p['permitido'] == true)
            .map((p) => p['id_sessao'].toString()),
      );

      UsuarioAtual.instance = UsuarioAtual(
        id: usuario.id,
        nome: usuario.nome,
        nivel: usuario.nivel,
        filialId: usuario.filialId,
        empresaId: usuario.empresaId,
        sessoesPermitidas: sessoesPermitidas,
        senhaTemporaria: usuario.senhaTemporaria,
      );

      await _carregarSessoesDoBanco();
    } catch (e) {
      debugPrint("❌ Erro ao carregar permissões: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro ao carregar permissões."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // MÉTODOS PARA GERENCIAR FLAGS DE VEÍCULOS
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
    //_resetarFlagsDocumentacao();
  }

  // NOVO: Método unificado para resetar todas as flags
  void _resetarTodasFlags() {
    setState(() {
      // Flags gerais
      selectedIndex = -1;
      showConversaoList = false;
      showControleAcesso = false;
      showConfigList = false;
      showUsuarios = false;
      _mostrarCalcGerado = false;
      _mostrarDownloads = false;
      
      // Flags para sessões específicas
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarListarCacls = false;
      _mostrarFiltrosEstoque = false;
      _mostrarEscolherFilial = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarIniciarCircuito = false;
      
      // Flags de Gestão de Frota
      _resetarTodasFlagsGestaoFrota();
      
      // Flag unificada
      _mostrarFilhosSessao = false;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
      
      // Dados de navegação
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

  // NOVO: Método unificado para mostrar filhos de uma sessão
  void _mostrarFilhosDaSessao(String nomeSessao) {
    final filhos = _filhosPorSessao[nomeSessao] ?? [];
    
    setState(() {
      _mostrarFilhosSessao = true;
      _sessaoAtual = nomeSessao;
      _filhosSessaoAtual = filhos;
      
      // Resetar TODAS as outras flags
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
      _mostrarIniciarCircuito = false;
      _mostrarCalcGerado = false;
      
      // Resetar flags de Gestão de Frota
      _mostrarVeiculos = false;
      _mostrarDetalhesVeiculo = false;
      _veiculoSelecionado = null;
      _mostrarMotoristas = false;
      //_mostrarControleDocumentos = false;
    });
  }

  // NOVO: Método unificado para voltar aos cards pai
  void _voltarParaCardsPai() {
    setState(() {
      _mostrarFilhosSessao = false;
      _sessaoAtual = null;
      _filhosSessaoAtual = [];
      
      // Resetar TODAS as flags de páginas específicas
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
      _mostrarIniciarCircuito = false;
      _mostrarCalcGerado = false;
      
      // Resetar TODAS as flags de Gestão de Frota
      _resetarTodasFlagsGestaoFrota();
      
      // Resetar outras flags importantes
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
                              onTap: () async {
                                _resetarTodasFlags();
                                setState(() {
                                  selectedIndex = index;
                                });

                                if (menuItems[index] == 'Sessões') {
                                  await _verificarPermissoesUsuario();
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
                                          ? const Color(0xFF2E7D32)
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
                                            ? const Color(0xFF2E7D32)
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
        ],
      ),
    );
  }

  Widget _buildPageContent(UsuarioAtual? usuario) {
    if (selectedIndex == -1) {
      return _buildInicioPage(usuario);
    }

    switch (menuItems[selectedIndex]) {
      case 'Sessões':
        return _buildSessoesPage(usuario);
      case 'Configurações':
        return _buildConfiguracoesPage(usuario);
      default:
        return Center(
          child: Text(
            '${menuItems[selectedIndex]} em construção...',
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  Widget _buildSessoesPage(UsuarioAtual? usuario) {
    if (carregandoSessoes) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
      );
    }

    if (sessoes.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma sessão disponível.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _buildConteudoSessoes(),
      ),
    );
  }

  // NOVO: Método unificado para construir o conteúdo das sessões
  Widget _buildConteudoSessoes() {
    // Páginas específicas (fluxos complexos)
    if (_mostrarFiltrosEstoque && _filialParaFiltroId != null) {
      return _buildFiltrosEstoquePage();
    }
    
    if (_mostrarDownloads) {
      return DownloadsPage(
        key: const ValueKey('downloads-page'),
        onVoltar: () {
          _mostrarFilhosDaSessao('Estoques');
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
      return CertificadoAnalisePage(
        key: const ValueKey('ordens-analise'),
        onVoltar: () {
          _mostrarFilhosDaSessao('Apuração');
        },
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
              _mostrarFilhosDaSessao('Apuração');
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
    
    if (_mostrarIniciarCircuito) {
      return IniciarCircuitoPage(
        key: const ValueKey('iniciar-circuito'),
        onVoltar: () {
          _mostrarFilhosDaSessao('Circuito');
        },
      );
    }
    
    // Se estiver mostrando calculadora gerada
    if (_mostrarCalcGerado) {
      return CalcPage(
        key: const ValueKey('calc-page'),
        dadosFormulario: _dadosCalcGerado ?? {},
      );
    }

    // ========== GESTÃO DE FROTA ==========
    // ESTAS VERIFICAÇÕES DEVEM VIR ANTES DE _mostrarFilhosSessao!
    
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
        placa: _veiculoSelecionado!['placa'],
        bocas: List<int>.from(_veiculoSelecionado!['bocas'] ?? []),
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

    // NÃO MAIS USANDO _mostrarControleDocumentos - AGORA VIA Navigator.push
    // REMOVA ESTA VERIFICAÇÃO:
    // if (_mostrarControleDocumentos) {
    //   return ControleDocumentosPage(
    //     key: const ValueKey('controle-documentos-page'),
    //   );
    // }
    
    // =====================================
    
    // SÓ DEPOIS DE TODAS AS PÁGINAS ESPECÍFICAS, verifica se está mostrando filhos
    if (_mostrarFilhosSessao && _sessaoAtual != null) {
      return _buildFilhosSessaoPage();
    }
    
    // Página padrão com cards pai
    return _buildGridWithSearch(sessoes);
  }

  // NOVO: Método unificado para construir página de filhos
  Widget _buildFilhosSessaoPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: _voltarParaCardsPai,
              tooltip: 'Voltar para sessões',
            ),
            const SizedBox(width: 10),
            Text(
              _sessaoAtual ?? '',
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

        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1,
            children: _filhosSessaoAtual.map((card) => _buildCardFilho(card)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEstoquePorEmpresaPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: () {
                _mostrarFilhosDaSessao('Estoques');
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'Estoque por empresa',
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
        const SizedBox(height: 20),

        if (carregandoEmpresas)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
          )
        else if (empresas.isEmpty)
          const Center(
            child: Text(
              'Nenhuma empresa encontrada.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Expanded(
            child: GridView.count(
              crossAxisCount: 7,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1,
              children: empresas.map((empresa) => _buildCardEmpresa(empresa)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFiliaisDaEmpresaPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: () {
                setState(() {
                  _mostrarFiliaisDaEmpresa = false;
                  _mostrarEstoquePorEmpresa = true;
                  _empresaSelecionadaId = null;
                  _empresaSelecionadaNome = null;
                });
              },
            ),
            const SizedBox(width: 10),
            Text(
              'Filiais - $_empresaSelecionadaNome',
              style: const TextStyle(
                fontSize: 24,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 20),

        if (carregandoFiliaisEmpresa)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
          )
        else if (filiaisDaEmpresa.isEmpty)
          const Center(
            child: Text(
              'Nenhuma filial encontrada para esta empresa.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Expanded(
            child: GridView.count(
              crossAxisCount: 7,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1,
              children: filiaisDaEmpresa.map((filial) => _buildCardFilial(filial)).toList(),
            ),
          ),
      ],
    );
  }

  // NOVO: Método unificado para construir card filho
  Widget _buildCardFilho(Map<String, dynamic> card) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _navegarParaCardFilho(card),
        hoverColor: const Color(0xFFE8F5E9),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                card['icon'],
                color: const Color.fromARGB(255, 48, 153, 35),
                size: 50,
              ),
              const SizedBox(height: 8),
              Text(
                card['label'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  card['descricao'] ?? '',
                  style: const TextStyle(
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
        hoverColor: const Color(0xFFE8F5E9),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                empresa['icon'],
                color: const Color.fromARGB(255, 48, 153, 35),
                size: 50,
              ),
              const SizedBox(height: 8),
              Text(
                empresa['label'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                empresa['descricao'] ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
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
  }

  Widget _buildCardFilial(Map<String, dynamic> filial) {
    return Material(
      elevation: 2,
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
        hoverColor: const Color(0xFFE8F5E9),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filial['icon'],
                color: const Color.fromARGB(255, 48, 153, 35),
                size: 50,
              ),
              const SizedBox(height: 8),
              Text(
                filial['label'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                filial['descricao'] ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
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
  }

  // NOVO: Método unificado para navegar para card filho
  void _navegarParaCardFilho(Map<String, dynamic> card) {
    final usuario = UsuarioAtual.instance;
    final tipo = card['tipo'];
    final sessaoPai = _sessaoAtual;

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
        _navegarParaCardVendas(tipo);
        break;
      case 'Bombeios':
        _navegarParaCardBombeios(tipo);
        break;
      default:
        debugPrint('Sessão pai não reconhecida: $sessaoPai');
    }
  }

  // Métodos específicos para cada sessão
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
      case 'tanques':
        setState(() {
          if (usuario!.nivel == 3) {
            _mostrarEscolherFilial = true;
            _contextoEscolhaFilial = 'tanques';
          } else {
            _mostrarTanques = true;
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
        debugPrint('Navegando para Movimentações');
        // Implementar navegação para movimentações
        break;
      case 'downloads':
        setState(() {
          _mostrarDownloads = true;
        });
        break;
    }
  }

  void _navegarParaCardCircuito(String tipo) {
    switch (tipo) {
      case 'iniciar_circuito':
        setState(() {
          _mostrarIniciarCircuito = true;
        });
        break;
      case 'acompanhar_veiculo':
        debugPrint('Abrir tela para acompanhar veículo');
        // Implementar navegação
        break;
      case 'visao_geral_circuito':
        debugPrint('Abrir visão geral dos circuitos');
        // Implementar navegação
        break;
    }
  }

  void _navegarParaCardGestaoFrota(String tipo) {
    switch (tipo) {
      case 'veiculos':
        // Navegação via setState (mantendo dentro da home)
        setState(() {
          _mostrarVeiculos = true;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
          _mostrarMotoristas = false;
          //_mostrarControleDocumentos = false;
        });
        break;
        
      case 'motoristas':
        // Navegação via setState (mantendo dentro da home)
        setState(() {
          _mostrarMotoristas = true;
          _mostrarVeiculos = false;
          _mostrarDetalhesVeiculo = false;
          _veiculoSelecionado = null;
          //_mostrarControleDocumentos = false;
        });
        break;
        
      case 'documentacao':
        // Navegação via Navigator.push (nova rota completa)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ControleDocumentosPage(),
          ),
        );
        break;
    }
  }

  void _navegarParaCardVendas(String tipo) {
    switch (tipo) {
      case 'programacao_vendas':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgramacaoPage(
              onVoltar: () {
                Navigator.pop(context);
              },
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
        // Implementar navegação quando criar a página
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (_) => const BombeiosPage()),
        // );
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

    if (usuario != null && usuario.nivel >= 2) {
      configCards.addAll([
        {
          'icon': Icons.admin_panel_settings,
          'label': 'Controle de acesso',
        },
        {
          'icon': Icons.people_alt,
          'label': 'Usuários',
        },
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: _buildGridConfiguracoes(configCards),
    );
  }

  Widget _buildGridConfiguracoes(List<Map<String, dynamic>> configCards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Configurações do sistema",
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1,
            children: configCards.map((c) {
              return Material(
                color: Colors.white,
                elevation: 1,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: () {
                    if (c['label'] == 'Controle de acesso') {
                      setState(() => showControleAcesso = true);
                    } else if (c['label'] == 'Usuários') {
                      setState(() => showUsuarios = true);
                    }
                  },
                  hoverColor: const Color(0xFFE8F5E9),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(c['icon'],
                          color: const Color.fromARGB(255, 48, 153, 35),
                          size: 50),
                      const SizedBox(height: 8),
                      Text(
                        c['label'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGridWithSearch(List<Map<String, dynamic>> sessoes) {
    final termoBusca = searchController.text.toLowerCase();

    final sessoesFiltradas = sessoes.where((s) {
      final label = (s['label'] ?? '').toString().toLowerCase();
      return label.contains(termoBusca);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 400,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Pesquisar sessões...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 25),

        if (sessoesFiltradas.isEmpty)
          const Center(
            child: Text(
              'Nenhuma sessão encontrada.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Expanded(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 7,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1,
              children: sessoesFiltradas.map((s) => _buildSessaoCard(s)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSessaoCard(Map<String, dynamic> sessao) {
    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          final nome = sessao['label'];
          
          // Resetar todas as flags
          _resetarTodasFlags();
          setState(() {
            selectedIndex = 0; // Mantém na aba "Sessões"
          });
          
          // Verificar se a sessão tem filhos definidos
          if (_filhosPorSessao.containsKey(nome)) {
            // Sessão com filhos: mostrar página de filhos
            _mostrarFilhosDaSessao(nome);
          } else {
            // Sessão sem filhos: navegar diretamente (comportamento antigo)
            _navegarParaSessaoSemFilhos(nome);
          }
        },
        hoverColor: const Color(0xFFE8F5E9),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(sessao['icon'],
                  color: const Color.fromARGB(255, 48, 153, 35), size: 50),
              const SizedBox(height: 6),
              Text(
                sessao['label'],
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NOVO: Método para navegar para sessões sem filhos (comportamento antigo)
  void _navegarParaSessaoSemFilhos(String nomeSessao) {
    // Este método pode ser usado para sessões que ainda não foram migradas
    // para a nova arquitetura ou que têm comportamentos específicos
    debugPrint('Navegando para sessão sem filhos: $nomeSessao');
    
    // Exemplo: se alguma sessão precisa de comportamento específico
    // switch (nomeSessao) {
    //   case 'Sessão Especial':
    //     // Comportamento específico
    //     break;
    //   default:
    //     // Comportamento padrão
    //     break;
    // }
  }

  IconData _definirIcone(String nome) {
    final lower = nome.toLowerCase();
    if (lower.contains('estoques')) return Icons.leaderboard;
    if (lower.contains('tabela')) return Icons.view_list;
    if (lower.contains('motor')) return Icons.people;
    if (lower.contains('abaste')) return Icons.local_gas_station;
    if (lower.contains('document')) return Icons.description;
    if (lower.contains('dep')) return Icons.warehouse;
    if (lower.contains('cacl')) return Icons.receipt_long;
    if (lower.contains('controle')) return Icons.car_repair;
    if (lower.contains('apura')) return Icons.analytics;
    if (lower.contains('cacl')) return Icons.analytics;
    if (lower.contains('venda')) return Icons.local_gas_station;
    if (lower.contains('tanque')) return Icons.storage;
    if (lower.contains('circuito')) return Icons.route;
    if (lower.contains('gestão') && lower.contains('frota')) return Icons.local_shipping;
    if (lower.contains('bombeios')) return Icons.invert_colors;
    return Icons.apps;
  }

  IconData _getMenuIcon(String item) {
    switch (item) {
      case 'Sessões':
        return Icons.apps;
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
              ? 'Olá, ${usuario.nome}! Bem-vindo ao CloudTrack!'
              : 'Bem-vindo ao CloudTrack!',
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
              'Seu ambiente moderno de gestão de estoques e logística em nuvem',
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
            ),
          ),
        );
      },
    );
  }
}