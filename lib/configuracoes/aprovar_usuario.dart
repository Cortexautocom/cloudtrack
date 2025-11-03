import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AprovarUsuarioPage extends StatefulWidget {
  final VoidCallback onVoltar;
  final Map<String, dynamic> usuario; // ✅ Recebe o usuário selecionado

  const AprovarUsuarioPage({
    super.key,
    required this.onVoltar,
    required this.usuario,
  });

  @override
  State<AprovarUsuarioPage> createState() => _AprovarUsuarioPageState();
}

class _AprovarUsuarioPageState extends State<AprovarUsuarioPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  String? nivelSelecionado;

  // 🔹 Aprova o usuário recebido
  Future<void> _aprovarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final email = widget.usuario['email'] as String;
      final nome = widget.usuario['nome'] as String;
      final celular = widget.usuario['celular'] as String?;
      final funcao = widget.usuario['funcao'] as String?;
      final filialId = widget.usuario['filial_id']?.toString();

      final int nivel =
          nivelSelecionado == "Gerência e coordenação" ? 2 : 1;

      // 1️⃣ Cria usuário no Supabase Auth e envia e-mail de convite
      await supabase.auth.admin.inviteUserByEmail(email);

      // 2️⃣ Insere na tabela 'usuarios'
      await supabase.from('usuarios').insert({
        'nome': nome,
        'email': email,
        'nivel': nivel,
        'celular': celular,
        'funcao': funcao,
        'id_filial': filialId,
      });

      // 3️⃣ Atualiza o cadastro pendente
      await supabase
          .from('cadastros_pendentes')
          .update({'status': 'aprovado', 'nivel': nivel})
          .eq('email', email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("✅ Usuário aprovado e e-mail de acesso enviado para $email."),
            backgroundColor: Colors.green,
          ),
        );
        widget.onVoltar(); // Volta para a lista
      }
    } catch (e) {
      debugPrint("❌ Erro ao aprovar usuário: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao aprovar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;

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
                  "Aprovar Usuário",
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

            // 🔹 Campos do usuário (somente leitura)
            _campo("Nome completo", u['nome']),
            _campo("E-mail", u['email']),
            _campo("Celular", u['celular']),
            _campo("Função / Cargo", u['funcao']),
            _campo("Filial ID", u['filial_id']),
            const SizedBox(height: 20),

            // 🔹 Selecionar nível
            DropdownButtonFormField<String>(
              value: nivelSelecionado,
              decoration: const InputDecoration(
                labelText: "Nível de acesso",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Operação, usuário comum",
                  child: Text("Operação, usuário comum"),
                ),
                DropdownMenuItem(
                  value: "Gerência e coordenação",
                  child: Text("Gerência e coordenação"),
                ),
              ],
              onChanged: (v) => setState(() => nivelSelecionado = v),
              validator: (v) =>
                  v == null ? "Selecione o nível de acesso" : null,
            ),
            const SizedBox(height: 30),

            // 🔹 Botão de aprovação
            Center(
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _aprovarUsuario,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(
                  _salvando ? "Aprovando..." : "Aprovar usuário",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: valor ?? '',
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
