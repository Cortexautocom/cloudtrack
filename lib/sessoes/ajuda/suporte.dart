import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SuportePage extends StatefulWidget {
  const SuportePage({super.key});

  @override
  State<SuportePage> createState() => _SuportePageState();
}

class _SuportePageState extends State<SuportePage> {
  final TextEditingController _mensagemController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<FAQItem> _faqs = [
    FAQItem(
      pergunta: 'Como redefinir minha senha?',
      resposta: 'Vá em Meu Perfil > Segurança > Alterar Senha.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Onde vejo meu histórico?',
      resposta: 'Menu > Relatórios > Histórico de Atividades.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Como exportar dados?',
      resposta: 'Configurações > Privacidade > Exportar dados.',
      isExpanded: false,
    ),
  ];

  @override
  void dispose() {
    _mensagemController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse('https://wa.me/5511999999999?text=Olá! Preciso de ajuda com o sistema.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final url = Uri.parse('mailto:suporte@powertankapp.com?subject=Suporte PowerTank');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _enviarMensagem() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enviado'),
          content: const Text('Mensagem enviada com sucesso.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      _mensagemController.clear();
      _emailController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Suporte', style: TextStyle(color: Color(0xFF0D47A1))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSlim(),
                const SizedBox(height: 16),

                _buildContatoSlim(),
                const SizedBox(height: 16),

                _buildFAQsSlim(),
                const SizedBox(height: 16),

                _buildFormularioSlim(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSlim() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: const Row(
        children: [
          Icon(Icons.support_agent, size: 28, color: Color(0xFF0D47A1)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Central de Suporte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContatoSlim() {
    return Row(
      children: [
        Expanded(
          child: _buildContatoCardSlim(
            icon: FontAwesomeIcons.whatsapp,
            title: 'WhatsApp',
            subtitle: 'Atendimento rápido',
            color: const Color(0xFF25D366),
            onTap: _launchWhatsApp,
            isFa: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildContatoCardSlim(
            icon: Icons.email,
            title: 'E-mail',
            subtitle: 'suporte@powertankapp.com',
            color: const Color(0xFFEA4335),
            onTap: _launchEmail,
          ),
        ),
      ],
    );
  }

  Widget _buildContatoCardSlim({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isFa = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: _box(),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(
                child: isFa ? FaIcon(icon, size: 16, color: color) : Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQsSlim() {
    return Container(
      decoration: _box(),
      child: Column(
        children: _faqs.map((faq) {
          return ExpansionTile(
            dense: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            title: Text(
              faq.pergunta,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0D47A1)),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.resposta,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormularioSlim() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Envie sua dúvida',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email, size: 18),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _mensagemController,
              maxLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Mensagem',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message, size: 18),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.length < 5) ? 'Mensagem muito curta' : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _enviarMensagem,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Enviar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }
}

class FAQItem {
  final String pergunta;
  final String resposta;
  bool isExpanded;

  FAQItem({
    required this.pergunta,
    required this.resposta,
    required this.isExpanded,
  });
}
