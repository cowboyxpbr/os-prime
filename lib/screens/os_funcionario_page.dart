import 'package:url_launcher/url_launcher.dart';
// ============================================================================
// ARQUIVO: TELA DE O.S. DO TÉCNICO COM 3 ABAS, HISTÓRICO E SUPORTE OFFLINE REAL
// lib/screens/os_funcionario_page.dart
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_base.dart';
import '../models/os_model.dart';
import '../modulo_cadastros.dart';

class TelaOSFuncionario extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaOSFuncionario({super.key, required this.usuarioLogado});
  @override
  State<TelaOSFuncionario> createState() => _TelaOSFuncionarioState();
}

class _TelaOSFuncionarioState extends State<TelaOSFuncionario> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  List<OrdemServico> _listaOffline = [];
  String _abaSelecionada = 'Ativas'; // 'Ativas', 'Aguardando', 'Concluidas'
  bool _popupAberto = false;
  final Set<String> _idsNotificadosNestaSessao = {};

  @override
  void initState() {
    super.initState();
    _carregarCacheLocal();
    _iniciarStream();
  }

  void _iniciarStream() {
    try {
      _stream = Supabase.instance.client
          .from('ordens_servico')
          .stream(primaryKey: ['id'])
          .order('id', ascending: false);
    } catch (_) {}
  }

  // 1. CARREGAMENTO OFFLINE IMEDIATO DO APARELHO
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
            if (os.endereco.isNotEmpty) Text("📍 ${os.endereco}", style: const TextStyle(fontSize: 12, color: corCianoSuave)),
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
                  labelText: paraOrcamento ? 'Laudo p/ Orçamento / Peças Necessárias *' : 'Relatório do Serviço / Peças Aplicadas *',
                  hintText: 'Descreva detalhadamente o serviço e materiais...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (paraOrcamento ? Colors.amberAccent : corVerdeWhats).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: (paraOrcamento ? Colors.amberAccent : corVerdeWhats).withAlpha(90)),
                ),
                child: Row(
                  children: [
                    Icon(paraOrcamento ? Icons.hourglass_top_rounded : Icons.assignment_turned_in, color: paraOrcamento ? Colors.amberAccent : corVerdeWhats, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        paraOrcamento
                            ? 'A O.S. irá para a aba "Aguardando Escritório" até o orçamento ser aprovado.'
                            : 'A O.S. será concluída e enviada diretamente para o Faturamento do escritório.',
                        style: TextStyle(color: paraOrcamento ? Colors.amberAccent : corVerdeWhats, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
            child: Text(paraOrcamento ? 'Enviar para Orçamento' : 'Finalizar O.S.', style: const TextStyle(fontWeight: FontWeight.bold)),
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

              // 🚀 Se finalizou direto, envia para Faturamento
              if (!paraOrcamento) {
                try {
                  await Supabase.instance.client.from('servicos').insert({
                    'cliente': os.cliente,
                    'telefone': os.telefone,
                    'endereco': os.endereco,
                    'descricao': "[${os.numeroOS}] $relatorio",
                    'quantidade': 1,
                    'valor_unitario': 0.0,
                    'status': 'Pendente',
                    'tecnico': widget.usuarioLogado.nome,
                    'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
                  });
                } catch (_) {}
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(paraOrcamento ? '📋 O.S. enviada para orçamento do escritório!' : '✅ O.S. Concluída com sucesso!'),
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

          // ==================================================================
          // 3 ABAS SEPARADAS: ATIVAS, AGUARDANDO ESCRITÓRIO E CONCLUÍDAS
          // ==================================================================
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
                  // Atualiza o cache local offline em segundo plano
                  ServicoOS.salvarLocal(todos);
                } else {
                  // Fallback offline instantaneo
                  listaBase = _listaOffline;
                }

                _verificarNovasOS(listaBase);

                // FILTRA EXATAMENTE PELA ABA SELECIONADA
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

                            // CASO 1: PENDENTE -> INICIAR ATENDIMENTO
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

                            // SEÇÃO DE EQUIPAMENTOS NA O.S. DO TÉCNICO
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

                            // CASO 2: EM ANDAMENTO -> ENVIAR P/ ORÇAMENTO OU FINALIZAR O.S.
                            if (emAndamento)
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
                                        onPressed: () => _modalFinalizarOS(os, paraOrcamento: true),
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
                                        onPressed: () => _modalFinalizarOS(os, paraOrcamento: false),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // CASO 3: SE ESTIVER NO ESCRITÓRIO OU CONCLUÍDA -> PERMITE EDITAR RELATÓRIO
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