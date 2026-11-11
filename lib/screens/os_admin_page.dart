// ============================================================================
// GESTÃO DE O.S. (ADMIN): DESPACHO DIRETO, SEM OPÇÃO GERAL, BUSCA E PUSH ONESIGNAL
// lib/screens/os_admin_page.dart (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_base.dart';
import '../models/os_model.dart';

class TelaOSAdmin extends StatefulWidget {
  const TelaOSAdmin({super.key});

  @override
  State<TelaOSAdmin> createState() => _TelaOSAdminState();
}

class _TelaOSAdminState extends State<TelaOSAdmin> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  List<OrdemServico> _offlineOS = [];
  List<UsuarioApp> _tecnicos = [];
  String _filtroStatus = 'Ativas';
  String _filtroPesquisa = '';
  bool _mostrarBusca = false;

  // Filtro estrito: apenas técnicos reais e sêniors (remove masters da escala de campo)
  List<UsuarioApp> get _tecnicosDeCampo =>
      _tecnicos.where((u) => !u.isMaster && u.usuario.trim().toLowerCase() != 'admin').toList();

  @override
  void initState() {
    super.initState();
    _stream = Supabase.instance.client
        .from('ordens_servico')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false);
    _carregarOfflineETecnicos();
    _executarLimpezaInicial();
  }

  Future<void> _carregarOfflineETecnicos() async {
    final locais = await ServicoOS.carregarLocal();
    try {
      final res = await Supabase.instance.client.from('usuarios').select().order('nome');
      _tecnicos = res.map((m) => UsuarioApp.fromMap(m)).toList();
    } catch (_) {
      _tecnicos = await CacheOffline.carregarUsuariosLocais();
    }
    if (mounted) {
      setState(() => _offlineOS = locais);
    }
  }

  Future<void> _executarLimpezaInicial() async {
    try {
      final res = await Supabase.instance.client.from('ordens_servico').select();
      final lista = (res as List).map((m) => OrdemServico.fromMap(m)).toList();
      _limparOSAntigas90Dias(lista);
    } catch (_) {}
  }

  void _limparOSAntigas90Dias(List<OrdemServico> lista) {
    final hoje = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy');
    for (var os in lista) {
      if (os.id != null && os.dataAbertura.isNotEmpty) {
        try {
          final dataLimpa = os.dataAbertura.split('•')[0].trim();
          final dt = fmt.parse(dataLimpa);
          if (hoje.difference(dt).inDays >= 90) {
            Supabase.instance.client.from('ordens_servico').delete().eq('id', os.id!).then((_) {});
          }
        } catch (_) {}
      }
    }
  }

  Color _corPrioridade(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'emergência':
      case 'emergencia':
        return Colors.redAccent;
      case 'urgente':
        return Colors.orangeAccent;
      case 'plantão':
      case 'plantao':
        return Colors.purpleAccent;
      default:
        return corCianoEletrico;
    }
  }

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'concluída':
      case 'concluida':
        return corVerdeWhats;
      case 'em andamento':
        return Colors.amberAccent;
      case 'faturada':
        return const Color(0xFF00E5FF);
      default:
        return corCianoSuave;
    }
  }

  Future<void> _gerarDocOS(OrdemServico os, String acao) async {
    try {
      final clienteObj = DadosCliente(
        nome: os.cliente,
        telefone: os.telefone,
        endereco: os.endereco,
      );

      final relatorioTec = (os.observacaoTecnico != null && os.observacaoTecnico!.isNotEmpty)
          ? '\n\nRelatório de Execução:\n${os.observacaoTecnico}'
          : '';

      final f = await PdfEngine.apenasGerarPdf(
        tipoDoc: 'ORDEM DE SERVIÇO',
        cliente: clienteObj,
        destaque: 'ORDEM DE SERVIÇO - ${os.numeroOS}',
        itens: [
          ItemServico(
            descricao: '${os.descricaoProblema}$relatorioTec',
            quantidade: 1,
            valorUnitario: 0.0,
          ),
        ],
        obs: 'Prioridade: ${os.prioridade.toUpperCase()} | Técnico: ${os.tecnicoDesignado} | Aberta em: ${os.dataAbertura}',
      );

      if (acao == 'imprimir') {
        await Share.shareXFiles([XFile(f.path)], text: 'Imprimir O.S. ${os.numeroOS}');
      } else if (acao == 'whats') {
        await Share.shareXFiles(
          [XFile(f.path)],
          text: 'Olá! Segue O.S. *${os.numeroOS}* - ${os.cliente}\nPrioridade: ${os.prioridade} | Status: ${os.status}',
        );
      } else {
        await Share.shareXFiles([XFile(f.path)], text: 'O.S. ${os.numeroOS} - ${os.cliente}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro O.S.: $e')));
      }
    }
  }

  void _modalSuperRelatorio(List<OrdemServico> todasOS) {
    String periodoSel = 'Mês Atual';
    String tecnicoSel = 'Todos';
    String prioridadeSel = 'Todas';
    String statusSel = 'Todas';
    bool gerandoRelatorio = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: corCianoEletrico)),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setR) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.analytics_rounded, color: corCianoEletrico, size: 22),
                      SizedBox(width: 8),
                      Text('Relatório Gerencial de O.S.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corCianoEletrico)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Período de Análise:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corCianoSuave)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: periodoSel,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'Hoje', child: Text('Hoje')),
                      DropdownMenuItem(value: 'Mês Atual', child: Text('Mês Atual')),
                      DropdownMenuItem(value: 'Trimestre (90 Dias)', child: Text('Trimestre (Últimos 90 Dias)')),
                      DropdownMenuItem(value: 'Completo (Todas)', child: Text('Completo (Todas as Datas)')),
                    ],
                    onChanged: (v) => setR(() => periodoSel = v ?? 'Mês Atual'),
                  ),
                  const SizedBox(height: 10),
                  const Text('Filtrar por Responsável:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corCianoSuave)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: tecnicoSel,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: 'Todos', child: Text('Todos os Responsáveis')),
                      ..._tecnicosDeCampo.map((u) {
                        String label = u.nome;
                        if (u.isSenior) label += ' (⭐ Sênior)';
                        return DropdownMenuItem(value: u.nome, child: Text(label));
                      }),
                    ],
                    onChanged: (v) => setR(() => tecnicoSel = v ?? 'Todos'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prioridade:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corCianoSuave)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: prioridadeSel,
                              dropdownColor: corCardFundo,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              items: const [
                                DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                                DropdownMenuItem(value: 'Normal', child: Text('Normal/Padrão')),
                                DropdownMenuItem(value: 'Urgente', child: Text('Urgente')),
                                DropdownMenuItem(value: 'Emergência', child: Text('Emergência')),
                                DropdownMenuItem(value: 'Plantão', child: Text('🚨 Plantão')),
                              ],
                              onChanged: (v) => setR(() => prioridadeSel = v ?? 'Todas'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status da O.S.:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corCianoSuave)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: statusSel,
                              dropdownColor: corCardFundo,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              items: const [
                                DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                                DropdownMenuItem(value: 'Pendente', child: Text('Abertas/Pendentes')),
                                DropdownMenuItem(value: 'Em Andamento', child: Text('Em Andamento')),
                                DropdownMenuItem(value: 'Concluída', child: Text('Concluídas')),
                                DropdownMenuItem(value: 'Faturada', child: Text('Faturadas')),
                              ],
                              onChanged: (v) => setR(() => statusSel = v ?? 'Todas'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 10)),
                          icon: gerandoRelatorio
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Gerar Relatório PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: gerandoRelatorio ? null : () => _processarRelatorio(todasOS, periodoSel, tecnicoSel, prioridadeSel, statusSel, false, ctx, setR),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F242C), foregroundColor: Colors.amberAccent, side: const BorderSide(color: Colors.amberAccent), padding: const EdgeInsets.symmetric(vertical: 10)),
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Imprimir Direto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: gerandoRelatorio ? null : () => _processarRelatorio(todasOS, periodoSel, tecnicoSel, prioridadeSel, statusSel, true, ctx, setR),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processarRelatorio(
    List<OrdemServico> todas,
    String periodo,
    String tecnico,
    String prioridade,
    String status,
    bool imprimir,
    BuildContext bCtx,
    StateSetter setR,
  ) async {
    setR(() => true);
    final hoje = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy');

    final filtradas = todas.where((os) {
      if (tecnico != 'Todos' && !os.tecnicoDesignado.toLowerCase().contains(tecnico.toLowerCase())) return false;
      if (prioridade != 'Todas' && os.prioridade.toLowerCase() != prioridade.toLowerCase()) return false;
      if (status != 'Todas' && os.status.toLowerCase() != status.toLowerCase()) return false;

      if (periodo != 'Completo (Todas)' && os.dataAbertura.isNotEmpty) {
        try {
          final dt = fmt.parse(os.dataAbertura.split('•')[0].trim());
          if (periodo == 'Hoje' && (dt.day != hoje.day || dt.month != hoje.month || dt.year != hoje.year)) return false;
          if (periodo == 'Mês Atual' && (dt.month != hoje.month || dt.year != hoje.year)) return false;
          if (periodo == 'Trimestre (90 Dias)' && hoje.difference(dt).inDays > 90) return false;
        } catch (_) {}
      }
      return true;
    }).toList();

    if (filtradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Nenhuma O.S. encontrada para os filtros selecionados.')));
      return;
    }

    final listaFormatada = filtradas.map((os) => {
      'cliente': os.cliente,
      'data': os.dataAbertura,
      'descricao': '[${os.numeroOS} - ${os.prioridade.toUpperCase()}] ${os.descricaoProblema}',
      'tecnico': os.tecnicoDesignado,
      'status': os.status,
      'quantidade': 1,
      'valor_unitario': 0.0,
    }).toList();

    try {
      final f = await PdfEngine.gerarRelatorioFaturamentoPdf(
        tipoRelatorio: 'Relatório Gerencial de O.S. ($periodo)',
        servicos: listaFormatada,
      );
      if (bCtx.mounted) Navigator.pop(bCtx);
      await Share.shareXFiles([XFile(f.path)], text: imprimir ? 'Imprimir Relatório de O.S.' : 'Relatório de Ordens de Serviço');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro relatório: $e')));
    }
  }

  void _buscarClientesParaOS(
    TextEditingController cC,
    TextEditingController eC,
    TextEditingController fC,
    StateSetter setM,
  ) async {
    final lista = await CacheOffline.carregarClientesLocal();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: corCianoEletrico)),
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(
          builder: (ctx, setB) {
            final filtrados = lista
                .where((c) =>
                    c.nome.toLowerCase().contains(filtro) ||
                    c.telefone.contains(filtro) ||
                    c.enderecoCompleto.toLowerCase().contains(filtro))
                .toList();

            return Container(
              padding: const EdgeInsets.all(14),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const Text('🔍 Selecionar Cliente Cadastrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18), hintText: 'Pesquisar nome, telefone ou endereço...', isDense: true),
                    onChanged: (v) => setB(() => filtro = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('Nenhum cliente no cache.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0F354A), child: Icon(Icons.person, color: corCianoEletrico, size: 16)),
                              title: Text(filtrados[i].nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                              subtitle: Text(filtrados[i].enderecoCompleto.isNotEmpty ? filtrados[i].enderecoCompleto : filtrados[i].telefone, style: const TextStyle(color: corCianoSuave, fontSize: 11)),
                              onTap: () {
                                setM(() {
                                  cC.text = filtrados[i].nome;
                                  eC.text = filtrados[i].enderecoCompleto;
                                  fC.text = filtrados[i].telefone;
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

  void _modalNovaOS() async {
    final cC = TextEditingController(), fC = TextEditingController(), eC = TextEditingController(), pC = TextEditingController();
    String prioridadeSel = 'Normal';
    final tecnicosDisponiveis = _tecnicosDeCampo;
    
    String? tecnicoSel = tecnicosDisponiveis.isNotEmpty ? tecnicosDisponiveis.first.nome : null;
    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: const Text('📋 Nova Ordem de Serviço (O.S.)', style: TextStyle(color: corCianoEletrico, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dados do Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: corCianoEletrico),
                          foregroundColor: corCianoEletrico,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        icon: const Icon(Icons.search, size: 14),
                        label: const Text('Buscar Cadastrado', style: TextStyle(fontSize: 11)),
                        onPressed: () => _buscarClientesParaOS(cC, eC, fC, setM),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(controller: cC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Cliente / Condomínio *', isDense: true)),
                  const SizedBox(height: 6),
                  TextField(controller: eC, decoration: const InputDecoration(labelText: 'Endereço da Obra', isDense: true)),
                  const SizedBox(height: 6),
                  TextField(controller: fC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: pC, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Descrição do Problema / O que fazer', alignLabelWithHint: true)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: tecnicoSel,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(labelText: 'Designar Técnico Responsável *', isDense: true),
                    items: tecnicosDisponiveis.map((u) {
                      String rotulo = u.nome;
                      if (u.isSenior) {
                        rotulo += ' (⭐ Sênior)';
                      } else {
                        rotulo += ' (Técnico)';
                      }
                      return DropdownMenuItem(value: u.nome, child: Text(rotulo));
                    }).toList(),
                    onChanged: (v) => setM(() => tecnicoSel = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: prioridadeSel,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(labelText: 'Prioridade', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Normal', child: Text('Normal (Padrão)', style: TextStyle(color: corCianoEletrico))),
                      DropdownMenuItem(value: 'Urgente', child: Text('Urgente', style: TextStyle(color: Colors.orangeAccent))),
                      DropdownMenuItem(value: 'Emergência', child: Text('Emergência Imediata', style: TextStyle(color: Colors.redAccent))),
                      DropdownMenuItem(value: 'Plantão', child: Text('🚨 Plantão Especial', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (v) => setM(() => prioridadeSel = v ?? 'Normal'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
              onPressed: salvando ? null : () async {
                if (cC.text.trim().isEmpty || pC.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha o cliente e o problema.')));
                  return;
                }
                if (tecnicoSel == null || tecnicoSel!.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Selecione um técnico responsável.')));
                  return;
                }

                setM(() => salvando = true);
                final numOS = 'OS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                final novaOS = OrdemServico(
                  numeroOS: numOS,
                  cliente: cC.text.trim(),
                  telefone: fC.text.trim(),
                  endereco: eC.text.trim(),
                  descricaoProblema: pC.text.trim(),
                  tecnicoDesignado: tecnicoSel!,
                  prioridade: prioridadeSel,
                  status: 'Pendente',
                  dataAbertura: DateFormat('dd/MM/yyyy • HH:mm').format(DateTime.now()),
                  visualizadoPeloTecnico: false,
                );

                await ServicoOS.criarOS(novaOS);

                final tecObj = _tecnicos.cast<UsuarioApp?>().firstWhere(
                  (u) => u?.nome.trim().toLowerCase() == tecnicoSel!.trim().toLowerCase(),
                  orElse: () => null,
                );
                final loginTecnico = tecObj != null ? tecObj.usuario : tecnicoSel!;

                ServicoNotificacaoOneSignal.enviarNotificacaoOS(
                  tecnicoLogin: loginTecnico,
                  numeroOS: numOS,
                  cliente: cC.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Criar O.S.'),
            ),
          ],
        ),
      ),
    );
  }

  void _modalEditarOS(OrdemServico os) async {
    final cC = TextEditingController(text: os.cliente);
    final fC = TextEditingController(text: os.telefone);
    final eC = TextEditingController(text: os.endereco);
    final pC = TextEditingController(text: os.descricaoProblema);

    String prioridadeSel = os.prioridade.isNotEmpty ? os.prioridade : 'Normal';
    final tecnicosDisponiveis = _tecnicosDeCampo;

    String? tecnicoSel = os.tecnicoDesignado;
    final existeTec = tecnicosDisponiveis.any((u) => u.nome == tecnicoSel);
    if (!existeTec && tecnicosDisponiveis.isNotEmpty) {
      tecnicoSel = tecnicosDisponiveis.first.nome;
    }

    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amberAccent)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.amberAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Editar ${os.numeroOS}', style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dados do Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: corCianoEletrico),
                          foregroundColor: corCianoEletrico,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        icon: const Icon(Icons.search, size: 14),
                        label: const Text('Buscar Cadastrado', style: TextStyle(fontSize: 11)),
                        onPressed: () => _buscarClientesParaOS(cC, eC, fC, setM),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(controller: cC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Cliente / Condomínio *', isDense: true)),
                  const SizedBox(height: 6),
                  TextField(controller: eC, decoration: const InputDecoration(labelText: 'Endereço da Obra', isDense: true)),
                  const SizedBox(height: 6),
                  TextField(controller: fC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', isDense: true)),
                  const SizedBox(height: 10),
                  TextField(controller: pC, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Descrição do Problema / O que fazer', alignLabelWithHint: true)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: tecnicoSel,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(labelText: 'Designar Técnico Responsável *', isDense: true),
                    items: tecnicosDisponiveis.map((u) {
                      String rotulo = u.nome;
                      if (u.isSenior) {
                        rotulo += ' (⭐ Sênior)';
                      } else {
                        rotulo += ' (Técnico)';
                      }
                      return DropdownMenuItem(value: u.nome, child: Text(rotulo));
                    }).toList(),
                    onChanged: (v) => setM(() => tecnicoSel = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: prioridadeSel,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(labelText: 'Prioridade', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Normal', child: Text('Normal (Padrão)', style: TextStyle(color: corCianoEletrico))),
                      DropdownMenuItem(value: 'Urgente', child: Text('Urgente', style: TextStyle(color: Colors.orangeAccent))),
                      DropdownMenuItem(value: 'Emergência', child: Text('Emergência Imediata', style: TextStyle(color: Colors.redAccent))),
                      DropdownMenuItem(value: 'Plantão', child: Text('🚨 Plantão Especial', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (v) => setM(() => prioridadeSel = v ?? 'Normal'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: salvando ? null : () async {
                if (cC.text.trim().isEmpty || pC.text.trim().isEmpty) return;
                setM(() => salvando = true);

                final novoTecnicoNome = tecnicoSel ?? os.tecnicoDesignado;
                final bool mudouTecnico = novoTecnicoNome.trim().toLowerCase() != os.tecnicoDesignado.trim().toLowerCase();

                final dadosAtualizados = {
                  'cliente': cC.text.trim(),
                  'telefone': fC.text.trim(),
                  'endereco': eC.text.trim(),
                  'descricao_problema': pC.text.trim(),
                  'tecnico_designado': novoTecnicoNome,
                  'prioridade': prioridadeSel,
                };

                try {
                  if (os.id != null) {
                    await Supabase.instance.client
                        .from('ordens_servico')
                        .update(dadosAtualizados)
                        .eq('id', os.id!)
                        .timeout(const Duration(seconds: 8));

                    final tecObj = _tecnicos.cast<UsuarioApp?>().firstWhere(
                      (u) => u?.nome.trim().toLowerCase() == novoTecnicoNome.trim().toLowerCase(),
                      orElse: () => null,
                    );
                    final loginTecnico = tecObj != null ? tecObj.usuario : novoTecnicoNome;

                    if (mudouTecnico) {
                      ServicoNotificacaoOneSignal.enviarNotificacaoOS(
                        tecnicoLogin: loginTecnico,
                        numeroOS: os.numeroOS,
                        cliente: cC.text.trim(),
                      );
                    } else {
                      ServicoNotificacaoOneSignal.enviarPush(
                        destinatarioLogin: loginTecnico,
                        titulo: '⚠️ O.S. Atualizada (${os.numeroOS})',
                        mensagem: 'Os dados da O.S. do cliente ${cC.text.trim()} foram atualizados.',
                        dados: {'tipo': 'ordem_servico', 'os_id': os.numeroOS},
                      );
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.green, content: Text('✅ ${os.numeroOS} atualizada com sucesso!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao atualizar O.S.: $e')),
                    );
                  }
                } finally {
                  if (ctx.mounted) setM(() => salvando = false);
                }
              },
              child: salvando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExcluirOS(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        title: const Text('Excluir O.S.?', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Deseja realmente apagar esta O.S.?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sim, Excluir'),
            onPressed: () async {
              try { await Supabase.instance.client.from('ordens_servico').delete().eq('id', id); } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Gestão de O.S. (Despacho)', exibirBotaoVoltar: true),

          // FILTROS DE STATUS
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Ativas', 'Pendente', 'Em Andamento', 'Concluída', 'Histórico (90 dias)'].map((status) {
                  final sel = _filtroStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: sel,
                      selectedColor: corCianoEletrico.withAlpha(50),
                      labelStyle: TextStyle(
                        color: sel ? corCianoEletrico : Colors.grey,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11.5,
                      ),
                      side: BorderSide(color: sel ? corCianoEletrico : Colors.white12),
                      onSelected: (_) => setState(() => _filtroStatus = status),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // BARRA DE FERRAMENTAS: FILTRO RETRÁTIL + RELATÓRIOS + NOVA O.S.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _mostrarBusca ? corCianoEletrico : Colors.white24),
                    foregroundColor: _mostrarBusca ? corCianoEletrico : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(_mostrarBusca ? Icons.close : Icons.filter_alt_outlined, size: 16),
                  label: Text(_mostrarBusca ? 'Fechar' : 'Filtrar', style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() {
                    _mostrarBusca = !_mostrarBusca;
                    if (!_mostrarBusca) _filtroPesquisa = '';
                  }),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amberAccent),
                    foregroundColor: Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Relatórios', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final snap = await Supabase.instance.client.from('ordens_servico').select().order('id', ascending: false);
                    final lista = snap.map((m) => OrdemServico.fromMap(m)).toList();
                    if (mounted) _modalSuperRelatorio(lista);
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corCianoEletrico,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nova O.S.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: _modalNovaOS,
                ),
              ],
            ),
          ),

          if (_mostrarBusca)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar cliente, O.S., técnico...',
                  prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 16),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (v) => setState(() => _filtroPesquisa = v.toLowerCase()),
              ),
            ),

          // LISTAGEM DE O.S.
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                final todos = (snap.data ?? []).map((m) => OrdemServico.fromMap(m)).toList();

                final filtrados = todos.where((os) {
                  if (_filtroStatus == 'Ativas') {
                    if (os.status == 'Faturada') return false;
                  } else if (_filtroStatus == 'Histórico (90 dias)') {
                    if (os.status != 'Faturada') return false;
                  } else {
                    if (os.status != _filtroStatus) return false;
                  }

                  if (_filtroPesquisa.isEmpty) return true;
                  final c = os.cliente.toLowerCase();
                  final numOS = os.numeroOS.toLowerCase();
                  final tec = os.tecnicoDesignado.toLowerCase();
                  return c.contains(_filtroPesquisa) || numOS.contains(_filtroPesquisa) || tec.contains(_filtroPesquisa);
                }).toList();

                if (filtrados.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhuma O.S. encontrada para este filtro.\n(O.S. faturadas ficam no Histórico por 90 dias)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: filtrados.length,
                  itemBuilder: (_, i) {
                    final os = filtrados[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _corPrioridade(os.prioridade).withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _corPrioridade(os.prioridade)),
                                  ),
                                  child: Text("${os.numeroOS} • ${os.prioridade.toUpperCase()}", style: TextStyle(color: _corPrioridade(os.prioridade), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: _corStatus(os.status).withAlpha(30), borderRadius: BorderRadius.circular(6)),
                                  child: Text(os.status, style: TextStyle(color: _corStatus(os.status), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: corTextoClaro)),
                            if (os.endereco.isNotEmpty) Text("📍 ${os.endereco}", style: const TextStyle(fontSize: 11, color: corCianoSuave)),
                            if (os.telefone.isNotEmpty) Text("📞 ${os.telefone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person, size: 13, color: corCianoSuave),
                                const SizedBox(width: 4),
                                Text("Técnico: ${os.tecnicoDesignado}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: corTextoClaro)),
                                const Spacer(),
                                Text("Aberta: ${os.dataAbertura}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                              child: Text(os.descricaoProblema, style: const TextStyle(fontSize: 11.5, color: corTextoClaro)),
                            ),
                            const Divider(height: 12),

                            // AÇÕES DA O.S. (SEM OS BOTÕES 'FATURAR' E 'PDF')
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.edit, size: 14, color: Colors.amberAccent),
                                  label: const Text('Editar', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _modalEditarOS(os),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.share, size: 14, color: corVerdeWhats),
                                  label: const Text('Whats', style: TextStyle(color: corVerdeWhats, fontSize: 11)),
                                  onPressed: () => _gerarDocOS(os, 'whats'),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.print, size: 14, color: Colors.amberAccent),
                                  label: const Text('Imprimir', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                  onPressed: () => _gerarDocOS(os, 'imprimir'),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                  tooltip: 'Excluir O.S.',
                                  onPressed: () => _confirmarExcluirOS(os.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



