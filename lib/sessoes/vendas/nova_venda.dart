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
    } catch (e) {
      setState(() {
        _placasEncontradas.clear();
      });
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tanque ${index + 1} • ${_capacidadesTanques[index]}.000 L',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _produtoPorTanque[index],
              items: const [
                DropdownMenuItem(value: null, child: Text('Produto')),
              ],
              onChanged: (v) {
                setState(() => _produtoPorTanque[index] = v);
              },
              decoration: const InputDecoration(
                labelText: 'Produto',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _clientePorTanque[index],
              decoration: const InputDecoration(
                labelText: 'Cliente',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _formaPagamentoPorTanque[index],
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
                border: OutlineInputBorder(),
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
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 800,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Nova Venda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // CONTEÚDO
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _placaController,
                      onChanged: _buscarPlacas,
                      decoration: InputDecoration(
                        labelText: 'Placa do veículo',
                        border: const OutlineInputBorder(),
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
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
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

                    const SizedBox(height: 24),

                    if (_qtdTanques > 0) ...[
                      const Text(
                        'Tanques',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_qtdTanques, _buildTanque),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // AÇÕES
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _emitirOrdem,
                    child: const Text('Emitir ordem'),
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
