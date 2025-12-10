import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/tabelas_de_conversao/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'configuracoes/usuarios.dart';
import 'perfil.dart';
import 'sessoes/apuracao/cacl.dart';
import 'sessoes/logistica/controle_documentos.dart';
import 'sessoes/apuracao/medicao.dart';
import 'sessoes/apuracao/tanques.dart';
import 'sessoes/apuracao/escolherfilial.dart';
import 'sessoes/vendas/programacao.dart';

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
  bool _mostrarApuracaoFilhos = false;
  bool _veioDaApuracao = false;
  bool _mostrarMedicaoTanques = false;
  bool _mostrarTanques = false;
  Map<String, dynamic>? _dadosCalcGerado;
  
  // FLAGS PARA ESCOLHA DE FILIAL
  bool _mostrarEscolherFilial = false; // ← FLAG ÚNICA PARA AMBAS AS FUNCIONALIDADES
  String? _filialSelecionadaId;
  String _contextoEscolhaFilial = ''; // ← 'medição' ou 'tanques'
  
  List<Map<String, dynamic>> sessoes = [];
  List<Map<String, dynamic>> apuracaoFilhos = [];

  @override
  void initState() {
    super.initState();
    _inicializarApuracaoFilhos();
    selectedIndex = -1;
  }

  void _inicializarApuracaoFilhos() {
    apuracaoFilhos = [
      {
        'icon': Icons.analytics,
        'label': 'Medição',
        'descricao': 'Sistema de medição e apuração',
      },
      {
        'icon': Icons.calculate,
        'label': 'CACL',
        'descricao': 'Cálculos e apurações contábeis',
      },
      {
        'icon': Icons.storage,
        'label': 'Tanques',
        'descricao': 'Gerenciamento de tanques de combustível',
      },
    ];
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
      _mostrarMedicaoTanques = false;
      _veioDaApuracao = false;
      _mostrarTanques = false;
      _mostrarEscolherFilial = false;
      _filialSelecionadaId = null;
      _contextoEscolhaFilial = '';
    });
  }

  void _voltarParaCardsPai() {
    setState(() {
      _mostrarApuracaoFilhos = false;
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
    // ✅ PÁGINA INICIAL TEM PRIORIDADE
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

        child: _mostrarEscolherFilial
            ? EscolherFilialPage(
                key: ValueKey('escolher-filial-$_contextoEscolhaFilial'),
                onVoltar: () {
                  setState(() {
                    _mostrarEscolherFilial = false;
                    if (_contextoEscolhaFilial == 'medição' && _veioDaApuracao) {
                      _mostrarApuracaoFilhos = true;
                    } else if (_contextoEscolhaFilial == 'tanques' && _veioDaApuracao) {
                      _mostrarApuracaoFilhos = true;
                    }
                    _contextoEscolhaFilial = '';
                  });
                },
                onSelecionarFilial: (idFilial) {
                  setState(() {
                    _filialSelecionadaId = idFilial;
                    _mostrarEscolherFilial = false;
                    
                    if (_contextoEscolhaFilial == 'medição') {
                      _mostrarMedicaoTanques = true;
                    } else if (_contextoEscolhaFilial == 'tanques') {
                      _mostrarTanques = true;
                    }
                    
                    _contextoEscolhaFilial = '';
                  });
                },
                titulo: _contextoEscolhaFilial == 'medição' 
                  ? 'Selecionar filial para medição'
                  : 'Selecionar filial para gerenciar tanques',
              )

            : _mostrarMedicaoTanques
                ? MedicaoTanquesPage(
                    key: const ValueKey('medicao-tanques'),
                    filialSelecionadaId: _filialSelecionadaId,
                    onVoltar: () {
                      final usuario = UsuarioAtual.instance;

                      setState(() {
                        _mostrarMedicaoTanques = false;
                        _filialSelecionadaId = null;

                        if (usuario!.nivel == 3) {
                          _mostrarEscolherFilial = true;
                          _contextoEscolhaFilial = 'medição';
                        } else {
                          if (_veioDaApuracao) {
                            _mostrarApuracaoFilhos = true;
                          }
                        }

                        _veioDaApuracao = false;
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
                          }
                        }

                        _veioDaApuracao = false;
                      });
                    },
                    filialSelecionadaId: _filialSelecionadaId,
                  )

            : _mostrarApuracaoFilhos
                ? _buildApuracaoFilhosPage()

            : _mostrarCalcGerado
                ? CalcPage(
                    key: const ValueKey('calc-page'),
                    dadosFormulario: _dadosCalcGerado ?? {},
                  )

            : showConversaoList
                ? TabelasDeConversao(
                    key: const ValueKey('tabelas'),
                    onVoltar: () {
                      setState(() => showConversaoList = false);
                    },
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
                  card['descricao'],
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

  void _navegarParaCardFilho(String nomeCard) {
    final usuario = UsuarioAtual.instance;

    switch (nomeCard) {
      case 'Medição':
        setState(() {
          _veioDaApuracao = true;
          _mostrarApuracaoFilhos = false;

          if (usuario!.nivel == 3) {
            _mostrarEscolherFilial = true;
            _contextoEscolhaFilial = 'medição';
          } else {
            _mostrarMedicaoTanques = true;
          }
        });
        break;

      case 'CACL':
        setState(() {
          _veioDaApuracao = true;
          _mostrarApuracaoFilhos = false;
          _mostrarCalcGerado = true;
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
          final usuario = UsuarioAtual.instance;

          if (nome == 'Tabelas de conversão') {
            setState(() => showConversaoList = true);
            return;
          }

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
              _mostrarCalcGerado = true;
            });
            return;
          }

          if (nome == 'Medição') {
            setState(() {
              _veioDaApuracao = false;
              showConversaoList = false;
              showControleAcesso = false;
              showUsuarios = false;

              if (usuario!.nivel == 3) {
                _mostrarEscolherFilial = true;
                _contextoEscolhaFilial = 'medição';
              } else {
                _mostrarMedicaoTanques = true;
              }
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
                    Navigator.pop(context); // Volta para o menu principal
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
    if (lower.contains('tabela')) return Icons.view_list;
    if (lower.contains('motor')) return Icons.people;
    if (lower.contains('rota')) return Icons.map;
    if (lower.contains('abaste')) return Icons.local_gas_station;
    if (lower.contains('document')) return Icons.description;
    if (lower.contains('dep')) return Icons.warehouse;
    if (lower.contains('cacl')) return Icons.receipt_long;
    if (lower.contains('controle')) return Icons.car_repair;
    if (lower.contains('apura')) return Icons.analytics;
    if (lower.contains('medic')) return Icons.analytics;
    if (lower.contains('venda')) return Icons.local_gas_station;
    if (lower.contains('tanque')) return Icons.storage;
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
              'Seu ambiente moderno de gestão de estoques e logística totalmente na nuvem,\ncom rotinas e fluxos planejados e implementados por inteligência artificial,\nbuscando máxima eficiência e redução de custos operacionais.',
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
}