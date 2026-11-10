// ============================================================================
// RELATÓRIO / LAUDO DE CAMPO E BANCADA COM IMPRESSÃO DIRETA E EXPURGO 90 DIAS
// lib/screens/relatorio_condominio_page.dart
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../app_base.dart';

class TelaRelatoriosCondominio extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaRelatoriosCondominio({super.key, required this.usuarioLogado});

  @override
  State<TelaRelatoriosCondominio> createState() => _TelaRelatoriosCondominioState();
}

class _TelaRelatoriosCondominioState extends State<TelaRelatoriosCondominio> {
  List<RelatorioCondominioModel> _relatorios = [];
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _limparLaudosAntigos90Dias();
    await _carregar();
  }

  Future<void> _carregar() async {
    final locais = await CacheOffline.carregarRelatoriosCondominioLocal();
    if (mounted) setState(() => _relatorios = locais);
  }

  // AUTO-LIMPEZA: Descarta fotos pesadas após 90 dias mantendo o laudo técnico
  Future<void> _limparLaudosAntigos90Dias() async {
    try {
      final lista = await CacheOffline.carregarRelatoriosCondominioLocal();
      final hoje = DateTime.now();
      final fmt = DateFormat('dd/MM/yyyy');
      bool alterou = false;

      for (var r in lista) {
        if (r.dataEmissao.isNotEmpty && r.fotos.isNotEmpty) {
          try {
            final dataLimpa = r.dataEmissao.split('-')[0].split('•')[0].trim();
            final dt = fmt.parse(dataLimpa);
            if (hoje.difference(dt).inDays >= 90) {
              for (var f in r.fotos) {
                try {
                  final arq = File(f.caminhoArquivo);
                  if (await arq.exists()) await arq.delete();
                } catch (_) {}
              }
              r.fotos.clear();
              alterou = true;
            }
          } catch (_) {}
        }
      }

      if (alterou) {
        await CacheOffline.salvarRelatoriosCondominioLocal(lista);
      }
    } catch (_) {}
  }

  void _abrirFormularioRelatorio([RelatorioCondominioModel? relatorioExistente]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioRelatorioCondominioPage(
          relatorioExistente: relatorioExistente,
          usuarioLogado: widget.usuarioLogado,
        ),
      ),
    ).then((_) => _carregar());
  }

  void _confirmarExcluir(RelatorioCondominioModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
        title: const Text('Excluir Registro?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: Text('Deseja realmente apagar o documento de "${r.nomeCondominio}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sim, Excluir'),
            onPressed: () async {
              _relatorios.removeWhere((item) => item.id == r.id);
              await CacheOffline.salvarRelatoriosCondominioLocal(_relatorios);
              if (ctx.mounted) Navigator.pop(ctx);
              _carregar();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _gerarECompartilharPdf(RelatorioCondominioModel r, String modo) async {
    try {
      final File f = await PdfEngine.gerarPdfRelatorioCompleto(r);
      String txt = 'Segue ${r.tipoDocumento} - ${r.nomeCondominio}';
      if (modo == 'imprimir') {
        txt = 'Imprimir ${r.tipoDocumento} - ${r.nomeCondominio}';
      } else if (modo == 'whats') {
        txt = 'Olá! Segue o laudo técnico do condomínio *${r.nomeCondominio}* em PDF.';
      }
      await Share.shareXFiles([XFile(f.path)], text: txt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao gerar documento: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _relatorios.where((r) {
      if (_filtro.isEmpty) return true;
      final f = _filtro.toLowerCase();
      return r.nomeCondominio.toLowerCase().contains(f) ||
          r.sindicoResponsavel.toLowerCase().contains(f) ||
          r.tituloLaudo.toLowerCase().contains(f) ||
          r.tipoDocumento.toLowerCase().contains(f);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          BannerOSPrime(
            subtituloTela: 'Relatórios & Laudos de Campo',
            exibirBotaoVoltar: true,
            acaoDireita: IconButton(
              icon: const Icon(Icons.add_circle, color: corCianoEletrico, size: 22),
              tooltip: 'Novo Laudo/Relatório',
              onPressed: () => _abrirFormularioRelatorio(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18),
                      hintText: 'Buscar condomínio, laudo, síndico...',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _filtro = v),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corCianoEletrico,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Novo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _abrirFormularioRelatorio(),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum relatório ou laudo salvo.\n(Fotos são limpas após 90 dias para poupar memória).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final r = filtrados[i];
                      final bool isBancada = r.tipoDocumento.contains('BANCADA');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isBancada ? Colors.amberAccent.withAlpha(90) : corCianoEletrico.withAlpha(60)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(r.nomeCondominio, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corTextoClaro)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBancada ? const Color(0x33FFC107) : const Color(0x3300D4FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      r.tipoDocumento,
                                      style: TextStyle(fontSize: 9.5, color: isBancada ? Colors.amberAccent : corCianoSuave, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (r.tituloLaudo.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text("📋 ${r.tituloLaudo}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corCianoSuave)),
                              ],
                              const SizedBox(height: 4),
                              Text("👤 Síndico: ${r.sindicoResponsavel} | 📞 ${r.telefone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              if (r.enderecoCompleto.isNotEmpty) Text("📍 ${r.enderecoCompleto}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.settings_suggest, size: 14, color: corCianoSuave),
                                  const SizedBox(width: 4),
                                  Text("${r.equipamentos.length} equip.", style: const TextStyle(fontSize: 11, color: corCianoSuave, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.photo_library, size: 14, color: corCianoSuave),
                                  const SizedBox(width: 4),
                                  Text("${r.fotos.length} foto(s)", style: const TextStyle(fontSize: 11, color: corCianoSuave)),
                                  const Spacer(),
                                  Text("Data: ${r.dataEmissao}", style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              ),
                              const Divider(height: 14),

                              // AÇÕES COMPLETAS: EDITAR, PDF, WHATSAPP E IMPRIMIR
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.edit, size: 14, color: corCianoSuave),
                                    label: const Text('Editar', style: TextStyle(color: corCianoSuave, fontSize: 11)),
                                    onPressed: () => _abrirFormularioRelatorio(r),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.picture_as_pdf, size: 14, color: corCianoEletrico),
                                    label: const Text('PDF', style: TextStyle(color: corCianoEletrico, fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _gerarECompartilharPdf(r, 'pdf'),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.share, size: 14, color: corVerdeWhats),
                                    label: const Text('Whats', style: TextStyle(color: corVerdeWhats, fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _gerarECompartilharPdf(r, 'whats'),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                    icon: const Icon(Icons.print, size: 14, color: Colors.amberAccent),
                                    label: const Text('Imprimir', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _gerarECompartilharPdf(r, 'imprimir'),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                    tooltip: 'Excluir',
                                    onPressed: () => _confirmarExcluir(r),
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
// FORMULÁRIO COM SELEÇÃO MÚLTIPLA DE FOTOS
// ============================================================================
class FormularioRelatorioCondominioPage extends StatefulWidget {
  final RelatorioCondominioModel? relatorioExistente;
  final UsuarioApp usuarioLogado;

  const FormularioRelatorioCondominioPage({super.key, this.relatorioExistente, required this.usuarioLogado});

  @override
  State<FormularioRelatorioCondominioPage> createState() => _FormularioRelatorioCondominioPageState();
}

class _FormularioRelatorioCondominioPageState extends State<FormularioRelatorioCondominioPage> {
  String _tipoDocumento = 'RELATÓRIO TÉCNICO DE CAMPO';
  final _condominioCtrl = TextEditingController();
  final _sindicoCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _tituloLaudoCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _recomendacoesCtrl = TextEditingController();

  final List<EquipamentoRelatorio> _equipamentos = [];
  final List<FotoRelatorio> _fotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final r = widget.relatorioExistente;
    if (r != null) {
      _tipoDocumento = r.tipoDocumento;
      _condominioCtrl.text = r.nomeCondominio;
      _sindicoCtrl.text = r.sindicoResponsavel;
      _telefoneCtrl.text = r.telefone;
      _cnpjCtrl.text = r.cnpjCpf;
      _enderecoCtrl.text = r.enderecoCompleto;
      _tituloLaudoCtrl.text = r.tituloLaudo;
      _diagnosticoCtrl.text = r.diagnosticoTecnico;
      _recomendacoesCtrl.text = r.recomendacoesServicos;
      _equipamentos.addAll(r.equipamentos);
      _fotos.addAll(r.fotos);
    }
  }

  @override
  void dispose() {
    _condominioCtrl.dispose();
    _sindicoCtrl.dispose();
    _telefoneCtrl.dispose();
    _cnpjCtrl.dispose();
    _enderecoCtrl.dispose();
    _tituloLaudoCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _recomendacoesCtrl.dispose();
    super.dispose();
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
        String f = '';
        return StatefulBuilder(
          builder: (ctx, setM) {
            final filtrados = lista.where((c) => c.nome.toLowerCase().contains(f) || c.telefone.contains(f)).toList();
            return Container(
              padding: const EdgeInsets.all(14),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const Text('🔍 Puxar Condomínio Cadastrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18), hintText: 'Pesquisar...', isDense: true),
                    onChanged: (v) => setM(() => f = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('Nenhum cadastro encontrado.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0F354A), child: Icon(Icons.apartment, color: corCianoEletrico, size: 16)),
                              title: Text(filtrados[i].nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                              subtitle: Text(filtrados[i].enderecoCompleto.isNotEmpty ? filtrados[i].enderecoCompleto : filtrados[i].telefone, style: const TextStyle(color: corCianoSuave, fontSize: 11)),
                              onTap: () {
                                setState(() {
                                  _condominioCtrl.text = filtrados[i].nome;
                                  _sindicoCtrl.text = filtrados[i].responsavel;
                                  _telefoneCtrl.text = filtrados[i].telefone;
                                  _cnpjCtrl.text = filtrados[i].documento;
                                  _enderecoCtrl.text = filtrados[i].enderecoCompleto;
                                });
                                Navigator.pop(ctx);
                              },
                            ),
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
        title: Text(isEd ? '✏️ Editar Equipamento' : '⚙️ Adicionar Equipamento', style: const TextStyle(color: corCianoEletrico, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tipoC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tipo do Equipamento', hintText: 'Ex: Bomba de Recalque 1...', isDense: true),
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

  Future<void> _adicionarFoto(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final XFile? foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
        if (foto != null) {
          setState(() {
            _fotos.add(FotoRelatorio(caminhoArquivo: foto.path, legenda: 'Registro Pericial ${_fotos.length + 1} - '));
          });
        }
      } else {
        final List<XFile> fotosSelecionadas = await _picker.pickMultiImage(imageQuality: 70);
        if (fotosSelecionadas.isNotEmpty) {
          setState(() {
            for (var foto in fotosSelecionadas) {
              _fotos.add(FotoRelatorio(caminhoArquivo: foto.path, legenda: 'Registro Pericial ${_fotos.length + 1} - '));
            }
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro fotos: $e')));
    }
  }

  void _modalOrigemFoto() {
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
              const Text("📸 Adicionar Fotos ao Laudo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                leading: const CircleAvatar(backgroundColor: Color(0xFF0F354A), child: Icon(Icons.photo_library, color: corCianoEletrico, size: 20)),
                title: const Text("Escolher Várias da Galeria (Múltiplas)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
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

  Future<void> _salvarRelatorio() async {
    final nome = _condominioCtrl.text.trim();
    final diagnostico = _diagnosticoCtrl.text.trim();

    if (nome.isEmpty || diagnostico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha o condomínio e o diagnóstico técnico!')));
      return;
    }

    setState(() => _salvando = true);

    final lista = await CacheOffline.carregarRelatoriosCondominioLocal();
    final idRelatorio = widget.relatorioExistente?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final relatorio = RelatorioCondominioModel(
      id: idRelatorio,
      tipoDocumento: _tipoDocumento,
      nomeCondominio: nome,
      sindicoResponsavel: _sindicoCtrl.text.trim(),
      telefone: _telefoneCtrl.text.trim(),
      cnpjCpf: _cnpjCtrl.text.trim(),
      enderecoCompleto: _enderecoCtrl.text.trim(),
      tituloLaudo: _tituloLaudoCtrl.text.trim().isNotEmpty ? _tituloLaudoCtrl.text.trim() : 'LAUDO TÉCNICO DE INSPEÇÃO PREDIAL',
      equipamentos: _equipamentos,
      diagnosticoTecnico: diagnostico,
      recomendacoesServicos: _recomendacoesCtrl.text.trim(),
      tecnicoResponsavel: widget.usuarioLogado.nome,
      dataEmissao: widget.relatorioExistente?.dataEmissao ?? DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now()),
      fotos: _fotos,
    );

    lista.removeWhere((item) => item.id == idRelatorio);
    lista.insert(0, relatorio);
    await CacheOffline.salvarRelatoriosCondominioLocal(lista);

    setState(() => _salvando = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Documento técnico salvo com sucesso!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BannerOSPrime(
            subtituloTela: widget.relatorioExistente != null ? 'Editar Documento' : 'Novo Laudo / Relatório',
            exibirBotaoVoltar: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: corCardFundo,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _tipoDocumento.contains('BANCADA') ? Colors.amberAccent : corCianoEletrico, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _tipoDocumento.contains('BANCADA') ? Icons.engineering : Icons.assignment,
                          color: _tipoDocumento.contains('BANCADA') ? Colors.amberAccent : corCianoEletrico,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _tipoDocumento,
                              dropdownColor: corCardFundo,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'RELATÓRIO TÉCNICO DE CAMPO',
                                  child: Text('Relatório Técnico de Campo', style: TextStyle(fontSize: 12.5, color: corCianoSuave, fontWeight: FontWeight.bold)),
                                ),
                                DropdownMenuItem(
                                  value: 'LAUDO TÉCNICO DE CAMPO E BANCADA',
                                  child: Text('Laudo Técnico de Campo e Bancada', style: TextStyle(fontSize: 12.5, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                              onChanged: (v) => setState(() => _tipoDocumento = v ?? 'RELATÓRIO TÉCNICO DE CAMPO'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x6600D4FF))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Dados do Condomínio / Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: corCianoEletrico), foregroundColor: corCianoEletrico, visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                              icon: const Icon(Icons.search, size: 14),
                              label: const Text('Buscar', style: TextStyle(fontSize: 11)),
                              onPressed: _buscarClientes,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(controller: _condominioCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome do Condomínio / Edifício', isDense: true)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _sindicoCtrl, decoration: const InputDecoration(labelText: 'Síndico / Contato', isDense: true))),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(controller: _telefoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', isDense: true))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(controller: _cnpjCtrl, decoration: const InputDecoration(labelText: 'CNPJ do Condomínio', isDense: true)),
                        const SizedBox(height: 6),
                        TextField(controller: _enderecoCtrl, decoration: const InputDecoration(labelText: 'Endereço Completo', isDense: true)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextField(controller: _tituloLaudoCtrl, decoration: const InputDecoration(labelText: 'Título do Laudo (Ex: AVALIAÇÃO TÉCNICA DAS BOMBAS)', isDense: true)),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings_suggest, color: corCianoEletrico, size: 18),
                          const SizedBox(width: 6),
                          Text("Equipamentos em Laudo (${_equipamentos.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corCianoEletrico)),
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
                        label: const Text('Adicionar Equipamento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _modalEquipamentoDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_equipamentos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                      child: const Center(child: Text('Nenhum equipamento adicionado.\nToque em "Adicionar Equipamento" para registrar tipo, marca, potência e tensão.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11))),
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

                  const SizedBox(height: 12),
                  TextField(
                    controller: _diagnosticoCtrl,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Texto Descritivo / Diagnóstico Técnico e Constatações',
                      hintText: 'Descreva detalhadamente o estado das bombas, ruídos, vazamentos, comandos, vibrações...',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: _recomendacoesCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Recomendações Técnicas e Serviços Propostos',
                      hintText: 'Descreva os serviços recomendados, peças a substituir com urgência...',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_library, color: corCianoEletrico, size: 18),
                          const SizedBox(width: 6),
                          Text("Laudo Fotográfico (${_fotos.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corCianoEletrico)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corCianoEletrico,
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: const Icon(Icons.add_a_photo, size: 14),
                        label: const Text('Anexar Fotos', style: TextStyle(fontSize: 11)),
                        onPressed: _modalOrigemFoto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_fotos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
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
                                child: Image.file(File(foto.caminhoArquivo), width: 52, height: 52, fit: BoxFit.cover),
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

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      icon: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.save, size: 18),
                      label: Text(_salvando ? 'Salvando...' : 'SALVAR LAUDO / RELATÓRIO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _salvando ? null : _salvarRelatorio,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

