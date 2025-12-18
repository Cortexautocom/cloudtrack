import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscolherFilialPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(String idFilial) onSelecionarFilial;
  final String titulo;
  
  // Adicione parâmetros para personalização
  final Color? corPrimaria;
  final Color? corFundoItem;
  final Color? corHover;

  const EscolherFilialPage({
    super.key,
    required this.onVoltar,
    required this.onSelecionarFilial,
    this.titulo = 'Selecionar filial',
    this.corPrimaria, // ← NOVO
    this.corFundoItem, // ← NOVO
    this.corHover, // ← NOVO
  });

  @override
  State<EscolherFilialPage> createState() => _EscolherFilialPageState();
}

class _EscolherFilialPageState extends State<EscolherFilialPage> {
  bool carregando = true;
  List<Map<String, dynamic>> filiais = [];

  // Cor padrão caso não seja fornecida
  Color get _corPrimaria => widget.corPrimaria ?? const Color(0xFF0D47A1);
  Color get _corFundoItem => widget.corFundoItem ?? const Color.fromARGB(255, 246, 255, 241);
  Color get _corHover => widget.corHover ?? const Color(0xFFE3F2FD);

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
              icon: Icon(Icons.arrow_back, color: _corPrimaria),
              onPressed: widget.onVoltar,
            ),
            const SizedBox(width: 10),
            Text(
              widget.titulo,
              style: TextStyle(
                fontSize: 22,
                color: _corPrimaria,
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
              ? Center(
                  child: CircularProgressIndicator(
                    color: _corPrimaria,
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
                          id: filial['id'].toString(),
                          nome: filial['nome'].toString(),
                          cidade: filial['cidade'].toString(),
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
      color: _corFundoItem,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () => widget.onSelecionarFilial(id),
        hoverColor: _corHover.withOpacity(0.5), // ← HOVER PERSONALIZADO
        splashColor: _corHover, // ← COR DO CLIQUE
        
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _corPrimaria.withOpacity(0.1), // ← USA COR PRIMÁRIA
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.business,
            color: _corPrimaria, // ← USA COR PRIMÁRIA
            size: 24,
          ),
        ),
        
        title: Text(
          nome,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _corPrimaria, // ← USA COR PRIMÁRIA
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