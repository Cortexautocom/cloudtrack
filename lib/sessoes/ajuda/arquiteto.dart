import 'package:flutter/material.dart';

class GrandeArquitetoPage extends StatefulWidget {
  const GrandeArquitetoPage({super.key});

  @override
  GrandeArquitetoPageState createState() => GrandeArquitetoPageState(); // CORREÇÃO: Mudado de _GrandeArquitetoPageState para GrandeArquitetoPageState
}

class GrandeArquitetoPageState extends State<GrandeArquitetoPage>
    with SingleTickerProviderStateMixin { // CORREÇÃO: Mudado de _GrandeArquitetoPageState para GrandeArquitetoPageState
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
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Imagem original
                Image.asset(
                  'assets/arquiteto.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 100,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Imagem não encontrada',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                // Gradiente nas bordas laterais (esquerda e direita)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black, // Borda esquerda
                          Colors.transparent, // Transição
                          Colors.transparent, // Centro
                          Colors.transparent, // Centro
                          Colors.black, // Borda direita
                        ],
                        stops: [0.0, 0.05, 0.5, 0.95, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Gradiente nas bordas superior e inferior
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black, // Borda superior
                          Colors.transparent, // Transição
                          Colors.transparent, // Centro
                          Colors.transparent, // Centro
                          Colors.black, // Borda inferior
                        ],
                        stops: [0.0, 0.05, 0.5, 0.95, 1.0],
                      ),
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