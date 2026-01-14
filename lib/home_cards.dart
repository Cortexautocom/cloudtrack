import 'package:flutter/material.dart';

class HomeCards extends StatelessWidget {
  final String menuSelecionado;
  final Function(String) onCardSelecionado;
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
          // Cabeçalho com botão de voltar e título
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

          // Conteúdo dos cards baseado no menu selecionado
          Expanded(
            child: _buildCardsConteudo(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsConteudo() {
    switch (menuSelecionado) {
      case 'Ajuda':
        return _buildCardsAjuda();
      default:
        return const Center(
          child: Text(
            'Conteúdo em construção...',
            style: TextStyle(color: Colors.grey),
          ),
        );
    }
  }

  Widget _buildCardsAjuda() {
    final List<Map<String, dynamic>> cards = [
      {
        'titulo': 'Grande Arquiteto',
        'descricao': 'Dicionário de dados, relações e estruturas do sistema',
        'icone': Icons.architecture,
        'cor': const Color(0xFF0D47A1),
        'tipo': 'grande_arquiteto',
      },
      // Outros cards de ajuda podem ser adicionados aqui futuramente
    ];

    return GridView.count(
      crossAxisCount: 7,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1,
      children: cards.map((card) => _buildCardItem(card)).toList(),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => onCardSelecionado(card['tipo']),
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
                card['icone'] as IconData,
                color: card['cor'] as Color,
                size: 50,
              ),
              const SizedBox(height: 8),
              Text(
                card['titulo'],
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
}