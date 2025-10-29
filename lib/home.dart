import 'package:flutter/material.dart';
import 'sessoes/tabelasdeconversao.dart';
import 'configuracoes/controle_acesso_usuarios.dart';
import 'login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  TextEditingController searchController = TextEditingController();

  // Itens do menu lateral
  final List<String> menuItems = [
    'Dashboard',
    'Sessões',
    'Relatórios',
    'Configurações',
    'Ajuda'
  ];

  // Controle de exibição
  bool showConversaoList = false;
  bool showControleAcesso = false;
  bool showConfigList = false;

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
                // ===== Logo =====
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Image.asset(
                    'assets/logo_top_home.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // ===== Nome + Perfil =====
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    children: [
                      Text(
                        usuario != null ? usuario.nome : "",
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
                          if (value == 'Sair') {
                            await Supabase.instance.client.auth.signOut();
                            UsuarioAtual.instance = null;
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginPage()),
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
                              onTap: () {
                                setState(() {
                                  selectedIndex = index;
                                  showConversaoList = false;
                                  showControleAcesso = false;
                                  showConfigList = false;
                                });
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
    final sessoes = [
      {
        'icon': Icons.view_list,
        'label': 'Tabelas de conversão',
        'id': '1748397b-d907-4d7e-a566-2f8e5cffc7d9'
      },
      {'icon': Icons.people, 'label': 'Motoristas', 'id': 'uuid_motoristas'},
      {'icon': Icons.map, 'label': 'Rotas', 'id': 'uuid_rotas'},
      {
        'icon': Icons.local_gas_station,
        'label': 'Abastecimentos',
        'id': 'uuid_abastecimentos'
      },
      {'icon': Icons.description, 'label': 'Documentos', 'id': 'uuid_documentos'},
      {'icon': Icons.warehouse, 'label': 'Depósitos', 'id': 'uuid_depositos'},
    ];

    final sessoesVisiveis = sessoes.where((sessao) {
      if (usuario == null) return false;
      if (usuario.nivel >= 2) return true;
      return usuario.temPermissao(sessao['id']?.toString() ?? '');
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(30),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: showConversaoList
            ? TabelasDeConversao(
                key: const ValueKey('tabelas'),
                onVoltar: () {
                  setState(() => showConversaoList = false);
                },
              )
            : _buildGridWithSearch(sessoesVisiveis, usuario),
      ),
    );
  }

  // ===== Página de Configurações =====
  Widget _buildConfiguracoesPage(UsuarioAtual? usuario) {
    if (showControleAcesso) {
      return ControleAcessoUsuarios(
        key: const ValueKey('controle_acesso'),
        onVoltar: () => setState(() => showControleAcesso = false),
      );
    }

    final List<Map<String, dynamic>> configCards = [];

    // Apenas nível 2 ou 3 visualiza o card Controle de Acesso
    if (usuario != null && usuario.nivel >= 2) {
      configCards.add({
        'icon': Icons.admin_panel_settings,
        'label': 'Controle de acesso',
      });
    }

    return Padding(
      padding: const EdgeInsets.all(30),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: showConfigList
            ? _buildGridConfiguracoes(configCards)
            : _buildGridConfiguracoes(configCards),
      ),
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
            crossAxisCount: 6,
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
  Widget _buildGridWithSearch(
      List<Map<String, dynamic>> sessoes, UsuarioAtual? usuario) {
    return Column(
      key: const ValueKey('grid_with_search'),
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
        Expanded(
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1,
            children: sessoes
                .where((s) => s['label']
                    .toLowerCase()
                    .contains(searchController.text.toLowerCase()))
                .map((s) => _buildSessaoCard(s['icon'], s['label']))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ===== Cada card =====
  Widget _buildSessaoCard(IconData icon, String label) {
    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          if (label == 'Tabelas de conversão') {
            setState(() => showConversaoList = true);
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
              Icon(icon,
                  color: const Color.fromARGB(255, 48, 153, 35), size: 50),
              const SizedBox(height: 6),
              Text(
                label,
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

  // ===== Ícones =====
  IconData _getMenuIcon(String item) {
    switch (item) {
      case 'Dashboard':
        return Icons.dashboard;
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
}
