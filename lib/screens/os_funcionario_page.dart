import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_base.dart';
import '../models/os_model.dart';
import '../modulo_cadastros.dart';
import '../modulo_documentos.dart';
import '../servico_licenca_bugs.dart';

class TelaOSFuncionario extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaOSFuncionario({super.key, required this.usuarioLogado});
  @override
  State<TelaOSFuncionario> createState() => _TelaOSFuncionarioState();
}

class _TelaOSFuncionarioState extends State<TelaOSFuncionario> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  List<OrdemServico> _listaOffline = [];
  final Map<String, String> _mapaDocClientes = {};
  final Set<String> _chavesOrcamentosExistentes = {};
  String _abaSelecionada = 'Ativas';
  bool _popupAberto = false;
  final Set<String> _idsNotificadosNestaSessao = {};

  @override
  void initState() {
    super.initState();
    _carregarCacheLocal();
    _carregarDocsEOrcamentos();
    _iniciarStream();
  }

  void _iniciarStream() {
    _stream = ServicoLicencaBugs.streamTabelaSegura('ordens_servico', orderBy: 'id', ascending: false);
  }

  Future<void> _carregarDocsEOrcamentos() async {
    try {
      final orcs = await ServicoOrcamentosSalvos.carregar();
      for (final o in orcs) {
        final nOS = (o['numero_os_origem'] ?? '').toString().trim().toLowerCase();
        final nCli = (o['cliente_nome'] ?? '').toString().trim().toLowerCase();
        if (nOS.isNotEmpty) _chavesOrcamentosExistentes.add(nOS);
        if (nCli.isNotEmpty) _chavesOrcamentosExistentes.add(nCli);
      }
    } catch (_) {}

    try {
      final locais = await CacheOffline.carregarClientesLocal();
      for (final c in locais) {
        if (c.nome.trim().isNotEmpty && c.documento.trim().isNotEmpty) {
          _mapaDocClientes[c.nome.trim().toLowerCase()] = c.documento.trim();
        }
      }
      final res = await supabase.from('clientes').select('nome, cpf_cnpj');
      for (final c in res) {
        final n = (c['nome'] ?? '').toString().trim().toLowerCase();
        final d = (c['cpf_cnpj'] ?? '').toString().trim();
        if (n.isNotEmpty && d.isNotEmpty) _mapaDocClientes[n] = d;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _carregarCacheLocal() async {
    try {
      final locais = await ServicoOS.carregarLocal();
      if (mounted && locais.isNotEmpty) {
        setState(() {
          _listaOffline = _filtrarParaMeuUsuario(locais);
        });
      }
    } catch (_) {}
  }

  List<OrdemServico> _filtrarParaMeuUsuario(List<OrdemServico> lista) {
    final meuLogin = widget.usuarioLogado.usuario.trim().toLowerCase().replaceAll('@', '');
    final meuNome = widget.usuarioLogado.nome.trim().toLowerCase();
    final meuPrimeiroNome = meuNome.isNotEmpty ? meuNome.split(' ').first : '';

    return lista.where((os) {
      final tec = os.tecnicoDesignado.trim().toLowerCase().replaceAll('@', '');
      if (tec.isEmpty) return false;
      return tec == meuLogin || tec == meuNome || (meuPrimeiroNome.isNotEmpty && tec == meuPrimeiroNome);
    }).toList();
  }

  Future<void> _abrirMapa(String endereco) async {
    final limpo = endereco.trim();
    if (limpo.isEmpty) return;
    final query = Uri.encodeComponent(limpo);
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  String? _extrairAtendente(String desc) {
    if (!desc.contains('[Atender no Local:')) return null;
    try {
      return desc.split('[Atender no Local:').last.split(']').first.trim();
    } catch (_) {
      return null;
    }
  }

  String? _extrairFoneAtendente(String desc) {
    final atendente = _extrairAtendente(desc);
    if (atendente == null) return null;
    final nums = atendente.replaceAll(RegExp(r'[^\d]'), '');
    return nums.length >= 8 ? nums : null;
  }

  Future<void> _abrirWhatsAtendente(String telefone, String numOS) async {
    final limpo = telefone.replaceAll(RegExp(r'[^\d]'), '');
    if (limpo.isEmpty) return;
    final numero = limpo.startsWith('55') ? limpo : '55$limpo';
    final msg = "Olá! Sou o técnico da empresa e estou a caminho para o atendimento da O.S. #$numOS.";
    final url = Uri.parse("https://wa.me/$numero?text=${Uri.encodeComponent(msg)}");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _confirmarAcaoComModal({
    required String titulo,
    required String mensagem,
    required Color corAcao,
    required VoidCallback onConfirmar,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: corAcao)),
        title: Text(titulo, style: TextStyle(color: corAcao, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(mensagem, style: const TextStyle(color: corTextoClaro, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corAcao, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirmar();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
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

  void _verificarNovasOS(List<OrdemServico> lista) {
    if (_popupAberto || !mounted) return;

    final pendentesNaoVistas = lista.where((os) =>
        os.status == 'Pendente' &&
        !os.visualizadoPeloTecnico &&
        !_idsNotificadosNestaSessao.contains(os.id ?? os.numeroOS)).toList();

    if (pendentesNaoVistas.isNotEmpty) {
      final nova = pendentesNaoVistas.first;
      _popupAberto = true;
      _idsNotificadosNestaSessao.add(nova.id ?? nova.numeroOS);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _exibirPopupNovaOS(nova);
      });
    }
  }

  void _exibirPopupNovaOS(OrdemServico os) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _corPrioridade(os.prioridade), width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.notification_important, color: _corPrioridade(os.prioridade), size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('🚨 NOVA O.S. RECEBIDA!', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _corPrioridade(os.prioridade).withAlpha(40), borderRadius: BorderRadius.circular(6)),
              child: Text("PRIORIDADE: ${os.prioridade.toUpperCase()} (${os.numeroOS})", style: TextStyle(color: _corPrioridade(os.prioridade), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(height: 8),
            Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corTextoClaro)),
                                        if (os.endereco.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: InkWell(
                                  onTap: () => _abrirMapa(os.endereco),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: corCianoEletrico.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: corCianoEletrico.withOpacity(0.35), width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.navigation_rounded, size: 14, color: corCianoEletrico),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            "📍 ${os.endereco}",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11.5, color: corCianoSuave, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: corCianoEletrico,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.directions_car_rounded, size: 11, color: Colors.black),
                                              SizedBox(width: 3),
                                              Text('GPS', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (os.telefone.isNotEmpty) Text("📞 ${os.telefone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text("Serviço a executar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
              child: Text(os.descricaoProblema, style: const TextStyle(fontSize: 12, color: corTextoClaro)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
            child: const Text('Entendido / Ver O.S.'),
            onPressed: () {
              if (os.id != null) ServicoOS.marcarVisualizado(os.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ).then((_) => _popupAberto = false);
  }

  void _modalEditarRelatorioOS(OrdemServico os) {
    final relatorioC = TextEditingController(text: os.observacaoTecnico ?? '');
    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: corCianoEletrico, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('Editar / Complementar Peças', style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corTextoClaro)),
                if (os.numeroOS.isNotEmpty) Text("Ref: ${os.numeroOS}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(
                  controller: relatorioC,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Relatório do Serviço / Peças Trocadas',
                    hintText: 'Adicione as peças aplicadas ou complemente o relatório...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
              onPressed: salvando
                  ? null
                  : () async {
                      final novoRel = relatorioC.text.trim();
                      if (novoRel.isEmpty) return;
                      setD(() => salvando = true);

                      try {
                        if (os.id != null) {
                          await Supabase.instance.client
                              .from('ordens_servico')
                              .update({'observacao_tecnico': novoRel})
                              .eq('id', os.id!);
                        }
                      } catch (_) {}

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(backgroundColor: Colors.green, content: Text('✅ Relatório atualizado!')),
                        );
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

  void _modalAdicionarEquipamento(OrdemServico os) {
    final tipoC = TextEditingController();
    final marcaC = TextEditingController();
    final modeloC = TextEditingController();
    final potenciaC = TextEditingController();
    final tensaoC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: const Text('⚙️ Adicionar Equipamento', style: TextStyle(color: corCianoEletrico, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tipoC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Tipo (Ex: Motobomba, Inversor, Sauna) *', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: marcaC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Marca (Ex: Dancor, WEG, Jacuzzi)', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: modeloC, decoration: const InputDecoration(labelText: 'Modelo', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: potenciaC, decoration: const InputDecoration(labelText: 'Potência (Ex: 1.5 CV, 2.0 HP)', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: tensaoC, decoration: const InputDecoration(labelText: 'Tensão (Ex: 220V Bifásico, 380V)', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
            child: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final t = tipoC.text.trim();
              if (t.isEmpty) return;
              final novoEq = EquipamentoRelatorio(
                tipo: t,
                marca: marcaC.text.trim(),
                modelo: modeloC.text.trim(),
                potencia: potenciaC.text.trim(),
                tensao: tensaoC.text.trim(),
              );

              setState(() {
                os.equipamentos.add(novoEq);
              });

              await ServicoOS.atualizarStatus(id: os.id, novoStatus: os.status, equipamentos: os.equipamentos);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _modalFinalizarOS(OrdemServico os, {required bool paraOrcamento}) {
    final relatorioC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: paraOrcamento ? Colors.amberAccent : corVerdeWhats),
        ),
        title: Row(
          children: [
            Icon(paraOrcamento ? Icons.receipt_long : Icons.check_circle, color: paraOrcamento ? Colors.amberAccent : corVerdeWhats, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                paraOrcamento ? 'Enviar p/ Orçamento Escritório' : 'Finalizar O.S. em Campo',
                style: TextStyle(color: paraOrcamento ? Colors.amberAccent : corVerdeWhats, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corTextoClaro)),
              if (os.numeroOS.isNotEmpty) Text("Ref: ${os.numeroOS}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(
                controller: relatorioC,
                minLines: 4,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: paraOrcamento ? 'Laudo p/ Orçamento / Peças Necessárias *' : 'Relatório do Serviço / Observações *',
                  hintText: 'Descreva detalhadamente o serviço e materiais...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: paraOrcamento ? Colors.amber : corVerdeWhats,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(paraOrcamento ? 'Confirmar Envio' : 'Confirmar Finalização', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final relatorio = relatorioC.text.trim();
              if (relatorio.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha o relatório técnico!')));
                return;
              }

              final statusNovo = paraOrcamento ? 'Aguardando Orçamento' : 'Concluída';
              await ServicoOS.atualizarStatus(
                id: os.id,
                novoStatus: statusNovo,
                relatorioTecnico: relatorio,
                equipamentos: os.equipamentos,
              );

              if (!paraOrcamento) {
                try {
                  double valorFinalFaturamento = 0.0;
                  String descricaoFinalFaturamento = "[${os.numeroOS}] $relatorio";

                  try {
                    final orcsSalvos = await ServicoOrcamentosSalvos.carregar();
                    for (final o in orcsSalvos) {
                      final nOrig = (o['numero_os_origem'] ?? '').toString().trim().toLowerCase();
                      final cOrig = (o['cliente_nome'] ?? '').toString().trim().toLowerCase();
                      if ((nOrig.isNotEmpty && nOrig == os.numeroOS.trim().toLowerCase()) ||
                          (cOrig.isNotEmpty && cOrig == os.cliente.trim().toLowerCase())) {
                        if (o['valor_total'] is num) {
                          valorFinalFaturamento = (o['valor_total'] as num).toDouble();
                        }
                        final itensOrc = (o['descricao_itens'] ?? '').toString();
                        if (itensOrc.isNotEmpty) {
                          descricaoFinalFaturamento = "[${os.numeroOS}] $itensOrc\n[Relatório Técnico: $relatorio]";
                        }
                        o['status'] = "Aprovado - Finalizado (${os.numeroOS})";
                        await ServicoOrcamentosSalvos.salvarOuAtualizar(o);
                        break;
                      }
                    }
                  } catch (_) {}

                  final checarServico = await supabase
                      .from('servicos')
                      .select('id')
                      .ilike('descricao', '%[${os.numeroOS}]%')
                      .maybeSingle();

                  final dadosFaturamento = {
                    'cliente': os.cliente,
                    'telefone': os.telefone,
                    'endereco': os.endereco,
                    'descricao': descricaoFinalFaturamento,
                    'quantidade': 1,
                    'valor_unitario': valorFinalFaturamento,
                    'status': 'Pendente',
                    'tecnico': widget.usuarioLogado.nome,
                    'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  };

                  if (checarServico != null && checarServico['id'] != null) {
                    await supabase.from('servicos').update(dadosFaturamento).eq('id', checarServico['id']);
                  } else {
                    await supabase.from('servicos').insert(dadosFaturamento);
                  }
                } catch (_) {}
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(paraOrcamento ? '📋 O.S. enviada para orçamento do escritório!' : '✅ O.S. Concluída e enviada ao Faturamento!'),
                ));
              }
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
          BannerOSPrime(
            subtituloTela: 'Minhas Ordens de Serviço',
            exibirBotaoVoltar: true,
            acaoDireita: IconButton(
              tooltip: 'Meu Bloco de Notas',
              icon: const Icon(Icons.edit_note_rounded, color: corCianoEletrico, size: 24),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TelaNotas(
                      usuarioKey: widget.usuarioLogado.usuario,
                      nomeUsuario: widget.usuarioLogado.nome,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                _botaoAbaOS('Ativas', '🟡 Em Aberto', Colors.amberAccent),
                const SizedBox(width: 6),
                _botaoAbaOS('Aguardando', '🟠 No Escritório', Colors.orangeAccent),
                const SizedBox(width: 6),
                _botaoAbaOS('Concluidas', '🟢 Concluídas', corVerdeWhats),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                List<OrdemServico> listaBase = [];

                if (snap.hasData && snap.data!.isNotEmpty) {
                  final todos = snap.data!.map((m) => OrdemServico.fromMap(m)).toList();
                  listaBase = _filtrarParaMeuUsuario(todos);
                  ServicoOS.salvarLocal(todos);
                } else {
                  listaBase = _listaOffline;
                }

                _verificarNovasOS(listaBase);

                final filtradas = listaBase.where((os) {
                  final st = os.status.trim().toLowerCase();
                  if (_abaSelecionada == 'Ativas') {
                    return st == 'pendente' || st == 'em andamento';
                  } else if (_abaSelecionada == 'Aguardando') {
                    return st == 'concluída' || st == 'concluida' || st == 'aguardando orçamento' || st == 'aguardando orcamento';
                  } else {
                    return st == 'faturada' || st == 'finalizada' || st.contains('faturad');
                  }
                }).toList();

                if (filtradas.isEmpty) {
                  String msg = 'Nenhuma O.S. ativa no momento.';
                  if (_abaSelecionada == 'Aguardando') msg = 'Nenhuma O.S. aguardando escritório.';
                  if (_abaSelecionada == 'Concluidas') msg = 'Nenhuma O.S. faturada/concluída ainda.';

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtradas.length,
                  itemBuilder: (_, i) {
                    final os = filtradas[i];
                    final stLower = os.status.trim().toLowerCase();
                    final bool pendente = stLower == 'pendente';
                    final bool emAndamento = stLower == 'em andamento';
                    final bool aguardandoOrcamento = stLower.contains('orçamento') || stLower.contains('orcamento');
                    final bool concluidaEscritorio = stLower == 'concluída' || stLower == 'concluida';

                    String statusRotulo = os.status;
                    Color corStatus = corCianoSuave;
                    if (pendente) {
                      statusRotulo = 'Pendente';
                      corStatus = Colors.amberAccent;
                    } else if (emAndamento) {
                      statusRotulo = 'Em Andamento';
                      corStatus = corCianoEletrico;
                    } else if (aguardandoOrcamento) {
                      statusRotulo = 'Aguardando Orçamento';
                      corStatus = Colors.orangeAccent;
                    } else if (concluidaEscritorio) {
                      statusRotulo = 'Aguardando Faturamento';
                      corStatus = Colors.orangeAccent;
                    } else {
                      statusRotulo = 'Faturada';
                      corStatus = corVerdeWhats;
                    }

                    final atend = _extrairAtendente(os.descricaoProblema);
                    final foneAtend = _extrairFoneAtendente(os.descricaoProblema);

                    // Verifica se esta O.S. (nova ou já cadastrada) já passou por orçamento ou retorno
                    final descUpper = os.descricaoProblema.toUpperCase();
                    final obsUpper = (os.observacaoTecnico ?? '').toUpperCase();
                    final bool jaTemOrcamentoOuRetorno =
                        descUpper.contains('ORÇAMENTO') ||
                        descUpper.contains('ORCAMENTO') ||
                        descUpper.contains('AUTORIZADO') ||
                        descUpper.contains('ITENS A EXECUTAR') ||
                        descUpper.contains('RETORNO') ||
                        descUpper.contains('GARANTIA') ||
                        obsUpper.isNotEmpty ||
                        _chavesOrcamentosExistentes.contains(os.numeroOS.trim().toLowerCase()) ||
                        _chavesOrcamentosExistentes.contains(os.cliente.trim().toLowerCase());

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: pendente
                              ? _corPrioridade(os.prioridade).withAlpha(120)
                              : (emAndamento ? corCianoEletrico.withAlpha(90) : Colors.white12),
                          width: pendente ? 1.5 : 1,
                        ),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _corPrioridade(os.prioridade).withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _corPrioridade(os.prioridade)),
                                  ),
                                  child: Text("${os.numeroOS} • ${os.prioridade.toUpperCase()}", style: TextStyle(color: _corPrioridade(os.prioridade), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: corStatus.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: corStatus.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    statusRotulo,
                                    style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: corTextoClaro)),
                            Padding(
                              padding: const EdgeInsets.only(top: 1, bottom: 2),
                              child: Text(
                                "📄 CPF/CNPJ: ${_mapaDocClientes[os.cliente.trim().toLowerCase()] ?? 'Não informado'}",
                                style: const TextStyle(fontSize: 11, color: corTextoClaro, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (atend != null)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amberAccent.withOpacity(0.6)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_pin_circle_rounded, size: 16, color: Colors.amberAccent),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text("Receber no Local: $atend", style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                    ),
                                    if (foneAtend != null)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: corVerdeWhats,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        ),
                                        icon: const Icon(Icons.chat, size: 12),
                                        label: const Text('WhatsApp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        onPressed: () => _abrirWhatsAtendente(foneAtend, os.numeroOS),
                                      ),
                                  ],
                                ),
                              ),
                            if (os.endereco.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 2),
                                child: InkWell(
                                  onTap: () => _abrirMapa(os.endereco),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: corCianoEletrico.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: corCianoEletrico.withOpacity(0.3), width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.navigation_rounded, size: 13, color: corCianoEletrico),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            "📍 ${os.endereco}",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: corCianoSuave, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: corCianoEletrico,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.directions_car_rounded, size: 11, color: Colors.black),
                                              SizedBox(width: 3),
                                              Text('GPS', style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (os.telefone.isNotEmpty) Text("📞 ${os.telefone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                              child: Text(os.descricaoProblema, style: const TextStyle(fontSize: 12, color: corTextoClaro)),
                            ),
                            if (os.observacaoTecnico != null && os.observacaoTecnico!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0x2625D366), borderRadius: BorderRadius.circular(6), border: Border.all(color: corVerdeWhats.withAlpha(90))),
                                child: Text("Relatório Técnico: ${os.observacaoTecnico}", style: const TextStyle(fontSize: 11, color: corVerdeWhats)),
                              ),
                            ],
                            const SizedBox(height: 10),

                            if (pendente)
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Iniciar Atendimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => ServicoOS.atualizarStatus(id: os.id, novoStatus: 'Em Andamento'),
                                ),
                              ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Equipamentos vinculados (${os.equipamentos.length}):", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: corCianoEletrico)),
                                if (pendente || emAndamento)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: corCianoEletrico,
                                      foregroundColor: Colors.black,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    ),
                                    icon: const Icon(Icons.add, size: 13),
                                    label: const Text('+ Equipamento', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    onPressed: () => _modalAdicionarEquipamento(os),
                                  ),
                              ],
                            ),
                            if (os.equipamentos.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: os.equipamentos.map((eq) => Chip(
                                  backgroundColor: corCardFundo,
                                  side: const BorderSide(color: corCianoSuave, width: 0.8),
                                  label: Text("${eq.tipo} - ${eq.marca}", style: const TextStyle(fontSize: 10, color: corTextoClaro)),
                                  deleteIcon: (pendente || emAndamento) ? const Icon(Icons.close, size: 12, color: Colors.redAccent) : null,
                                  onDeleted: (pendente || emAndamento) ? () async {
                                    setState(() {
                                      os.equipamentos.remove(eq);
                                    });
                                    await ServicoOS.atualizarStatus(id: os.id, novoStatus: os.status, equipamentos: os.equipamentos);
                                  } : null,
                                )).toList(),
                              ),
                            ],
                            const SizedBox(height: 8),

                            // SE EM ANDAMENTO: OCULTA 'ENVIAR P/ ORÇAMENTO' SE JÁ TIVER ORÇAMENTO OU RETORNO!
                            if (emAndamento)
                              if (jaTemOrcamentoOuRetorno)
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: corVerdeWhats, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text('Finalizar O.S.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _confirmarAcaoComModal(
                                      titulo: 'Finalizar O.S.?',
                                      mensagem: 'Deseja finalizar o atendimento de ${os.cliente} e enviar ao escritório?',
                                      corAcao: corVerdeWhats,
                                      onConfirmar: () => _modalFinalizarOS(os, paraOrcamento: false),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber.shade700,
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.receipt_long, size: 14),
                                          label: const Text('Enviar p/ Orçamento', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          onPressed: () => _confirmarAcaoComModal(
                                            titulo: 'Enviar para Orçamento?',
                                            mensagem: 'Deseja encaminhar a O.S. de ${os.cliente} para orçamento no escritório?',
                                            corAcao: Colors.amber.shade800,
                                            onConfirmar: () => _modalFinalizarOS(os, paraOrcamento: true),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: corVerdeWhats,
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.check_circle, size: 14),
                                          label: const Text('Finalizar O.S.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          onPressed: () => _confirmarAcaoComModal(
                                            titulo: 'Finalizar O.S.?',
                                            mensagem: 'Deseja finalizar o atendimento de ${os.cliente} e enviar ao escritório?',
                                            corAcao: corVerdeWhats,
                                            onConfirmar: () => _modalFinalizarOS(os, paraOrcamento: false),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                            if (concluidaEscritorio || aguardandoOrcamento)
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: corCianoEletrico),
                                    foregroundColor: corCianoEletrico,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.edit, size: 13),
                                  label: const Text('Editar / Adicionar Peças', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  onPressed: () => _modalEditarRelatorioOS(os),
                                ),
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

  Widget _botaoAbaOS(String id, String rotulo, Color cor) {
    final sel = _abaSelecionada == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _abaSelecionada = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? cor.withOpacity(0.22) : corCardFundo,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? cor : Colors.white12, width: sel ? 1.4 : 1),
          ),
          child: Center(
            child: Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: sel ? cor : Colors.grey,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 10.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}