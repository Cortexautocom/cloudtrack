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
  final PageController _pageController = PageController();
  
  // Lista de FAQs
  final List<FAQItem> _faqs = [
    FAQItem(
      pergunta: 'Como posso redefinir minha senha?',
      resposta: 'Acesse "Meu Perfil" > "Segurança" > "Alterar Senha". Você receberá um e-mail com as instruções.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Onde vejo meu histórico de atividades?',
      resposta: 'No menu principal, vá para "Relatórios" > "Histórico de Atividades". Você pode filtrar por data e tipo de atividade.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Como faço para exportar meus dados?',
      resposta: 'Em "Configurações" > "Privacidade", você encontrará a opção para exportar todos os seus dados em formato CSV ou PDF.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'O sistema está disponível 24/7?',
      resposta: 'Sim! Nossa plataforma está disponível 24 horas por dia, 7 dias por semana. Apenas manutenções agendadas podem causar interrupções breves.',
      isExpanded: false,
    ),
    FAQItem(
      pergunta: 'Quais navegadores são compatíveis?',
      resposta: 'Chrome 90+, Firefox 88+, Safari 14+, Edge 90+. Recomendamos sempre usar a versão mais recente.',
      isExpanded: false,
    ),
  ];

  @override
  void dispose() {
    _mensagemController.dispose();
    _emailController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse('https://wa.me/5511999999999?text=Olá! Preciso de ajuda com o sistema.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Não foi possível abrir o WhatsApp';
    }
  }

  Future<void> _launchPhone() async {
    final url = Uri.parse('tel:+5511999999999');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Não foi possível fazer a ligação';
    }
  }

  Future<void> _launchEmail() async {
    final url = Uri.parse(
      'mailto:suporte@powertankapp.com?subject=Suporte Sistema&body=Preciso de ajuda com:',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Não foi possível abrir o e-mail';
    }
  }

  void _enviarMensagem() {
    if (_formKey.currentState!.validate()) {
      // Simulação de envio
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mensagem Enviada'),
          content: const Text('Sua mensagem foi enviada com sucesso! Entraremos em contato em até 24 horas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Central de Suporte',
          style: TextStyle(
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header com título e descrição
                _buildHeader(),
                const SizedBox(height: 40),

                // Cards de contato rápido
                _buildCardsContato(),
                const SizedBox(height: 40),

                // Seção de FAQs com abas
                _buildFAQsSection(),
                const SizedBox(height: 40),

                // Formulário e informações lado a lado
                _buildContentRow(),
                const SizedBox(height: 40),

                // Links úteis
                _buildLinksUteis(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent,
              size: 40,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Como podemos ajudar você?',
            style: TextStyle(
              fontSize: 28,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Encontre respostas rápidas em nossas FAQs ou entre em contato diretamente com nossa equipe especializada.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCardsContato() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contato Rápido',
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha a forma mais conveniente para falar conosco:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildContatoCard(
                icon: Icons.phone,
                title: 'Telefone',
                subtitle: '(11) 99999-9999',
                color: const Color(0xFF34A853),
                onTap: _launchPhone,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildContatoCard(
                icon: FontAwesomeIcons.whatsapp,
                title: 'WhatsApp',
                subtitle: 'Chat imediato',
                color: const Color(0xFF25D366),
                onTap: _launchWhatsApp,
                isFontAwesome: true,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildContatoCard(
                icon: Icons.email,
                title: 'E-mail',
                subtitle: 'suporte@powertankapp.com',
                color: const Color(0xFFEA4335),
                onTap: _launchEmail,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContatoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isFontAwesome = false,
  }) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isFontAwesome
                      ? FaIcon(
                          icon,
                          size: 28,
                          color: color,
                        )
                      : Icon(
                          icon,
                          size: 28,
                          color: color,
                        ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Clique para contatar',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Perguntas Frequentes',
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_faqs.length} FAQs',
                style: const TextStyle(
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Encontre respostas para as dúvidas mais comuns:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: _faqs.map((faq) => _buildFAQItem(faq)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQItem(FAQItem faq) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          title: Text(
            faq.pergunta,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0D47A1),
            ),
          ),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              size: 18,
              color: Color(0xFF0D47A1),
            ),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(70, 0, 20, 20),
          initiallyExpanded: faq.isExpanded,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.resposta,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildFormularioContato(),
        ),
        const SizedBox(width: 30),
        Expanded(
          flex: 1,
          child: _buildInfoSidebar(),
        ),
      ],
    );
  }

  Widget _buildFormularioContato() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Envie sua dúvida',
            style: TextStyle(
              fontSize: 20,
              color: Color(0xFF0D47A1),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preencha o formulário abaixo e nossa equipe entrará em contato:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 25),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Seu e-mail',
                    prefixIcon: const Icon(Icons.email, color: Color(0xFF0D47A1)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1)),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira seu e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'Por favor, insira um e-mail válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _mensagemController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Sua mensagem',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.message, color: Color(0xFF0D47A1)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1)),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    hintText: 'Descreva sua dúvida ou problema...',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira sua mensagem';
                    }
                    if (value.length < 10) {
                      return 'Por favor, forneça mais detalhes';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _enviarMensagem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Enviar Mensagem',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSidebar() {
    return Column(
      children: [
        // Horário de atendimento
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time,
                      size: 20,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Horário de Atendimento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildInfoItem(
                icon: Icons.calendar_today,
                text: 'Segunda a Sexta: 08:00 às 18:00',
              ),
              const SizedBox(height: 8),
              _buildInfoItem(
                icon: Icons.calendar_today,
                text: 'Sábado: 09:00 às 13:00',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 16,
                      color: const Color(0xFF25D366),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WhatsApp 24h para emergências',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Estatísticas
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nosso Suporte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 15),
              _buildStatItem(
                value: '24h',
                label: 'Tempo médio de resposta',
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                value: '98%',
                label: 'Satisfação dos clientes',
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                value: '15 min',
                label: 'Resolução média',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLinksUteis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recursos Adicionais',
          style: TextStyle(
            fontSize: 22,
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildResourceCard(
              icon: Icons.book,
              title: 'Manual do Usuário',
              description: 'Guia completo do sistema',
            ),
            _buildResourceCard(
              icon: Icons.video_library,
              title: 'Tutoriais em Vídeo',
              description: 'Passo a passo em vídeo',
            ),
            _buildResourceCard(
              icon: Icons.update,
              title: 'Atualizações',
              description: 'Novidades do sistema',
            ),
            _buildResourceCard(
              icon: Icons.security,
              title: 'Privacidade',
              description: 'Políticas de segurança',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResourceCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
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