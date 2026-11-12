// ============================================================================
// ARQUIVO AUXILIAR: LANÇAMENTO MANUAL, CENTRAL DE PRECIFICAÇÃO E GESTÃO
// lib/screens/menu_telas_auxiliares.dart (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_base.dart';

// ============================================================================
// 1. LANÇAR MANUAL (APONTAMENTO DE CAMPO FEITO PELO TÉCNICO SEM PREÇO)
// ============================================================================
class TelaLancamentoTrabalhoFuncionario extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  final bool modoAdmin;
  const TelaLancamentoTrabalhoFuncionario({
    super.key,
    required this.usuarioLogado,
    this.modoAdmin = false,
  });

  @override
  State<TelaLancamentoTrabalhoFuncionario> createState() => _TelaLancamentoTrabalhoFuncionarioState();
}

class _TelaLancamentoTrabalhoFuncionarioState extends State<TelaLancamentoTrabalhoFuncionario> {
  final _clienteCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final List<ItemServico> _itens = [];
  bool _salvando = false;
  String? _idEdicaoEmAndamento;
  DateTime _dataSelecionada = DateTime.now();

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _telefoneCtrl.dispose();
    _enderecoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  List<ItemServico> _converterDescricaoEmItens(String descricao) {
    if (descricao.trim().isEmpty) return [];
    final partes = descricao.split(' | ');
    final List<ItemServico> resultado = [];

    for (var p in partes) {
      final itemStr = p.trim();
      final regexSimples = RegExp(r'^(\d+(?:\.\d+)?)\s*x\s*(.*)$');
      final match = regexSimples.firstMatch(itemStr);
      if (match != null) {
        final q = double.tryParse(match.group(1)!) ?? 1;
        final d = match.group(2) ?? '';
        resultado.add(ItemServico(descricao: d, quantidade: q, valorUnitario: 0.0));
      } else {
        resultado.add(ItemServico(descricao: itemStr, quantidade: 1, valorUnitario: 0.0));
      }
    }
    return resultado;
  }

  void _carregarParaEdicao(Map<String, dynamic> servico) {
    setState(() {
      _idEdicaoEmAndamento = servico['id']?.toString();
      _clienteCtrl.text = servico['cliente'] ?? '';
      _telefoneCtrl.text = servico['telefone'] ?? '';
      _enderecoCtrl.text = servico['endereco'] ?? '';

      if (servico['data'] != null && servico['data'].toString().isNotEmpty) {
        try {
          _dataSelecionada = DateFormat('dd/MM/yyyy').parse(servico['data'].toString());
        } catch (_) {
          _dataSelecionada = DateTime.now();
        }
      }

      final descCompleta = servico['descricao']?.toString() ?? '';
      final regexObs = RegExp(r'\[Obs:\s*(.*?)\]');
      final matchObs = regexObs.firstMatch(descCompleta);

      if (matchObs != null) {
        _obsCtrl.text = matchObs.group(1) ?? '';
        final descSemObs = descCompleta.replaceAll(matchObs.group(0)!, '').trim();
        _itens.clear();
        _itens.addAll(_converterDescricaoEmItens(descSemObs));
      } else {
        _obsCtrl.clear();
        _itens.clear();
        _itens.addAll(_converterDescricaoEmItens(descCompleta));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: corCianoEletrico, content: Text('✏️ Dados carregados! Altere e toque em Salvar.')),
    );
  }

  Future<void> _selecionarDataServico() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: corCianoEletrico, onPrimary: Colors.black, surface: corCardFundo),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dataSelecionada = picked);
    }
  }

  void _abrirPopupItem([int? indexEdit]) {
    final bool isEd = indexEdit != null;
    final dCtrl = TextEditingController(text: isEd ? _itens[indexEdit].descricao : '');
    final qCtrl = TextEditingController(
      text: isEd
          ? (_itens[indexEdit].quantidade % 1 == 0 ? _itens[indexEdit].quantidade.toInt().toString() : _itens[indexEdit].quantidade.toString())
          : '1',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: Text(isEd ? '✏️ Editar Item' : '➕ Adicionar Atividade / Peça', style: const TextStyle(color: corCianoEletrico, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dCtrl,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Descrição do que foi feito', alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantidade', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
            child: const Text('Confirmar'),
            onPressed: () {
              if (dCtrl.text.trim().isEmpty) return;
              final q = double.tryParse(qCtrl.text.replaceAll(',', '.')) ?? 1;
              setState(() {
                if (isEd) {
                  _itens[indexEdit].descricao = dCtrl.text.trim();
                  _itens[indexEdit].quantidade = q;
                } else {
                  _itens.add(ItemServico(descricao: dCtrl.text.trim(), quantidade: q, valorUnitario: 0.0));
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
    final locais = await CacheOffline.carregarClientesLocal();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: corCianoEletrico)),
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(
          builder: (ctx, setM) {
            final filtrados = locais.where((c) =>
                c.nome.toLowerCase().contains(filtro) ||
                c.telefone.contains(filtro) ||
                c.enderecoCompleto.toLowerCase().contains(filtro)).toList();

            return Container(
              padding: const EdgeInsets.all(14),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const Text('🔍 Selecionar Cliente Cadastrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18), hintText: 'Pesquisar...', isDense: true),
                    onChanged: (v) => setM(() => filtro = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(child: Text('Nenhum cliente encontrado no cache.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                        : ListView.builder(
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) => ListTile(
                              dense: true,
                              leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0F354A), child: Icon(Icons.person, color: corCianoEletrico, size: 16)),
                              title: Text(filtrados[i].nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                              subtitle: Text(filtrados[i].enderecoCompleto.isNotEmpty ? filtrados[i].enderecoCompleto : filtrados[i].telefone, style: const TextStyle(color: corCianoSuave, fontSize: 11)),
                              onTap: () {
                                setState(() {
                                  _clienteCtrl.text = filtrados[i].nome;
                                  _telefoneCtrl.text = filtrados[i].telefone;
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

  Future<void> _enviarTrabalho() async {
    final cliente = _clienteCtrl.text.trim();
    if (cliente.isEmpty || _itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha o cliente e inclua ao menos 1 item executado.')),
      );
      return;
    }

    setState(() => _salvando = true);
    final descConsolidada = _itens.map((e) => "${e.quantidade % 1 == 0 ? e.quantidade.toInt() : e.quantidade}x ${e.descricao}").join(' | ');
    final obs = _obsCtrl.text.trim();
    final descricaoFinal = obs.isNotEmpty ? "$descConsolidada [Obs: $obs]" : descConsolidada;

    final dados = {
      'cliente': cliente,
      'telefone': _telefoneCtrl.text.trim(),
      'endereco': _enderecoCtrl.text.trim(),
      'descricao': descricaoFinal,
      'quantidade': 1,
      'valor_unitario': 0.0,
      'status': 'Pendente',
      'tecnico': widget.usuarioLogado.nome,
      'data': DateFormat('dd/MM/yyyy').format(_dataSelecionada),
    };

    try {
      if (_idEdicaoEmAndamento != null) {
        await supabase.from('servicos').update(dados).eq('id', _idEdicaoEmAndamento!).timeout(const Duration(seconds: 10));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Lançamento atualizado com sucesso!')));
      } else {
        await supabase.from('servicos').insert(dados).timeout(const Duration(seconds: 10));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Trabalho de campo enviado ao escritório!')));
      }
    } catch (e) {
      await CacheOffline.salvarServicoFilaOffline(dados);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.amber.shade800, content: const Text('📦 Salvo no celular (será sincronizado na conexão)!')));
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
          _idEdicaoEmAndamento = null;
          _dataSelecionada = DateTime.now();
          _clienteCtrl.clear();
          _telefoneCtrl.clear();
          _enderecoCtrl.clear();
          _obsCtrl.clear();
          _itens.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meuNome = widget.usuarioLogado.nome.trim();

    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Lançar Trabalho de Campo (Manual)', exibirBotaoVoltar: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: corCardFundo,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _idEdicaoEmAndamento != null ? Colors.amberAccent : corCianoEletrico.withOpacity(0.65),
                        width: 1.3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _idEdicaoEmAndamento != null ? '✏️ Editando Serviço' : 'Local / Cliente da Obra',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _idEdicaoEmAndamento != null ? Colors.amberAccent : corTextoClaro),
                            ),
                            if (_idEdicaoEmAndamento != null)
                              TextButton(
                                onPressed: () => setState(() {
                                  _idEdicaoEmAndamento = null;
                                  _dataSelecionada = DateTime.now();
                                  _clienteCtrl.clear();
                                  _telefoneCtrl.clear();
                                  _enderecoCtrl.clear();
                                  _obsCtrl.clear();
                                  _itens.clear();
                                }),
                                child: const Text('Cancelar Edição', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                              )
                            else
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: corCianoEletrico),
                                  foregroundColor: corCianoEletrico,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                ),
                                icon: const Icon(Icons.search, size: 14),
                                label: const Text('Buscar', style: TextStyle(fontSize: 11)),
                                onPressed: _buscarClientes,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(controller: _clienteCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome do Cliente / Condomínio', isDense: true)),
                        const SizedBox(height: 6),
                        TextField(controller: _enderecoCtrl, decoration: const InputDecoration(labelText: 'Endereço / Local', isDense: true)),
                        const SizedBox(height: 6),
                        TextField(controller: _telefoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone de Contato (Opcional)', isDense: true)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _selecionarDataServico,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Data de Realização do Serviço', prefixIcon: Icon(Icons.calendar_month, color: corCianoEletrico, size: 18), isDense: true),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd/MM/yyyy').format(_dataSelecionada), style: const TextStyle(fontSize: 13, color: corTextoClaro, fontWeight: FontWeight.bold)),
                                const Text('Toque para alterar', style: TextStyle(color: corCianoSuave, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Serviços e Atividades:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corCianoEletrico)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Adicionar Item', style: TextStyle(fontSize: 11)),
                        onPressed: () => _abrirPopupItem(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_itens.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('Nenhum item adicionado.\nToque em "Adicionar Item" acima.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11))),
                    )
                  else
                    ..._itens.asMap().entries.map((entry) {
                      final i = entry.key;
                      final it = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(it.descricao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                          subtitle: Text("Quantidade: ${it.quantidade % 1 == 0 ? it.quantidade.toInt() : it.quantidade}", style: const TextStyle(color: corCianoSuave, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit, color: corCianoSuave, size: 16), onPressed: () => _abrirPopupItem(i)),
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: () => setState(() => _itens.removeAt(i))),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 8),
                  TextField(controller: _obsCtrl, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Observação técnica do serviço executado', alignLabelWithHint: true)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: corVerdeWhats, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      icon: _salvando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_salvando ? 'Salvando...' : (_idEdicaoEmAndamento != null ? 'SALVAR ALTERAÇÕES' : 'ENVIAR PARA O ESCRITÓRIO'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _salvando ? null : _enviarTrabalho,
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 6),
                  const Text('MEUS TRABALHOS PENDENTES (AGUARDANDO FATURAMENTO)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corCianoSuave, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase.from('servicos').stream(primaryKey: ['id']).order('id', ascending: false),
                    builder: (context, snap) {
                      final todos = snap.data ?? [];
                      final meusPendentes = todos.where((s) {
                        final tec = (s['tecnico'] ?? '').toString().trim().toLowerCase();
                        final status = (s['status'] ?? '').toString();
                        return (tec == meuNome.toLowerCase() || tec.contains(meuNome.toLowerCase())) && status == 'Pendente';
                      }).toList();

                      if (meusPendentes.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: corCardFundo, borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('Nenhum serviço pendente. Todos já foram faturados pelo escritório!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11))),
                        );
                      }

                      return Column(
                        children: meusPendentes.map((s) {
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
                                      Expanded(child: Text(s['cliente'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0x33FFC107), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('A Faturar', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  if (s['endereco'] != null && s['endereco'].toString().isNotEmpty)
                                    Text("📍 ${s['endereco']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: const Color(0x22000000), borderRadius: BorderRadius.circular(6)),
                                    child: Text(s['descricao'] ?? '', style: const TextStyle(fontSize: 11.5, color: corTextoClaro)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: corCianoEletrico), foregroundColor: corCianoEletrico, visualDensity: VisualDensity.compact),
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('Editar Campos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () => _carregarParaEdicao(s),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
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

// ============================================================================
// 2. CENTRAL: LANÇAR COM PREÇO (PRECIFICAÇÃO DE O.S., PDF, WHATSAPP E EXCLUSÃO)
// ============================================================================
class TelaPrecificacaoOS extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaPrecificacaoOS({super.key, required this.usuarioLogado});

  @override
  State<TelaPrecificacaoOS> createState() => _TelaPrecificacaoOSState();
}

class _TelaPrecificacaoOSState extends State<TelaPrecificacaoOS> {
  final supabase = Supabase.instance.client;

  // ==========================================================================
  // ITEM 3: DEVOLVER O.S. AO TÉCNICO (GARANTIA / RETRABALHO)
  // ==========================================================================
  void _modalDevolverOS(Map<String, dynamic> os) {
    final motivoC = TextEditingController();
    String tipoEtiqueta = 'GARANTIA';
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            backgroundColor: corCardFundo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.orangeAccent),
            ),
            title: Row(
              children: const [
                Icon(Icons.replay_circle_filled, color: Colors.orangeAccent, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voltar O.S. (Garantia / Retorno)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corTextoClaro),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Ref: ${os['numero_os'] ?? 'S/N'} • ${os['cliente'] ?? ''}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corCianoSuave)),
                  const SizedBox(height: 2),
                  Text("👤 Técnico: ${os['tecnico_designado'] ?? 'Não informado'}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 12),
                  const Text('Tipo de Devolução:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: corTextoClaro)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['GARANTIA', 'RETRABALHO', 'AJUSTE'].map((t) {
                      final sel = tipoEtiqueta == t;
                      return ChoiceChip(
                        label: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: sel ? Colors.black : corTextoClaro)),
                        selected: sel,
                        selectedColor: Colors.orangeAccent,
                        backgroundColor: corCardFundo,
                        onSelected: (v) {
                          if (v) setD(() => tipoEtiqueta = t);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motivoC,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Motivo / Instruções para o Técnico',
                      hintText: 'Explique o que precisa ser refeito ou verificado em garantia...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: enviando
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_rounded, size: 15),
                label: const Text('Devolver ao Técnico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: enviando
                    ? null
                    : () async {
                        final motivo = motivoC.text.trim();
                        if (motivo.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Informe o motivo da garantia / devolução!')),
                          );
                          return;
                        }

                        setD(() => enviando = true);
                        try {
                          final obsAnterior = (os['observacao_tecnico'] != null && os['observacao_tecnico'].toString().isNotEmpty)
                              ? "\n\n[HISTÓRICO ANTERIOR]: ${os['observacao_tecnico']}"
                              : '';
                          final novoProblema = "${os['descricao_problema'] ?? ''}\n\n⚠️ [DEVOLUÇÃO ESCRITÓRIO - $tipoEtiqueta]: $motivo";

                          await supabase.from('ordens_servico').update({
                            'status': 'Em Andamento',
                            'prioridade': tipoEtiqueta,
                            'descricao_problema': novoProblema,
                            'observacao_tecnico': "[RETORNO $tipoEtiqueta]: $motivo$obsAnterior",
                            'visualizado_pelo_tecnico': false,
                          }).eq('id', os['id']);

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.orange.shade800,
                                content: Text('↩️ O.S. #${os['numero_os']} devolvida como $tipoEtiqueta para ${os['tecnico_designado']}!'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao devolver O.S.: $e')),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setD(() => enviando = false);
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  List<ItemServico> _extrairItens(Map<String, dynamic> os, double valorTotal) {
    final relatorio = (os['observacao_tecnico'] ?? os['descricao_problema'] ?? '').toString();
    if (relatorio.isEmpty) {
      return [ItemServico(descricao: 'Serviço Técnico Especializado', quantidade: 1, valorUnitario: valorTotal)];
    }

    final partes = relatorio.split(' | ');
    final List<ItemServico> itens = [];

    for (var p in partes) {
      final itemStr = p.trim();
      final regexCompleto = RegExp(r'^(\d+(?:\.\d+)?)\s*x\s*(.*?)\s*\(\s*R\$\s*(\d+(?:[\.,]\d+)?)\s*\)$');
      final match = regexCompleto.firstMatch(itemStr);
      if (match != null) {
        final q = double.tryParse(match.group(1)!) ?? 1;
        final d = match.group(2) ?? '';
        final v = double.tryParse(match.group(3)!.replaceAll(',', '.')) ?? 0;
        itens.add(ItemServico(descricao: d, quantidade: q, valorUnitario: v));
      } else {
        itens.add(ItemServico(descricao: itemStr, quantidade: 1, valorUnitario: 0.0));
      }
    }

    if (itens.length == 1 && itens.first.valorUnitario == 0 && valorTotal > 0) {
      itens.first.valorUnitario = valorTotal;
    }
    return itens;
  }

  Future<void> _gerarPdfOS(Map<String, dynamic> os, {required bool diretoImpressao, required bool viaWhats}) async {
    try {
      final double valor = double.tryParse((os['valor_total'] ?? 0).toString()) ?? 0.0;
      final itens = _extrairItens(os, valor);

      final clienteObj = DadosCliente(
        nome: os['cliente'] ?? '',
        telefone: os['telefone'] ?? '',
        documento: os['cpf_cnpj'] ?? '',
        endereco: os['endereco'] ?? '',
      );

      final file = await PdfEngine.apenasGerarPdf(
        tipoDoc: 'ORÇAMENTO',
        destaque: "ORDEM DE SERVIÇO Nº ${os['numero_os'] ?? ''}",
        cliente: clienteObj,
        itens: itens,
        valorTotal: valor,
        tecnico: os['tecnico_designado'] ?? 'Técnico Responsável',
        obs: "Prioridade: ${os['prioridade'] ?? 'NORMAL'}\nProblema: ${os['descricao_problema'] ?? ''}\nServiço Realizado: ${os['observacao_tecnico'] ?? ''}",
      );

      if (viaWhats) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: "Olá! Segue o detalhamento do atendimento da *O.S. PRIME* (O.S. ${os['numero_os'] ?? ''}).",
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: diretoImpressao ? "Imprimir O.S. ${os['numero_os']}" : "Documento O.S. ${os['numero_os']}",
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao gerar PDF: $e')));
    }
  }

  void _confirmarExcluirOS(Map<String, dynamic> os) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
        title: const Text('Excluir O.S. Definitivamente?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: Text('Deseja realmente apagar a ${os['numero_os']} de "${os['cliente']}"?\n\n⚠️ Esta O.S. será apagada e NÃO constará no histórico do técnico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sim, Excluir'),
            onPressed: () async {
              try {
                if (os['id'] != null) {
                  await supabase.from('ordens_servico').delete().eq('id', os['id']);
                }
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('🗑️ O.S. excluída com sucesso!')));
            },
          ),
        ],
      ),
    );
  }

  void _modalEditarEPrecificar(Map<String, dynamic> os) {
    final valorCtrl = TextEditingController(text: (os['valor_total'] ?? '0,00').toString());
    final descProblemaCtrl = TextEditingController(text: os['descricao_problema'] ?? '');
    final relatorioTecnicoCtrl = TextEditingController(text: os['observacao_tecnico'] ?? '');
    String statusFaturamento = 'Pendente';
    bool enviandoFaturamento = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: corCianoEletrico, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Editar & Precificar ${os['numero_os'] ?? 'O.S.'}', style: const TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Cliente: ${os['cliente'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: corTextoClaro)),
                Text("Técnico: ${os['tecnico_designado'] ?? 'Geral'}", style: const TextStyle(fontSize: 11.5, color: corCianoSuave)),
                const SizedBox(height: 10),
                TextField(
                  controller: valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor Total Precificado (R\$)', prefixText: 'R\$ ', isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: statusFaturamento,
                  dropdownColor: corCardFundo,
                  decoration: const InputDecoration(labelText: 'Situação no Faturamento', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Pendente', child: Text('🟡 A Faturar (Pendente)', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: 'Faturado', child: Text('✅ Faturado (Quitado)', style: TextStyle(color: corVerdeWhats, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (v) => setD(() => statusFaturamento = v ?? 'Pendente'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descProblemaCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Problema Inicial / Solicitação', alignLabelWithHint: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: relatorioTecnicoCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'O que foi executado & Peças Aplicadas', alignLabelWithHint: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: corCianoEletrico)),
              onPressed: enviandoFaturamento
                  ? null
                  : () async {
                      final valorNum = double.tryParse(valorCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
                      try {
                        if (os['id'] != null) {
                          await supabase.from('ordens_servico').update({
                            'descricao_problema': descProblemaCtrl.text.trim(),
                            'observacao_tecnico': relatorioTecnicoCtrl.text.trim(),
                            'valor_total': valorNum,
                          }).eq('id', os['id']);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ O.S. atualizada!')));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')));
                      }
                    },
              child: const Text('Apenas Salvar', style: TextStyle(color: corCianoEletrico)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: corVerdeWhats, foregroundColor: Colors.white),
              icon: enviandoFaturamento
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text('Enviar p/ Faturamento'),
              onPressed: enviandoFaturamento
                  ? null
                  : () async {
                      setD(() => enviandoFaturamento = true);
                      final valorNum = double.tryParse(valorCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
                      final novoRelatorio = relatorioTecnicoCtrl.text.trim();

                      final dadosFaturamento = {
                        'cliente': os['cliente'] ?? '',
                        'telefone': os['telefone'] ?? '',
                        'endereco': os['endereco'] ?? '',
                        'descricao': "[${os['numero_os'] ?? 'O.S.'}] $novoRelatorio",
                        'quantidade': 1,
                        'valor_unitario': valorNum,
                        'status': statusFaturamento,
                        'tecnico': os['tecnico_designado'] ?? 'Escritório',
                        'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      };

                      try {
                        await supabase.from('servicos').insert(dadosFaturamento).timeout(const Duration(seconds: 8));
                        if (os['id'] != null) {
                          await supabase.from('ordens_servico').update({
                            'status': 'Faturada',
                            'valor_total': valorNum,
                          }).eq('id', os['id']);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: Colors.green, content: Text('🚀 Enviado ao Faturamento Nuvem e transferido para o histórico do técnico!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao enviar: $e')));
                      } finally {
                        if (ctx.mounted) setD(() => enviandoFaturamento = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Lançar c/ Preço • Central O.S.', exibirBotaoVoltar: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.assignment_turned_in_rounded, color: corCianoEletrico, size: 20),
                SizedBox(width: 8),
                Text('Ordens Concluídas Aguardando Faturamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('ordens_servico').stream(primaryKey: ['id']).order('id', ascending: false),
              builder: (context, snap) {
                final todas = snap.data ?? [];

                final paraPrecificar = todas.where((os) {
                  final status = (os['status'] ?? '').toString().trim();
                  return status == 'Concluída';
                }).toList();

                if (paraPrecificar.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhuma O.S. aguardando precificação no momento.\nAssim que os técnicos concluírem serviços em campo, eles aparecerão aqui!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: paraPrecificar.length,
                  itemBuilder: (_, i) {
                    final os = paraPrecificar[i];
                    final double valorAtual = double.tryParse((os['valor_total'] ?? 0).toString()) ?? 0.0;

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
                                Text("${os['numero_os'] ?? 'O.S.'} • ${os['prioridade'] ?? 'NORMAL'}", style: const TextStyle(fontWeight: FontWeight.bold, color: corCianoEletrico, fontSize: 12.5)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0x3325D366), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    valorAtual > 0 ? "Precificado: R\$ ${valorAtual.toStringAsFixed(2)}" : 'Aguardando Preço',
                                    style: TextStyle(color: valorAtual > 0 ? corVerdeWhats : Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(os['cliente'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: corTextoClaro)),
                            if (os['endereco'] != null && os['endereco'].toString().isNotEmpty)
                              Text("📍 ${os['endereco']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text("👤 Técnico: ${os['tecnico_designado'] ?? 'Geral'}", style: const TextStyle(fontSize: 11.5, color: corCianoSuave, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                "Problema: ${os['descricao_problema'] ?? ''}\nRelatório do Técnico: ${os['observacao_tecnico'] ?? 'Concluído em campo'}",
                                style: const TextStyle(fontSize: 11.5, color: corTextoClaro),
                              ),
                            ),
                            const Divider(height: 14),
                            Row(
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit, color: corCianoEletrico, size: 18),
                                  tooltip: 'Editar / Precificar',
                                  onPressed: () => _modalEditarEPrecificar(os),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.print, color: Colors.amberAccent, size: 18),
                                  tooltip: 'Imprimir PDF',
                                  onPressed: () => _gerarPdfOS(os, diretoImpressao: true, viaWhats: false),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.share, color: corVerdeWhats, size: 18),
                                  tooltip: 'Enviar WhatsApp',
                                  onPressed: () => _gerarPdfOS(os, diretoImpressao: false, viaWhats: true),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                  tooltip: 'Excluir O.S.',
                                  onPressed: () => _confirmarExcluirOS(os),
                                ),
                                                                const Spacer(),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.orangeAccent),
                                    foregroundColor: Colors.orangeAccent,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.replay, size: 14),
                                  label: const Text('Voltar O.S.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _modalDevolverOS(os),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: corVerdeWhats,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.price_check, size: 15),
                                  label: const Text('Precificar & Nuvem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _modalEditarEPrecificar(os),
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

// ============================================================================
// 3. GESTÃO DE EQUIPE (COM PROTEÇÃO DO 1º MASTER PRINCIPAL)
// ============================================================================
class TelaGestaoUsuarios extends StatefulWidget {
  const TelaGestaoUsuarios({super.key});
  @override
  State<TelaGestaoUsuarios> createState() => _TelaGestaoUsuariosState();
}

class _TelaGestaoUsuariosState extends State<TelaGestaoUsuarios> {
  final supabase = Supabase.instance.client;
  List<UsuarioApp> _usuariosLocais = [];

  @override
  void initState() {
    super.initState();
    _carregarUsuariosLocais();
  }

  Future<void> _carregarUsuariosLocais() async {
    final locais = await CacheOffline.carregarUsuariosLocais();
    if (mounted) setState(() => _usuariosLocais = locais);
  }

  void _modalEditarLoginESenha(UsuarioApp u) {
    final nomeC = TextEditingController(text: u.nome);
    final userC = TextEditingController(text: u.usuario);
    final foneC = TextEditingController(text: u.telefone ?? '');
    final passC = TextEditingController(text: u.senha);
    String cargoSel = u.cargo;
    if (cargoSel != 'master' && cargoSel != 'senior' && cargoSel != 'funcionario') {
      cargoSel = u.isAdmin ? 'master' : 'funcionario';
    }
    bool senhaOculta = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: Text('✏️ Editar ${u.nome}', style: const TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomeC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome Completo', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: userC, decoration: const InputDecoration(labelText: 'Login / Usuário *', isDense: true)),
                const SizedBox(height: 8),
                TextField(
                  controller: foneC,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp / Celular', prefixIcon: Icon(Icons.phone, color: corVerdeWhats, size: 18), isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passC,
                  obscureText: senhaOculta,
                  decoration: InputDecoration(
                    labelText: 'Senha *',
                    isDense: true,
                    suffixIcon: IconButton(icon: Icon(senhaOculta ? Icons.visibility : Icons.visibility_off, color: corCianoSuave, size: 18), onPressed: () => setM(() => senhaOculta = !senhaOculta)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: cargoSel,
                  isExpanded: true,
                  dropdownColor: corCardFundo,
                  decoration: const InputDecoration(labelText: 'Nível de Acesso', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'funcionario', child: Text('Técnico / Funcionário', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'senior', child: Text('⭐ Admin Sênior (Operacional)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'master', child: Text('👑 Admin Master (Acesso Total)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ],
                  onChanged: (v) => setM(() => cargoSel = v ?? 'funcionario'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
              child: const Text('Salvar Alterações'),
              onPressed: () async {
                final novoUser = userC.text.trim().toLowerCase().replaceAll('@', '');
                final novoFone = foneC.text.trim();
                final novaSenha = passC.text.trim();
                final novoNome = nomeC.text.trim();

                if (novoUser.isEmpty || novaSenha.isEmpty || novoNome.isEmpty) return;

                final antigoUser = u.usuario.trim().toLowerCase().replaceAll('@', '');
                u.nome = novoNome;
                u.usuario = novoUser;
                u.telefone = novoFone;
                u.senha = novaSenha;
                u.cargo = cargoSel;

                await CacheOffline.salvarUsuarioLocal(u, usuarioAntigo: antigoUser);
                if (antigoUser != novoUser) {
                  await CacheOffline.excluirUsuarioLocal(antigoUser);
                }

                try {
                  final mapAtualizar = u.toMap()..remove('id');
                  await supabase.from('usuarios').update(mapAtualizar).ilike('usuario', antigoUser);
                } catch (e) {
                  try {
                    await supabase.from('usuarios').upsert(u.toMap()..remove('id'));
                  } catch (_) {}
                }

                await _carregarUsuariosLocais();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Usuário atualizado com sucesso!')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _modalNovoUsuario() {
    final nomeC = TextEditingController(), userC = TextEditingController(), foneC = TextEditingController(), passC = TextEditingController();
    String cargoSel = 'funcionario';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
          title: const Text('➕ Cadastrar na Equipe', style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomeC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome do Funcionário *', isDense: true)),
                const SizedBox(height: 6),
                TextField(controller: userC, decoration: const InputDecoration(labelText: 'Login / Usuário (sem espaço) *', isDense: true)),
                const SizedBox(height: 6),
                TextField(
                  controller: foneC,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp do Membro', hintText: '(47) 99999-9999', prefixIcon: Icon(Icons.phone, color: corVerdeWhats, size: 18), isDense: true),
                ),
                const SizedBox(height: 6),
                TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: 'Senha Inicial *', isDense: true)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: cargoSel,
                  isExpanded: true,
                  dropdownColor: corCardFundo,
                  decoration: const InputDecoration(labelText: 'Tipo de Acesso', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'funcionario', child: Text('Técnico / Funcionário (Restrito)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'senior', child: Text('⭐ Admin Sênior (Operacional)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    DropdownMenuItem(value: 'master', child: Text('👑 Admin Master (Acesso Total)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                  ],
                  onChanged: (v) => setM(() => cargoSel = v ?? 'funcionario'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
              child: const Text('Cadastrar'),
              onPressed: () async {
                final nomeLimpo = nomeC.text.trim();
                final userLimpo = userC.text.trim().toLowerCase().replaceAll('@', '').replaceAll(' ', '');
                final passLimpo = passC.text.trim();

                if (nomeLimpo.isEmpty || userLimpo.isEmpty || passLimpo.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha nome, login e senha!')),
                  );
                  return;
                }

                final novo = UsuarioApp(
                  nome: nomeLimpo,
                  usuario: userLimpo,
                  telefone: foneC.text.trim(),
                  senha: passLimpo,
                  cargo: cargoSel,
                  primeiroAcesso: false,
                );

                await CacheOffline.salvarUsuarioLocal(novo);

                String? erroSupabase;
                try {
                  final mapParaNuvem = novo.toMap()..remove('id');
                  final existente = await supabase
                      .from('usuarios')
                      .select()
                      .ilike('usuario', userLimpo)
                      .timeout(const Duration(seconds: 8));

                  if (existente.isNotEmpty) {
                    await supabase.from('usuarios').update(mapParaNuvem).ilike('usuario', userLimpo);
                  } else {
                    await supabase.from('usuarios').insert(mapParaNuvem);
                  }
                } catch (e) {
                  erroSupabase = e.toString();
                }

                await _carregarUsuariosLocais();
                if (ctx.mounted) Navigator.pop(ctx);
                
                if (mounted) {
                  if (erroSupabase != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.redAccent, content: Text('⚠️ Salvo no aparelho, mas deu erro na nuvem: $erroSupabase')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Colors.green, content: Text('🚀 Funcionário cadastrado na nuvem com sucesso! Já pode fazer login.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExcluirUsuario(UsuarioApp u, {bool ehPrimeiroMaster = false}) async {
    // 🛡️ BLOQUEIO ABSOLUTO DO 1º MASTER E DO ADMIN RAIZ
    if (ehPrimeiroMaster || u.usuario.trim().toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ O Administrador Master principal não pode ser excluído.')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.redAccent)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Excluir ${u.nome}?', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text('Tem certeza que deseja apagar o usuário @${u.usuario}? O acesso dele será encerrado imediatamente.', style: const TextStyle(color: corTextoClaro, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final userLimpo = u.usuario.trim().toLowerCase().replaceAll('@', '');
      await CacheOffline.excluirUsuarioLocal(userLimpo);
      try {
        await supabase.from('usuarios').delete().ilike('usuario', userLimpo);
      } catch (_) {}
      await _carregarUsuariosLocais();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text('🗑️ Usuário @$userLimpo excluído!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Gestão de Usuários e Cargos', exibirBotaoVoltar: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Usuários Cadastrados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corTextoClaro)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.person_add, size: 14),
                  label: const Text('Novo Usuário', style: TextStyle(fontSize: 11)),
                  onPressed: _modalNovoUsuario,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('usuarios').stream(primaryKey: ['id']).order('nome'),
              builder: (context, snapshot) {
                final listaRaw = snapshot.data;
                List<UsuarioApp> usuarios = [];

                if (listaRaw != null && listaRaw.isNotEmpty) {
                  usuarios = listaRaw.map((m) => UsuarioApp.fromMap(m)).toList();
                } else {
                  usuarios = _usuariosLocais;
                }

                if (usuarios.isEmpty) {
                  return const Center(child: Text('Nenhum usuário cadastrado.', style: TextStyle(color: Colors.grey)));
                }

                // ============================================================
                // 🔍 REGRA DE PROTEÇÃO: IDENTIFICA O 1º USUÁRIO MASTER CADASTRADO
                // ============================================================
                String? primeiroMasterUser;
                String? primeiroMasterId;

                if (listaRaw != null && listaRaw.isNotEmpty) {
                  final mastersRaw = listaRaw.where((m) {
                    final c = (m['cargo'] ?? '').toString().toLowerCase().trim();
                    return c == 'master';
                  }).toList();

                  if (mastersRaw.isNotEmpty) {
                    mastersRaw.sort((a, b) {
                      if (a['created_at'] != null && b['created_at'] != null) {
                        try {
                          final dtA = DateTime.parse(a['created_at'].toString());
                          final dtB = DateTime.parse(b['created_at'].toString());
                          return dtA.compareTo(dtB);
                        } catch (_) {}
                      }
                      final idA = int.tryParse(a['id']?.toString() ?? '');
                      final idB = int.tryParse(b['id']?.toString() ?? '');
                      if (idA != null && idB != null) return idA.compareTo(idB);
                      return 0;
                    });

                    primeiroMasterUser = (mastersRaw.first['usuario'] ?? '').toString().trim().toLowerCase();
                    primeiroMasterId = mastersRaw.first['id']?.toString();
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: usuarios.length,
                  itemBuilder: (_, i) {
                    final u = usuarios[i];
                    final userLogin = u.usuario.trim().toLowerCase();

                    final bool ehPrimeiroMaster = u.isMaster && (
                      userLogin == 'admin' ||
                      (primeiroMasterUser != null && userLogin == primeiroMasterUser) ||
                      (primeiroMasterId != null && u.id != null && u.id == primeiroMasterId)
                    );

                    final String cargoTxt = u.isMaster 
                        ? (ehPrimeiroMaster ? "Master (Principal)" : "Master") 
                        : (u.isSenior ? "Sênior" : "Técnico");
                        
                    final Color cargoCor = u.isMaster ? Colors.amberAccent : (u.isSenior ? corCianoEletrico : Colors.grey);
                    final bool temWhats = u.telefone != null && u.telefone!.trim().isNotEmpty;

                    final bool podeExcluir = !ehPrimeiroMaster;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF0F354A),
                          child: Icon(
                            u.isMaster ? Icons.workspace_premium : (u.isSenior ? Icons.stars : Icons.person),
                            color: cargoCor,
                            size: 16,
                          ),
                        ),
                        title: Text(u.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                        subtitle: Text('Login: @${u.usuario} • $cargoTxt ${temWhats ? '• 📞 ${u.telefone}' : ''}', style: TextStyle(color: cargoCor, fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit, color: corCianoEletrico, size: 18),
                              tooltip: 'Editar Login e Cargo',
                              onPressed: () => _modalEditarLoginESenha(u),
                            ),
                            if (podeExcluir)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                                tooltip: 'Excluir Usuário',
                                onPressed: () => _confirmarExcluirUsuario(u, ehPrimeiroMaster: ehPrimeiroMaster),
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



