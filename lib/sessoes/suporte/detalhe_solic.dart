import 'package:flutter/material.dart';

class DetalheSolicitacaoPage extends StatelessWidget {
  final Map<String, dynamic> solicitacao;
  final VoidCallback onVoltar;

  const DetalheSolicitacaoPage({
    super.key,
    required this.solicitacao,
    required this.onVoltar,
  });

  String _formatarData(String? data) {
    if (data == null) return '-';
    try {
      final d = DateTime.parse(data);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return data;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'concluido':
        return Colors.green;
      case 'em analise':
      case 'desenvolvimento':
        return Colors.blue;
      case 'pendente':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = solicitacao['usuarios']?['Nome_apelido'] ?? 'Anonimo';
    final titulo = solicitacao['titulo'] ?? 'Sem titulo';
    final texto = solicitacao['texto'] ?? 'Sem descricao detalhada.';
    final status = solicitacao['status']?.toUpperCase() ?? 'PENDENTE';
    final dataCriacao = _formatarData(solicitacao['data_criacao']);
    final previsao = _formatarData(solicitacao['previsao']);

    return Scaffold(
      backgroundColor: Colors.white, // Fundo branco na pagina toda
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar branca
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)), // Icone escuro
          onPressed: onVoltar,
        ),
        title: const Text(
          'Detalhes da Solicitacao',
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold),
        ),
        elevation: 0.5, // Leve sombra
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white, // Container branco
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    'Criado em: $dataCriacao',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'DESCRICAO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SOLICITANTE', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: Color(0xFF263238)),
                            const SizedBox(width: 4),
                            Text(usuario, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PREVISAO', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF263238)),
                            const SizedBox(width: 4),
                            Text(previsao, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
