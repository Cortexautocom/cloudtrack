import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscolherFilialMedicaoPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(String idFilial) onSelecionarFilial;

  const EscolherFilialMedicaoPage({
    super.key,
    required this.onVoltar,
    required this.onSelecionarFilial,
  });

  @override
  State<EscolherFilialMedicaoPage> createState() =>
      _EscolherFilialMedicaoPageState();
}

class _EscolherFilialMedicaoPageState extends State<EscolherFilialMedicaoPage> {
  bool carregando = true;
  List<Map<String, dynamic>> filiais = [];

  @override
  void initState() {
    super.initState();
    _carregarFiliais();
  }

  Future<void> _carregarFiliais() async {
    try {
      final supabase = Supabase.instance.client;

      final response =
          await supabase.from('filiais').select('id, nome, cidade').order('nome');

      setState(() {
        filiais = List<Map<String, dynamic>>.from(response);
        carregando = false;
      });

    } catch (e) {
      setState(() => carregando = false);
      print("Erro ao carregar filiais: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            const Text(
              'Selecionar filial para medição',
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Divider(),

        const SizedBox(height: 20),

        // Conteúdo
        Expanded(
          child: carregando
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0D47A1),
                  ),
                )
              : filiais.isEmpty
                  ? Center(
                      child: Text(
                        "Nenhuma filial encontrada.",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.8,
                      children: filiais.map((filial) {
                        return _buildFilialCard(
                          id: filial['id'],
                          nome: filial['nome'],
                          cidade: filial['cidade'],
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilialCard({
    required String id,
    required String nome,
    required String cidade,
  }) {
    return Material(
      elevation: 3,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => widget.onSelecionarFilial(id),
        hoverColor: const Color(0xFFE8F5E9),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.business,
                size: 40,
                color: Color(0xFF0D47A1),
              ),
              const SizedBox(height: 10),
              Text(
                nome,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cidade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
