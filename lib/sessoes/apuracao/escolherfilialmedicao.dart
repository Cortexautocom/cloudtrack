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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filiais.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final filial = filiais[index];
                        return _buildFilialListItem(
                          id: filial['id'],
                          nome: filial['nome'],
                          cidade: filial['cidade'],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilialListItem({
    required String id,
    required String nome,
    required String cidade,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => widget.onSelecionarFilial(id),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.business,
            color: Color(0xFF0D47A1),
            size: 24,
          ),
        ),
        title: Text(
          nome,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D47A1),
          ),
        ),
        subtitle: Text(
          cidade,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}