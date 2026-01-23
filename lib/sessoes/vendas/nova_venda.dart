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

      placa.placasEncontradas = List<Map<String, dynamic>>.from(response);
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // TÍTULO DO TANQUE (centralizado verticalmente)
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tanque • ${tanque.capacidade}.000 L',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // PRODUTO (200px)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: tanque.produtoId,
              isExpanded: true,
              items: _produtos
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text(
                        p['nome'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => tanque.produtoId = v,
              decoration: _inputDecoration('Produto'),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // CLIENTE (250px)
          SizedBox(
            width: 250,
            child: TextFormField(
              controller: tanque.clienteController,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration('Cliente'),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // FORMA DE PAGAMENTO (200px)
          SizedBox(
            width: 200,
            child: TextFormField(
              controller: tanque.pagamentoController,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration('Forma de pagamento'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaca(_PlacaVenda placa, {bool primeira = false}) {
    final isVermelho = primeira; // Primeira placa sempre vermelha
    final index = _placasVenda.indexOf(placa) + 1;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LINHA DA PLACA + "+"
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CAMPO DA PLACA
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Placa $index',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: placa.controller,
                      onChanged: (v) => _buscarPlacas(placa, v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isVermelho ? Colors.red : Colors.grey.shade400,
                            width: isVermelho ? 2.0 : 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isVermelho ? Colors.red : Colors.grey.shade400,
                            width: isVermelho ? 2.0 : 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: isVermelho ? Colors.red : Colors.blue,
                            width: isVermelho ? 2.5 : 1.5,
                          ),
                        ),
                        suffixIcon: placa.carregandoPlacas
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.search, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (primeira) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    tooltip: 'Adicionar outra placa',
                    icon: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    onPressed: _adicionarPlaca,
                  ),
                ),
              ],
            ],
          ),

          if (placa.mostrarSugestoes)
            Container(
              margin: const EdgeInsets.only(top: 4, left: 0),
              width: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: placa.placasEncontradas.map((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(
                      item['placas'],
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _selecionarPlaca(placa, item),
                  );
                }).toList(),
              ),
            ),

          if (placa.tanques.isNotEmpty) ...[
            const SizedBox(height: 12),
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
      labelStyle: const TextStyle(fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.blue, width: 1.2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 900,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Nova Venda',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // CONTEÚDO
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BOTÃO CANCELAR (150px)
                  SizedBox(
                    width: 150,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // BOTÃO EMITIR ORDEM (150px)
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _emitirOrdem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        'Emitir ordem',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
  final TextEditingController clienteController = TextEditingController();
  final TextEditingController pagamentoController = TextEditingController();

  _TanqueVenda({required this.capacidade});

  void dispose() {
    clienteController.dispose();
    pagamentoController.dispose();
  }
}