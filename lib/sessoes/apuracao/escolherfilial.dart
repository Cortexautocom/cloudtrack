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
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _accent = Color(0xFF1B6A6F);
  static const Color _line = Color(0xFFE6DCCB);
  static const Color _muted = Color(0xFF5A6B7A);

  bool carregando = true;
  List<Map<String, dynamic>> filiais = [];

  // Cor padrão caso não seja fornecida
  Color get _corPrimaria => widget.corPrimaria ?? _accent;
  Color get _corFundoItem => widget.corFundoItem ?? Colors.white;
  Color get _corHover => widget.corHover ?? _accent.withOpacity(0.08);

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
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _line, width: 1.2)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: _ink),
                onPressed: widget.onVoltar,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        color: _ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Selecione a filial para continuar',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _corPrimaria.withOpacity(0.7), width: 1.2),
                ),
                child: Text(
                  '${filiais.length} filiais',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

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
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filiais.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
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
    return InkWell(
      onTap: () => widget.onSelecionarFilial(id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: _corFundoItem,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _corPrimaria.withOpacity(0.4), width: 1.2),
              ),
              child: Icon(
                Icons.business,
                color: _corPrimaria,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cidade,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _corPrimaria.withOpacity(0.6), width: 1.2),
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 16,
                color: _accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}