// ============================================================================
// ARQUIVO: FATURAMENTO NA NUVEM E RELATÓRIO CONSOLIDADO SEPARADO
// lib/modulo_financeiro.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'app_base.dart';

// EXPORTA OS OUTROS DOIS MÓDULOS PARA O APP RECONHECER TUDO AUTOMATICAMENTE
export 'modulo_documentos.dart';
export 'modulo_cadastros.dart';

// ============================================================================
// 1. FATURAMENTO NA NUVEM COM CARDS-BOTÃO INTELIGENTES E RELATÓRIO DETALHADO
// ============================================================================
class TelaFaturamento extends StatefulWidget {
  const TelaFaturamento({super.key});
  @override
  State<TelaFaturamento> createState() => _TelaFaturamentoState();
}

class _TelaFaturamentoState extends State<TelaFaturamento> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  List<Map<String, dynamic>> _offline = [];
  String _aba = 'Pendente'; // 'Pendente' ou 'Faturado'
  String _filtroPesquisa = '';
  final Set<dynamic> _processadosLimpeza = {};
  bool _gerandoRelatorio = false;

  @override
  void initState() {
    super.initState();
    _stream = supabase.from('servicos').stream(primaryKey: ['id']).order('id', ascending: false);
    _carregarOffline();
  }

  Future<void> _carregarOffline() async {
    final f = await CacheOffline.obterFilaServicosOffline();
    if (mounted) setState(() => _offline = f);
  }

  void _limparAntigos(List<Map<String, dynamic>> lista) {
    final hoje = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy');
    for (var s in lista) {
      final id = s['id'];
      if (id != null && !_processadosLimpeza.contains(id) && s['status'] == 'Faturado' && s['data'] != null) {
        _processadosLimpeza.add(id);
        try {
          if (hoje.difference(fmt.parse(s['data'].toString())).inDays >= 20) {
            supabase.from('servicos').delete().eq('id', id).then((_) {});
          }
        } catch (_) {}
      }
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

  String _formatarItensEmDescricao(List<ItemServico> itens) {
    return itens.map((e) {
      final qStr = (e.quantidade % 1 == 0) ? e.quantidade.toInt().toString() : e.quantidade.toString();
      return "$qStr" "x ${e.descricao} (R\$ ${e.valorUnitario.toStringAsFixed(2)})";
    }).join(' | ');
  }

  void _modalItemDialog({
    required BuildContext parentCtx,
    ItemServico? itemEdit,
    required void Function(ItemServico itemSalvo) onSalvar,
  }) {
    final dC = TextEditingController(text: itemEdit?.descricao ?? '');
    final qC = TextEditingController(text: itemEdit != null ? (itemEdit.quantidade % 1 == 0 ? itemEdit.quantidade.toInt().toString() : itemEdit.quantidade.toString()) : '1');
    final vC = TextEditingController(text: itemEdit != null ? itemEdit.valorUnitario.toStringAsFixed(2) : '');

    showDialog(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: Text(itemEdit != null ? '✏️ Editar Item e Preço' : '➕ Adicionar Item e Preço', style: const TextStyle(color: corCianoEletrico, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dC,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Descrição / Peça / Serviço', alignLabelWithHint: true),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: qC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Qtd', isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: vC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor Unit. (R\$)', isDense: true))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
            child: const Text('Salvar'),
            onPressed: () {
              if (dC.text.trim().isEmpty) return;
              final q = double.tryParse(qC.text.replaceAll(',', '.')) ?? 1;
              final v = double.tryParse(vC.text.replaceAll(',', '.')) ?? 0;
              onSalvar(ItemServico(descricao: dC.text.trim(), quantidade: q, valorUnitario: v));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

    // ==========================================================================
  // DEVOLVER O.S. AO TÉCNICO (GARANTIA / RETRABALHO) DIRETO DO FATURAMENTO
  // ==========================================================================
  void _modalDevolverOS(Map<String, dynamic> servico) {
    final desc = (servico['descricao'] ?? '').toString();
    final regexOS = RegExp(r'\[(OS-[^\]]+|O\.S\.[^\]]+)\]', caseSensitive: false);
    final match = regexOS.firstMatch(desc);
    final numOS = match != null ? match.group(1) : null;

    final motivoC = TextEditingController();
    String tipoEtiqueta = 'GARANTIA';
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.orangeAccent),
          ),
          title: const Row(
            children: [
              Icon(Icons.replay_circle_filled, color: Colors.orangeAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text('Voltar O.S. (Garantia/Retorno)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: corTextoClaro)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Cliente: ${servico['cliente'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corCianoSuave)),
                if (numOS != null) Text("Ref: $numOS", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                const Text('Motivo da Devolução:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: corTextoClaro)),
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
                      onSelected: (v) { if (v) setD(() => tipoEtiqueta = t); },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: motivoC,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Instruções para o Técnico *',
                    hintText: 'Explique o que precisa ser refeito ou ajustado...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
              onPressed: enviando ? null : () async {
                final motivo = motivoC.text.trim();
                if (motivo.isEmpty) return;
                setD(() => enviando = true);
                try {
                  if (numOS != null) {
                    await supabase.from('ordens_servico').update({
                      'status': 'Em Andamento',
                      'prioridade': tipoEtiqueta,
                      'observacao_tecnico': "[RETORNO $tipoEtiqueta]: $motivo",
                      'visualizado_pelo_tecnico': false,
                    }).ilike('numero_os', numOS);
                  }
                  if (servico['id'] != null) {
                    await supabase.from('servicos').delete().eq('id', servico['id']);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.orange.shade800, content: Text('↩️ O.S. devolvida ao técnico como $tipoEtiqueta!')),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')));
                } finally {
                  if (ctx.mounted) setD(() => enviando = false);
                }
              },
              child: const Text('Confirmar Devolução', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _modalGerenciarItensDoServico(Map<String, dynamic> servico) {
    final num valorTotalOriginal = servico['valor_unitario'] is num ? servico['valor_unitario'] : 0;
    final List<ItemServico> itens = _converterDescricaoEmItens(servico['descricao']?.toString() ?? '', valorTotalOriginal);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final double totalAtualizado = itens.fold(0.0, (acc, it) => acc + it.subtotal);
          return AlertDialog(
            backgroundColor: corCardFundo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
            title: Text('🛠️ Precificar - ${servico['cliente']}', style: const TextStyle(color: corCianoEletrico, fontSize: 15)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Peças e Mão de Obra:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Adicionar', style: TextStyle(fontSize: 11)),
                          onPressed: () => _modalItemDialog(parentCtx: ctx, onSalvar: (novo) => setM(() => itens.add(novo))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (itens.isEmpty)
                      Container(padding: const EdgeInsets.all(12), child: const Center(child: Text('Nenhum item adicionado.', style: TextStyle(color: Colors.grey, fontSize: 12))))
                    else
                      ...itens.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final it = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(it.descricao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corTextoClaro)),
                            subtitle: Text("${it.quantidade % 1 == 0 ? it.quantidade.toInt() : it.quantidade} un x R\$ ${it.valorUnitario.toStringAsFixed(2)} = R\$ ${it.subtotal.toStringAsFixed(2)}", style: const TextStyle(color: corCianoSuave, fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: corCianoSuave, size: 16), onPressed: () => _modalItemDialog(parentCtx: ctx, itemEdit: it, onSalvar: (ed) => setM(() => itens[idx] = ed))),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: () => setM(() => itens.removeAt(idx))),
                              ],
                            ),
                          ),
                        );
                      }),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                        Text('R\$ ${totalAtualizado.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corCianoEletrico)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                child: const Text('Salvar Preços'),
                onPressed: () async {
                  final novaDescricao = _formatarItensEmDescricao(itens);
                  try {
                    await supabase.from('servicos').update({
                      'descricao': novaDescricao,
                      'quantidade': 1,
                      'valor_unitario': totalAtualizado,
                    }).eq('id', servico['id']).timeout(const Duration(seconds: 5));
                  } catch (_) {}
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _alternarStatusFaturado(Map<String, dynamic> servico) async {
    final bool estaFaturado = (servico['status'] ?? '') == 'Faturado';
    final novoStatus = estaFaturado ? 'Pendente' : 'Faturado';

    try {
      await supabase.from('servicos').update({
        'status': novoStatus,
        'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      }).eq('id', servico['id']).timeout(const Duration(seconds: 5));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: estaFaturado ? Colors.amber.shade800 : corVerdeWhats,
          content: Text(estaFaturado ? '↩️ Serviço revertido para Pendente' : '✅ Serviço faturado com sucesso!'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao atualizar: $e')));
      }
    }
  }

  // ==========================================================================
  // RELATÓRIO COMPLETO COM VALORES SEPARADOS: PENDENTES, FATURADOS E TOTAL GERAL
  // ==========================================================================
  void _modalRelatorioConsolidadoDetalhado(List<Map<String, dynamic>> todosServicos) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    double totalPendente = 0.0;
    int qtdPendentes = 0;
    double totalFaturado = 0.0;
    int qtdFaturados = 0;

    for (var s in todosServicos) {
      final num q = s['quantidade'] is num ? s['quantidade'] : 1;
      final num v = s['valor_unitario'] is num ? s['valor_unitario'] : 0;
      final total = q * v;

      if (s['status'] == 'Faturado') {
        totalFaturado += total;
        qtdFaturados++;
      } else {
        totalPendente += total;
        qtdPendentes++;
      }
    }

    final double totalGeral = totalPendente + totalFaturado;
    final int qtdTotal = qtdPendentes + qtdFaturados;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: const Row(
          children: [
            Icon(Icons.analytics_rounded, color: corCianoEletrico, size: 24),
            SizedBox(width: 8),
            Text('Relatório Geral Completo', style: TextStyle(color: corCianoEletrico, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Resumo detalhado de todos os valores e serviços da nuvem:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 14),

              // CARD 1: SERVIÇOS PENDENTES (A FATURAR)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x26FFC107),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withAlpha(90)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("🟡 SERVIÇOS PENDENTES", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("$qtdPendentes serviço(s) a faturar", style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
                    ]),
                    Text(moeda.format(totalPendente), style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // CARD 2: SERVIÇOS PRONTOS (FATURADOS)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x2625D366),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: corVerdeWhats.withAlpha(90)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("✅ SERVIÇOS FATURADOS", style: TextStyle(color: corVerdeWhats, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("$qtdFaturados serviço(s) quitados", style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
                    ]),
                    Text(moeda.format(totalFaturado), style: const TextStyle(color: corVerdeWhats, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // CARD 3: MONTANTE GERAL TOTAL
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x2600D4FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: corCianoEletrico, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("🔵 MONTANTE GERAL TOTAL", style: TextStyle(color: corCianoEletrico, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      Text("Total: $qtdTotal serviço(s)", style: const TextStyle(color: corTextoClaro, fontSize: 11)),
                    ]),
                    Text(moeda.format(totalGeral), style: const TextStyle(color: corCianoEletrico, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Gerar Relatório PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              _gerarRelatorioPdf('Consolidado Geral', todosServicos);
            },
          ),
        ],
      ),
    );
  }

  void _escolherEGerarRelatorio(List<Map<String, dynamic>> todosServicos) {
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
              const Text("📄 Emitir Relatório Financeiro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corCianoEletrico)),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                leading: const CircleAvatar(backgroundColor: Color(0x33FFC107), child: Icon(Icons.pending_actions, color: Colors.amberAccent, size: 20)),
                title: const Text("Relatório de Pendentes (A Faturar)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                subtitle: const Text("Apenas serviços aguardando faturamento", style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _gerarRelatorioPdf('A Faturar (Pendentes)', todosServicos.where((s) => s['status'] != 'Faturado').toList());
                },
              ),
              ListTile(
                dense: true,
                leading: const CircleAvatar(backgroundColor: Color(0x3325D366), child: Icon(Icons.check_circle, color: corVerdeWhats, size: 20)),
                title: const Text("Relatório de Faturados (Quitados)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                subtitle: const Text("Apenas serviços já recebidos", style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _gerarRelatorioPdf('Faturados', todosServicos.where((s) => s['status'] == 'Faturado').toList());
                },
              ),
              ListTile(
                dense: true,
                leading: const CircleAvatar(backgroundColor: Color(0x3300D4FF), child: Icon(Icons.analytics_rounded, color: corCianoEletrico, size: 20)),
                title: const Text("Relatório Completo (Valores Separados e Total)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                subtitle: const Text("Montante Pendente + Montante Faturado + Geral", style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _modalRelatorioConsolidadoDetalhado(todosServicos);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _gerarRelatorioPdf(String tipo, List<Map<String, dynamic>> lista) async {
    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Não há serviços para gerar este relatório.')));
      return;
    }
    setState(() => _gerandoRelatorio = true);
    try {
      final f = await PdfEngine.gerarRelatorioFaturamentoPdf(tipoRelatorio: tipo, servicos: lista);
      await Share.shareXFiles([XFile(f.path)], text: 'Relatório Financeiro O.S. PRIME - $tipo');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao gerar relatório: $e')));
    } finally {
      if (mounted) setState(() => _gerandoRelatorio = false);
    }
  }

  void _gerarDocDiretoDoServico(Map<String, dynamic> servico, String tipoDoc) {
    final num valorTotalOriginal = servico['valor_unitario'] is num ? servico['valor_unitario'] : 0;
    final List<ItemServico> itens = _converterDescricaoEmItens(servico['descricao']?.toString() ?? '', valorTotalOriginal);

    final clienteObj = DadosCliente(
      nome: servico['cliente'] ?? '',
      telefone: servico['telefone'] ?? '',
      documento: servico['cpf_cnpj'] ?? '',
      endereco: servico['endereco'] ?? '',
    );

    PdfEngine.gerarECompartilhar(
      tipoDoc: tipoDoc,
      cliente: clienteObj,
      destaque: tipoDoc == 'ORÇAMENTO' ? 'ORÇAMENTO DE PRESTAÇÃO DE SERVIÇOS' : 'RECIBO DE PAGAMENTO QUITADO',
      itens: itens,
      obs: 'Atendimento técnico: ${servico['tecnico'] ?? 'Equipe O.S. PRIME'}',
    );
  }

  void _confirmarExclusaoServico(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        title: const Text('Excluir Registro?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: const Text('Deseja apagar este registro de faturamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('Excluir'),
            onPressed: () async {
              try { await supabase.from('servicos').delete().eq('id', id); } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Faturamento', exibirBotaoVoltar: true),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                final todos = snap.data ?? [];
                if (todos.isNotEmpty) _limparAntigos(todos);

                double totalPendente = 0.0;
                double totalFaturado = 0.0;
                for (var s in todos) {
                  final num qtd = s['quantidade'] is num ? s['quantidade'] : 1;
                  final num val = s['valor_unitario'] is num ? s['valor_unitario'] : 0;
                  final t = qtd * val;
                  if (s['status'] == 'Faturado') {
                    totalFaturado += t;
                  } else {
                    totalPendente += t;
                  }
                }

                final listaFiltrada = todos.where((s) {
                  final statusOk = (s['status'] ?? 'Pendente') == _aba;
                  if (!statusOk) return false;
                  if (_filtroPesquisa.isEmpty) return true;
                  final c = (s['cliente'] ?? '').toString().toLowerCase();
                  final d = (s['descricao'] ?? '').toString().toLowerCase();
                  final t = (s['tecnico'] ?? '').toString().toLowerCase();
                  return c.contains(_filtroPesquisa) || d.contains(_filtroPesquisa) || t.contains(_filtroPesquisa);
                }).toList();

                final bool selPendente = _aba == 'Pendente';
                final bool selFaturado = _aba == 'Faturado';

                return Column(
                  children: [
                    // ========================================================
                    // 🚀 CARDS-BOTÃO INTERATIVOS: CLIQUE DIRETO NO VALOR!
                    // ========================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // BOTÃO 1: "A FATURAR" (AO CLICAR, FILTRA OS PENDENTES)
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _aba = 'Pendente'),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selPendente ? const Color(0x3DFFC107) : const Color(0x14FFC107),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selPendente ? Colors.amberAccent : Colors.amberAccent.withOpacity(0.3),
                                    width: selPendente ? 2.0 : 1.0,
                                  ),
                                  boxShadow: selPendente
                                      ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.25), blurRadius: 8, spreadRadius: 1)]
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "A FATURAR",
                                          style: TextStyle(
                                            color: selPendente ? Colors.amberAccent : Colors.amberAccent.withOpacity(0.7),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (selPendente)
                                          const Icon(Icons.check_circle, size: 12, color: Colors.amberAccent),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      moeda.format(totalPendente),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 13.5,
                                        fontWeight: selPendente ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // BOTÃO 2: "FATURADO" (AO CLICAR, FILTRA OS QUITADOS)
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _aba = 'Faturado'),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selFaturado ? const Color(0x3D25D366) : const Color(0x1425D366),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selFaturado ? corVerdeWhats : corVerdeWhats.withOpacity(0.3),
                                    width: selFaturado ? 2.0 : 1.0,
                                  ),
                                  boxShadow: selFaturado
                                      ? [BoxShadow(color: corVerdeWhats.withOpacity(0.25), blurRadius: 8, spreadRadius: 1)]
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "FATURADO",
                                          style: TextStyle(
                                            color: selFaturado ? corVerdeWhats : corVerdeWhats.withOpacity(0.7),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (selFaturado)
                                          const Icon(Icons.check_circle, size: 12, color: corVerdeWhats),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      moeda.format(totalFaturado),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: corVerdeWhats,
                                        fontSize: 13.5,
                                        fontWeight: selFaturado ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // BOTÃO RELATÓRIO
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: corCianoEletrico),
                              foregroundColor: corCianoEletrico,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _gerandoRelatorio
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: corCianoEletrico, strokeWidth: 2))
                                : const Icon(Icons.print, size: 16),
                            label: const Text('Relatório', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: _gerandoRelatorio ? null : () => _escolherEGerarRelatorio(todos),
                          ),
                        ],
                      ),
                    ),

                    // CAMPO DE BUSCA DIRETO (SEM AQUELES BOTÕES DUPLICADOS EMBAIXO)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Filtrar por cliente, técnico ou serviço...',
                          prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _filtroPesquisa = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // LISTA DE ITENS
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await CacheOffline.sincronizarFilaComNuvem();
                          setState(() {});
                        },
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          children: [
                            if (_aba == 'Pendente' && _offline.isNotEmpty) ...[
                              ..._offline.map((s) => Card(
                                child: ListTile(
                                  dense: true,
                                  title: Text(s['cliente'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text("${s['descricao']}\n🟡 Salvo no Celular (Offline)", style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                ),
                              )),
                              const Divider(color: corCianoEletrico),
                            ],
                            if (listaFiltrada.isEmpty)
                              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhum registro encontrado.', style: TextStyle(color: Colors.grey, fontSize: 13))))
                            else
                              ...listaFiltrada.map((s) {
                                final num qtd = s['quantidade'] is num ? s['quantidade'] : 1;
                                final num unit = s['valor_unitario'] is num ? s['valor_unitario'] : 0;
                                final num totalValor = qtd * unit;
                                final bool semPreco = totalValor <= 0;
                                final bool fat = (s['status'] ?? '') == 'Faturado';
                                final String tecnico = s['tecnico']?.toString() ?? 'Escritório';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          Expanded(child: Text(s['cliente'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: corTextoClaro, fontSize: 15))),
                                          Text(
                                            semPreco ? 'Aguardando Valor' : moeda.format(totalValor),
                                            style: TextStyle(fontWeight: FontWeight.bold, color: semPreco ? Colors.amberAccent : (fat ? corVerdeWhats : corCianoEletrico), fontSize: 14),
                                          ),
                                        ]),
                                        if (s['endereco'] != null && s['endereco'].toString().isNotEmpty)
                                          Padding(padding: const EdgeInsets.only(top: 2), child: Text("📍 ${s['endereco']}", style: const TextStyle(fontSize: 11, color: corCianoSuave))),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          const Icon(Icons.person_pin, size: 13, color: corCianoSuave),
                                          const SizedBox(width: 4),
                                          Text("Técnico: $tecnico", style: const TextStyle(color: corCianoSuave, fontSize: 11, fontWeight: FontWeight.bold)),
                                          const Spacer(),
                                          Text("Data: ${s['data'] ?? ''}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ]),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity, padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                                          child: Text(s['descricao'] ?? '', style: const TextStyle(fontSize: 12, color: corTextoClaro)),
                                        ),
                                        const Divider(height: 12),
                                                                                Row(children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            icon: const Icon(Icons.edit_note, size: 16, color: Colors.amberAccent),
                                            label: const Text('Preços', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                            onPressed: () => _modalGerenciarItensDoServico(s),
                                          ),
                                          if (!fat && s['descricao'] != null && (s['descricao'].toString().contains('[OS') || s['descricao'].toString().contains('[O.S'))) ...[
                                            TextButton.icon(
                                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                              icon: const Icon(Icons.replay, size: 14, color: Colors.orangeAccent),
                                              label: const Text('Devolver O.S.', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: () => _modalDevolverOS(s),
                                            ),
                                          ],
                                          PopupMenuButton<String>(
                                            tooltip: 'Gerar PDF',
                                            icon: const Icon(Icons.picture_as_pdf, color: corCianoEletrico, size: 18),
                                            onSelected: (tipo) => _gerarDocDiretoDoServico(s, tipo),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'ORÇAMENTO', child: Text('Gerar Orçamento PDF')),
                                              PopupMenuItem(value: 'RECIBO', child: Text('Gerar Recibo PDF')),
                                            ],
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            icon: Icon(fat ? Icons.undo : Icons.check_circle, size: 15, color: fat ? Colors.amberAccent : corVerdeWhats),
                                            label: Text(fat ? 'Reverter' : 'Faturar', style: TextStyle(color: fat ? Colors.amberAccent : corVerdeWhats, fontWeight: FontWeight.bold, fontSize: 11)),
                                            onPressed: () => _alternarStatusFaturado(s),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                            onPressed: () => _confirmarExclusaoServico(s['id']),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



