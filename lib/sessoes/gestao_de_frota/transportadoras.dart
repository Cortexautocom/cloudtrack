import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==============================
// DIALOG CADASTRO / EDIÇÃO TRANSPORTADORA
// ==============================
class DialogCadastroTransportadora extends StatefulWidget {
  final Map<String, dynamic>? transportadora;
  final VoidCallback onSalvo;

  const DialogCadastroTransportadora({
    super.key,
    this.transportadora,
    required this.onSalvo,
  });

  @override
  State<DialogCadastroTransportadora> createState() =>
      _DialogCadastroTransportadoraState();
}

class _DialogCadastroTransportadoraState
    extends State<DialogCadastroTransportadora> {
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _ieController = TextEditingController();
  final _tel1Controller = TextEditingController();
  final _tel2Controller = TextEditingController();
  final _situacaoController = TextEditingController();
  final _nome2Controller = TextEditingController();

  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cnpjController.dispose();
    _ieController.dispose();
    _tel1Controller.dispose();
    _tel2Controller.dispose();
    _situacaoController.dispose();
    _nome2Controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final t = widget.transportadora;
    if (t != null) {
      _nomeController.text = t['nome'] ?? '';
      _cnpjController.text = t['cnpj'] ?? '';
      _ieController.text = t['inscricao_estadual'] ?? '';
      _tel1Controller.text = t['telefone_um'] ?? '';
      _tel2Controller.text = t['telefone_dois'] ?? '';
      _situacaoController.text = t['situacao'] ?? '';
      _nome2Controller.text = t['nome_dois'] ?? '';
    }
  }

  Future<void> _salvar() async {
    if (_nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório')),
      );
      return;
    }

    setState(() => _salvando = true);

    final dados = {
      'nome': _nomeController.text,
      'cnpj': _cnpjController.text.isNotEmpty ? _cnpjController.text : null,
      'inscricao_estadual':
          _ieController.text.isNotEmpty ? _ieController.text : null,
      'telefone_um':
          _tel1Controller.text.isNotEmpty ? _tel1Controller.text : null,
      'telefone_dois':
          _tel2Controller.text.isNotEmpty ? _tel2Controller.text : null,
      'situacao':
          _situacaoController.text.isNotEmpty ? _situacaoController.text : null,
      'nome_dois':
          _nome2Controller.text.isNotEmpty ? _nome2Controller.text : null,
    };

    try {
      if (widget.transportadora == null) {
        await Supabase.instance.client
            .from('transportadoras')
            .insert(dados);
      } else {
        await Supabase.instance.client
            .from('transportadoras')
            .update(dados)
            .eq('id', widget.transportadora!['id']);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSalvo();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transportadora salva com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          label: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.blue[900]!),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[900]!, width: 1),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Text(
                    widget.transportadora == null
                        ? 'Nova Transportadora'
                        : 'Editar Transportadora',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dados Gerais',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _campo('Nome *', _nomeController),
                          _campo('Nome Fantasia', _nome2Controller),
                          _campo('CNPJ', _cnpjController),
                          _campo('Inscrição Estadual', _ieController),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contato e Situação',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _campo('Telefone 1', _tel1Controller),
                          _campo('Telefone 2', _tel2Controller),
                          _campo('Situação', _situacaoController),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            ,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: _salvando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Salvar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DialogConfirmarExclusaoTransportadora extends StatelessWidget {
  final String nome;
  final VoidCallback onConfirmar;

  const DialogConfirmarExclusaoTransportadora({
    super.key,
    required this.nome,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue[900]!, width: 1),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Excluir Transportadora',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tem certeza que deseja excluir "$nome"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            const Text(
              'Esta ação é irreversível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: const Text('Voltar', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirmar();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Sim, excluir', style: TextStyle(fontSize: 13)),
                  ),
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
// MENU 3 PONTOS TRANSPORTADORA
// ==============================
class MenuTransportadoraWidget extends StatelessWidget {
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const MenuTransportadoraWidget({
    super.key,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      onSelected: (v) {
        if (v == 'editar') onEditar();
        if (v == 'excluir') onExcluir();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'editar',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: Colors.blue[900]),
              const SizedBox(width: 8),
              Text('Editar', style: TextStyle(fontSize: 13, color: Colors.grey[800])),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excluir',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text('Excluir', style: TextStyle(fontSize: 13, color: Colors.grey[800])),
            ],
          ),
        ),
      ],
    );
  }
}

// ==============================
// PÁGINA DE TRANSPORTADORAS
// ==============================
class TransportadorasPage extends StatefulWidget {
  const TransportadorasPage({super.key});

  @override
  State<TransportadorasPage> createState() => _TransportadorasPageState();
}

class _TransportadorasPageState extends State<TransportadorasPage> {
  List<Map<String, dynamic>> _transportadoras = [];
  bool _carregando = true;
  String _filtro = '';
  final _buscaController = TextEditingController();

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await Supabase.instance.client
          .from('transportadoras')
          .select()
          .order('nome');

      if (!mounted) return;
      setState(() {
        _transportadoras = List<Map<String, dynamic>>.from(data);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar transportadoras: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro.isEmpty) return _transportadoras;
    return _transportadoras.where((t) {
      final nome = (t['nome'] ?? '').toString().toLowerCase();
      final nomeFantasia = (t['nome_dois'] ?? '').toString().toLowerCase();
      final cnpj = (t['cnpj'] ?? '').toString().toLowerCase();
      final telefone = (t['telefone_um'] ?? '').toString().toLowerCase();
      final situacao = (t['situacao'] ?? '').toString().toLowerCase();
      return nome.contains(_filtro.toLowerCase()) ||
          nomeFantasia.contains(_filtro.toLowerCase()) ||
          cnpj.contains(_filtro.toLowerCase()) ||
          telefone.contains(_filtro.toLowerCase()) ||
          situacao.contains(_filtro.toLowerCase());
    }).toList();
  }

  Future<void> _excluir(String id) async {
    try {
      await Supabase.instance.client.from('transportadoras').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transportadora excluída com sucesso'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _abrirCadastro([Map<String, dynamic>? t]) {
    showDialog(
      context: context,
      builder: (_) => DialogCadastroTransportadora(
        transportadora: t,
        onSalvo: _carregar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                tooltip: 'Atualizar',
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _buscaController,
                  onChanged: (v) => setState(() => _filtro = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar nome, CNPJ, telefone...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      borderSide: BorderSide(color: Color(0xFF0D47A1)),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirCadastro(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova Transportadora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 40),
              SizedBox(width: 260, child: Text('NOME', style: _headerStyle)),
              SizedBox(width: 180, child: Text('NOME FANTASIA', style: _headerStyle)),
              SizedBox(width: 150, child: Text('CNPJ', style: _headerStyle)),
              SizedBox(width: 140, child: Text('TELEFONE', style: _headerStyle)),
              Expanded(child: Text('SITUAÇÃO', style: _headerStyle)),
            ],
          ),
        ),

        Expanded(
          child: _carregando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
                )
              : _filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma transportadora encontrada',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtrados.length,
                      itemBuilder: (context, i) {
                        final t = _filtrados[i];
                        final nome = (t['nome'] ?? '--').toString();
                        final nomeDois = (t['nome_dois'] ?? '--').toString();
                        final cnpj = (t['cnpj'] ?? '--').toString();
                        final telefone = (t['telefone_um'] ?? '--').toString();
                        final situacao = (t['situacao'] ?? '--').toString();

                        return Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: i.isEven ? Colors.white : Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: MenuTransportadoraWidget(
                                  onEditar: () => _abrirCadastro(t),
                                  onExcluir: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => DialogConfirmarExclusaoTransportadora(
                                        nome: nome,
                                        onConfirmar: () => _excluir(t['id'].toString()),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                child: Text(
                                  nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: Text(
                                  nomeDois,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: nomeDois == '--' ? Colors.grey : Colors.black,
                                    fontStyle: nomeDois == '--' ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(
                                  cnpj,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cnpj == '--' ? Colors.grey : Colors.black,
                                    fontStyle: cnpj == '--' ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: Text(
                                  telefone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: telefone == '--' ? Colors.grey : Colors.black,
                                    fontStyle: telefone == '--' ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  situacao,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: situacao == '--' ? Colors.grey : Colors.black,
                                    fontStyle: situacao == '--' ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_filtrados.length} transportadora${_filtrados.length != 1 ? 's' : ''} encontrada${_filtrados.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _headerStyle = TextStyle(
  fontWeight: FontWeight.bold,
  color: Color(0xFF0D47A1),
  fontSize: 12,
);
