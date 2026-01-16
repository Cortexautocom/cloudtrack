import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_page.dart';

// ============================================
// PÁGINA PRINCIPAL - O GRANDE ARQUITETO
// ============================================

class GrandeArquitetoPage extends StatefulWidget {
  const GrandeArquitetoPage({super.key});

  @override
  GrandeArquitetoPageState createState() => GrandeArquitetoPageState();
}

class GrandeArquitetoPageState extends State<GrandeArquitetoPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCenteredText(
    String text, {
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.normal,
    double lineHeight = 1.4,
  }) {
    return SizedBox(
      width: 300,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Cinzel',
          fontSize: fontSize,
          color: Colors.white,
          fontWeight: fontWeight,
          height: lineHeight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtém o nome do usuário atual (se disponível)
    final usuarioNome = UsuarioAtual.instance?.nome ?? 'Viajante';
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'O Grande Arquiteto',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCenteredText(
                          'Bem-vindo, $usuarioNome!\nVocê chegou ao Grande Arquiteto.',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(height: 16),
                        _buildCenteredText(
                          'Faça perguntas, peça melhorias, traga problemas.\n'
                          'Escreva do seu jeito, traga ideias mal formadas,\n'
                          'liberte sua mente.\n\n'
                          'O Grande Arquiteto agradece sua contribuição.',
                          fontSize: 20,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 300,
                          child: ElevatedButton(
                            onPressed: () async {
                              final voltarParaAjuda = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EnviarSugestaoPage(),
                                ),
                              );

                              if (voltarParaAjuda == true && context.mounted) {
                                Navigator.pop(context, 'voltar_ajuda');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Libertar minha mente',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // IMAGEM COM DEGRADÊ
                SizedBox(
                  width: 800,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Stack(
                      children: [
                        Image.asset('assets/arquiteto.png'),

                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 80,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF000000),
                                  Color(0x99000000),
                                  Color(0x00000000),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 80,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Color(0xFF000000),
                                  Color(0x99000000),
                                  Color(0x00000000),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF000000),
                                  Color(0x66000000),
                                  Color(0x00000000),
                                  Color(0x00000000),
                                  Color(0x66000000),
                                  Color(0xFF000000),
                                ],
                                stops: [0.0, 0.15, 0.3, 0.7, 0.85, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// PÁGINA DE ENVIO DE SUGESTÕES (COM SUPABASE)
// ============================================

class EnviarSugestaoPage extends StatefulWidget {
  const EnviarSugestaoPage({super.key});

  @override
  EnviarSugestaoPageState createState() => EnviarSugestaoPageState();
}

class EnviarSugestaoPageState extends State<EnviarSugestaoPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  String _charCount = '0/5000';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateCharCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateCharCount() {
    setState(() {
      final text = _textController.text;
      _charCount = '${text.length}/5000';
    });
  }

  Future<void> _showConfirmationDialog() async {
    // Verifica se o widget ainda está montado
    if (!mounted) return;

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escreva sua mensagem antes de enviar.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirmar envio',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Tem certeza que deseja enviar?\n\n'
          'Não gostaria de acrescentar mais nada?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              // Botão esquerdo - "Vou acrescentar"
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Vou acrescentar',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Botão direito - "Sim, enviar" com largura ajustada
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero, // Permite que o botão seja menor
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sim, enviar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == true) {
      await _submitMessage();
    }
  }

  Future<void> _submitMessage() async {
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      
      // Obtém o ID do usuário atual (se disponível)
      final usuarioId = UsuarioAtual.instance?.id;
      final texto = _textController.text.trim();
      
      if (texto.isEmpty) {
        throw Exception('A mensagem não pode estar vazia.');
      }

      // Prepara os dados para inserir na tabela 'ajuda'
      final data = {
        'usuario_id': usuarioId, // Pode ser null se não houver usuário
        'texto': texto, // O texto completo da mensagem
        'data_criacao': DateTime.now().toIso8601String(),
        'status': 'pendente', // Status padrão
      };

      // Insere na tabela 'ajuda' do Supabase
      final response = await supabase
          .from('ajuda')
          .insert(data)
          .select();

      // Verifica se a inserção foi bem-sucedida
      if (response.isEmpty) {
        throw Exception('Falha ao salvar a mensagem no banco de dados.');
      }

      // Aguarda um pouco para mostrar o feedback visual
      await Future.delayed(const Duration(milliseconds: 500));

      // Verifica se o widget ainda está montado antes de usar context
      if (!mounted) {
        setState(() => _isSubmitting = false);
        return;
      }

      // Mensagem salva com sucesso
      await _mostrarDialogoSucesso();
      
    } catch (e) {
      print('Erro ao salvar mensagem: $e');
      
      // Trata erros
      if (mounted) {
        await _mostrarDialogoErro(mensagem: 'Erro ao enviar mensagem: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _mostrarDialogoSucesso() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Mensagem Enviada!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sua mensagem foi salva e será analisada com atenção.\n\n'
                'O Grande Arquiteto agradece sua contribuição!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Fechar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoErro({String mensagem = 'Ocorreu um erro ao enviar sua mensagem. Tente novamente.'}) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Erro no Envio',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTipsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Dicas para sua mensagem',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTipItem('🎯', 'Seja específico nos seus pedidos'),
              _buildTipItem('💡', 'Descreva problemas de forma clara'),
              _buildTipItem('🚀', 'Sugira melhorias práticas'),
              _buildTipItem('🤔', 'Traga dúvidas sobre o sistema'),
              _buildTipItem('❤️', 'Críticas construtivas são bem-vindas'),
              const SizedBox(height: 16),
              const Text(
                'O Grande Arquiteto entende ideias em formação, '
                'então não se preocupe com a perfeição.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Libertar Minha Mente',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showTipsDialog,
            tooltip: 'Dicas para sua mensagem',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;
          
          // Ajusta tamanhos baseado na tela
          final containerWidth = screenWidth > 900 ? 800.0 : screenWidth * 0.9;
          final containerHeight = screenHeight > 700 ? 400.0 : screenHeight * 0.5;
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cabeçalho inspiracional (menor)
                      Container(
                        width: containerWidth,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Compartilhe suas ideias, dúvidas e sugestões',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'O Grande Arquiteto está pronto para ouvir você',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Campo de texto (com altura ajustável)
                      Container(
                        width: containerWidth,
                        height: containerHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Cabeçalho do textarea
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Escreva sua mensagem',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _charCount,
                                    style: TextStyle(
                                      color: _textController.text.length > 5000
                                          ? Colors.red
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Textarea
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  maxLines: null,
                                  maxLength: 5000,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Descreva sua ideia, problema ou sugestão aqui...\n\n'
                                        '• O que você gostaria de melhorar?\n'
                                        '• Que dificuldade está enfrentando?\n'
                                        '• Como imagina que poderia ser diferente?',
                                    hintStyle: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey,
                                      height: 1.4,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    counterText: '',
                                  ),
                                  cursorColor: Colors.black,
                                  keyboardType: TextInputType.multiline,
                                  textCapitalization: TextCapitalization.sentences,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contador de caracteres e botões
                      const SizedBox(height: 20),
                      SizedBox(
                        width: containerWidth,
                        child: Column(
                          children: [
                            // Contador
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _charCount,
                                style: TextStyle(
                                  color: _textController.text.length > 5000
                                      ? Colors.red
                                      : Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Botões
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Botão limpar
                                OutlinedButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () {
                                          _textController.clear();
                                          _focusNode.requestFocus();
                                        },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Limpar',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Botão enviar
                                ElevatedButton(
                                  onPressed: _isSubmitting ? null : _showConfirmationDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          'Enviar Mensagem',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Rodapé informativo (só mostra se houver espaço)
                      if (screenHeight > 600) ...[
                        const SizedBox(height: 30),
                        Container(
                          width: containerWidth,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.security,
                                color: Colors.white54,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Sua mensagem é confidencial. Será usada para melhorias no sistema.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}