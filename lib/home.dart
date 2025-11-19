import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sessoes/tabelas_de_conversao/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'configuracoes/usuarios.dart';
import 'perfil.dart';
import 'sessoes/CALC/cacl.dart';
import 'sessoes/CALC/form_calc.dart';
import 'sessoes/controle_documentos.dart';

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
  bool _mostrarFormCalc = false;
  bool _mostrarCalcGerado = false;
  Map<String, dynamic>? _dadosCalcGerado;
  

  List<Map<String, dynamic>> sessoes = [];

  @override
  void initState() {
    super.initState();
  }

  /// 🔹 Carrega todas as sessões do banco e aplica filtro de permissões
  Future<void> _carregarSessoesDoBanco() async {
    setState(() => carregandoSessoes = true);
    final supabase = Supabase.instance.client;
    final usuario = UsuarioAtual.instance;

    try {
      final dados = await supabase.from('sessoes').select('id, nome');

      // Aplica filtro conforme nível
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
      // Manter o catch é uma boa prática
    } finally {
      setState(() => carregandoSessoes = false);
    }
  }

  /// 🔹 Verifica permissões do usuário ao clicar em "Sessões"
  Future<void> _verificarPermissoesUsuario() async {
    final usuario = UsuarioAtual.instance;
    if (usuario == null) return;

    try {
      final supabase = Supabase.instance.client;

      // 🔹 Nível 2+ tem acesso total
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

      // 🔹 Busca permissões atualizadas da tabela
      final permissoes = await supabase
          .from('permissoes')
          .select('id_sessao, permitido')
          .eq('id_usuario', usuario.id);

      final sessoesPermitidas = List<String>.from(
        permissoes
            .where((p) => p['permitido'] == true)
            .map((p) => p['id_sessao'].toString()),
      );

      // 🔹 Atualiza as permissões no objeto global
      UsuarioAtual.instance = UsuarioAtual(
        id: usuario.id,
        nome: usuario.nome,
        nivel: usuario.nivel,
        filialId: usuario.filialId,
        sessoesPermitidas: sessoesPermitidas,
        senhaTemporaria: usuario.senhaTemporaria,
      );

      // 🔹 Atualiza a exibição das sessões
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

  /// 🔹 Navega para a página Início
  void _navegarParaInicio() {
    setState(() {
      selectedIndex = -1;
      showConversaoList = false;
      showControleAcesso = false;
      showConfigList = false;
      showUsuarios = false;
      _mostrarFormCalc = false;
      _mostrarCalcGerado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = UsuarioAtual.instance;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ===== Barra superior =====
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
                // 🔹 LOGO CLICÁVEL - LEVA PARA INÍCIO
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

          // ===== Corpo principal =====
          Expanded(
            child: Row(
              children: [
                // ===== Menu lateral =====
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
                                  _mostrarFormCalc = false;
                                  _mostrarCalcGerado = false;
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

                // ===== Conteúdo principal =====
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

  // ===== Decide o que mostrar =====
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

  // ===== Página de Sessões =====
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

        child: _mostrarFormCalc
            ? FormCalcPage(
                onVoltar: () {
                  setState(() {
                    _mostrarFormCalc = false;
                    _mostrarCalcGerado = false;
                  });
                },
              )              
            : _mostrarCalcGerado
                ? CalcPage(
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

  // ===== Página de Configurações =====
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

  // ===== Grade de Configurações =====
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

  // ===== Grade de Sessões com busca =====
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

  // ===== Cada card =====
  Widget _buildSessaoCard(Map<String, dynamic> sessao) {
    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          final nome = sessao['label'];

          if (nome == 'Tabelas de conversão') {
            setState(() => showConversaoList = true);
            return;
          }

          if (nome == 'CALC') {
            setState(() {
              showConversaoList = false;
              showControleAcesso = false;
              showUsuarios = false;
              _mostrarFormCalc = true;
            });
            return;
          }
          if (nome == 'Controle 1') {
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

  // ===== Ícone automático conforme nome =====
  IconData _definirIcone(String nome) {
    final lower = nome.toLowerCase();
    if (lower.contains('tabela')) return Icons.view_list;
    if (lower.contains('motor')) return Icons.people;
    if (lower.contains('rota')) return Icons.map;
    if (lower.contains('abaste')) return Icons.local_gas_station;
    if (lower.contains('document')) return Icons.description;
    if (lower.contains('dep')) return Icons.warehouse;
    if (lower.contains('calc')) return Icons.receipt_long;
    if (lower.contains('controle')) return Icons.car_repair;
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

  // ===== Página Início =====
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
            'Bem-vindo ao CloudTrack!',
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
              'Seu ambiente moderno de gestão de estoques e logística totalmente na nuvem,\ncom rotinas e fluxos planejados e implementedos por inteligência artificial,\nbuscando máxima eficiência e redução de custos operacionais.',
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