// ============================================================================
// GESTÃO DE O.S. (ADMIN): DESPACHO DIRETO, 1 CLIQUE DETALHES, ALTERAR CLIENTE
// lib/screens/os_admin_page.dart (VERSÃO OFICIAL)
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
  final Map<String, String> _mapaDocClientesAdm = {};

  Future<void> _carregarDocsSupabaseAdm() async {
    try {
      final locais = await CacheOffline.carregarClientesLocal();
      for (final c in locais) {
        if (c.nome.trim().isNotEmpty && c.documento.trim().isNotEmpty) {
          _mapaDocClientesAdm[c.nome.trim().toLowerCase()] = c.documento.trim();
        }
      }
      final res = await supabase.from('clientes').select('nome, cpf_cnpj');
      for (final c in res) {
        final n = (c['nome'] ?? '').toString().trim().toLowerCase();
        final d = (c['cpf_cnpj'] ?? '').toString().trim();
        if (n.isNotEmpty && d.isNotEmpty) _mapaDocClientesAdm[n] = d;
      }
      if (mounted) setState(() {});
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

  List<DadosCliente> _listaClientesCache = [];
  Future<void> _carregarClientesCache() async {
    try {
      final locais = await CacheOffline.carregarClientesLocal();
      if (mounted) setState(() => _listaClientesCache = locais);
      final res = await supabase.from('clientes').select().timeout(const Duration(seconds: 10));
      if (res.isNotEmpty) {
        final remotos = (res as List).map((m) => DadosCliente.fromMap(Map<String, dynamic>.from(m))).toList();
        if (mounted) setState(() => _listaClientesCache = remotos);
      }
    } catch (_) {}
  }

  late final Stream<List<Map<String, dynamic>>> _stream;
  List<OrdemServico> _offlineOS = [];
  List<UsuarioApp> _tecnicos = [];
  String _filtroStatus = 'Todas';
  String _filtroPesquisa = '';
  bool _mostrarBusca = false;

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
    _carregarDocsSupabaseAdm();
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
    _carregarClientesCache();
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
      case 'em reparo de bancada':
        return Colors.orangeAccent;
      case 'aguardando orçamento':
        return Colors.orangeAccent;
      case 'faturada':
        return const Color(0xFF00E5FF);
      default:
        return corCianoSuave;
    }
  }

  void _modalAlterarClienteOS(OrdemServico os) {
    final novoNomeCtrl = TextEditingController(text: os.cliente);
    final novoFoneCtrl = TextEditingController(text: os.telefone);
    final novoEndCtrl = TextEditingController(text: os.endereco);
    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: Row(
            children: [
              const Icon(Icons.person_pin_rounded, color: corCianoEletrico, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text("Alterar Cliente (${os.numeroOS})", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Substitua o nome genérico pelo cliente real:", style: TextStyle(color: Colors.grey, fontSize: 11.5)),
                const SizedBox(height: 12),
                TextField(controller: novoNomeCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome do Cliente / Condomínio *', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: novoFoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone / WhatsApp', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: novoEndCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Endereço da Obra', isDense: true)),
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
                      final n = novoNomeCtrl.text.trim();
                      if (n.isEmpty) return;
                      setD(() => salvando = true);
                      try {
                        final idNum = int.tryParse(os.id.toString()) ?? os.id;
                        await Supabase.instance.client.from('ordens_servico').update({
                          'cliente': n,
                          'telefone': novoFoneCtrl.text.trim(),
                          'endereco': novoEndCtrl.text.trim(),
                        }).eq('id', idNum!);

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: Colors.green, content: Text('✅ Cliente de ${os.numeroOS} atualizado para "$n"!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')));
                      } finally {
                        if (ctx.mounted) setD(() => salvando = false);
                      }
                    },
              child: const Text('Salvar Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _modalDetalhesOSAdmin(OrdemServico os) {
    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: corCianoEletrico, width: 1.2),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _corPrioridade(os.prioridade).withAlpha(40), borderRadius: BorderRadius.circular(6), border: Border.all(color: _corPrioridade(os.prioridade))),
                      child: Text("${os.numeroOS} • ${os.prioridade.toUpperCase()}", style: TextStyle(color: _corPrioridade(os.prioridade), fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Text(os.status.toUpperCase(), style: TextStyle(color: _corStatus(os.status), fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: corTextoClaro))),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: corCianoEletrico), visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.edit, size: 13, color: corCianoEletrico),
                      label: const Text('Alterar Cliente', style: TextStyle(color: corCianoEletrico, fontSize: 11)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _modalAlterarClienteOS(os);
                      },
                    ),
                  ],
                ),
                Text("📄 CPF/CNPJ: ${_mapaDocClientesAdm[os.cliente.trim().toLowerCase()] ?? 'Não informado'}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (os.telefone.isNotEmpty) Text("📞 Telefone: ${os.telefone}", style: const TextStyle(fontSize: 11.5, color: corCianoSuave)),
                                              if (os.status.toLowerCase().contains('escritório') || os.status.toLowerCase().contains('escritorio'))
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orangeAccent, width: 1.2),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.notification_important_rounded, color: Colors.orangeAccent, size: 16),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '⚠️ AGUARDANDO DECISÃO DO ESCRITÓRIO (DESPACHE O DESTINO)',
                                          style: TextStyle(color: Colors.orangeAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (os.endereco.isNotEmpty) Text("📍 Endereço: ${os.endereco}", style: const TextStyle(fontSize: 11.5, color: corTextoClaro)),
                const SizedBox(height: 10),
                Text("👤 Técnico Designado: ${os.tecnicoDesignado}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corCianoEletrico)),
                Text("📅 Aberta em: ${os.dataAbertura}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                const Text("Problema Relatado / Instruções:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
                  child: Text(os.descricaoProblema, style: const TextStyle(fontSize: 12.5, color: corTextoClaro)),
                ),
                if (os.observacaoTecnico != null && os.observacaoTecnico!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text("Relatório do Técnico de Campo / Oficina:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corVerdeWhats)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0x2625D366), borderRadius: BorderRadius.circular(8), border: Border.all(color: corVerdeWhats.withOpacity(0.5))),
                    child: Text(os.observacaoTecnico!, style: const TextStyle(fontSize: 12, color: corVerdeWhats)),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                        icon: const Icon(Icons.alt_route_rounded, size: 16),
                        label: const Text('Determinar Destino'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _modalVoltarOSGarantia(os);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _modalVoltarOSGarantia(OrdemServico os) {
    final motivoC = TextEditingController();
    String destinoEscolhido = 'Oficina';
    String tecnicoSel = os.tecnicoDesignado;
    if (_tecnicosDeCampo.isNotEmpty && !_tecnicosDeCampo.any((t) => t.nome == tecnicoSel)) {
      tecnicoSel = _tecnicosDeCampo.first.nome;
    }
    bool enviando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amberAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.alt_route_rounded, color: Colors.amberAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Determinar Destino da O.S.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("O.S. #${os.numeroOS} • ${os.cliente}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: corCianoSuave)),
                const SizedBox(height: 12),
                const Text('QUAL É O DESTINO DESTE EQUIPAMENTO?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: corCianoEletrico)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('🛠️ Oficina (Bancada)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: destinoEscolhido == 'Oficina',
                      selectedColor: Colors.orangeAccent,
                      onSelected: (v) => setD(() => destinoEscolhido = 'Oficina'),
                    ),
                    ChoiceChip(
                      label: const Text('📋 Orçamento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: destinoEscolhido == 'Orcamento',
                      selectedColor: Colors.amberAccent,
                      onSelected: (v) => setD(() => destinoEscolhido = 'Orcamento'),
                    ),
                    ChoiceChip(
                      label: const Text('🚗 Rua (Executar / Entregar)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: destinoEscolhido == 'Rua',
                      selectedColor: corCianoEletrico,
                      onSelected: (v) => setD(() => destinoEscolhido = 'Rua'),
                    ),
                    ChoiceChip(
                      label: const Text('💰 Faturamento Direto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      selected: destinoEscolhido == 'Faturamento',
                      selectedColor: corVerdeWhats,
                      onSelected: (v) => setD(() => destinoEscolhido = 'Faturamento'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (destinoEscolhido == 'Oficina' || destinoEscolhido == 'Rua') ...[
                  const Text('Funcionário Designado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: corTextoClaro)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: tecnicoSel,
                    dropdownColor: const Color(0xFF142030),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: _tecnicosDeCampo.map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setD(() => tecnicoSel = v ?? tecnicoSel),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: motivoC,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Instruções / Motivo do Despacho *',
                    hintText: 'Explique o que deve ser feito nesta etapa...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              icon: enviando
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Confirmar Despacho', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: enviando
                  ? null
                  : () async {
                      final motivo = motivoC.text.trim();
                      if (motivo.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha as instruções!')));
                        return;
                      }
                      setD(() => enviando = true);
                      try {
                        String novoStatus = 'Em Andamento';
                        String prioridade = os.prioridade;

                        if (destinoEscolhido == 'Oficina') {
                          novoStatus = 'Em Reparo de Bancada';
                          prioridade = 'Oficina';
                        } else if (destinoEscolhido == 'Orcamento') {
                          novoStatus = 'Aguardando Orçamento';
                        } else if (destinoEscolhido == 'Rua') {
                          novoStatus = 'Em Andamento';
                        } else if (destinoEscolhido == 'Faturamento') {
                          novoStatus = 'Concluída';
                        }

                        final idNum = int.tryParse(os.id.toString()) ?? os.id;
                        final novoProb = "${os.descricaoProblema}\n\n⚠️ [DESPACHO ESCRITÓRIO - $destinoEscolhido]: $motivo";

                        await Supabase.instance.client.from('ordens_servico').update({
                          'status': novoStatus,
                          'prioridade': prioridade,
                          'tecnico_designado': tecnicoSel,
                          'descricao_problema': novoProb,
                          'observacao_tecnico': "[ESCRITÓRIO -> $destinoEscolhido]: $motivo",
                          'visualizado_pelo_tecnico': false,
                        }).eq('id', idNum!);

                        if (destinoEscolhido == 'Oficina') {
                          ServicoNotificacaoOneSignal.enviarNotificacaoOficina(
                            tecnicoLogin: tecnicoSel,
                            numeroOS: os.numeroOS,
                            cliente: os.cliente,
                          );
                        } else {
                          ServicoNotificacaoOneSignal.enviarNotificacaoOS(
                            tecnicoLogin: tecnicoSel,
                            numeroOS: os.numeroOS,
                            cliente: os.cliente,
                            categoria: prioridade,
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: Colors.green, content: Text('🚀 O.S. #${os.numeroOS} despachada para $destinoEscolhido!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')));
                      } finally {
                        if (ctx.mounted) setD(() => enviando = false);
                      }
                    },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Gestão de O.S. (Despacho)', exibirBotaoVoltar: true),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                {'id': 'Todas', 'label': 'Todas', 'cor': corCianoEletrico},
                {'id': 'Pendente', 'label': 'Pendentes', 'cor': Colors.orangeAccent},
                {'id': 'Em Andamento', 'label': 'Em Andamento', 'cor': Colors.amberAccent},
                {'id': 'Concluída', 'label': 'Concluídas', 'cor': corVerdeWhats},
              ].map((item) {
                final String id = item['id'] as String;
                final String label = item['label'] as String;
                final Color cor = item['cor'] as Color;
                final bool sel = _filtroStatus == id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: InkWell(
                      onTap: () => setState(() => _filtroStatus = id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        decoration: BoxDecoration(
                          color: sel ? cor.withOpacity(0.22) : corCardFundo,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sel ? cor : Colors.white12, width: sel ? 1.5 : 1),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sel ? cor : Colors.grey.shade400,
                              fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                final todos = (snap.data ?? []).map((m) => OrdemServico.fromMap(m)).toList();

                final filtrados = todos.where((os) {
                  final st = os.status.trim().toLowerCase();
                  if (_filtroStatus == 'Pendente') {
                    if (st != 'pendente' && !st.contains('escritório') && !st.contains('escritorio')) return false;
                  } else if (_filtroStatus == 'Em Andamento') {
                    if (st != 'em andamento' && !st.contains('bancada')) return false;
                  } else if (_filtroStatus == 'Concluída') {
                    if (st != 'concluída' && st != 'concluida' && st != 'faturada') return false;
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
                      child: Text('Nenhuma O.S. encontrada para este filtro.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _modalDetalhesOSAdmin(os),
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
                              Row(
                                children: [
                                  Expanded(child: Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: corTextoClaro))),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: corCianoEletrico, size: 20),
                                    tooltip: 'Alterar Cliente',
                                    onPressed: () => _modalAlterarClienteOS(os),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  "📄 CPF/CNPJ: ${_mapaDocClientesAdm[os.cliente.trim().toLowerCase()] ?? 'Não informado'}",
                                  style: const TextStyle(fontSize: 11, color: corTextoClaro, fontWeight: FontWeight.bold),
                                ),
                              ),
                                                            if (os.status.toLowerCase().contains('escritório') || os.status.toLowerCase().contains('escritorio'))
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orangeAccent, width: 1.2),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.notification_important_rounded, color: Colors.orangeAccent, size: 16),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '⚠️ AGUARDANDO DECISÃO DO ESCRITÓRIO (DESPACHE O DESTINO)',
                                          style: TextStyle(color: Colors.orangeAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.orangeAccent, width: 1),
                                      foregroundColor: Colors.orangeAccent,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    icon: const Icon(Icons.alt_route_rounded, size: 13),
                                    label: const Text('Despachar Destino', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _modalVoltarOSGarantia(os),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: corVerdeWhats, width: 1),
                                      foregroundColor: corVerdeWhats,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    icon: const Icon(Icons.share, size: 13),
                                    label: const Text('Whats', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _gerarDocOS(os, 'whats'),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: corCianoEletrico, width: 1),
                                      foregroundColor: corCianoEletrico,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    icon: const Icon(Icons.print, size: 13),
                                    label: const Text('Imprimir', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _gerarDocOS(os, 'imprimir'),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    tooltip: 'Excluir O.S.',
                                    onPressed: () => _confirmarExcluirOS(os.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
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