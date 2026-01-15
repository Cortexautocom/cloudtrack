import 'package:flutter/material.dart';

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
                          'Bem-vindo!\nVocê chegou ao Grande Arquiteto.',
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Sua mente está livre para criar!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
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

                // IMAGEM COM DEGRADÊ (mantida como estava)
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
