import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../login_page.dart';
import 'cacl.dart';

class FormCalcPage extends StatefulWidget {
  final VoidCallback? onVoltar;

  const FormCalcPage({
    super.key,
    this.onVoltar,
  });

  @override
  State<FormCalcPage> createState() => _FormCalcPageState();
}

class _FormCalcPageState extends State<FormCalcPage> {
  final baseController = TextEditingController();
  final tanqueController = TextEditingController();
  final dataController = TextEditingController();
  final horaController = TextEditingController();
  final responsavelController = TextEditingController();

  String? produtoSelecionado;
  List<String> listaProdutos = [];

  bool carregandoProdutos = true;
  bool carregandoBase = true;

  final corCinza = const Color.fromARGB(255, 214, 214, 214);

  @override
  void initState() {
    super.initState();
    _carregarBaseDoUsuario();
    _carregarProdutos();
    _preencherDataHora();
  }

  void _preencherDataHora() {
    final agora = DateTime.now();

    dataController.text =
        "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}";

    horaController.text =
        "${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _carregarBaseDoUsuario() async {
    final supabase = Supabase.instance.client;

    try {
      final usuario = UsuarioAtual.instance;
      if (usuario == null || usuario.filialId == null) {
        setState(() => carregandoBase = false);
        return;
      }

      final resposta = await supabase
          .from('filiais')
          .select('nome')
          .eq('id', usuario.filialId!)
          .maybeSingle();

      if (resposta != null && resposta['nome'] != null) {
        baseController.text = resposta['nome'];
      }
    } catch (e) {
      debugPrint("Erro ao carregar base: $e");
    }

    setState(() => carregandoBase = false);
  }

  Future<void> _carregarProdutos() async {
    final supabase = Supabase.instance.client;

    try {
      final resposta = await supabase
          .from('produtos')
          .select('produto')
          .order('produto', ascending: true);

      listaProdutos =
          List<String>.from(resposta.map((p) => p['produto'].toString()));

      if (listaProdutos.isNotEmpty) {
        produtoSelecionado = listaProdutos.first;
      }
    } catch (e) {
      debugPrint("Erro ao carregar produtos: $e");
    }

    setState(() => carregandoProdutos = false);
  }

  void _abrirCalcPageComDados(Map<String, dynamic> dados) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CalcPage(dadosFormulario: dados),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const SizedBox(width: 5),
                const Text(
                  "Gerar Certificado de Arqueação (CALC)",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                _campoBase(),
                const SizedBox(width: 20),
                _campoProduto(),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                _campo("Tanque nº", tanqueController),
                const SizedBox(width: 20),
                _campoSomenteLeitura("Data", dataController),
                const SizedBox(width: 20),
                _campoSomenteLeitura("Hora", horaController),
              ],
            ),

            const SizedBox(height: 20),

            _campo("Responsável pela medição", responsavelController),

            const SizedBox(height: 40),

            SizedBox(
              width: 200,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  final dados = {
                    "base": baseController.text,
                    "produto": produtoSelecionado ?? "",
                    "tanque": tanqueController.text,
                    "data": dataController.text,
                    "hora": horaController.text,
                    "responsavel": responsavelController.text,
                  };
                  
                  _abrirCalcPageComDados(dados);
                },
                child: const Text(
                  "Abrir Certificado",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoBase() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Base",
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: baseController,
            enabled: false,
            decoration: InputDecoration(
              filled: true,
              fillColor: corCinza,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoProduto() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Produto",
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 6),

          carregandoProdutos
              ? Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: corCinza,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: produtoSelecionado,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: listaProdutos.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => produtoSelecionado = value);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _campo(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoSomenteLeitura(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: false,
            decoration: InputDecoration(
              filled: true,
              fillColor: corCinza,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}