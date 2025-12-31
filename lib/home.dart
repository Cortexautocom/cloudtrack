import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/tabelas_de_conversao/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'configuracoes/usuarios.dart';
import 'perfil.dart';
import 'sessoes/apuracao/cacl.dart';
import 'sessoes/logistica/controle_documentos.dart';
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

  bool showConversaoList = false;
  bool showControleAcesso = false;
  bool showConfigList = false;
  bool carregandoSessoes = false;
  bool showUsuarios = false;
  bool _mostrarCalcGerado = false;
  bool _mostrarDownloads = false;
  bool _mostrarApuracaoFilhos = false;
  bool _veioDaApuracao = false;
  bool _mostrarMedicaoTanques = false;
  bool _mostrarTanques = false;
  bool _mostrarOrdensAnalise = false;
  bool _mostrarHistorico = false;
  bool _mostrarListarCacls = false;
  bool _mostrarFiltrosEstoque = false;
  bool _mostrarCircuitoFilhos = false;
  String? _filialSelecionadaNome;
  Map<String, dynamic>? _dadosCalcGerado;
  
  // FLAGS PARA ESCOLHA DE FILIAL
  bool _mostrarEscolherFilial = false;
  String? _filialSelecionadaId;
  String _contextoEscolhaFilial = '';
  String? _filialParaFiltroId;
  String? _filialParaFiltroNome;
  String? _empresaParaFiltroId;
  String? _empresaParaFiltroNome;
  
  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, dynamic>> apuracaoFilhos = [];
  List<Map<String, dynamic>> estoquesFilhos = [];
  List<Map<String, dynamic>> empresas = [];
  List<Map<String, dynamic>> filiaisDaEmpresa = [];
  List<Map<String, dynamic>> circuitoFilhos = [];
  bool _mostrarEstoquesFilhos = false;
  bool _mostrarEstoquePorEmpresa = false;
  bool _mostrarFiliaisDaEmpresa = false;
  bool carregandoEmpresas = false;
  bool carregandoFiliaisEmpresa = false;
  String? _empresaSelecionadaNome;
  String? _empresaSelecionadaId;

  @override
  void initState() {
    super.initState();
    _inicializarApuracaoFilhos();
    _inicializarEstoquesFilhos();
    _inicializarCircuitoFilhos();
    selectedIndex = -1;
  }

  void _inicializarApuracaoFilhos() {
    apuracaoFilhos = [
      {
        'icon': Icons.analytics,
        'label': 'CACL',
        'descricao': 'Emitir CACL',
      },      
      {
        'icon': Icons.oil_barrel,
        'label': 'Tanques',
        'descricao': 'Gerenciamento de tanques',
      },
      {
        'icon': Icons.assignment,
        'label': 'Ordens / Análise',
        'descricao': 'Geração e gestão de ordens',
      },
      {
        'icon': Icons.history,
        'label': 'Histórico',
        'descricao': 'Consultar histórico de CACLs emitidos',
      },
      {
        'icon': Icons.table_chart,
        'label': 'Tabelas de Conversão',
        'descricao': 'Tabelas de conversão de densidade e temperatura',
      },
    ];
  }

  void _inicializarEstoquesFilhos() {
    estoquesFilhos = [
      {
        'icon': Icons.hub,
        'label': 'Estoque Geral',
        'descricao': 'Visão consolidada dos estoques da base',
      },
      {
        'icon': Icons.business,
        'label': 'Estoque por empresa',
        'descricao': 'Estoques separados por empresa',
      },
      {
        'icon': Icons.swap_horiz,
        'label': 'Movimentações',
        'descricao': 'Acompanhar entradas e saídas em geral',
      },
    ];
  }

  void _inicializarCircuitoFilhos() {
    circuitoFilhos = [
      {
        'icon': Icons.play_arrow,
        'label': 'Iniciar Circuito',
        'descricao': 'Iniciar novo fluxo de carga/descarga',
      },
      {
        'icon': Icons.directions_car,
        'label': 'Acompanhar veículo',
        'descricao': 'Monitorar veículo em trânsito',
      },
      {
        'icon': Icons.dashboard,
        'label': 'Visão geral',
        'descricao': 'Panorama completo dos circuitos',
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

  void _navegarParaInicio() {
    setState(() {
      selectedIndex = -1;
      showConversaoList = false;
      showControleAcesso = false;
      showConfigList = false;
      showUsuarios = false;
      _mostrarCalcGerado = false;
      _mostrarApuracaoFilhos = false;
      _veioDaApuracao = false;
      _mostrarMedicaoTanques = false;
      _mostrarTanques = false;
      _mostrarEscolherFilial = false;
      _filialSelecionadaId = null;
      _filialSelecionadaNome = null;
      _contextoEscolhaFilial = '';
      _mostrarOrdensAnalise = false;
      _mostrarHistorico = false;
      _mostrarEstoquePorEmpresa = false;
      _mostrarEstoquesFilhos = false;
      _mostrarFiliaisDaEmpresa = false;
      _mostrarListarCacls = false;
      _mostrarDownloads = false;
      _empresaSelecionadaId = null;
      _empresaSelecionadaNome = null;
      _mostrarFiltrosEstoque = false;
      _filialParaFiltroId = null;
      _filialParaFiltroNome = null;
      _empresaParaFiltroId = null;
      _empresaParaFiltroNome = null;
      _mostrarFiltrosEstoque = false;
      _mostrarCircuitoFilhos = false;
    });
  }

  void _voltarParaCardsPai() {
    setState(() {
      _mostrarApuracaoFilhos = false;
      _veioDaApuracao = false;
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
                    onTap: _navegarParaInicio,
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
                                setState(() {
                                  selectedIndex = index;
                                  showConversaoList = false;
                                  showControleAcesso = false;
                                  showConfigList = false;
                                  showUsuarios = false;
                                  _mostrarCalcGerado = false;
                                  _mostrarApuracaoFilhos = false;
                                  _mostrarMedicaoTanques = false;
                                  _veioDaApuracao = false;
                                  _mostrarTanques = false;
                                  _mostrarEscolherFilial = false;
                                  _filialSelecionadaId = null;
                                  _contextoEscolhaFilial = '';
                                  _mostrarOrdensAnalise = false;
                                  _mostrarHistorico = false;
                                  _mostrarEstoquePorEmpresa = false;
                                  _mostrarEstoquesFilhos = false;
                                  _mostrarFiliaisDaEmpresa = false;
                                  _mostrarListarCacls = false;
                                  _filialParaFiltroId = null;
                                  _filialParaFiltroNome = null;
                                  _empresaParaFiltroId = null;
                                  _empresaParaFiltroNome = null;
                                  _mostrarFiltrosEstoque = false;
                                  _mostrarCircuitoFilhos = false;
                                });

                                if (menuItems[index] == 'Sessões') {
                                  await _verificarPermissoesUsuario();
                                }

                                if (menuItems[index] != 'Configurações') {
                                  setState(() {
                                    showControleAcesso = false;
                                    showUsuarios = false;
                                  });
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
        child: _mostrarFiltrosEstoque && _filialParaFiltroId != null
            ? _buildFiltrosEstoquePage()
            : _mostrarDownloads
                ? DownloadsPage(
                    key: const ValueKey('downloads-page'),
                    onVoltar: () {
                      setState(() {
                        _mostrarDownloads = false;
                        _mostrarEstoquesFilhos = true;
                      });
                    },
                  )
                : showConversaoList
                    ? TabelasDeConversao(
                        key: const ValueKey('tabelas'),
                        onVoltar: () {
                          setState(() {
                            showConversaoList = false;
                            if (_veioDaApuracao) {
                              _mostrarApuracaoFilhos = true;
                            }
                          });
                        },
                      )
                    : _mostrarListarCacls
                        ? ListarCaclsPage(
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
                                  if (_veioDaApuracao) {
                                    _mostrarApuracaoFilhos = true;
                                  }
                                }
                              });
                            },
                            filialId: _filialSelecionadaId!,
                            filialNome: _filialSelecionadaNome ?? 'Filial',
                            onIrParaEmissao: () {
                              setState(() {
                                _mostrarListarCacls = false;
                                _mostrarMedicaoTanques = true;
                                _mostrarApuracaoFilhos = true;
                                _veioDaApuracao = true;
                              });
                            },
                          )
                        : _mostrarOrdensAnalise
                            ? CertificadoAnalisePage(
                                key: const ValueKey('ordens-analise'),
                                onVoltar: () {
                                  setState(() {
                                    _mostrarOrdensAnalise = false;
                                    if (_veioDaApuracao) {
                                      _mostrarApuracaoFilhos = true;
                                    }
                                  });
                                },
                              )
                            : _mostrarHistorico
                                ? HistoricoCaclPage(
                                    key: const ValueKey('historico-cacl'),
                                    onVoltar: () {
                                      setState(() {
                                        _mostrarHistorico = false;
                                        if (_veioDaApuracao) {
                                          _mostrarApuracaoFilhos = true;
                                        }
                                      });
                                    },
                                  )
                                : _mostrarEscolherFilial
                                    ? EscolherFilialPage(
                                        key: ValueKey('escolher-filial-$_contextoEscolhaFilial'),
                                        onVoltar: () {
                                          setState(() {
                                            _mostrarEscolherFilial = false;
                                            if (_veioDaApuracao) {
                                              _mostrarApuracaoFilhos = true;
                                            }
                                            _contextoEscolhaFilial = '';
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
                                            debugPrint('❌ Erro ao carregar dados da filial: $e');
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
                                      )
                                    : _mostrarMedicaoTanques
                                        ? MedicaoTanquesPage(
                                            key: const ValueKey('medicao-tanques'),
                                            filialSelecionadaId: _filialSelecionadaId,
                                            onVoltar: () {
                                              final usuario = UsuarioAtual.instance;

                                              setState(() {
                                                _mostrarMedicaoTanques = false;

                                                if (usuario!.nivel == 3) {
                                                  _mostrarListarCacls = true;
                                                } else {
                                                  _mostrarListarCacls = true;
                                                }
                                              });
                                            },
                                            onFinalizarCACL: () {
                                              setState(() {
                                                _mostrarMedicaoTanques = false;
                                                _mostrarListarCacls = false;
                                                _mostrarApuracaoFilhos = true;
                                                _veioDaApuracao = true;
                                              });
                                            },
                                          )
                                        : _mostrarTanques
                                            ? GerenciamentoTanquesPage(
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
                                                      if (_veioDaApuracao) {
                                                        _mostrarApuracaoFilhos = true;
                                                      } else {
                                                        _mostrarApuracaoFilhos = false;
                                                      }
                                                    }
                                                  });
                                                },
                                                filialSelecionadaId: _filialSelecionadaId,
                                              )
                                            : _mostrarFiliaisDaEmpresa
                                                ? _buildFiliaisDaEmpresaPage()
                                                : _mostrarEstoquePorEmpresa
                                                    ? _buildEstoquePorEmpresaPage()
                                                    : _mostrarEstoquesFilhos
                                                        ? _buildEstoquesFilhosPage()
                                                        : _mostrarCircuitoFilhos
                                                            ? _buildCircuitoFilhosPage()
                                                            : _mostrarApuracaoFilhos
                                                                ? _buildApuracaoFilhosPage()
                                                                : _mostrarCalcGerado
                                                                    ? CalcPage(
                                                                        key: const ValueKey('calc-page'),
                                                                        dadosFormulario: _dadosCalcGerado ?? {},
                                                                      )
                                                                    : _buildGridWithSearch(sessoes),
      ),
    );
  }

  Widget _buildApuracaoFilhosPage() {
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
            const Text(
              'Apuração',
              style: TextStyle(
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
          child: _buildGridApuracaoFilhos(),
        ),
      ],
    );
  }

  Widget _buildEstoquesFilhosPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: () {
                setState(() {
                  _mostrarEstoquesFilhos = false;
                });
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'Estoques',
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

        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1,
            children: estoquesFilhos
                .map((card) => _buildCardApuracaoFilho(card))
                .toList(),
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
                setState(() {
                  _mostrarEstoquePorEmpresa = false;
                  _mostrarEstoquesFilhos = true;
                });
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

  Widget _buildGridApuracaoFilhos() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 7,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1,
      children: apuracaoFilhos.map((card) => _buildCardApuracaoFilho(card)).toList(),
    );
  }

  Widget _buildCardApuracaoFilho(Map<String, dynamic> card) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          _navegarParaCardFilho(card['label']);
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
            // Mostrar página de filtros usando estado
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

  void _navegarParaCardFilho(String nomeCard) {
    final usuario = UsuarioAtual.instance;

    switch (nomeCard) {
      case 'CACL':
        setState(() {
          _veioDaApuracao = true;
          _mostrarApuracaoFilhos = false;

          if (usuario!.nivel == 3) {
            _mostrarEscolherFilial = true;
            _contextoEscolhaFilial = 'cacl';
          } else {
            _mostrarMedicaoTanques = true;
          }
        });
        break;
            
      case 'Tanques':
        setState(() {
          _veioDaApuracao = true;
          _mostrarApuracaoFilhos = false;

          if (usuario!.nivel == 3) {
            _mostrarEscolherFilial = true;
            _contextoEscolhaFilial = 'tanques';
          } else {
            _mostrarTanques = true;
          }
        });
        break;
          
      case 'Ordens / Análise':
        setState(() {
          _veioDaApuracao = true;
          _mostrarOrdensAnalise = true;
          _mostrarApuracaoFilhos = false;
        });
        break;
          
      case 'Histórico':
        setState(() {
          _veioDaApuracao = true;
          _mostrarApuracaoFilhos = false;
          _mostrarHistorico = true;
        });
        break;
          
      case 'Tabelas de Conversão':
        setState(() {
          _veioDaApuracao = true;
          _mostrarApuracaoFilhos = false;
          showConversaoList = true;
        });
        break;
          
      case 'Estoque Geral':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EstoqueGeralPage(),
          ),
        );
        break;
          
      case 'Estoque por empresa':
        setState(() {
          _mostrarEstoquePorEmpresa = true;
          _mostrarEstoquesFilhos = false;
          _carregarEmpresas();
        });
        break;

      case 'Movimentações':
        debugPrint('Navegando para Movimentações');
        break;

      case 'Downloads':
        setState(() {
          _mostrarDownloads = true;
          _mostrarEstoquesFilhos = false;
        });
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
          
          setState(() {
            _mostrarDownloads = false;
            _mostrarEstoquesFilhos = false;
            _mostrarApuracaoFilhos = false;
          });
          
          if (nome == 'Estoques') {
            setState(() {
              _mostrarEstoquesFilhos = true;
            });
            return;
          }

          final usuario = UsuarioAtual.instance;

          if (nome == 'Apuração') {
            setState(() {
              showConversaoList = false;
              showControleAcesso = false;
              showUsuarios = false;
              _mostrarApuracaoFilhos = true;
            });
            return;
          }          

          if (nome == 'CACL') {
            setState(() {
              _veioDaApuracao = false;
              showConversaoList = false;
              showControleAcesso = false;
              showUsuarios = false;

              if (usuario!.nivel == 3) {
                _mostrarEscolherFilial = true;
                _contextoEscolhaFilial = 'cacl';
              } else {
                _mostrarMedicaoTanques = true;
              }
            });
            return;
          }
          
      if (nome == 'Circuito') {
        setState(() {
          _mostrarCircuitoFilhos = true;
        });
        return;
      }
          
          if (nome == 'Tanques') {
            setState(() {
              _veioDaApuracao = false;
              showConversaoList = false;
              showControleAcesso = false;
              showUsuarios = false;

              if (usuario!.nivel == 3) {
                _mostrarEscolherFilial = true;
                _contextoEscolhaFilial = 'tanques';
              } else {
                _mostrarTanques = true;
              }
            });
            return;
          }

          if (nome == 'Vendas') {
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
            return;
          }
          
          if (nome == 'Logística') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ControleDocumentosPage()),
            );
            return;
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

  IconData _definirIcone(String nome) {
    final lower = nome.toLowerCase();
    if (lower.contains('estoques')) return Icons.leaderboard;
    if (lower.contains('tabela')) return Icons.view_list;
    if (lower.contains('motor')) return Icons.people;
    if (lower.contains('rota')) return Icons.map;
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
        // Navegar para EstoqueMesPage
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

  Widget _buildCircuitoFilhosPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: () {
                setState(() {
                  _mostrarCircuitoFilhos = false;
                });
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'Circuito',
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

        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1,
            children: circuitoFilhos
                .map((card) => _buildCardCircuitoFilho(card))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCardCircuitoFilho(Map<String, dynamic> card) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          _navegarParaCardCircuito(card['label']);
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

  void _navegarParaCardCircuito(String nomeCard) {
    switch (nomeCard) {
      case 'Iniciar Circuito':
        debugPrint('Abrir tela para iniciar novo circuito');
        // Aqui você pode adicionar navegação para uma nova tela
        break;
        
      case 'Acompanhar veículo':
        debugPrint('Abrir tela para acompanhar veículo');
        // Aqui você pode adicionar navegação para uma nova tela
        break;
        
      case 'Visão geral':
        debugPrint('Abrir visão geral dos circuitos');
        // Aqui você pode adicionar navegação para uma nova tela
        break;
    }
  }
}