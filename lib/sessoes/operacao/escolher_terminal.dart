import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EscolherTerminalPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Function(String idTerminal) onSelecionarTerminal;
  final String titulo;
  
  // Adicione parâmetros para personalização
  final Color? corPrimaria;
  final Color? corFundoItem;
  final Color? corHover;

  const EscolherTerminalPage({
    super.key,
    required this.onVoltar,
    required this.onSelecionarTerminal,
    this.titulo = 'Selecionar terminal',
    this.corPrimaria, // ← NOVO
    this.corFundoItem, // ← NOVO
    this.corHover, // ← NOVO
  });

  @override
  State<EscolherTerminalPage> createState() => _EscolherTerminalPageState();
}

class _EscolherTerminalPageState extends State<EscolherTerminalPage> {
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _accent = Color(0xFF1B6A6F);
  static const Color _line = Color(0xFFE6DCCB);
  static const Color _muted = Color(0xFF5A6B7A);

  bool carregando = true;
  List<Map<String, dynamic>> terminais = [];

  // Cor padrão caso não seja fornecida
  Color get _corPrimaria => widget.corPrimaria ?? _accent;
  Color get _corFundoItem => widget.corFundoItem ?? Colors.white;

  @override
  void initState() {
    super.initState();
    _carregarTerminais();
  }

  Future<void> _carregarTerminais() async {
    try {
      final supabase = Supabase.instance.client;

        final response =
          await supabase.from('terminais').select('id, nome, cidade').order('nome');

      setState(() {
        terminais = List<Map<String, dynamic>>.from(response);
        carregando = false;
      });

    } catch (e) {
      setState(() => carregando = false);
      print("Erro ao carregar terminais: $e");
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
                          'Selecione o terminal para continuar',
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
                      '${terminais.length} terminais',
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
                  : terminais.isEmpty
                  ? Center(
                    child: Text(
                      "Nenhum terminal encontrado.",
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: terminais.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final terminal = terminais[index];
                        return _buildTerminalListItem(
                          id: terminal['id'].toString(),
                          nome: terminal['nome'].toString(),
                          cidade: terminal['cidade']?.toString() ?? '',
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTerminalListItem({
    required String id,
    required String nome,
    required String cidade,
  }) {
    return _TerminalCard(
      id: id,
      nome: nome,
      cidade: cidade,
      corPrimaria: _corPrimaria,
      corFundoItem: _corFundoItem,
      onTap: () => widget.onSelecionarTerminal(id),
    );
  }
}

class _TerminalCard extends StatefulWidget {
  final String id;
  final String nome;
  final String cidade;
  final Color corPrimaria;
  final Color corFundoItem;
  final VoidCallback onTap;

  const _TerminalCard({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.corPrimaria,
    required this.corFundoItem,
    required this.onTap,
  });

  @override
  State<_TerminalCard> createState() => _TerminalCardState();
}

class _TerminalCardState extends State<_TerminalCard> {
  static const Color _ink = Color(0xFF0E1C2F);
  static const Color _accent = Color(0xFF1B6A6F);
  static const Color _line = Color(0xFFE6DCCB);
  static const Color _muted = Color(0xFF5A6B7A);

  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Material(
          color: _isHovering ? const Color(0xFFF5F5F5) : widget.corFundoItem,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _line, width: 1.2),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.corPrimaria.withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.business,
                      color: widget.corPrimaria,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.cidade,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.corPrimaria.withOpacity(0.6),
                        width: 1.2,
                      ),
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
          ),
        ),
      ),
    );
  }
}