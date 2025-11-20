import 'package:flutter/material.dart';

class MedicaoTanquesPage extends StatefulWidget {
  const MedicaoTanquesPage({super.key});

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Medição de Tanques'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        constraints: const BoxConstraints(maxWidth: 670),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            _buildHeader(),
            const SizedBox(height: 20),
            
            // Data
            _buildDateField(),
            const SizedBox(height: 30),
            
            // Lista de tanques
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < tanques.length; i++)
                      _buildTanqueCard(tanques[i], i),
                  ],
                ),
              ),
            ),
            
            // Botões de ação
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        const SizedBox(height: 10),
        const Divider(thickness: 1, color: Colors.grey),
      ],
    );
  }

  Widget _buildDateField() {
    return Container(
      width: 200,
      child: TextFormField(
        controller: _dataController,
        decoration: InputDecoration(
          labelText: 'Data da Medição',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        readOnly: true,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildTanqueCard(Map<String, dynamic> tanque, int tankIndex) {
    final controllers = _controllers[tankIndex];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do tanque
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tanque['numero'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tanque['produto'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Capacidade: ${tanque['capacidade']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medição da Manhã (Abertura)
                Expanded(
                  child: _buildMedicaoSection(
                    titulo: 'MEDIÇÃO DA MANHÃ',
                    subtitulo: 'Abertura do Dia',
                    cor: Colors.blue[50]!,
                    corBorda: Colors.blue,
                    controllers: controllers.sublist(0, 6), // Primeiros 6 controllers
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Divisória visual
                Container(
                  width: 1,
                  height: 400,
                  color: Colors.grey[300],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Medição da Tarde (Fechamento)
                Expanded(
                  child: _buildMedicaoSection(
                    titulo: 'MEDIÇÃO DA TARDE',
                    subtitulo: 'Fechamento do Dia',
                    cor: Colors.green[50]!,
                    corBorda: Colors.green,
                    controllers: controllers.sublist(6, 12), // Últimos 6 controllers
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
    // controllers[0] = altura_cm
    // controllers[1] = altura_mm  
    // controllers[2] = temp_tanque
    // controllers[3] = densidade
    // controllers[4] = temp_amostra
    // controllers[5] = observacoes
    
    return Container(
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corBorda.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: corBorda.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
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
          
          // Campos de entrada
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Altura do líquido
                _buildInputGroup(
                  label: 'ALTURA DO LÍQUIDO',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            controller: controllers[0], // altura_cm
                            label: 'Centímetros (cm)',
                            hintText: 'Ex: 735',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildNumberInput(
                            controller: controllers[1], // altura_mm
                            label: 'Milímetros (mm)',
                            hintText: 'Ex: 35',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Temperatura e Densidade
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberInput(
                        controller: controllers[2], // temp_tanque
                        label: 'TEMP. TANQUE (°C)',
                        hintText: 'Ex: 28.5',
                        decimal: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildNumberInput(
                        controller: controllers[3], // densidade
                        label: 'DENSIDADE',
                        hintText: 'Ex: 0.745',
                        decimal: true,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Temperatura da amostra
                _buildNumberInput(
                  controller: controllers[4], // temp_amostra
                  label: 'TEMP. AMOSTRA (°C)',
                  hintText: 'Ex: 28.0',
                  decimal: true,
                ),
                
                const SizedBox(height: 12),
                
                // Observações
                TextFormField(
                  controller: controllers[5], // observacoes
                  decoration: InputDecoration(
                    labelText: 'OBSERVAÇÕES',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
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
        const SizedBox(height: 4),
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
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _salvarMedicoes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.save, color: Colors.white, size: 18),
            label: const Text(
              'SALVAR MEDIÇÕES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _imprimirRelatorio,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: Color(0xFF0D47A1)),
            ),
            icon: const Icon(Icons.print, size: 18, color: Color(0xFF0D47A1)),
            label: const Text(
              'IMPRIMIR RELATÓRIO',
              style: TextStyle(
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _salvarMedicoes() {
    // Simulação de salvamento
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar Medições'),
        content: const Text('Todas as medições serão salvas no sistema.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Medições salvas com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _imprimirRelatorio() {
    // Simulação de impressão
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imprimir Relatório'),
        content: const Text('O relatório de medições será gerado para impressão.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Relatório enviado para impressão!'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Imprimir'),
          ),
        ],
      ),
    );
  }
}