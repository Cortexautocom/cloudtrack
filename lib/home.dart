import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  TextEditingController searchController = TextEditingController();

  final List<String> menuItems = [
    'Dashboard',
    'Sessões',
    'Relatórios',
    'Configurações',
    'Ajuda'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔹 TOPBAR FIXA NO TOPO
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 255, 255, 255),
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
                // LOGO À ESQUERDA
                Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/logo_top_home.png',
                        //height: 40,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),                      
                    ],
                  ),
                ),
                // MENU USUÁRIO (direita)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.account_circle,
                        color: Color(0xFF0D47A1), size: 30),
                    onSelected: (value) {
                      if (value == 'Sair') {
                        // Implementar logout depois
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
                ),
              ],
            ),
          ),

          // 🔹 CONTEÚDO: MENU + PÁGINA
          Expanded(
            child: Row(
              children: [
                // MENU LATERAL (agora começa abaixo da topbar)
                Container(
                  width: 150,
                  color: const Color(0xFFF5F5F5),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // MENU ITENS
                      Expanded(
                        child: ListView.builder(
                          itemCount: menuItems.length,
                          itemBuilder: (context, index) {
                            bool isSelected = selectedIndex == index;
                            return InkWell(
                              onTap: () {
                                setState(() => selectedIndex = index);
                              },
                              child: AnimatedContainer(
                                key: ValueKey(index), // força o Flutter a animar a troca entre itens
                                duration: const Duration(milliseconds: 600), // tempo da transição
                                curve: Curves.easeInOut, // suaviza início e fim
                                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(1)
                                      : const Color(0xFFF5F5F5).withOpacity(1),
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected ? const Color.fromARGB(255, 100, 167, 255) : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 600),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
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

                // ÁREA PRINCIPAL
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400), // tempo da animação
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child); // efeito fade
                    },
                    child: _buildPageContent(), // o conteúdo que muda
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------
  // CONTEÚDOS DAS PÁGINAS
  // --------------------------------
  Widget _buildPageContent() {
    if (menuItems[selectedIndex] == 'Sessões') {
      return _buildSessoesPage();
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

  Widget _buildSessoesPage() {
    final List<Map<String, dynamic>> sessoes = [
      {'icon': Icons.local_shipping, 'label': 'Frotas'},
      {'icon': Icons.people, 'label': 'Motoristas'},
      {'icon': Icons.map, 'label': 'Rotas'},
      {'icon': Icons.local_gas_station, 'label': 'Abastecimentos'},
      {'icon': Icons.description, 'label': 'Documentos'},
      {'icon': Icons.warehouse, 'label': 'Depósitos'},
    ];

    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CAMPO DE BUSCA
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
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 25),

          // GRID DE SESSÕES (cards menores)
          Expanded(
            child: GridView.count(
              crossAxisCount: 5, // 🔹 aumenta colunas para cards menores
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1, // 🔹 1 = quadrado, >1 = mais largo
              children: sessoes
                  .where((s) => s['label']
                      .toLowerCase()
                      .contains(searchController.text.toLowerCase()))
                  .map((s) => _buildSessaoCard(s['icon'], s['label']))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessaoCard(IconData icon, String label) {
    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.hardEdge, // mantém hover dentro
      child: InkWell(
        onTap: () {},
        hoverColor: const Color(0xFFE8F5E9),
        child: Container(
          width: 110, // 🔹 define largura mínima visual
          height: 110, // 🔹 define altura menor
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color.fromARGB(255, 48, 153, 35), size: 50),
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
