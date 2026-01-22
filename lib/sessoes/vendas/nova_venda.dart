import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NovaVendaDialog extends StatefulWidget {
  final Function(bool sucesso)? onSalvar;
  final String? filialId;
  final String? filialNome;

  const NovaVendaDialog({
    super.key,
    this.onSalvar,
    this.filialId,
    this.filialNome,
  });

  @override
  State<NovaVendaDialog> createState() => _NovaVendaDialogState();
}

class _NovaVendaDialogState extends State<NovaVendaDialog> {
  // =======================
  // MODELOS INTERNOS
  // =======================
  final List<_PlacaVenda> _placasVenda = [];

  List<Map<String, dynamic>> _produtos = [];
  bool _carregandoProdutos = false;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    _adicionarPlaca(); // primeira placa já nasce aberta
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregandoProdutos = true);
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase.from('produtos').select('id, nome').order('nome');
      _produtos = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      _produtos = [];
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  // =======================
  // PLACAS
  // =======================
  void _adicionarPlaca() {
    setState(() {
      _placasVenda.add(_PlacaVenda());
    });
  }

  Future<void> _buscarPlacas(_PlacaVenda placa, String texto) async {
    if (texto.length < 3) {
      placa.placasEncontradas.clear();
      placa.mostrarSugestoes = false;
      setState(() {});
      return;
    }

    placa.carregandoPlacas = true;
    placa.mostrarSugestoes = true;
    setState(() {});

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('view_placas_tanques')
          .select('placas, tanques')
          .ilike('placas', '${texto.replaceAll('-', '').toUpperCase()}%')
          .order('placas')
          .limit(10);

      placa.placasEncontradas =
          List<Map<String, dynamic>>.from(response);
    } catch (_) {
      placa.placasEncontradas.clear();
    } finally {
      placa.carregandoPlacas = false;
      setState(() {});
    }
  }

  void _selecionarPlaca(_PlacaVenda placa, Map<String, dynamic> item) {
    placa.controller.text = item['placas'];
    placa.mostrarSugestoes = false;

    final List<dynamic> tanques = item['tanques'] ?? [];

    placa.tanques.clear();
    for (final t in tanques) {
      placa.tanques.add(_TanqueVenda(capacidade: t.toString()));
    }

    setState(() {});
  }

  // =======================
  // UI
  // =======================
  Widget _buildTanqueLinha(_TanqueVenda tanque) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tanque • ${tanque.capacidade}.000 L',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // PRODUTO
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: tanque.produtoId,
                  isExpanded: true,
                  items: _produtos
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['nome']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => tanque.produtoId = v,
                  decoration: _inputDecoration('Produto'),
                ),
              ),
              const SizedBox(width: 8),
              // CLIENTE
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: tanque.clienteController,
                  decoration: _inputDecoration('Cliente'),
                ),
              ),
              const SizedBox(width: 8),
              // PAGAMENTO
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: tanque.pagamentoController,
                  decoration: _inputDecoration('Forma de pagamento'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaca(_PlacaVenda placa, {bool primeira = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LINHA DA PLACA + "+"
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: placa.controller,
                  onChanged: (v) => _buscarPlacas(placa, v),
                  decoration: InputDecoration(
                    labelText: 'Placa do veículo',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: placa.carregandoPlacas
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ),
              if (primeira) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Adicionar outra placa',
                  icon: const Icon(Icons.add_circle,
                      color: Color(0xFF0D47A1), size: 32),
                  onPressed: _adicionarPlaca,
                ),
              ],
            ],
          ),

          if (placa.mostrarSugestoes)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: placa.placasEncontradas.map((item) {
                  return ListTile(
                    title: Text(item['placas']),
                    onTap: () => _selecionarPlaca(placa, item),
                  );
                }).toList(),
              ),
            ),

          if (placa.tanques.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (_carregandoProdutos)
              const Center(child: CircularProgressIndicator()),
            ...placa.tanques.map(_buildTanqueLinha),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      isDense: true,
    );
  }

  void _emitirOrdem() {
    widget.onSalvar?.call(true);
    Navigator.of(context).pop(true);
  }

  // =======================
  // BUILD
  // =======================
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 900,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Nova Venda',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white),
                    onPressed: () =>
                        Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // CONTEÚDO
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: List.generate(
                    _placasVenda.length,
                    (i) => _buildPlaca(
                      _placasVenda[i],
                      primeira: i == 0,
                    ),
                  ),
                ),
              ),
            ),

            // FOOTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
                border:
                    Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _emitirOrdem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0D47A1),
                      ),
                      child: const Text(
                        'Emitir ordem',
                        style: TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final p in _placasVenda) {
      p.dispose();
    }
    super.dispose();
  }
}

// =======================
// CLASSES AUXILIARES
// =======================
class _PlacaVenda {
  final TextEditingController controller = TextEditingController();

  bool mostrarSugestoes = false;
  bool carregandoPlacas = false;
  List<Map<String, dynamic>> placasEncontradas = [];

  final List<_TanqueVenda> tanques = [];

  void dispose() {
    controller.dispose();
    for (final t in tanques) {
      t.dispose();
    }
  }
}

class _TanqueVenda {
  final String capacidade;
  String? produtoId;
  final TextEditingController clienteController =
      TextEditingController();
  final TextEditingController pagamentoController =
      TextEditingController();

  _TanqueVenda({required this.capacidade});

  void dispose() {
    clienteController.dispose();
    pagamentoController.dispose();
  }
}
