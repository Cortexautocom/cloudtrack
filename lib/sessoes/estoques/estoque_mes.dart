import 'package:flutter/material.dart';

class EstoqueMesPage extends StatelessWidget {
  final String filialId;
  final String nomeFilial;

  const EstoqueMesPage({
    super.key,
    required this.filialId,
    required this.nomeFilial,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D47A1),
        title: Text(
          'Estoque mensal – $nomeFilial',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowHeight: 48,
              dataRowHeight: 44,
              columnSpacing: 24,
              headingRowColor: MaterialStateProperty.all(
                Colors.grey.shade100,
              ),
              columns: const [
                DataColumn(label: Text('Dia')),
                DataColumn(label: Text('Entrada (Amb.)'), numeric: true),
                DataColumn(label: Text('Entrada (20ºC)'), numeric: true),
                DataColumn(label: Text('Saída (Amb.)'), numeric: true),
                DataColumn(label: Text('Saída (20ºC)'), numeric: true),
                DataColumn(label: Text('Saldo (Amb.)'), numeric: true),
                DataColumn(label: Text('Saldo (20ºC)'), numeric: true),
              ],
              rows: _linhasMock(),
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 MOCK – remover quando integrar com Supabase
  static List<DataRow> _linhasMock() {
    return [
      _linha(
        dia: '01/12/2025',
        entAmb: 10000,
        ent20: 9800,
        saiAmb: 4500,
        sai20: 4400,
        saldoAmb: 5500,
        saldo20: 5400,
      ),
      _linha(
        dia: '02/12/2025',
        entAmb: 8000,
        ent20: 7900,
        saiAmb: 3000,
        sai20: 2950,
        saldoAmb: 10500,
        saldo20: 10350,
      ),
    ];
  }

  static DataRow _linha({
    required String dia,
    required num entAmb,
    required num ent20,
    required num saiAmb,
    required num sai20,
    required num saldoAmb,
    required num saldo20,
  }) {
    return DataRow(
      cells: [
        DataCell(Text(dia)),
        DataCell(_num(entAmb)),
        DataCell(_num(ent20)),
        DataCell(_num(saiAmb)),
        DataCell(_num(sai20)),
        DataCell(_num(saldoAmb)),
        DataCell(_num(saldo20)),
      ],
    );
  }

  static Widget _num(num valor) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        valor.toStringAsFixed(0),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
