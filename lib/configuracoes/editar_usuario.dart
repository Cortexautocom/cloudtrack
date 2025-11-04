import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditarUsuarioPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Map<String, dynamic> usuario; // ✅ Usuário selecionado

  const EditarUsuarioPage({
    super.key,
    required this.onVoltar,
    required this.usuario,
  });

  @override
  State<EditarUsuarioPage> createState() => _EditarUsuarioPageState();
}

class _EditarUsuarioPageState extends State<EditarUsuarioPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final celularController = TextEditingController();
  final funcaoController = TextEditingController();
  String? filialSelecionada;
  String? nivelSelecionado;
  String? statusAtual;

  List<Map<String, dynamic>> _filiais = [];
  bool _salvando = false;
  bool _editado = false;

  @override
  void initState() {
    super.initState();
    _carregarFiliais();
    _preencherCampos();
  }

  void _preencherCampos() {
    final u = widget.usuario;
    nomeController.text = u['nome'] ?? '';
    emailController.text = u['email'] ?? '';
    celularController.text = u['celular'] ?? '';
    funcaoController.text = u['funcao'] ?? '';
    filialSelecionada = u['id_filial']?.toString();
    nivelSelecionado = u['nivel']?.toString();
    statusAtual = u['status'] ?? 'ativo';

    // Detecta alterações
    nomeController.addListener(_verificarAlteracoes);
    emailController.addListener(_verificarAlteracoes);
    celularController.addListener(_verificarAlteracoes);
    funcaoController.addListener(_verificarAlteracoes);
  }

  Future<void> _carregarFiliais() async {
    try {
      final res = await supabase.from('filiais').select('id, nome');
      setState(() {
        _filiais = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar filiais: $e');
    }
  }

  void _verificarAlteracoes() {
    final u = widget.usuario;
    final alterado = nomeController.text != (u['nome'] ?? '') ||
        emailController.text != (u['email'] ?? '') ||
        celularController.text != (u['celular'] ?? '') ||
        funcaoController.text != (u['funcao'] ?? '') ||
        filialSelecionada != (u['id_filial']?.toString()) ||
        nivelSelecionado != (u['nivel']?.toString());
    setState(() => _editado = alterado);
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      await supabase.from('usuarios').update({
        'nome': nomeController.text.trim(),
        'email': emailController.text.trim(),
        'celular': celularController.text.trim(),
        'funcao': funcaoController.text.trim(),
        'id_filial': filialSelecionada,
        'nivel': int.tryParse(nivelSelecionado ?? '1'),
      }).eq('id', widget.usuario['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alterações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onVoltar();
      }
    } catch (e) {
      debugPrint('❌ Erro ao salvar alterações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _suspenderUsuario() async {
    try {
      await supabase
          .from('usuarios')
          .update({'status': 'suspenso'}).eq('id', widget.usuario['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Usuário suspenso com sucesso.'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onVoltar();
      }
    } catch (e) {
      debugPrint('❌ Erro ao suspender usuário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao suspender: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(30),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // 🔹 Cabeçalho
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
                  onPressed: widget.onVoltar,
                ),
                const Text(
                  "Editar Usuário",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 20),

            // 🔹 Campos
            _campo("Nome completo", nomeController),
            _campo("E-mail", emailController, tipo: TextInputType.emailAddress),
            _campo("Celular", celularController, tipo: TextInputType.phone),
            _campo("Função / Cargo", funcaoController),

            // 🔹 Filial
            DropdownButtonFormField<String>(
              value: filialSelecionada,
              decoration: const InputDecoration(
                labelText: "Filial",
                border: OutlineInputBorder(),
              ),
              items: _filiais
                  .map((f) => DropdownMenuItem(
                        value: f['id'].toString(),
                        child: Text(f['nome']),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  filialSelecionada = v;
                  _verificarAlteracoes();
                });
              },
            ),
            const SizedBox(height: 16),

            // 🔹 Nível
            DropdownButtonFormField<String>(
              value: nivelSelecionado,
              decoration: const InputDecoration(
                labelText: "Nível de acesso",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "1", child: Text("Usuário comum")),
                DropdownMenuItem(value: "2", child: Text("Gerência")),
                DropdownMenuItem(value: "3", child: Text("Administrador")),
              ],
              onChanged: (v) {
                setState(() {
                  nivelSelecionado = v;
                  _verificarAlteracoes();
                });
              },
            ),
            const SizedBox(height: 20),

            // 🔹 Status
            TextFormField(
              enabled: false,
              decoration: InputDecoration(
                labelText: "Status atual: $statusAtual",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            // 🔹 Botão "Salvar e sair"
            Center(
              child: ElevatedButton.icon(
                onPressed: (_editado && !_salvando) ? _salvarAlteracoes : null,
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text(_salvando ? "Salvando..." : "Salvar e sair"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 🔹 Botão "Suspender usuário"
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: _suspenderUsuario,
                icon: const Icon(Icons.block, color: Colors.white),
                label: const Text("Suspender usuário"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Campo genérico
  Widget _campo(String label, TextEditingController controller,
      {TextInputType tipo = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
