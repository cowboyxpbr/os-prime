// ============================================================================
// HISTÓRICO COMPLETO & PRESTAÇÃO DE CONTAS DO TÉCNICO (MODAL CENTRALIZADO)
// lib/screens/historico_funcionario_page.dart (O.S. Prime)
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_base.dart';

// Modelo unificado de item de histórico (O.S. ou Trabalho Manual)
class RegistroHistorico {
  final String id;
  final String tipo; // 'O.S.' ou 'Trabalho Manual'
  final String referencia;
  final String cliente;
  final String telefone;
  final String endereco;
  final String descricao;
  final String prioridade;
  final String status;
  final String dataFormatada;
  final DateTime dataObj;
  final double valor;

  RegistroHistorico({
    required this.id,
    required this.tipo,
    required this.referencia,
    required this.cliente,
    required this.telefone,
    required this.endereco,
    required this.descricao,
    required this.prioridade,
    required this.status,
    required this.dataFormatada,
    required this.dataObj,
    this.valor = 0.0,
  });
}

class TelaHistoricoFuncionario extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaHistoricoFuncionario({super.key, required this.usuarioLogado});

  @override
  State<TelaHistoricoFuncionario> createState() => _TelaHistoricoFuncionarioState();
}

class _TelaHistoricoFuncionarioState extends State<TelaHistoricoFuncionario> {
  final supabase = Supabase.instance.client;

  List<RegistroHistorico> _todosRegistros = [];
  bool _carregando = true;

  // Busca e Filtros
  bool _exibirBusca = false;
  String _busca = '';

  // Filtros ativos para Relatório
  bool _filtroPlantao = true;
  bool _filtroEmergencia = true;
  bool _filtroUrgencia = true;
  bool _filtroPadrao = true;
  bool _filtroOS = true;
  bool _filtroManual = true;

  DateTime? _dataInicial;
  DateTime? _dataFinal;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Color _corPrioridade(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'emergência':
      case 'emergencia':
        return Colors.redAccent;
      case 'urgente':
      case 'urgência':
      case 'urgencia':
        return Colors.orangeAccent;
      case 'plantão':
      case 'plantao':
        return Colors.purpleAccent;
      default:
        return corCianoEletrico;
    }
  }

  // Verifica se o registro pertence estritamente ao usuário logado
  bool _pertenceAoTecnico(String? tecCampo, String meuLogin, String meuNome) {
    if (tecCampo == null || tecCampo.trim().isEmpty) return false;
    final tec = tecCampo.trim().toLowerCase();
    return tec == meuLogin ||
        tec == meuNome ||
        (meuLogin.isNotEmpty && tec.contains(meuLogin)) ||
        (meuNome.isNotEmpty && tec.contains(meuNome)) ||
        (meuNome.isNotEmpty && meuNome.contains(tec));
  }

  Future<void> _carregarHistorico() async {
    setState(() => _carregando = true);
    final List<RegistroHistorico> lista = [];
    final meuLogin = widget.usuarioLogado.usuario.trim().toLowerCase();
    final meuNome = widget.usuarioLogado.nome.trim().toLowerCase();

    // Conjunto para guardar as referências das O.S. já carregadas (evita duplicatas)
    final Set<String> numerosOSCarregados = {};

    try {
      // 1. CARREGA AS ORDENS DE SERVIÇO DO USUÁRIO
      final resOS = await supabase.from('ordens_servico').select().order('id', ascending: false);
      for (var m in resOS) {
        final status = (m['status'] ?? '').toString().trim();
        final stLower = status.toLowerCase();

        // 🛡️ Se for cancelada ou excluída em qualquer variação, NUNCA entra no histórico
        // Não entram no histórico: canceladas, excluídas ou que ainda estejam pendentes/em andamento
        if (stLower.contains('cancel') || stLower.contains('exclu') || stLower == 'pendente' || stLower == 'em andamento') {
          continue;
        }

        // Verifica se pertence estritamente ao usuário logado
        final tec = (m['tecnico_designado'] ?? m['tecnico'] ?? '').toString();
        final corresponde = _pertenceAoTecnico(tec, meuLogin, meuNome);

        if (corresponde) {
          DateTime dt = DateTime.now();
          if (m['created_at'] != null) {
            try {
              dt = DateTime.parse(m['created_at']).toLocal();
            } catch (_) {}
          }

          final num valorOS = m['valor_total'] is num ? m['valor_total'] : 0.0;
          final numOS = (m['numero_os'] ?? 'O.S.').toString().trim();
          
          // Registra para impedir que a cópia em 'servicos' duplique este item
          if (numOS.isNotEmpty) {
            numerosOSCarregados.add(numOS.toLowerCase());
          }

          lista.add(RegistroHistorico(
            id: m['id']?.toString() ?? '',
            tipo: 'O.S.',
            referencia: numOS,
            cliente: m['cliente'] ?? 'Cliente não informado',
            telefone: m['telefone'] ?? '',
            endereco: m['endereco'] ?? '',
            descricao: (m['observacao_tecnico'] != null && m['observacao_tecnico'].toString().isNotEmpty)
                ? m['observacao_tecnico'].toString()
                : (m['descricao_problema'] ?? ''),
            prioridade: m['prioridade'] ?? 'Normal',
            status: status == 'Faturada' ? 'Faturada no Escritório' : status,
            dataFormatada: DateFormat('dd/MM/yyyy').format(dt),
            dataObj: dt,
            valor: valorOS.toDouble(),
          ));
        }
      }

      // 2. CARREGA APENAS OS TRABALHOS MANUAIS REAIS (IGNORANDO CÓPIAS DE O.S.)
      final resServicos = await supabase.from('servicos').select().order('id', ascending: false);
      for (var s in resServicos) {
        final status = (s['status'] ?? '').toString().trim();
        final stLower = status.toLowerCase();

        // 🛡️ Se for cancelado ou excluído, nunca entra no histórico
        // Não entram no histórico: canceladas, excluídas ou que ainda estejam pendentes/em andamento
        if (stLower.contains('cancel') || stLower.contains('exclu') || stLower == 'pendente' || stLower == 'em andamento') {
          continue;
        }

        final desc = (s['descricao'] ?? '').toString().trim();
        final descLower = desc.toLowerCase();

        // 🛡️ ANTI-DUPLICAÇÃO: Se for cópia de O.S. já enviada ao faturamento, IGNORA!
        final bool comecaComOS = descLower.startsWith('[os') || descLower.startsWith('[o.s');
        final bool jaCarregado = numerosOSCarregados.any((osRef) => descLower.contains(osRef));
        
        if (comecaComOS || jaCarregado) {
          continue; // Pula este registro pois ele já está no histórico vindo de ordens_servico!
        }

        final tec = (s['tecnico'] ?? s['tecnico_designado'] ?? '').toString();
        final corresponde = _pertenceAoTecnico(tec, meuLogin, meuNome);

        if (corresponde) {
          DateTime dt = DateTime.now();
          if (s['data'] != null) {
            try {
              dt = DateFormat('dd/MM/yyyy').parse(s['data'].toString());
            } catch (_) {}
          }

          final num qtd = s['quantidade'] is num ? s['quantidade'] : 1;
          final num val = s['valor_unitario'] is num ? s['valor_unitario'] : 0.0;

          lista.add(RegistroHistorico(
            id: s['id']?.toString() ?? '',
            tipo: 'Trabalho Manual',
            referencia: 'Lançamento Direto',
            cliente: s['cliente'] ?? 'Cliente não informado',
            telefone: s['telefone'] ?? '',
            endereco: s['endereco'] ?? '',
            descricao: desc,
            prioridade: 'Normal',
            status: s['status'] ?? 'Finalizado',
            dataFormatada: s['data']?.toString() ?? DateFormat('dd/MM/yyyy').format(dt),
            dataObj: dt,
            valor: (qtd * val).toDouble(),
          ));
        }
      }

      // Ordena decrescente por data (mais recentes no topo)
      lista.sort((a, b) => b.dataObj.compareTo(a.dataObj));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _todosRegistros = lista;
        _carregando = false;
      });
    }
  }

  List<RegistroHistorico> _obterFiltrados({
    bool aplicarCheckboxes = false,
    bool? plantao,
    bool? emergencia,
    bool? urgencia,
    bool? padrao,
    bool? os,
    bool? manual,
    DateTime? dIni,
    DateTime? dFim,
  }) {
    final usePlantao = aplicarCheckboxes ? (plantao ?? _filtroPlantao) : true;
    final useEmergencia = aplicarCheckboxes ? (emergencia ?? _filtroEmergencia) : true;
    final useUrgencia = aplicarCheckboxes ? (urgencia ?? _filtroUrgencia) : true;
    final usePadrao = aplicarCheckboxes ? (padrao ?? _filtroPadrao) : true;
    final useOS = aplicarCheckboxes ? (os ?? _filtroOS) : true;
    final useManual = aplicarCheckboxes ? (manual ?? _filtroManual) : true;
    final inicio = dIni ?? _dataInicial;
    final fim = dFim ?? _dataFinal;

    return _todosRegistros.where((item) {
      if (_busca.trim().isNotEmpty) {
        final b = _busca.trim().toLowerCase();
        final match = item.cliente.toLowerCase().contains(b) ||
            item.endereco.toLowerCase().contains(b) ||
            item.descricao.toLowerCase().contains(b) ||
            item.referencia.toLowerCase().contains(b);
        if (!match) return false;
      }

      if (aplicarCheckboxes) {
        if (!useOS && item.tipo == 'O.S.') return false;
        if (!useManual && item.tipo == 'Trabalho Manual') return false;

        final p = item.prioridade.toLowerCase();
        final isPlantao = p.contains('plant');
        final isEmergencia = p.contains('emerg');
        final isUrgencia = p.contains('urg');
        final isPadrao = !isPlantao && !isEmergencia && !isUrgencia;

        if (isPlantao && !usePlantao) return false;
        if (isEmergencia && !useEmergencia) return false;
        if (isUrgencia && !useUrgencia) return false;
        if (isPadrao && !usePadrao) return false;
      }

      if (inicio != null) {
        final i = DateTime(inicio.year, inicio.month, inicio.day);
        if (item.dataObj.isBefore(i)) return false;
      }
      if (fim != null) {
        final f = DateTime(fim.year, fim.month, fim.day, 23, 59, 59);
        if (item.dataObj.isAfter(f)) return false;
      }

      return true;
    }).toList();
  }

  void _modalDetalhesSomenteLeitura(RegistroHistorico item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _corPrioridade(item.prioridade), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(item.tipo == 'O.S.' ? Icons.assignment : Icons.build_circle, color: _corPrioridade(item.prioridade), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${item.referencia} • Somente Leitura',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _corPrioridade(item.prioridade).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _corPrioridade(item.prioridade)),
                    ),
                    child: Text(
                      item.prioridade.toUpperCase(),
                      style: TextStyle(color: _corPrioridade(item.prioridade), fontWeight: FontWeight.bold, fontSize: 10.5),
                    ),
                  ),
                  Text(
                    "📅 ${item.dataFormatada}",
                    style: const TextStyle(color: corCianoSuave, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text("CLIENTE:", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(item.cliente, style: const TextStyle(color: corTextoClaro, fontSize: 14, fontWeight: FontWeight.bold)),
              if (item.telefone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text("📞 ${item.telefone}", style: const TextStyle(color: corCianoSuave, fontSize: 11.5)),
              ],
              if (item.endereco.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text("📍 ${item.endereco}", style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
              ],
              const SizedBox(height: 10),
              const Divider(color: Colors.white12),
              const Text("SERVIÇO / ATIVIDADE REALIZADA:", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                child: Text(item.descricao, style: const TextStyle(color: corTextoClaro, fontSize: 12.5)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Status: ${item.status}", style: const TextStyle(color: corVerdeWhats, fontWeight: FontWeight.bold, fontSize: 11.5)),
                  if (item.valor > 0)
                    Text(
                      "Valor: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(item.valor)}",
                      style: const TextStyle(color: corCianoEletrico, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalRelatorio() {
    bool tempPlantao = _filtroPlantao;
    bool tempEmergencia = _filtroEmergencia;
    bool tempUrgencia = _filtroUrgencia;
    bool tempPadrao = _filtroPadrao;
    bool tempOS = _filtroOS;
    bool tempManual = _filtroManual;
    DateTime? tempIni = _dataInicial;
    DateTime? tempFim = _dataFinal;
    bool processando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: corCardFundo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: corCianoEletrico, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final itensFiltrados = _obterFiltrados(
            aplicarCheckboxes: true,
            plantao: tempPlantao,
            emergencia: tempEmergencia,
            urgencia: tempUrgencia,
            padrao: tempPadrao,
            os: tempOS,
            manual: tempManual,
            dIni: tempIni,
            dFim: tempFim,
          );

          return SafeArea(
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
                        Text(
                          'Emissão de Relatório de Produção',
                          style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Marque as caixas e selecione o período desejado:',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    const Text('PERÍODO DE FECHAMENTO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corCianoSuave)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: tempIni ?? DateTime.now(),
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2035),
                                builder: (c, w) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: corCianoEletrico, onPrimary: Colors.black, surface: corCardFundo)), child: w!),
                              );
                              if (p != null) setM(() => tempIni = p);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: const Color(0xFF162332), borderRadius: BorderRadius.circular(8), border: Border.all(color: tempIni != null ? corCianoEletrico : Colors.white12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Data Inicial', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  Text(tempIni != null ? DateFormat('dd/MM/yyyy').format(tempIni!) : 'Selecionar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tempIni != null ? corTextoClaro : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: tempFim ?? (tempIni ?? DateTime.now()),
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2035),
                                builder: (c, w) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: corCianoEletrico, onPrimary: Colors.black, surface: corCardFundo)), child: w!),
                              );
                              if (p != null) setM(() => tempFim = p);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: const Color(0xFF162332), borderRadius: BorderRadius.circular(8), border: Border.all(color: tempFim != null ? corCianoEletrico : Colors.white12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Data Final', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  Text(tempFim != null ? DateFormat('dd/MM/yyyy').format(tempFim!) : 'Selecionar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tempFim != null ? corTextoClaro : Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (tempIni != null || tempFim != null)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.redAccent, size: 18),
                            onPressed: () => setM(() {
                              tempIni = null;
                              tempFim = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text('TAGS DE PRIORIDADE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corCianoSuave)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildCheckbox(label: '🚨 Plantão', value: tempPlantao, cor: Colors.purpleAccent, onChanged: (v) => setM(() => tempPlantao = v!)),
                        _buildCheckbox(label: '⚠️ Emergência', value: tempEmergencia, cor: Colors.redAccent, onChanged: (v) => setM(() => tempEmergencia = v!)),
                        _buildCheckbox(label: '⚡ Urgência', value: tempUrgencia, cor: Colors.orangeAccent, onChanged: (v) => setM(() => tempUrgencia = v!)),
                        _buildCheckbox(label: '✅ Padrão', value: tempPadrao, cor: corCianoEletrico, onChanged: (v) => setM(() => tempPadrao = v!)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    const Text('TIPO DE REGISTRO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: corCianoSuave)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildCheckbox(label: 'Ordens de Serviço (O.S.)', value: tempOS, cor: corAmareloSuave, onChanged: (v) => setM(() => tempOS = v!)),
                        const SizedBox(width: 8),
                        _buildCheckbox(label: 'Trabalhos de Campo', value: tempManual, cor: corVerdeWhats, onChanged: (v) => setM(() => tempManual = v!)),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.white24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${itensFiltrados.length} serviço(s) selecionado(s)',
                          style: const TextStyle(color: corCianoSuave, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => setM(() {
                            tempPlantao = true;
                            tempEmergencia = true;
                            tempUrgencia = true;
                            tempPadrao = true;
                            tempOS = true;
                            tempManual = true;
                            tempIni = null;
                            tempFim = null;
                          }),
                          child: const Text('Marcar Todos', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: corCianoEletrico,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: processando
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('Exportar PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            onPressed: processando || itensFiltrados.isEmpty
                                ? null
                                : () async {
                                    setM(() => processando = true);
                                    await _exportarRelatorio(itensFiltrados, tempIni, tempFim, false);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: corVerdeWhats,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Enviar WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            onPressed: processando || itensFiltrados.isEmpty
                                ? null
                                : () async {
                                    setM(() => processando = true);
                                    await _exportarRelatorio(itensFiltrados, tempIni, tempFim, true);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckbox({required String label, required bool value, required Color cor, required ValueChanged<bool?> onChanged}) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? cor.withOpacity(0.18) : const Color(0xFF162332),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: value ? cor : Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: value ? cor : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: value ? corTextoClaro : Colors.grey, fontWeight: value ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportarRelatorio(List<RegistroHistorico> itens, DateTime? ini, DateTime? fim, bool viaWhats) async {
    String periodoTexto = 'Completo';
    if (ini != null && fim != null) {
      periodoTexto = "${DateFormat('dd/MM/yyyy').format(ini)} até ${DateFormat('dd/MM/yyyy').format(fim)}";
    } else if (ini != null) {
      periodoTexto = "A partir de ${DateFormat('dd/MM/yyyy').format(ini)}";
    } else if (fim != null) {
      periodoTexto = "Até ${DateFormat('dd/MM/yyyy').format(fim)}";
    }

    final listaFormatada = itens.map((r) => {
      'cliente': r.cliente,
      'data': r.dataFormatada,
      'descricao': '[${r.tipo} • ${r.referencia} | ${r.prioridade.toUpperCase()}] ${r.descricao}',
      'tecnico': widget.usuarioLogado.nome,
      'status': r.status,
      'quantidade': 1,
      'valor_unitario': r.valor,
    }).toList();

    try {
      final f = await PdfEngine.gerarRelatorioFaturamentoPdf(
        tipoRelatorio: 'Prestação de Contas - ${widget.usuarioLogado.nome} ($periodoTexto)',
        servicos: listaFormatada,
      );

      if (viaWhats) {
        await Share.shareXFiles([XFile(f.path)], text: '📄 Segue meu relatório de prestação de contas (${widget.usuarioLogado.nome}) - O.S. Prime.');
      } else {
        await Share.shareXFiles([XFile(f.path)], text: 'Prestação de Contas - ${widget.usuarioLogado.nome}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao gerar relatório: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final registros = _obterFiltrados();

    return Scaffold(
      body: Column(
        children: [
          BannerOSPrime(
            subtituloTela: 'Histórico & Prestação de Contas',
            exibirBotaoVoltar: true,
            acaoDireita: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_exibirBusca ? Icons.close : Icons.search, color: corCianoEletrico, size: 20),
                  tooltip: _exibirBusca ? 'Fechar Busca' : 'Buscar Serviços',
                  onPressed: () => setState(() {
                    _exibirBusca = !_exibirBusca;
                    if (!_exibirBusca) _busca = '';
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: corVerdeWhats, size: 20),
                  tooltip: 'Emitir Relatório / WhatsApp',
                  onPressed: _abrirModalRelatorio,
                ),
              ],
            ),
          ),

          if (_exibirBusca)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: corCianoEletrico, size: 18),
                  hintText: 'Pesquisar cliente, endereço, O.S...',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${registros.length} serviço(s) listado(s)',
                  style: const TextStyle(color: corCianoSuave, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corCianoEletrico,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.analytics_rounded, size: 16),
                  label: const Text('Relatório', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: _abrirModalRelatorio,
                ),
              ],
            ),
          ),

          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: corCianoEletrico))
                : registros.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum serviço encontrado no histórico.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: registros.length,
                        itemBuilder: (_, i) {
                          final r = registros[i];
                          final corP = _corPrioridade(r.prioridade);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: corP.withAlpha(80)),
                            ),
                            child: ListTile(
                              dense: true,
                              onTap: () => _modalDetalhesSomenteLeitura(r),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.cliente,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: corTextoClaro),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: corP.withAlpha(40),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: corP),
                                    ),
                                    child: Text(
                                      r.prioridade.toUpperCase(),
                                      style: TextStyle(color: corP, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),
                                  Text(
                                    "${r.tipo} • ${r.referencia} • 📅 ${r.dataFormatada}",
                                    style: const TextStyle(color: corCianoSuave, fontSize: 10.5),
                                  ),
                                  if (r.endereco.isNotEmpty)
                                    Text(
                                      "📍 ${r.endereco}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.grey, fontSize: 10.5),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: corCianoSuave),
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



