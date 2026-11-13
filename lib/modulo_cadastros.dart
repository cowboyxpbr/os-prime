import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_base.dart';

class TelaClientes extends StatefulWidget {
  const TelaClientes({super.key});
  @override
  State<TelaClientes> createState() => _TelaClientesState();
}

class _TelaClientesState extends State<TelaClientes> {
  String _filtro = '';
  List<DadosCliente> _lista = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final locais = await CacheOffline.carregarClientesLocal();
    if (mounted) setState(() => _lista = locais);

    try {
      final res = await supabase.from('clientes').select().order('nome').timeout(const Duration(seconds: 4));
      if (res.isNotEmpty) {
        final remotos = (res as List).map((m) => DadosCliente.fromMap(Map<String, dynamic>.from(m))).toList();
        final Map<String, DadosCliente> mapa = {};
        for (var c in remotos) {
          if (c.id != null) mapa[c.id!] = c;
        }
        for (var c in locais) {
          if (c.id != null && !mapa.containsKey(c.id)) {
            mapa[c.id!] = c;
          }
        }
        final unificada = mapa.values.toList();
        await CacheOffline.salvarClientesLocal(unificada);
        if (mounted) setState(() => _lista = unificada);
      }
    } catch (_) {}
  }

  void _modalCliente([DadosCliente? ed]) {
    final isEd = ed != null;
    final n = TextEditingController(text: ed?.nome ?? '');
    final r = TextEditingController(text: ed?.responsavel ?? '');
    final f = TextEditingController(text: ed?.telefone ?? '');
    final d = TextEditingController(text: ed?.documento ?? '');
    final m = TextEditingController(text: ed?.email ?? '');
    final e = TextEditingController(text: ed?.endereco ?? '');
    final b = TextEditingController(text: ed?.bairro ?? '');
    final c = TextEditingController(text: ed?.cidade ?? '');
    final comp = TextEditingController(text: ed?.complemento ?? '');
    bool salvandoInterno = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: Row(
            children: [
              Icon(isEd ? Icons.edit : Icons.person_add, color: corCianoEletrico, size: 20),
              const SizedBox(width: 8),
              Text(isEd ? 'Editar Cliente' : 'Novo Cliente', style: const TextStyle(color: corCianoEletrico, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: n, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome do Cliente / Empresa *', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: r, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Responsável / Síndico', isDense: true)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: f, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp / Telefone', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: d, decoration: const InputDecoration(labelText: 'CPF ou CNPJ', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: m, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: e, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Rua e Número', isDense: true)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: b, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Bairro', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: c, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Cidade', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: comp, decoration: const InputDecoration(labelText: 'Complemento / Referência', isDense: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: salvandoInterno ? null : () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: salvandoInterno
                  ? null
                  : () async {
                      final nomeLimpo = n.text.trim();
                      if (nomeLimpo.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Informe o nome do cliente!')));
                        return;
                      }
                      setM(() => salvandoInterno = true);
                      final idFinal = ed?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                      final clienteAtualizado = DadosCliente(
                        id: idFinal,
                        nome: nomeLimpo,
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
                      locais.removeWhere((item) => (item.id != null && item.id == idFinal) || item.nome.trim().toLowerCase() == nomeLimpo.toLowerCase());
                      locais.insert(0, clienteAtualizado);
                      await CacheOffline.salvarClientesLocal(locais);
                      if (mounted) setState(() => _lista = List.from(locais));

                      try {
                        final Map<String, dynamic> payload = {
                          'nome': clienteAtualizado.nome,
                          'responsavel': clienteAtualizado.responsavel,
                          'telefone': clienteAtualizado.telefone,
                          'cpf_cnpj': clienteAtualizado.documento,
                          'documento': clienteAtualizado.documento,
                          'email': clienteAtualizado.email,
                          'endereco': clienteAtualizado.endereco,
                          'bairro': clienteAtualizado.bairro,
                          'cidade': clienteAtualizado.cidade,
                          'complemento': clienteAtualizado.complemento,
                        };
                        if (isEd && ed.id != null) {
                          await supabase.from('clientes').update(payload).eq('id', ed.id!).timeout(const Duration(seconds: 5));
                        } else {
                          final res = await supabase.from('clientes').insert(payload).select().maybeSingle().timeout(const Duration(seconds: 5));
                          if (res != null && res['id'] != null) {
                            clienteAtualizado.id = res['id'].toString();
                            await CacheOffline.salvarClientesLocal(locais);
                          }
                        }
                      } catch (_) {}

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(isEd ? '✅ Cliente atualizado!' : '✅ Cliente cadastrado com sucesso!')));
                      }
                    },
              child: salvandoInterno
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text(isEd ? 'Salvar Alterações' : 'Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _excluirCliente(DadosCliente c) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
        title: const Text('Excluir Cliente?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: Text('Deseja realmente remover o cliente "${c.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );

    if (conf == true) {
      final locais = await CacheOffline.carregarClientesLocal();
      locais.removeWhere((item) => (c.id != null && item.id == c.id) || item.nome.trim().toLowerCase() == c.nome.trim().toLowerCase());
      await CacheOffline.salvarClientesLocal(locais);
      if (mounted) setState(() => _lista = List.from(locais));
      if (c.id != null) {
        try {
          await supabase.from('clientes').delete().eq('id', c.id!).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('🗑️ Cliente removido!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _lista.where((c) {
      if (_filtro.isEmpty) return true;
      final f = _filtro.toLowerCase();
      return c.nome.toLowerCase().contains(f) || c.telefone.contains(f) || c.responsavel.toLowerCase().contains(f);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Cadastro de Clientes', exibirBotaoVoltar: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18),
                      hintText: 'Buscar por nome, fone, responsável...',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _filtro = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
                  icon: const Icon(Icons.person_add, size: 18),
                  tooltip: 'Adicionar Cliente',
                  onPressed: () => _modalCliente(),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(child: Text('Nenhum cliente cadastrado.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final c = filtrados[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0F354A), child: Icon(Icons.person, color: corCianoEletrico, size: 16)),
                          title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                          subtitle: Text(
                            "📞 ${c.telefone.isNotEmpty ? c.telefone : 'Sem telefone'}\n📍 ${c.enderecoCompleto.isNotEmpty ? c.enderecoCompleto : 'Sem endereço'}",
                            style: const TextStyle(color: corCianoSuave, fontSize: 10),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit, color: corCianoEletrico, size: 16), onPressed: () => _modalCliente(c)),
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: () => _excluirCliente(c)),
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

class TelaNotas extends StatefulWidget {
  final String? usuarioKey;
  final String? nomeUsuario;

  const TelaNotas({super.key, this.usuarioKey, this.nomeUsuario});

  @override
  State<TelaNotas> createState() => _TelaNotasState();
}

class _TelaNotasState extends State<TelaNotas> {
  List<NotaApp> _notas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await CacheOffline.carregarNotasLocal(usuarioKey: widget.usuarioKey);
    if (mounted) {
      setState(() => _notas = lista);
      _verificarAlarmesVencendo(lista);
    }
  }

  DateTime? _extrairDataAlarme(String dataHoraStr) {
    if (!dataHoraStr.contains('🔔 ALARME:')) return null;
    try {
      final parte = dataHoraStr.split('🔔 ALARME:').last.trim();
      return DateFormat('dd/MM/yyyy HH:mm').parse(parte);
    } catch (_) {
      return null;
    }
  }

  void _verificarAlarmesVencendo(List<NotaApp> lista) {
    final agora = DateTime.now();
    for (final n in lista) {
      final dtAlarme = _extrairDataAlarme(n.dataHora);
      if (dtAlarme != null) {
        final diffMin = dtAlarme.difference(agora).inMinutes;
        if (diffMin <= 0 && diffMin >= -120) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.amberAccent,
                duration: const Duration(seconds: 6),
                content: Text(
                  '⏰ ALARME DE NOTA: "${n.titulo}" (${DateFormat('dd/MM/yyyy HH:mm').format(dtAlarme)})!',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            );
          });
          break;
        }
      }
    }
  }

  void _abrirDetalheNota([NotaApp? notaExistente]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaDetalheNota(
          nota: notaExistente,
          usuarioKey: widget.usuarioKey,
        ),
      ),
    );
    _carregar();
  }

  Future<void> _excluirNota(NotaApp n) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
        title: const Text('Excluir Anotação', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: Text('Deseja excluir "${n.titulo.isEmpty ? 'Sem Título' : n.titulo}"?', style: const TextStyle(color: corTextoClaro, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      final lista = await CacheOffline.carregarNotasLocal(usuarioKey: widget.usuarioKey);
      lista.removeWhere((item) => item.id == n.id);
      await CacheOffline.salvarNotasLocal(lista, usuarioKey: widget.usuarioKey);
    if (_alarmeSelecionado != null) {
      ServicoNotificacaoOneSignal.agendarAlarmeNotaPush(tituloNota: t.isEmpty ? 'Lembrete / Evento' : t, conteudoNota: c, dataAlarmeLocal: _alarmeSelecionado!);
    }
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitulo = (widget.nomeUsuario != null && widget.nomeUsuario!.trim().isNotEmpty)
        ? 'Notas de Campo • ${widget.nomeUsuario}'
        : 'Notas de Campo & Alarmes';

    return Scaffold(
      body: Column(
        children: [
          BannerOSPrime(subtituloTela: subtitulo, exibirBotaoVoltar: true),
          Expanded(
            child: _notas.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma anotação ou alarme salvo.\nToque no botão "+" para criar!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notas.length,
                    itemBuilder: (_, i) {
                      final n = _notas[i];
                      final temAlarme = n.dataHora.contains('🔔 ALARME:');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: temAlarme ? Colors.amberAccent.withOpacity(0.8) : Colors.white12, width: temAlarme ? 1.4 : 1),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: temAlarme ? Colors.amberAccent.withOpacity(0.2) : const Color(0xFF0F354A),
                            child: Icon(
                              temAlarme ? Icons.alarm_on_rounded : Icons.note_alt_rounded,
                              color: temAlarme ? Colors.amberAccent : corCianoEletrico,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            n.titulo.isEmpty ? 'Sem Título' : n.titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro),
                          ),
                          subtitle: Text(
                            n.dataHora,
                            style: TextStyle(
                              fontSize: 11,
                              color: temAlarme ? Colors.amberAccent : corCianoSuave,
                              fontWeight: temAlarme ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () => _excluirNota(n),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 12, color: corCianoSuave),
                            ],
                          ),
                          onTap: () => _abrirDetalheNota(n),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: corCianoEletrico,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add, size: 20),
        onPressed: () => _abrirDetalheNota(),
      ),
    );
  }
}

class TelaDetalheNota extends StatefulWidget {
  final NotaApp? nota;
  final String? usuarioKey;

  const TelaDetalheNota({super.key, this.nota, this.usuarioKey});

  @override
  State<TelaDetalheNota> createState() => _TelaDetalheNotaState();
}

class _TelaDetalheNotaState extends State<TelaDetalheNota> {
  late final TextEditingController _titCtrl;
  late final TextEditingController _conteudoCtrl;
  late String dataCriacaoBase;
  DateTime? _alarmeSelecionado;

  @override
  void initState() {
    super.initState();
    _titCtrl = TextEditingController(text: widget.nota?.titulo ?? '');
    _conteudoCtrl = TextEditingController(text: widget.nota?.conteudo ?? '');
    final rawData = widget.nota?.dataHora ?? DateFormat('dd/MM/yyyy • HH:mm').format(DateTime.now());
    if (rawData.contains(' | 🔔 ALARME:')) {
      final partes = rawData.split(' | 🔔 ALARME:');
      dataCriacaoBase = partes.first.trim();
      try {
        _alarmeSelecionado = DateFormat('dd/MM/yyyy HH:mm').parse(partes.last.trim());
      } catch (_) {}
    } else {
      dataCriacaoBase = rawData;
    }
  }

  @override
  void dispose() {
    _titCtrl.dispose();
    _conteudoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataHoraAlarme() async {
    final agora = DateTime.now();
    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _alarmeSelecionado ?? agora,
      firstDate: DateTime(agora.year, agora.month, agora.day),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.amberAccent,
            onPrimary: Colors.black,
            surface: corCardFundo,
          ),
        ),
        child: child!,
      ),
    );
    if (dataEscolhida == null || !mounted) return;

    final horaEscolhida = await showTimePicker(
      context: context,
      initialTime: _alarmeSelecionado != null
          ? TimeOfDay.fromDateTime(_alarmeSelecionado!)
          : TimeOfDay.fromDateTime(agora.add(const Duration(hours: 1))),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.amberAccent,
            onPrimary: Colors.black,
            surface: corCardFundo,
          ),
        ),
        child: child!,
      ),
    );
    if (horaEscolhida == null || !mounted) return;

    setState(() {
      _alarmeSelecionado = DateTime(
        dataEscolhida.year,
        dataEscolhida.month,
        dataEscolhida.day,
        horaEscolhida.hour,
        horaEscolhida.minute,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber.shade800,
        content: Text(
          '⏰ Alarme programado para ${DateFormat('dd/MM/yyyy às HH:mm').format(_alarmeSelecionado!)}! Toque no ✅ no topo para salvar.',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    final t = _titCtrl.text.trim();
    final c = _conteudoCtrl.text.trim();
    if (t.isEmpty && c.isEmpty && _alarmeSelecionado == null) {
      Navigator.pop(context);
      return;
    }

    final String fmtAlarme = _alarmeSelecionado != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(_alarmeSelecionado!)
        : '';
    final String dataHoraFinal = _alarmeSelecionado != null
        ? '$dataCriacaoBase | 🔔 ALARME: $fmtAlarme'
        : dataCriacaoBase;

    final lista = await CacheOffline.carregarNotasLocal(usuarioKey: widget.usuarioKey);
    final idNota = widget.nota?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    lista.removeWhere((n) => n.id == idNota);
    lista.insert(0, NotaApp(id: idNota, titulo: t.isEmpty ? 'Lembrete / Evento' : t, conteudo: c, dataHora: dataHoraFinal));

    await CacheOffline.salvarNotasLocal(lista, usuarioKey: widget.usuarioKey);
    if (_alarmeSelecionado != null) {
      ServicoNotificacaoOneSignal.agendarAlarmeNotaPush(tituloNota: t.isEmpty ? 'Lembrete / Evento' : t, conteudoNota: c, dataAlarmeLocal: _alarmeSelecionado!);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    if (widget.nota == null) {
      Navigator.pop(context);
      return;
    }
    final lista = await CacheOffline.carregarNotasLocal(usuarioKey: widget.usuarioKey);
    lista.removeWhere((n) => n.id == widget.nota!.id);
    await CacheOffline.salvarNotasLocal(lista, usuarioKey: widget.usuarioKey);
    if (_alarmeSelecionado != null) {
      ServicoNotificacaoOneSignal.agendarAlarmeNotaPush(tituloNota: t.isEmpty ? 'Lembrete / Evento' : t, conteudoNota: c, dataAlarmeLocal: _alarmeSelecionado!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strAlarme = _alarmeSelecionado != null
        ? DateFormat('dd/MM/yyyy • HH:mm').format(_alarmeSelecionado!)
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: corCardFundo,
        title: const Text('Nota & Evento', style: TextStyle(color: corCianoEletrico, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Programar Alarme / Evento',
            icon: Icon(
              _alarmeSelecionado != null ? Icons.alarm_on_rounded : Icons.add_alarm_rounded,
              color: Colors.amberAccent,
            ),
            onPressed: _selecionarDataHoraAlarme,
          ),
          if (widget.nota != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _excluir,
            ),
          IconButton(
            icon: const Icon(Icons.check, color: corVerdeWhats),
            onPressed: _salvar,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _selecionarDataHoraAlarme,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _alarmeSelecionado != null ? const Color(0x26FFC107) : corCardFundo,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _alarmeSelecionado != null ? Colors.amberAccent : corCianoEletrico.withOpacity(0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _alarmeSelecionado != null ? Icons.notifications_active_rounded : Icons.event_available_rounded,
                      color: _alarmeSelecionado != null ? Colors.amberAccent : corCianoEletrico,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strAlarme != null
                            ? '🔔 Alarme Programado: $strAlarme'
                            : '⏰ Toque aqui para programar Data e Hora de Alarme / Evento',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _alarmeSelecionado != null ? Colors.amberAccent : corCianoSuave,
                        ),
                      ),
                    ),
                    if (_alarmeSelecionado != null)
                      InkWell(
                        onTap: () => setState(() => _alarmeSelecionado = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16, color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titCtrl,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corTextoClaro),
              decoration: const InputDecoration(hintText: 'Título da nota ou evento...', border: InputBorder.none, filled: false),
            ),
            Text('Criada em: $dataCriacaoBase', style: const TextStyle(fontSize: 11, color: corCianoSuave)),
            const Divider(color: Colors.white24),
            Expanded(
              child: TextField(
                controller: _conteudoCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 14, color: corTextoClaro),
                decoration: const InputDecoration(hintText: 'Digite suas anotações ou detalhes do evento...', border: InputBorder.none, filled: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}