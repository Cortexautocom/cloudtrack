import 'package:flutter/material.dart';

class CertificadoAnalisePage extends StatefulWidget {
  final VoidCallback onVoltar;

  const CertificadoAnalisePage({
    Key? key,
    required this.onVoltar,
  }) : super(key: key);

  @override
  State<CertificadoAnalisePage> createState() => _CertificadoAnalisePageState();
}

class _CertificadoAnalisePageState extends State<CertificadoAnalisePage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho com botão de voltar
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
              tooltip: 'Voltar para apuração',
            ),
            const SizedBox(width: 10),
            const Text(
              'Certificado de Análise',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        const Divider(color: Colors.grey),
        const SizedBox(height: 20),
        
        // Conteúdo da página (provisório)
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment,
                  size: 80,
                  color: Color(0xFF0D47A1),
                ),
                SizedBox(height: 20),
                Text(
                  'Página de Certificado de Análise',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF0D47A1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Funcionalidade em desenvolvimento',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 30),
                
                // Botões de ação provisórios
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _mostrarMensagem('Gerar Certificado');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D47A1),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Novo Certificado',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 20),
                    
                    ElevatedButton(
                      onPressed: () {
                        _mostrarMensagem('Consultar Certificados');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2E7D32),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Consultar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 20),
                    
                    ElevatedButton(
                      onPressed: () {
                        _mostrarMensagem('Relatórios');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD32F2F),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Relatórios',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 40),
                
                // Informações adicionais
                Container(
                  width: 600,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color.fromARGB(255, 233, 233, 233)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Funcionalidades planejadas:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildFeatureItem('Geração de certificados de análise'),
                      _buildFeatureItem('Consulta e histórico'),
                      _buildFeatureItem('Impressão de certificados'),
                      _buildFeatureItem('Integração com medições'),
                      _buildFeatureItem('Exportação para PDF/Excel'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _mostrarMensagem(String acao) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$acao - Funcionalidade em desenvolvimento'),
        backgroundColor: Color(0xFF0D47A1),
        duration: Duration(seconds: 2),
      ),
    );
  }
}