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
                // LOGO À ESQUERDA
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/logo_top_home.png',
                        height: 35,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "CloudTrack",
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  border: isSelected
                                      ? const Border(
                                          left: BorderSide(
                                              color: Color(0xFF2E7D32),
                                              width: 4))
                                      : null,
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
                                    Expanded(
                                      child: Text(
                                        menuItems[index],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFF2E7D32)
                                              : Colors.grey[800],
                                        ),
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
                  child: _buildPageContent(),
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
          const SizedBox(height: 30),
          // GRID DE SESSÕES
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge, // 🔹 impede o hover ultrapassar o card
      child: InkWell(
        onTap: () {
          // ação do card
        },
        onHover: (hovering) {
          // opcional: efeitos mais sutis podem ser adicionados aqui
        },
        hoverColor: const Color(0xFFE8F5E9), // cor de destaque suave
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF2E7D32), size: 45),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
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
