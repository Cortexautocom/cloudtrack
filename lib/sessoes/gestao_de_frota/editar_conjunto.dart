import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==============================
// DIALOG DE SELEÇÃO DE PLACA
// ==============================
class SelecionarPlacaDialog extends StatefulWidget {
  final String titulo;
  final String? placaAtual;
  final String campoConjunto; // 'cavalo', 'reboque_um' ou 'reboque_dois'
  final String conjuntoId;
  final bool apenasReboques; // Se true, mostra apenas placas com tanques
  
  const SelecionarPlacaDialog({
    super.key,
    required this.titulo,
    this.placaAtual,
    required this.campoConjunto,
    required this.conjuntoId,
    this.apenasReboques = false,
  });

  @override
  State<SelecionarPlacaDialog> createState() => _SelecionarPlacaDialogState();
}

class _SelecionarPlacaDialogState extends State<SelecionarPlacaDialog> {
  String? _placaSelecionada;
  List<Map<String, dynamic>> _placasDisponiveis = [];
  List<Map<String, dynamic>> _placasFiltradas = [];
  List<String> _placasEmConjuntos = [];
  bool _carregando = true;
  final TextEditingController _buscaController = TextEditingController();
  final Map<String, List<String>> _placasDuplicadas = {}; // placa -> [conjunto_ids]

  @override
  void initState() {
    super.initState();
    _placaSelecionada = widget.placaAtual;
    _buscaController.addListener(_filtrarPlacas);
    _carregarDados();
  }

  @override
  void dispose() {
    _buscaController.removeListener(_filtrarPlacas);
    _buscaController.dispose();
    super.dispose();
  }

  void _filtrarPlacas() {
    final texto = _buscaController.text.toLowerCase();
    if (texto.isEmpty) {
      setState(() {
        _placasFiltradas = List.from(_placasDisponiveis);
      });
    } else {
      setState(() {
        _placasFiltradas = _placasDisponiveis.where((equipamento) {
          final placa = equipamento['placa']?.toString().toLowerCase() ?? '';
          return placa.contains(texto);
        }).toList();
      });
    }
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      // Carregar todas as placas de equipamentos
      final query = Supabase.instance.client
          .from('equipamentos')
          .select('id, placa, tanques')
          .order('placa');
      
      final equipamentosData = await query;
      
      // Filtrar equipamentos conforme necessário
      List<Map<String, dynamic>> equipamentosFiltrados;
      
      if (widget.apenasReboques) {
        // Para reboques: apenas placas que têm tanques (array não vazio)
        equipamentosFiltrados = equipamentosData.where((equipamento) {
          final tanques = equipamento['tanques'];
          return tanques is List && tanques.isNotEmpty;
        }).toList();
      } else {
        // Para cavalo: todos os equipamentos
        equipamentosFiltrados = List.from(equipamentosData);
      }
      
      _placasDisponiveis = equipamentosFiltrados;
      _placasFiltradas = List.from(_placasDisponiveis);
      
      // Carregar todas as placas que já estão em conjuntos
      final conjuntosData = await Supabase.instance.client
          .from('conjuntos')
          .select('id, cavalo, reboque_um, reboque_dois');
      
      // Coletar todas as placas usadas em conjuntos
      for (final conjunto in conjuntosData) {
        final conjuntoId = conjunto['id'].toString();
        
        // Cavalo
        if (conjunto['cavalo'] != null) {
          final placa = conjunto['cavalo'].toString();
          _placasEmConjuntos.add(placa);
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
        
        // Reboque 1
        if (conjunto['reboque_um'] != null) {
          final placa = conjunto['reboque_um'].toString();
          _placasEmConjuntos.add(placa);
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
        
        // Reboque 2
        if (conjunto['reboque_dois'] != null) {
          final placa = conjunto['reboque_dois'].toString();
          _placasEmConjuntos.add(placa);
          _adicionarPlacaDuplicada(placa, conjuntoId);
        }
      }
      
      // Remover placas duplicadas da lista
      _placasEmConjuntos = _placasEmConjuntos.toSet().toList();
      
    } catch (e) {
      print('Erro ao carregar dados: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _adicionarPlacaDuplicada(String placa, String conjuntoId) {
    if (!_placasDuplicadas.containsKey(placa)) {
      _placasDuplicadas[placa] = [];
    }
    if (!_placasDuplicadas[placa]!.contains(conjuntoId)) {
      _placasDuplicadas[placa]!.add(conjuntoId);
    }
  }

  bool _placaEstaDuplicada(String placa) {
    // Uma placa está duplicada se está em mais de um conjunto
    final conjuntos = _placasDuplicadas[placa];
    return conjuntos != null && conjuntos.length > 1;
  }

  bool _placaEstaEmOutroConjunto(String placa) {
    // Verifica se a placa está em outro conjunto diferente do atual
    if (!_placasDuplicadas.containsKey(placa)) return false;
    
    final conjuntos = _placasDuplicadas[placa]!;
    // Se a placa não está em nenhum conjunto ou está apenas no conjunto atual, retorna false
    if (conjuntos.isEmpty || (conjuntos.length == 1 && conjuntos.contains(widget.conjuntoId))) {
      return false;
    }
    
    // Se está em algum conjunto que não é o atual
    return conjuntos.any((id) => id != widget.conjuntoId);
  }

  Future<void> _atualizarConjunto() async {
    if (_placaSelecionada == null) {
      // Se nenhuma placa foi selecionada, apenas fecha o dialog
      Navigator.of(context).pop();
      return;
    }

    // Verificar se a placa está em outro conjunto
    if (_placaEstaEmOutroConjunto(_placaSelecionada!)) {
      final continuar = await _mostrarDialogoDuplicidade();
      if (!continuar) {
        return; // Usuário cancelou, mantém o dialog aberto
      }
    }

    // Atualizar o conjunto no banco de dados
    try {
      await Supabase.instance.client
          .from('conjuntos')
          .update({widget.campoConjunto: _placaSelecionada})
          .eq('id', widget.conjuntoId);

      // Fechar o dialog e retornar sucesso
      Navigator.of(context).pop(true);
    } catch (e) {
      print('Erro ao atualizar conjunto: $e');
      // Mostrar mensagem de erro
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _mostrarDialogoDuplicidade() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Atenção!'),
            content: const Text(
              'Esta placa já faz parte de outro conjunto. '
              'Deseja prosseguir mesmo com a duplicidade?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Não'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sim, prosseguir'),
              ),
            ],
          ),
        ) ?? false;
  }

  Widget _buildListaPlacas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de busca
        TextField(
          controller: _buscaController,
          decoration: InputDecoration(
            hintText: 'Digite para buscar a placa...',
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          onChanged: (value) => _filtrarPlacas(),
        ),
        
        const SizedBox(height: 12),
        
        // Legenda
        if (_buscaController.text.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Digite para filtrar ou selecione abaixo',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        
        const SizedBox(height: 8),
        
        // Lista de placas filtradas
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _placasFiltradas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _buscaController.text.isNotEmpty
                          ? 'Nenhuma placa encontrada'
                          : 'Nenhuma placa disponível',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _placasFiltradas.length,
                  itemBuilder: (context, index) {
                    final equipamento = _placasFiltradas[index];
                    final placa = equipamento['placa']?.toString() ?? '';
                    final estaDuplicada = _placaEstaDuplicada(placa);
                    final selecionada = _placaSelecionada == placa;
                    
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _placaSelecionada = placa;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selecionada
                              ? const Color(0xFF0D47A1).withOpacity(0.1)
                              : estaDuplicada
                                  ? Colors.red.shade50
                                  : Colors.white,
                          border: Border(
                            bottom: index < _placasFiltradas.length - 1
                                ? BorderSide(color: Colors.grey.shade200)
                                : BorderSide.none,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selecionada ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20,
                              color: selecionada 
                                  ? const Color(0xFF0D47A1)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        placa,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          color: estaDuplicada ? Colors.red : Colors.black,
                                        ),
                                      ),
                                      if (estaDuplicada) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.warning, size: 14, color: Colors.red),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${_placasDuplicadas[placa]!.length} conjuntos)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.red,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  // Mostrar tanques se for equipamento com tanques
                                  if (equipamento['tanques'] != null && 
                                      equipamento['tanques'] is List &&
                                      (equipamento['tanques'] as List).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Tanques: ${_formatarTanques(equipamento['tanques'])}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
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
                  },
                ),
        ),
      ],
    );
  }

  String _formatarTanques(dynamic tanquesData) {
    if (tanquesData is List) {
      final lista = tanquesData.cast<int>();
      return lista.join(' + ');
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            
            if (widget.apenasReboques)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Mostrando apenas equipamentos com tanques',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            if (_carregando)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
              )
            else
              _buildListaPlacas(),
            
            const SizedBox(height: 20),
            
            // Opção para limpar/remover a placa
            if (widget.placaAtual != null && widget.placaAtual!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _placaSelecionada = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Remover placa'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _placaSelecionada == widget.placaAtual
                      ? null // Desabilita se não houve alteração
                      : _atualizarConjunto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// FUNÇÃO PARA ABRIR DIALOG DE EDIÇÃO
// ==============================
Future<bool?> mostrarDialogEditarPlaca({
  required BuildContext context,
  required String titulo,
  required String? placaAtual,
  required String campoConjunto,
  required String conjuntoId,
  bool apenasReboques = false,
}) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => SelecionarPlacaDialog(
      titulo: titulo,
      placaAtual: placaAtual,
      campoConjunto: campoConjunto,
      conjuntoId: conjuntoId,
      apenasReboques: apenasReboques,
    ),
  );
}

// ==============================
// FUNÇÃO PARA ATUALIZAR UMA PLACA NO CONJUNTO
// ==============================
Future<bool> atualizarPlacaConjunto({
  required BuildContext context,
  required String conjuntoId,
  required String campo, // 'cavalo', 'reboque_um', 'reboque_dois'
  String? placaAtual,
}) async {
  String titulo;
  bool apenasReboques;
  
  switch (campo) {
    case 'cavalo':
      titulo = 'Selecione o novo cavalo';
      apenasReboques = false; // Cavalo pode ser qualquer equipamento
      break;
    case 'reboque_um':
    case 'reboque_dois':
      titulo = campo == 'reboque_um' 
          ? 'Selecione o novo reboque 1' 
          : 'Selecione o novo reboque 2';
      apenasReboques = true; // Reboques devem ter tanques
      break;
    default:
      titulo = 'Selecione a nova placa';
      apenasReboques = false;
  }

  final resultado = await mostrarDialogEditarPlaca(
    context: context,
    titulo: titulo,
    placaAtual: placaAtual,
    campoConjunto: campo,
    conjuntoId: conjuntoId,
    apenasReboques: apenasReboques,
  );

  return resultado == true;
}

// ==============================
// WIDGET DE PLACA CLICÁVEL
// ==============================
class PlacaClicavelWidget extends StatefulWidget {
  final String? placa;
  final String conjuntoId;
  final String campoConjunto;
  final VoidCallback? onAtualizado;
  final Map<String, List<String>> placasDuplicadas;
  
  const PlacaClicavelWidget({
    super.key,
    required this.placa,
    required this.conjuntoId,
    required this.campoConjunto,
    this.onAtualizado,
    required this.placasDuplicadas,
  });

  @override
  State<PlacaClicavelWidget> createState() => _PlacaClicavelWidgetState();
}

class _PlacaClicavelWidgetState extends State<PlacaClicavelWidget> {
  bool _clicado = false;
  DateTime? _ultimoClique;

  bool get _estaDuplicada {
    if (widget.placa == null) return false;
    final conjuntos = widget.placasDuplicadas[widget.placa!];
    return conjuntos != null && conjuntos.length > 1;
  }

  void _onTap() {
    final agora = DateTime.now();
    
    if (_ultimoClique != null && 
        agora.difference(_ultimoClique!) < const Duration(milliseconds: 300)) {
      // Clique duplo detectado
      _abrirDialogEdicao();
      setState(() {
        _clicado = true;
      });
      // Resetar após 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _clicado = false;
          });
        }
      });
    } else {
      // Primeiro clique
      setState(() {
        _clicado = true;
      });
      // Resetar após 300ms se não houver segundo clique
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _clicado) {
          setState(() {
            _clicado = false;
          });
        }
      });
    }
    
    _ultimoClique = agora;
  }

  Future<void> _abrirDialogEdicao() async {
    final atualizado = await atualizarPlacaConjunto(
      context: context,
      conjuntoId: widget.conjuntoId,
      campo: widget.campoConjunto,
      placaAtual: widget.placa,
    );
    
    if (atualizado && widget.onAtualizado != null) {
      widget.onAtualizado!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.placa == null || widget.placa!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          '--',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _clicado
                ? const Color(0xFF0D47A1).withOpacity(0.2)
                : _estaDuplicada
                    ? Colors.red.shade50
                    : const Color(0xFF0D47A1).withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _clicado
                  ? const Color(0xFF0D47A1)
                  : _estaDuplicada
                      ? Colors.red.withOpacity(0.3)
                      : const Color(0xFF0D47A1).withOpacity(0.2),
              width: _estaDuplicada ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.placa!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _clicado
                      ? const Color(0xFF0D47A1)
                      : _estaDuplicada
                          ? Colors.red
                          : const Color(0xFF0D47A1).withOpacity(0.8),
                ),
              ),
              if (_estaDuplicada) ...[
                const SizedBox(width: 4),
                const Icon(Icons.warning, size: 12, color: Colors.red),
              ],
            ],
          ),
        ),
      ),
    );
  }
}