import 'package:flutter/material.dart';
import 'sessoes/tabelasdeconversao.dart';
import 'login_page.dart'; // para voltar ao LoginPage
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

  final List<String> menuItems = [
    'Dashboard',
    'Sessões',
    'Relatórios',
    'Configurações',
    'Ajuda'
  ];

  bool showConversaoList = false;
  bool showTabelaVolume = false;
  bool showTabelaDensidade = false;

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
                // ===== Logo lado esquerdo =====
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Image.asset(
                    'assets/logo_top_home.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // ===== Nome do usuário + menu de perfil =====
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    children: [
                      // Nome do usuário logado
                      Text(
                        usuario != null ? usuario.nome : "",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Dropdown de perfil
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.account_circle,
                          color: Color(0xFF0D47A1),
                          size: 30,
                        ),
                        onSelected: (value) async {
                          if (value == 'Sair') {
                            // 🔹 Desloga do Supabase e volta ao login
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
                        itemBuilder: (BuildContext context) {
                          return {'Perfil', 'Sair'}.map((String choice) {
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
                              onTap: () => setState(() => selectedIndex = index),
                              child: AnimatedContainer(
                                key: ValueKey(index),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFF5F5F5),
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected
                                          ? const Color.fromARGB(
                                              255, 100, 167, 255)
                                          : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 600),
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF2E7D32)
                                            : Colors.grey[800],
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
                                          Text(menuItems[index]),
                                        ],
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
    if (menuItems[selectedIndex] == 'Sessões') {
      return _buildSessoesPage(usuario);
    } else {
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
    // Lista completa das sessões disponíveis
    final List<Map<String, dynamic>> sessoes = [
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

    // 🔒 Filtra sessões de acordo com as permissões do usuário
    final sessoesVisiveis = sessoes.where((sessao) {
      if (usuario == null) return false;
      if (usuario.nivel >= 2) return true; // gerente ou admin veem tudo
      return usuario.temPermissao(sessao['id']);
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
                  setState(() {
                    showConversaoList = false;
                    showTabelaVolume = false;
                    showTabelaDensidade = false;
                  });
                },
              )
            : _buildGridWithSearch(sessoesVisiveis),
      ),
    );
  }

  // ===== Grade + Pesquisa =====
  Widget _buildGridWithSearch(List<Map<String, dynamic>> sessoes) {
    return Column(
      key: const ValueKey('grid_with_search'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de pesquisa
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
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 25),

        // Grade de cards filtrados
        Expanded(
          child: GridView.count(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
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
            setState(() {
              showConversaoList = true;
            });
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

  // ===== Ícones do menu lateral =====
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
