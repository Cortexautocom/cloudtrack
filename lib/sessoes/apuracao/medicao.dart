import 'package:flutter/material.dart';

class MedicaoTanquesPage extends StatefulWidget {
  final VoidCallback onVoltar;
  
  const MedicaoTanquesPage({
    super.key,
    required this.onVoltar,
  });

  @override
  State<MedicaoTanquesPage> createState() => _MedicaoTanquesPageState();
}

class _MedicaoTanquesPageState extends State<MedicaoTanquesPage> {
  final List<Map<String, dynamic>> tanques = [
    {
      'numero': 'TQ-001',
      'produto': 'GASOLINA COMUM',
      'capacidade': '50.000 L',
    },
    {
      'numero': 'TQ-002',
      'produto': 'ÓLEO DIESEL S10',
      'capacidade': '75.000 L',
    },
    {
      'numero': 'TQ-003',
      'produto': 'ETANOL HIDRATADO',
      'capacidade': '30.000 L',
    },
    {
      'numero': 'TQ-004',
      'produto': 'GASOLINA PREMIUM',
      'capacidade': '25.000 L',
    },
  ];

  final List<List<TextEditingController>> _controllers = [];
  final TextEditingController _dataController = TextEditingController(
    text: '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'
  );

  @override
  void initState() {
    super.initState();
    // Inicializar controllers para cada tanque
    for (int i = 0; i < tanques.length; i++) {
      _controllers.add([
        // Abertura - 6 controllers
        TextEditingController(text: '735'), // altura_cm
        TextEditingController(text: '35'),  // altura_mm
        TextEditingController(text: '28.5'), // temp_tanque
        TextEditingController(text: '0.745'), // densidade
        TextEditingController(text: '28.0'), // temp_amostra
        TextEditingController(), // observacao_abertura
        
        // Fechamento - 6 controllers
        TextEditingController(text: '685'), // altura_cm
        TextEditingController(text: '20'),  // altura_mm
        TextEditingController(text: '29.0'), // temp_tanque
        TextEditingController(text: '0.745'), // densidade
        TextEditingController(text: '28.5'), // temp_amostra
        TextEditingController(), // observacao_fechamento
      ]);
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    for (var tankControllers in _controllers) {
      for (var controller in tankControllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header com botão voltar
        _buildHeader(),
        const SizedBox(height: 20),
        
        // Conteúdo principal
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Data e informações do dia
                _buildInfoDia(),
                const SizedBox(height: 32),
                
                // Lista de tanques
                Column(
                  children: [
                    for (int i = 0; i < tanques.length; i++)
                      _buildTanqueCard(tanques[i], i),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Botões de ação
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D47A1)),
              onPressed: widget.onVoltar,
              tooltip: 'Voltar para Apuração',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTROLE DE MEDIÇÃO DIÁRIA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'Sistema de Apuração - Base de Combustíveis',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'MEDIÇÃO',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.grey),
      ],
    );
  }

  Widget _buildInfoDia() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data da Medição',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    child: TextFormField(
                      controller: _dataController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      readOnly: true,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 60,
              color: Colors.grey[300],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operador',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'João Silva',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int tankIndex) {
    final controllers = _controllers[tankIndex];
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do tanque
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tanque['numero'],
                    style: const TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tanque['produto'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capacidade: ${tanque['capacidade']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Conteúdo - Abertura e Fechamento
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medição da Manhã (Abertura)
                Expanded(
                  child: _buildMedicaoSection(
                    titulo: 'MEDIÇÃO DA MANHÃ',
                    subtitulo: 'Abertura do Dia - 06:00h',
                    cor: Colors.blue[50]!,
                    corBorda: Colors.blue,
                    controllers: controllers.sublist(0, 6),
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Divisória visual
                Container(
                  width: 1,
                  height: 420,
                  color: Colors.grey[300],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: Text(
                          'COMPARAÇÃO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Medição da Tarde (Fechamento)
                Expanded(
                  child: _buildMedicaoSection(
                    titulo: 'MEDIÇÃO DA TARDE', 
                    subtitulo: 'Fechamento do Dia - 18:00h',
                    cor: Colors.green[50]!,
                    corBorda: Colors.green,
                    controllers: controllers.sublist(6, 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicaoSection({
    required String titulo,
    required String subtitulo,
    required Color cor,
    required Color corBorda,
    required List<TextEditingController> controllers,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corBorda.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: corBorda.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: corBorda.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: corBorda,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: corBorda,
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 12,
                          color: corBorda.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Campos de entrada
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Altura do líquido
                _buildInputGroup(
                  label: 'ALTURA DO LÍQUIDO',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildNumberInput(
                            controller: controllers[0],
                            label: 'Centímetros (cm)',
                            hintText: '735',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildNumberInput(
                            controller: controllers[1],
                            label: 'Milímetros (mm)',
                            hintText: '35',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Temperatura e Densidade
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberInput(
                        controller: controllers[2],
                        label: 'TEMP. TANQUE (°C)',
                        hintText: '28.5',
                        decimal: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberInput(
                        controller: controllers[3],
                        label: 'DENSIDADE',
                        hintText: '0.745',
                        decimal: true,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Temperatura da amostra
                _buildNumberInput(
                  controller: controllers[4],
                  label: 'TEMP. AMOSTRA (°C)',
                  hintText: '28.0',
                  decimal: true,
                ),
                
                const SizedBox(height: 16),
                
                // Observações
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OBSERVAÇÕES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: controllers[5],
                      decoration: InputDecoration(
                        hintText: 'Informações relevantes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool decimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _salvarMedicoes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.save, color: Colors.white, size: 20),
            label: const Text(
              'SALVAR MEDIÇÕES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 20),
          OutlinedButton.icon(
            onPressed: _imprimirRelatorio,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Color(0xFF0D47A1), width: 2),
            ),
            icon: const Icon(Icons.print, size: 20, color: Color(0xFF0D47A1)),
            label: const Text(
              'IMPRIMIR RELATÓRIO',
              style: TextStyle(
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _salvarMedicoes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Salvar Medições'),
          ],
        ),
        content: const Text('Todas as medições serão salvas no sistema. Deseja continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Medições salvas com sucesso!'),
                  backgroundColor: Colors.green[700],
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _imprimirRelatorio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Imprimir Relatório'),
          ],
        ),
        content: const Text('O relatório de medições será gerado para impressão.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Relatório enviado para impressão!'),
                  backgroundColor: const Color(0xFF0D47A1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
            ),
            child: const Text('Imprimir'),
          ),
        ],
      ),
    );
  }
}