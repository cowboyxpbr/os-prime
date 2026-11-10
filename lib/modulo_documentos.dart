// ============================================================================
// ARQUIVO: ORÇAMENTOS COM DATA FLEXÍVEL, EQUIPAMENTOS, LAUDO E HISTÓRICO 90 DIAS
// lib/modulo_documentos.dart
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'app_base.dart';

// ============================================================================
// 1. GERENCIADOR LOCAL DE ORÇAMENTOS SALVOS (AUTO-EXPURGO 90 DIAS)
// ============================================================================
class ServicoOrcamentosSalvos {
  static Future<File> _obterArquivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/orcamentos_salvos_app.json');
  }

  static Future<List<Map<String, dynamic>>> carregar() async {
    try {
      final f = await _obterArquivo();
      if (await f.exists()) {
        final txt = await f.readAsString();
        final List dec = jsonDecode(txt);
        return dec.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> salvarLista(List<Map<String, dynamic>> lista) async {
    try {
      final f = await _obterArquivo();
      await f.writeAsString(jsonEncode(lista));
    } catch (_) {}
  }

  static Future<void> salvarOuAtualizar(Map<String, dynamic> orcamento) async {
    final lista = await carregar();
    final id = orcamento['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    orcamento['id'] = id;
    lista.removeWhere((item) => item['id'] == id);
    lista.insert(0, orcamento);
    await salvarLista(lista);
  }

  static Future<void> excluir(String id) async {
    final lista = await carregar();
    lista.removeWhere((item) => item['id'] == id);
    await salvarLista(lista);
  }

  // AUTO-LIMPEZA: Descarta orçamentos com mais de 90 dias
  static Future<void> limparAntigos90Dias() async {
    try {
      final lista = await carregar();
      final hoje = DateTime.now();
      final fmt = DateFormat('dd/MM/yyyy');
      bool alterou = false;

      lista.removeWhere((orc) {
        try {
          final dataStr = (orc['data'] ?? '').toString();
          if (dataStr.isNotEmpty) {
            final dt = fmt.parse(dataStr);
            if (hoje.difference(dt).inDays >= 90) {
              alterou = true;
              return true;
            }
          }
        } catch (_) {}
        return false;
      });

      if (alterou) {
        await salvarLista(lista);
      }
    } catch (_) {}
  }
}

// ============================================================================
// 2. TELA DE HISTÓRICO DE ORÇAMENTOS SALVOS
// ============================================================================
class TelaListaOrcamentosSalvos extends StatefulWidget {
  const TelaListaOrcamentosSalvos({super.key});

  @override
  State<TelaListaOrcamentosSalvos> createState() => _TelaListaOrcamentosSalvosState();
}

class _TelaListaOrcamentosSalvosState extends State<TelaListaOrcamentosSalvos> {
  List<Map<String, dynamic>> _lista = [];
  String _filtro = '';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await ServicoOrcamentosSalvos.limparAntigos90Dias();
    final orcs = await ServicoOrcamentosSalvos.carregar();
    if (mounted) {
      setState(() {
        _lista = orcs;
        _carregando = false;
      });
    }
  }

  void _aprovarEEnviarParaPendentes(Map<String, dynamic> orc) async {
    final String cliente = orc['cliente_nome'] ?? 'Cliente';
    final double total = (orc['valor_total'] is num) ? (orc['valor_total'] as num).toDouble() : 0.0;
    final String descricao = orc['descricao_itens'] ?? '';

    final dadosFaturamento = {
      'cliente': cliente,
      'telefone': orc['cliente_telefone'] ?? '',
      'cpf_cnpj': orc['cliente_documento'] ?? '',
      'endereco': orc['cliente_endereco'] ?? '',
      'titulo_destaque': orc['titulo_destaque'] ?? 'ORÇAMENTO APROVADO',
      'descricao': descricao,
      'quantidade': 1,
      'valor_unitario': total,
      'status': 'Pendente',
      'tecnico': 'Escritório',
      'data': orc['data'] ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
    };

    try {
      await supabase.from('servicos').insert(dadosFaturamento).timeout(const Duration(seconds: 8));
      orc['status'] = 'Aprovado';
      await ServicoOrcamentosSalvos.salvarOuAtualizar(orc);
      _iniciar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: corVerdeWhats, content: Text('🚀 Orçamento APROVADO e enviado para Serviços Pendentes no Faturamento!')),
        );
      }
    } catch (e) {
      await CacheOffline.salvarServicoFilaOffline(dadosFaturamento);
      orc['status'] = 'Aprovado';
      await ServicoOrcamentosSalvos.salvarOuAtualizar(orc);
      _iniciar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Salvo offline: Enviado para a fila de faturamento!')),
        );
      }
    }
  }

  void _confirmarExcluir(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
        title: const Text('Excluir Orçamento?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: const Text('Deseja realmente apagar este orçamento da sua lista?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sim, Excluir'),
            onPressed: () async {
              await ServicoOrcamentosSalvos.excluir(id);
              Navigator.pop(ctx);
              _iniciar();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.green, content: Text('🗑️ Orçamento excluído da lista!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final filtrados = _lista.where((o) {
      if (_filtro.isEmpty) return true;
      final f = _filtro.toLowerCase();
      final c = (o['cliente_nome'] ?? '').toString().toLowerCase();
      final d = (o['descricao_itens'] ?? '').toString().toLowerCase();
      return c.contains(f) || d.contains(f);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Histórico de Orçamentos', exibirBotaoVoltar: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Filtrar por cliente ou peça...',
                prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: corCianoEletrico))
                : filtrados.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum orçamento salvo no histórico.\n(Orçamentos expiram após 90 dias para economia de memória).',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) {
                          final orc = filtrados[i];
                          final double total = (orc['valor_total'] is num) ? (orc['valor_total'] as num).toDouble() : 0.0;
                          final bool aprovado = orc['status'] == 'Aprovado';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: aprovado ? corVerdeWhats.withAlpha(90) : corCianoEletrico.withAlpha(70)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: aprovado ? const Color(0x2625D366) : const Color(0x2600D4FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          aprovado ? '🟢 APROVADO' : '🟡 AGUARDANDO CLIENTE',
                                          style: TextStyle(color: aprovado ? corVerdeWhats : corCianoEletrico, fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(orc['data'] ?? '', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(orc['cliente_nome'] ?? 'Cliente sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corTextoClaro)),
                                  if (orc['cliente_telefone'] != null && orc['cliente_telefone'].toString().isNotEmpty)
                                    Text("📞 ${orc['cliente_telefone']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                                    child: Text(orc['descricao_itens'] ?? '', style: const TextStyle(fontSize: 12, color: corTextoClaro)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('TOTAL:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corTextoClaro)),
                                      Text(moeda.format(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corCianoEletrico)),
                                    ],
                                  ),
                                  const Divider(height: 14),

                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: corCianoEletrico),
                                          foregroundColor: corCianoEletrico,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('Editar', style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TelaEmissaoDoc(
                                                tipoDoc: 'ORÇAMENTO',
                                                orcamentoParaEditar: orc,
                                              ),
                                            ),
                                          ).then((_) => _iniciar());
                                        },
                                      ),
                                      const Spacer(),
                                      if (!aprovado)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: corVerdeWhats,
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          icon: const Icon(Icons.check_circle_outline, size: 15),
                                          label: const Text('Aprovar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _aprovarEEnviarParaPendentes(orc),
                                        ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                        tooltip: 'Excluir Orçamento',
                                        onPressed: () => _confirmarExcluir(orc['id']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. TELA DE EMISSÃO: DATA FLEXÍVEL, EQUIPAMENTOS TÉCNICOS E AÇÕES RÁPIDAS
// ============================================================================
class TelaEmissaoDoc extends StatefulWidget {
  final String tipoDoc;
  final DadosCliente? clienteInicial;
  final Map<String, dynamic>? orcamentoParaEditar;

  const TelaEmissaoDoc({
    super.key,
    required this.tipoDoc,
    this.clienteInicial,
    this.orcamentoParaEditar,
  });

  @override
  State<TelaEmissaoDoc> createState() => _TelaEmissaoDocState();
}

class _TelaEmissaoDocState extends State<TelaEmissaoDoc> {
  DadosCliente? _clienteAtual;
  final _destaqueCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _laudoCampoCtrl = TextEditingController();
  late final TextEditingController _dataDocCtrl;

  final List<ItemServico> _itens = [];
  final List<EquipamentoRelatorio> _equipamentos = [];
  final List<FotoRelatorio> _fotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _gerandoPdf = false;
  dynamic _idServicoFaturamentoOrigem;
  String? _idOrcamentoEditando;

  double get _totalGeral => _itens.fold(0.0, (acc, item) => acc + item.subtotal);

  @override
  void initState() {
    super.initState();
    _clienteAtual = widget.clienteInicial;
    _dataDocCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));

    if (widget.orcamentoParaEditar != null) {
      final orc = widget.orcamentoParaEditar!;
      _idOrcamentoEditando = orc['id'];
      _clienteAtual = DadosCliente(
        nome: orc['cliente_nome'] ?? '',
        telefone: orc['cliente_telefone'] ?? '',
        documento: orc['cliente_documento'] ?? '',
        endereco: orc['cliente_endereco'] ?? '',
      );
      _destaqueCtrl.text = orc['titulo_destaque'] ?? '';
      _obsCtrl.text = orc['obs'] ?? '';
      _laudoCampoCtrl.text = orc['laudo_descritivo'] ?? '';
      if (orc['data'] != null && orc['data'].toString().isNotEmpty) {
        _dataDocCtrl.text = orc['data'];
      }

      final double val = (orc['valor_total'] is num) ? (orc['valor_total'] as num).toDouble() : 0.0;
      _itens.addAll(_converterDescricaoEmItens(orc['descricao_itens'] ?? '', val));

      // Carrega equipamentos salvos caso existam
      if (orc['equipamentos'] != null && orc['equipamentos'] is List) {
        for (var e in (orc['equipamentos'] as List)) {
          _equipamentos.add(EquipamentoRelatorio.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
  }

  @override
  void dispose() {
    _destaqueCtrl.dispose();
    _obsCtrl.dispose();
    _laudoCampoCtrl.dispose();
    _dataDocCtrl.dispose();
    super.dispose();
  }

  // SELETOR DE DATA FLEXÍVEL (RETROATIVA, HOJE OU ADIANTADA)
  Future<void> _selecionarData() async {
    final fmt = DateFormat('dd/MM/yyyy');
    DateTime inicial = DateTime.now();
    try {
      if (_dataDocCtrl.text.isNotEmpty) inicial = fmt.parse(_dataDocCtrl.text);
    } catch (_) {}

    final DateTime? selecionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: corCianoEletrico,
            onPrimary: Colors.black,
            surface: corCardFundo,
            onSurface: corTextoClaro,
          ),
        ),
        child: child!,
      ),
    );

    if (selecionada != null) {
      setState(() {
        _dataDocCtrl.text = fmt.format(selecionada);
      });
    }
  }

  // MODAL PARA ADICIONAR / EDITAR EQUIPAMENTO NO ORÇAMENTO
  void _modalEquipamentoDialog([int? indexEdit]) {
    final bool isEd = indexEdit != null;
    final tipoC = TextEditingController(text: isEd ? _equipamentos[indexEdit].tipo : '');
    final marcaC = TextEditingController(text: isEd ? _equipamentos[indexEdit].marca : '');
    final modeloC = TextEditingController(text: isEd ? _equipamentos[indexEdit].modelo : '');
    final potenciaC = TextEditingController(text: isEd ? _equipamentos[indexEdit].potencia : '');
    final tensaoC = TextEditingController(text: isEd ? _equipamentos[indexEdit].tensao : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: Text(isEd ? '✏️ Editar Equipamento' : '⚙️ Equipamento do Orçamento', style: const TextStyle(color: corCianoEletrico, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tipoC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tipo de Equipamento', hintText: 'Ex: Bomba de Recalque 1, Motor...', isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: marcaC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Marca', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: modeloC, decoration: const InputDecoration(labelText: 'Modelo', isDense: true))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: potenciaC, decoration: const InputDecoration(labelText: 'Potência', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: tensaoC, decoration: const InputDecoration(labelText: 'Tensão', isDense: true))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
            child: const Text('Salvar'),
            onPressed: () {
              if (tipoC.text.trim().isEmpty) return;
              setState(() {
                final eq = EquipamentoRelatorio(
                  tipo: tipoC.text.trim(),
                  marca: marcaC.text.trim().isNotEmpty ? marcaC.text.trim() : '-',
                  modelo: modeloC.text.trim().isNotEmpty ? modeloC.text.trim() : '-',
                  potencia: potenciaC.text.trim().isNotEmpty ? potenciaC.text.trim() : '-',
                  tensao: tensaoC.text.trim().isNotEmpty ? tensaoC.text.trim() : '-',
                );
                if (isEd) {
                  _equipamentos[indexEdit] = eq;
                } else {
                  _equipamentos.add(eq);
                }
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _marcarServicoComoFaturadoSeAplicavel() async {
    if (widget.tipoDoc == 'RECIBO' && _idServicoFaturamentoOrigem != null) {
      try {
        await supabase.from('servicos').update({
          'status': 'Faturado',
          'data': _dataDocCtrl.text.trim(),
        }).eq('id', _idServicoFaturamentoOrigem);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: corVerdeWhats, content: Text('✅ Serviço vinculado foi marcado como FATURADO na nuvem!')),
          );
        }
      } catch (_) {}
    }
  }

  List<ItemServico> _converterDescricaoEmItens(String descricao, num valorTotal) {
    if (descricao.trim().isEmpty) return [];
    final partes = descricao.split(' | ');
    final List<ItemServico> resultado = [];

    for (var p in partes) {
      final itemStr = p.trim();
      final regexCompleto = RegExp(r'^(\d+(?:\.\d+)?)\s*x\s*(.*?)\s*\(\s*R\$\s*(\d+(?:[\.,]\d+)?)\s*\)$');
      final matchCompleto = regexCompleto.firstMatch(itemStr);

      if (matchCompleto != null) {
        final q = double.tryParse(matchCompleto.group(1)!) ?? 1;
        final d = matchCompleto.group(2) ?? '';
        final v = double.tryParse(matchCompleto.group(3)!.replaceAll(',', '.')) ?? 0;
        resultado.add(ItemServico(descricao: d, quantidade: q, valorUnitario: v));
        continue;
      }

      final regexSimples = RegExp(r'^(\d+(?:\.\d+)?)\s*x\s*(.*)$');
      final matchSimples = regexSimples.firstMatch(itemStr);
      if (matchSimples != null) {
        final q = double.tryParse(matchSimples.group(1)!) ?? 1;
        final d = matchSimples.group(2) ?? '';
        resultado.add(ItemServico(descricao: d, quantidade: q, valorUnitario: 0.0));
        continue;
      }

      resultado.add(ItemServico(descricao: itemStr, quantidade: 1, valorUnitario: 0.0));
    }

    if (resultado.length == 1 && resultado.first.valorUnitario == 0 && valorTotal > 0) {
      resultado.first.valorUnitario = valorTotal.toDouble() / resultado.first.quantidade;
    }

    return resultado;
  }

  void _salvarOrcamentoNaLista() async {
    if (_clienteAtual == null || _itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Selecione o cliente e adicione itens!')));
      return;
    }

    final descricaoItens = _itens.map((e) => "${e.quantidade % 1 == 0 ? e.quantidade.toInt() : e.quantidade}x ${e.descricao} (R\$ ${e.valorUnitario.toStringAsFixed(2)})").join(' | ');

    final orc = {
      'id': _idOrcamentoEditando ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'cliente_nome': _clienteAtual!.nome,
      'cliente_telefone': _clienteAtual!.telefone,
      'cliente_documento': _clienteAtual!.documento,
      'cliente_endereco': _clienteAtual!.enderecoCompleto,
      'titulo_destaque': _destaqueCtrl.text.trim().isNotEmpty ? _destaqueCtrl.text.trim() : 'ORÇAMENTO',
      'descricao_itens': descricaoItens,
      'laudo_descritivo': _laudoCampoCtrl.text.trim(),
      'obs': _obsCtrl.text.trim(),
      'valor_total': _totalGeral,
      'data': _dataDocCtrl.text.trim(), // DATA SELECIONADA NO CALENDÁRIO
      'status': widget.orcamentoParaEditar?['status'] ?? 'Pendente',
      'equipamentos': _equipamentos.map((e) => e.toMap()).toList(), // EQUIPAMENTOS SALVOS
    };

    await ServicoOrcamentosSalvos.salvarOuAtualizar(orc);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('💾 Orçamento salvo no Histórico de Orçamentos!')),
      );
    }
  }

  String _prepararLaudoComEquipamentos() {
    String laudo = _laudoCampoCtrl.text.trim();
    if (_equipamentos.isNotEmpty) {
      final eqTxt = _equipamentos.map((e) => "• ${e.tipo} (Marca: ${e.marca} | Modelo: ${e.modelo} | Potência: ${e.potencia} | Tensão: ${e.tensao})").join("\n");
      laudo = "EQUIPAMENTOS EM AVALIAÇÃO:\n$eqTxt\n\n$laudo".trim();
    }
    return laudo;
  }

  Future<void> _dispararImpressaoOuCompartilhamento(bool diretoParaImpressao) async {
    if (_clienteAtual == null || _itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Selecione o cliente e adicione itens!')));
      return;
    }
    setState(() => _gerandoPdf = true);
    try {
      final f = await PdfEngine.apenasGerarPdf(
        tipoDoc: widget.tipoDoc,
        cliente: _clienteAtual!,
        destaque: _destaqueCtrl.text,
        itens: _itens,
        obs: '${_obsCtrl.text.trim()}\nData de Emissão: ${_dataDocCtrl.text.trim()}'.trim(),
        laudoDescritivo: _prepararLaudoComEquipamentos(),
        fotos: _fotos,
      );
      await _marcarServicoComoFaturadoSeAplicavel();

      await Share.shareXFiles(
        [XFile(f.path)],
        text: diretoParaImpressao ? 'Imprimir ${widget.tipoDoc} - ${_clienteAtual!.nome}' : 'Segue ${widget.tipoDoc} - ${_clienteAtual!.nome} (${_dataDocCtrl.text.trim()})',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  void _modalPuxarDoFaturamento() async {
    List<Map<String, dynamic>> pendentes = [];
    try {
      final res = await supabase.from('servicos').select().order('id', ascending: false).timeout(const Duration(seconds: 4));
      pendentes = res.where((s) => s['status'] != 'Faturado').toList();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: corCianoEletrico)),
      builder: (ctx) {
        String f = '';
        return StatefulBuilder(
          builder: (ctx, setS) {
            final filtrados = pendentes.where((s) {
              final c = (s['cliente'] ?? '').toString().toLowerCase();
              final d = (s['descricao'] ?? '').toString().toLowerCase();
              return c.contains(f) || d.contains(f);
            }).toList();

            return Container(
              padding: const EdgeInsets.all(14),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const Text('📥 Puxar Trabalho do Faturamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18), hintText: 'Pesquisar cliente ou serviço...', isDense: true),
                    onChanged: (v) => setS(() => f = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('Nenhum serviço a faturar encontrado.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) {
                              final s = filtrados[i];
                              final num val = s['valor_unitario'] is num ? s['valor_unitario'] : 0;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  title: Text(s['cliente'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                                  subtitle: Text("${s['descricao']}\nValor: R\$ ${val.toStringAsFixed(2)}", style: const TextStyle(color: corCianoSuave, fontSize: 11)),
                                  onTap: () {
                                    setState(() {
                                      _idServicoFaturamentoOrigem = s['id'];
                                      _clienteAtual = DadosCliente(
                                        nome: s['cliente'] ?? '',
                                        telefone: s['telefone'] ?? '',
                                        documento: s['cpf_cnpj'] ?? '',
                                        endereco: s['endereco'] ?? '',
                                      );
                                      _destaqueCtrl.text = 'RECIBO DE PAGAMENTO QUITADO';
                                      _itens.clear();
                                      _itens.addAll(_converterDescricaoEmItens(s['descricao'] ?? '', val));
                                      _obsCtrl.text = "Atendimento técnico: ${s['tecnico'] ?? 'Equipe O.S. PRIME'}";
                                    });
                                    Navigator.pop(ctx);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _modalNovoClienteRapido() {
    final n = TextEditingController(), r = TextEditingController(), f = TextEditingController();
    final d = TextEditingController(), m = TextEditingController(), e = TextEditingController();
    final b = TextEditingController(), c = TextEditingController(), comp = TextEditingController();
    bool salvandoCliente = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: Text('Cadastrar e Usar no ${widget.tipoDoc}', style: const TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: n, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome do Cliente / Condomínio *', isDense: true)),
                  const SizedBox(height: 6),
                  TextField(controller: r, decoration: const InputDecoration(labelText: 'Responsável / Contato', isDense: true)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(controller: f, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: d, decoration: const InputDecoration(labelText: 'CPF ou CNPJ', isDense: true))),
                  ]),
                  const SizedBox(height: 6),
                  TextField(controller: m, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', isDense: true)),
                  const SizedBox(height: 6),
                  TextField(controller: e, decoration: const InputDecoration(labelText: 'Rua e Número', isDense: true)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(controller: b, decoration: const InputDecoration(labelText: 'Bairro', isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: c, decoration: const InputDecoration(labelText: 'Cidade', isDense: true))),
                  ]),
                  const SizedBox(height: 6),
                  TextField(controller: comp, decoration: const InputDecoration(labelText: 'Complemento / Referência', isDense: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              onPressed: salvandoCliente
                  ? null
                  : () async {
                      if (n.text.trim().isEmpty) return;
                      setM(() => salvandoCliente = true);

                      final novoCliente = DadosCliente(
                        nome: n.text.trim(),
                        responsavel: r.text.trim(),
                        telefone: f.text.trim(),
                        documento: d.text.trim(),
                        email: m.text.trim(),
                        endereco: e.text.trim(),
                        bairro: b.text.trim(),
                        cidade: c.text.trim(),
                        complemento: comp.text.trim(),
                      );

                      final locais = await CacheOffline.carregarClientesLocal();
                      locais.removeWhere((item) => item.nome.toLowerCase() == novoCliente.nome.toLowerCase() || (item.id != null && item.id == novoCliente.id));
                      locais.insert(0, novoCliente);
                      await CacheOffline.salvarClientesLocal(locais);

                      try {
                        final res = await supabase.from('clientes').insert(novoCliente.toMap()).select().single().timeout(const Duration(seconds: 5));
                        novoCliente.id = res['id']?.toString();
                      } catch (_) {}

                      setState(() => _clienteAtual = novoCliente);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: salvandoCliente
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Salvar e Puxar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adicionarFoto(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final XFile? foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
        if (foto != null) {
          setState(() {
            _fotos.add(FotoRelatorio(caminhoArquivo: foto.path, legenda: 'Registro de Campo ${_fotos.length + 1} - '));
          });
        }
      } else {
        final List<XFile> fotos = await _picker.pickMultiImage(imageQuality: 70);
        if (fotos.isNotEmpty) {
          setState(() {
            for (var f in fotos) {
              _fotos.add(FotoRelatorio(caminhoArquivo: f.path, legenda: 'Registro de Campo ${_fotos.length + 1} - '));
            }
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro fotos: $e')));
    }
  }

  void _modalEscolherOrigemFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: corCianoEletrico)),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("📸 Anexar Fotos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                leading: const CircleAvatar(backgroundColor: Color(0xFF0F354A), child: Icon(Icons.photo_library, color: corCianoEletrico, size: 20)),
                title: const Text("Escolher da Galeria (Múltiplas)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                subtitle: const Text("Segure o dedo e selecione todas de uma vez", style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _adicionarFoto(ImageSource.gallery);
                },
              ),
              ListTile(
                dense: true,
                leading: const CircleAvatar(backgroundColor: Color(0xFF0F354A), child: Icon(Icons.camera_alt, color: corCianoSuave, size: 20)),
                title: const Text("Tirar Foto com a Câmera", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                onTap: () {
                  Navigator.pop(ctx);
                  _adicionarFoto(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirPopupItem([int? indexEdit]) {
    final bool isEd = indexEdit != null;
    final dCtrl = TextEditingController(text: isEd ? _itens[indexEdit].descricao : '');
    final qCtrl = TextEditingController(text: isEd ? (_itens[indexEdit].quantidade % 1 == 0 ? _itens[indexEdit].quantidade.toInt().toString() : _itens[indexEdit].quantidade.toString()) : '1');
    final vCtrl = TextEditingController(text: isEd ? _itens[indexEdit].valorUnitario.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: Text(isEd ? '✏️ Editar Item' : '➕ Adicionar Item / Peça', style: const TextStyle(color: corCianoEletrico, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dCtrl,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Descrição Completa / Peça / Serviço', alignLabelWithHint: true),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: qCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Qtd', isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: vCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor Unit.', isDense: true))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('Salvar'),
            onPressed: () {
              if (dCtrl.text.trim().isEmpty) return;
              final q = double.tryParse(qCtrl.text.replaceAll(',', '.')) ?? 1;
              final v = double.tryParse(vCtrl.text.replaceAll(',', '.')) ?? 0;
              setState(() {
                if (isEd) {
                  _itens[indexEdit].descricao = dCtrl.text.trim();
                  _itens[indexEdit].quantidade = q;
                  _itens[indexEdit].valorUnitario = v;
                } else {
                  _itens.add(ItemServico(descricao: dCtrl.text.trim(), quantidade: q, valorUnitario: v));
                }
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _buscarClientes() async {
    final lista = await ServicoClientes.carregarClientes();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: corCianoEletrico)),
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(builder: (ctx, setM) {
          final filtrados = lista.where((c) => c.nome.toLowerCase().contains(filtro) || c.telefone.contains(filtro)).toList();
          return Container(
            padding: const EdgeInsets.all(14),
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(children: [
              const Text('🔍 Selecionar Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
              const SizedBox(height: 8),
              TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18), hintText: 'Pesquisar cliente...', isDense: true), onChanged: (v) => setM(() => filtro = v.toLowerCase())),
              const SizedBox(height: 8),
              Expanded(
                child: filtrados.isEmpty
                    ? const Center(child: Text('Nenhum cliente cadastrado.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0F354A), child: Icon(Icons.person, color: corCianoEletrico, size: 16)),
                          title: Text(filtrados[i].nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                          subtitle: Text(filtrados[i].telefone, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          onTap: () {
                            setState(() => _clienteAtual = filtrados[i]);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
              ),
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final bool isRecibo = widget.tipoDoc == 'RECIBO';
    final bool isOrcamento = widget.tipoDoc == 'ORÇAMENTO';

    return Scaffold(
      body: Column(
        children: [
          BannerOSPrime(
            subtituloTela: isRecibo ? 'Emissão de Recibo' : 'Emissão de Orçamento',
            exibirBotaoVoltar: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(12), border: Border.all(color: _clienteAtual == null ? const Color(0x80FFC107) : const Color(0x6600D4FF))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_clienteAtual == null)
                          const Text('Nenhum cliente selecionado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent))
                        else ...[
                          Text(_clienteAtual!.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corTextoClaro)),
                          Text("📞 ${_clienteAtual!.telefone} | Doc: ${_clienteAtual!.documento}", style: const TextStyle(fontSize: 11, color: corCianoSuave)),
                          Text("📍 ${_clienteAtual!.enderecoCompleto}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isRecibo) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: corVerdeWhats,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                icon: const Icon(Icons.cloud_download, size: 14),
                                label: const Text('Puxar Faturamento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _modalPuxarDoFaturamento,
                              ),
                              const SizedBox(width: 6),
                            ],
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: corCianoEletrico),
                                foregroundColor: corCianoEletrico,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              icon: const Icon(Icons.person_add_alt_1, size: 14),
                              label: const Text('+ Novo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: _modalNovoClienteRapido,
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              icon: const Icon(Icons.search, size: 14),
                              label: Text(_clienteAtual == null ? 'Buscar' : 'Trocar', style: const TextStyle(fontSize: 11)),
                              onPressed: _buscarClientes,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ============================================================
                  // TÍTULO DESTAQUE + SELETOR DE DATA FLEXÍVEL (CALENDÁRIO)
                  // ============================================================
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _destaqueCtrl,
                          decoration: const InputDecoration(labelText: 'Título / Faixa Destaque no PDF', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _selecionarData,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: corCardFundo,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: corCianoEletrico.withAlpha(90)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, color: corCianoEletrico, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _dataDocCtrl.text,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: corTextoClaro),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ============================================================
                  // SEÇÃO DE EQUIPAMENTOS DO ORÇAMENTO (TIPO, MARCA, POTÊNCIA...)
                  // ============================================================
                  if (isOrcamento) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_suggest, color: corCianoEletrico, size: 18),
                            const SizedBox(width: 6),
                            Text("Equipamentos em Orçamento (${_equipamentos.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corCianoEletrico)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corCianoEletrico,
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Equipamento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _modalEquipamentoDialog(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_equipamentos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                        child: const Center(
                          child: Text(
                            'Nenhum equipamento adicionado. (Opcional - Adicione bombas, motores, inversores...)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                      )
                    else
                      ..._equipamentos.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final eq = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(eq.tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                            subtitle: Text(
                              "Marca: ${eq.marca} | Modelo: ${eq.modelo}\nPotência: ${eq.potencia} | Tensão: ${eq.tensao}",
                              style: const TextStyle(color: corCianoSuave, fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit, color: corCianoSuave, size: 16), onPressed: () => _modalEquipamentoDialog(idx)),
                                IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: () => setState(() => _equipamentos.removeAt(idx))),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 10),
                  ],

                  // ============================================================
                  // ITENS E PEÇAS
                  // ============================================================
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Itens e Peças:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corCianoEletrico)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Adicionar Item', style: TextStyle(fontSize: 11)),
                      onPressed: () => _abrirPopupItem(),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  if (_itens.isEmpty)
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('Nenhum item adicionado.', style: TextStyle(color: Colors.grey, fontSize: 12))))
                  else
                    ..._itens.asMap().entries.map((entry) {
                      final i = entry.key; final it = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(it.descricao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                          subtitle: Text("${it.quantidade % 1 == 0 ? it.quantidade.toInt() : it.quantidade} un x ${moeda.format(it.valorUnitario)} = ${moeda.format(it.subtotal)}", style: const TextStyle(color: corCianoEletrico, fontSize: 11)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, color: corCianoSuave, size: 16), onPressed: () => _abrirPopupItem(i)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: () => setState(() => _itens.removeAt(i))),
                          ]),
                        ),
                      );
                    }),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _laudoCampoCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Laudo Técnico Pericial de Campo (Vinculado às Fotos)',
                      hintText: 'Descreva o estado das bombas, comandos ou motivos da troca...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(controller: _obsCtrl, decoration: const InputDecoration(labelText: 'Observação / Condições de Garantia', isDense: true)),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.photo_camera_back, color: corCianoEletrico, size: 18),
                        const SizedBox(width: 6),
                        Text("Fotos do Laudo (${_fotos.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corCianoEletrico)),
                      ]),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corCianoEletrico,
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: const Icon(Icons.add_a_photo, size: 14),
                        label: const Text('Anexar Fotos', style: TextStyle(fontSize: 11)),
                        onPressed: _modalEscolherOrigemFoto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_fotos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                      child: const Center(child: Text('Nenhuma foto anexada. Toque em "Anexar Fotos" acima.', style: TextStyle(color: Colors.grey, fontSize: 11))),
                    )
                  else
                    ..._fotos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final foto = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(File(foto.caminhoArquivo), width: 50, height: 50, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(text: foto.legenda)..selection = TextSelection.collapsed(offset: foto.legenda.length),
                                  decoration: InputDecoration(
                                    labelText: 'Legenda Foto ${idx + 1}',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  onChanged: (v) => foto.legenda = v,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                tooltip: 'Excluir esta foto',
                                onPressed: () => setState(() => _fotos.removeAt(idx)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(8), border: Border.all(color: corCianoEletrico)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('TOTAL DO DOCUMENTO:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: corTextoClaro)),
                      Text(moeda.format(_totalGeral), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: corCianoEletrico)),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ============================================================
                  // LINHA 1: BOTÕES COMPACTOS DE AÇÃO (PDF, WHATSAPP E IMPRIMIR)
                  // ============================================================
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: corCianoEletrico),
                              foregroundColor: corCianoEletrico,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.save_alt, size: 15),
                            label: const Text('SALVAR PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                            onPressed: _gerandoPdf ? null : () => _dispararImpressaoOuCompartilhamento(false),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: corVerdeWhats,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.share, size: 15),
                            label: const Text('WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                            onPressed: () {
                              if (_clienteAtual == null || _itens.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Selecione o cliente e adicione itens!')));
                                return;
                              }
                              PdfEngine.gerarECompartilhar(
                                tipoDoc: widget.tipoDoc,
                                cliente: _clienteAtual!,
                                destaque: _destaqueCtrl.text,
                                itens: _itens,
                                obs: '${_obsCtrl.text.trim()}\nData de Emissão: ${_dataDocCtrl.text.trim()}'.trim(),
                                laudoDescritivo: _prepararLaudoComEquipamentos(),
                                fotos: _fotos,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F242C),
                              foregroundColor: corCianoEletrico,
                              side: const BorderSide(color: corCianoEletrico),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.print, size: 15),
                            label: const Text('IMPRIMIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                            onPressed: _gerandoPdf ? null : () => _dispararImpressaoOuCompartilhamento(true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ============================================================
                  // LINHA 2: SALVAR NA LISTA + HISTÓRICO DE ORÇAMENTOS (ORÇAMENTO)
                  // ============================================================
                  if (isOrcamento) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F354A),
                                foregroundColor: corCianoEletrico,
                                side: const BorderSide(color: corCianoEletrico, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                              label: const Text(
                                'SALVAR NA LISTA',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              onPressed: _salvarOrcamentoNaLista,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                                foregroundColor: Colors.amberAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.folder_special_rounded, size: 16),
                              label: const Text(
                                'HISTÓRICO',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TelaListaOrcamentosSalvos()),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // LINHA 2 PARA O RECIBO: SALVAR NO FATURAMENTO
                  if (isRecibo) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: corCianoSuave, visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: const Text('Salvar no Faturamento', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          if (_clienteAtual == null || _itens.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Selecione o cliente e adicione itens!')));
                            return;
                          }
                          final dados = {
                            'cliente': _clienteAtual!.nome,
                            'telefone': _clienteAtual!.telefone,
                            'cpf_cnpj': _clienteAtual!.documento,
                            'endereco': _clienteAtual!.enderecoCompleto,
                            'titulo_destaque': _destaqueCtrl.text.trim(),
                            'descricao': _itens.map((e) => "${e.quantidade % 1 == 0 ? e.quantidade.toInt() : e.quantidade}x ${e.descricao} (R\$ ${e.valorUnitario.toStringAsFixed(2)})").join(' | '),
                            'quantidade': 1,
                            'valor_unitario': _totalGeral,
                            'status': 'Faturado',
                            'tecnico': 'Escritório',
                            'data': _dataDocCtrl.text.trim(),
                          };
                          try {
                            await supabase.from('servicos').insert(dados).timeout(const Duration(seconds: 10));
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Salvo no faturamento com sucesso!')));
                          } catch (e) {
                            await CacheOffline.salvarServicoFilaOffline(dados);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('⚠️ Salvo offline: $e')));
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

