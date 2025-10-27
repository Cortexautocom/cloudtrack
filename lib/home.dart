import 'package:flutter/material.dart';

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

  // Controle dos menus
  bool showConversaoList = false;
  bool showTabelaVolume = false;
  bool showTabelaDensidade = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ===== Barra superior =====
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
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/logo_top_home.png',
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.account_circle,
                        color: Color(0xFF0D47A1), size: 30),
                    onSelected: (value) {
                      if (value == 'Sair') {}
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
                                setState(() => selectedIndex = index);
                              },
                              child: AnimatedContainer(
                                key: ValueKey(index),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 15, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(1)
                                      : const Color(0xFFF5F5F5).withOpacity(1),
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
                    child: _buildPageContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====== Decide o que mostrar ======
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

  // ===== Página de Sessões =====
  Widget _buildSessoesPage() {
    final List<Map<String, dynamic>> sessoes = [
      {'icon': Icons.view_list, 'label': 'Tabelas de conversão'},
      {'icon': Icons.people, 'label': 'Motoristas'},
      {'icon': Icons.map, 'label': 'Rotas'},
      {'icon': Icons.local_gas_station, 'label': 'Abastecimentos'},
      {'icon': Icons.description, 'label': 'Documentos'},
      {'icon': Icons.warehouse, 'label': 'Depósitos'},
    ];

    return Padding(
      padding: const EdgeInsets.all(30),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: showConversaoList
            ? _buildConversaoList()
            : _buildGridWithSearch(sessoes),
      ),
    );
  }

  // ===== Grade + Barra de Pesquisa =====
  Widget _buildGridWithSearch(List<Map<String, dynamic>> sessoes) {
    return Column(
      key: const ValueKey('grid_with_search'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Barra de Pesquisa =====
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

        // ===== Grade de cards =====
        Expanded(
          child: GridView.count(
            key: const ValueKey('grid'),
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            crossAxisCount: 10,
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

  // ===== Menu de tabelas de conversão (lista expansível) =====
  Widget _buildConversaoList() {
    return Container(
      key: const ValueKey('list'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botão de voltar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                onPressed: () {
                  setState(() {
                    showConversaoList = false;
                    showTabelaVolume = false;
                    showTabelaDensidade = false;
                  });
                },
              ),
              const Text(
                "Tabelas de conversão",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const Divider(),

          // Lista principal
          ListTile(
            leading: const Icon(Icons.stacked_bar_chart, color: Colors.green),
            title: const Text("Tabela de Conversão de Volume"),
            trailing: Icon(
              showTabelaVolume ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                showTabelaVolume = !showTabelaVolume;
                showTabelaDensidade = false;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: showTabelaVolume
                ? Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ListTile(
                          title: Text("TCV Anidro e Hidratado"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                        ListTile(
                          title: Text("TCV Gasolina e Diesel"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          ListTile(
            leading: const Icon(Icons.science, color: Colors.blue),
            title: const Text("Tabela de Conversão de Densidade"),
            trailing: Icon(
              showTabelaDensidade ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                showTabelaDensidade = !showTabelaDensidade;
                showTabelaVolume = false;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: showTabelaDensidade
                ? Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ListTile(
                          title: Text("TCD Anidro e Hidratado"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                        ListTile(
                          title: Text("TCD Gasolina e Diesel"),
                          leading: Icon(Icons.insert_drive_file_outlined),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ===== Cada card da grade =====
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
              showTabelaVolume = false;
              showTabelaDensidade = false;
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
