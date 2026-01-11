import 'package:flutter/material.dart';

class TransferenciasPage extends StatefulWidget {
  final VoidCallback onVoltar;

  const TransferenciasPage({super.key, required this.onVoltar});

  @override
  State<TransferenciasPage> createState() => _TransferenciasPageState();
}

class _TransferenciasPageState extends State<TransferenciasPage> {
  DateTime data = DateTime.now();

  String? motorista;
  String? produto;
  String? transportadora;
  String? cavalo;
  String? reboque1;
  String? reboque2;
  String? origem;
  String? destino;

  final TextEditingController qtdController = TextEditingController();

  final List<Map<String, dynamic>> transferencias = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 10),
        _cardLancamento(),
        const SizedBox(height: 20),
        Expanded(child: _tabelaLancadas()),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
          onPressed: widget.onVoltar,
        ),
        const SizedBox(width: 10),
        const Text(
          'Transferências entre filiais',
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _cardLancamento() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: const [
              Icon(Icons.swap_horiz, color: Color(0xFF2E7D32)),
              SizedBox(width: 10),
              Text(
                'Nova transferência',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ]),
            const Divider(),
            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                _campoData(),
                _dropdown('Motorista', ['João', 'Pedro', 'Carlos'], (v) => motorista = v),
                _dropdown('Produto', ['Diesel S10', 'Gasolina', 'Etanol'], (v) => produto = v),
                _campoQtd(),
                _dropdown('Transportadora', ['Petroserra', 'Shell', 'Raízen'], (v) => transportadora = v),
                _dropdown('Cavalo', ['ABC-1234', 'DEF-5678'], (v) => cavalo = v),
                _dropdown('Reboque 1', ['R1-001', 'R1-002'], (v) => reboque1 = v),
                _dropdown('Reboque 2', ['R2-001', 'R2-002'], (v) => reboque2 = v),
                _dropdown('Origem', ['Base SP', 'Base RJ'], (v) => origem = v),
                _dropdown('Destino', ['Base MG', 'Base BA'], (v) => destino = v),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Registrar transferência'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                ),
                onPressed: _registrar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoData() {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: data,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (d != null) setState(() => data = d);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Data'),
          child: Text('${data.day}/${data.month}/${data.year}'),
        ),
      ),
    );
  }

  Widget _campoQtd() {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: qtdController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Qtd.'),
      ),
    );
  }

  Widget _dropdown(String label, List<String> itens, Function(String?) onChanged) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: itens
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _registrar() {
    if (produto == null || origem == null || destino == null || qtdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos obrigatórios')),
      );
      return;
    }

    setState(() {
      transferencias.add({
        'data': data,
        'motorista': motorista,
        'produto': produto,
        'qtd': qtdController.text,
        'transportadora': transportadora,
        'origem': origem,
        'destino': destino,
      });

      qtdController.clear();
    });
  }

  Widget _tabelaLancadas() {
    if (transferencias.isEmpty) {
      return const Center(child: Text('Nenhuma transferência registrada'));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Produto')),
            DataColumn(label: Text('Qtd')),
            DataColumn(label: Text('Origem')),
            DataColumn(label: Text('Destino')),
            DataColumn(label: Text('Motorista')),
          ],
          rows: transferencias.map((t) {
            return DataRow(cells: [
              DataCell(Text('${t['data'].day}/${t['data'].month}')),
              DataCell(Text(t['produto'] ?? '')),
              DataCell(Text(t['qtd'] ?? '')),
              DataCell(Text(t['origem'] ?? '')),
              DataCell(Text(t['destino'] ?? '')),
              DataCell(Text(t['motorista'] ?? '')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
