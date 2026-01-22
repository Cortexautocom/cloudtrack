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
  final TextEditingController _placaController = TextEditingController();

  bool _mostrarSugestoes = false;
  bool _carregandoPlacas = false;
  List<Map<String, dynamic>> _placasEncontradas = [];

  int _qtdTanques = 0;
  List<String> _capacidadesTanques = [];

  final List<TextEditingController> _clientePorTanque = [];
  final List<TextEditingController> _formaPagamentoPorTanque = [];
  final List<String?> _produtoPorTanque = [];

  List<Map<String, dynamic>> _produtos = [];
  bool _carregandoProdutos = false;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  Future<void> _carregarProdutos() async {
    setState(() => _carregandoProdutos = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('produtos')
          .select('id, nome')
          .order('nome');

      setState(() {
        _produtos = List<Map<String, dynamic>>.from(response);
      });
    } catch (_) {
      setState(() => _produtos = []);
    } finally {
      setState(() => _carregandoProdutos = false);
    }
  }

  Future<void> _buscarPlacas(String texto) async {
    if (texto.length < 3) {
      setState(() {
        _placasEncontradas.clear();
        _mostrarSugestoes = false;
      });
      return;
    }

    setState(() {
      _carregandoPlacas = true;
      _mostrarSugestoes = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('view_placas_tanques')
          .select('placas, tanques')
          .ilike('placas', '${texto.replaceAll('-', '').toUpperCase()}%')
          .order('placas')
          .limit(10);

      setState(() {
        _placasEncontradas = List<Map<String, dynamic>>.from(response);
      });
    } catch (_) {
      setState(() => _placasEncontradas.clear());
    } finally {
      setState(() => _carregandoPlacas = false);
    }
  }

  void _selecionarPlaca(Map<String, dynamic> item) {
    _placaController.text = item['placas'];
    _mostrarSugestoes = false;

    final List<dynamic> tanques = item['tanques'] ?? [];

    setState(() {
      _qtdTanques = tanques.length;
      _capacidadesTanques = tanques.map((e) => e.toString()).toList();

      _clientePorTanque.clear();
      _formaPagamentoPorTanque.clear();
      _produtoPorTanque.clear();

      for (int i = 0; i < _qtdTanques; i++) {
        _clientePorTanque.add(TextEditingController());
        _formaPagamentoPorTanque.add(TextEditingController());
        _produtoPorTanque.add(null);
      }
    });
  }

  Widget _buildTanque(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tanque ${index + 1} • ${_capacidadesTanques[index]}.000 L',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _produtoPorTanque[index],
              isExpanded: true,
              items: _produtos.map((p) {
                return DropdownMenuItem<String>(
                  value: p['id'].toString(),
                  child: Text(p['nome']),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _produtoPorTanque[index] = v);
              },
              decoration: InputDecoration(
                labelText: 'Produto',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _clientePorTanque[index],
              decoration: InputDecoration(
                labelText: 'Cliente',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _formaPagamentoPorTanque[index],
              decoration: InputDecoration(
                labelText: 'Forma de pagamento',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _emitirOrdem() {
    widget.onSalvar?.call(true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 800,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Nova Venda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // CONTEÚDO
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Placa do veículo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _placaController,
                      onChanged: _buscarPlacas,
                      decoration: InputDecoration(
                        hintText: 'Digite a placa',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _carregandoPlacas
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.search),
                      ),
                    ),

                    if (_mostrarSugestoes)
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
                          children: _placasEncontradas.map((item) {
                            return ListTile(
                              title: Text(item['placas']),
                              onTap: () => _selecionarPlaca(item),
                            );
                          }).toList(),
                        ),
                      ),

                    if (_qtdTanques > 0) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'Tanques',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_carregandoProdutos)
                        const Center(child: CircularProgressIndicator()),
                      ...List.generate(_qtdTanques, _buildTanque),
                    ],
                  ],
                ),
              ),
            ),

            // FOOTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _emitirOrdem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Emitir ordem',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
    _placaController.dispose();
    for (final c in _clientePorTanque) {
      c.dispose();
    }
    for (final c in _formaPagamentoPorTanque) {
      c.dispose();
    }
    super.dispose();
  }
}
