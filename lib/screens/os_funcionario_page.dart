// ============================================================================
// ARQUIVO: TELA DE O.S. DO TÉCNICO COM ACESSO RÍGIDO INDIVIDUAL E SIGILO TOTAL
// lib/screens/os_funcionario_page.dart (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================

import 'package:flutter/material.dart';
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
  bool _popupAberto = false;
  final Set<String> _idsNotificadosNestaSessao = {};

  @override
  void initState() {
    super.initState();
    _stream = Supabase.instance.client
        .from('ordens_servico')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false);
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
        return Colors.purpleAccent; // DESTAQUE ROXO NEON PARA PLANTÃO
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
              decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
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

  // EDITA O RELATÓRIO DO TÉCNICO ENQUANTO NÃO FOI FATURADA PELO ESCRITÓRIO
  void _modalEditarRelatorioOS(OrdemServico os) {
    final relatorioC = TextEditingController(text: os.observacaoTecnico ?? '');
    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: corCianoEletrico),
          ),
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
                    hintText: 'Adicione as peças esquecidas ou complemente o relatório...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 Você pode editar até que o escritório lance para Faturamento Nuvem.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
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
                          const SnackBar(backgroundColor: Colors.green, content: Text('✅ Relatório da O.S. atualizado!')),
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

  // FINALIZAÇÃO PELO TÉCNICO (MANDA DIRETO P/ A TELA "LANÇAR COM PREÇO" DO ESCRITÓRIO)
  void _modalFinalizarOS(OrdemServico os, {required bool enviarAoEscritorio}) {
    final relatorioC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: enviarAoEscritorio ? corVerdeWhats : corCianoSuave),
        ),
        title: Row(
          children: [
            Icon(enviarAoEscritorio ? Icons.send_rounded : Icons.check_circle, color: enviarAoEscritorio ? corVerdeWhats : corCianoSuave, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                enviarAoEscritorio ? 'Concluir & Enviar Escritório' : 'Concluir O.S. Interna',
                style: TextStyle(color: enviarAoEscritorio ? corVerdeWhats : corCianoSuave, fontSize: 15, fontWeight: FontWeight.bold),
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
                decoration: const InputDecoration(
                  labelText: 'Relatório do Serviço / Peças Trocadas',
                  hintText: 'Descreva detalhadamente o serviço executado e todas as peças instaladas...',
                  alignLabelWithHint: true,
                ),
              ),
              if (enviarAoEscritorio) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0x2625D366), borderRadius: BorderRadius.circular(6), border: Border.all(color: corVerdeWhats.withAlpha(90))),
                  child: const Row(
                    children: [
                      Icon(Icons.assignment_turned_in, color: corVerdeWhats, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Será enviado para a tela de Precificação do Escritório.',
                          style: TextStyle(color: corVerdeWhats, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enviarAoEscritorio ? corVerdeWhats : corCianoEletrico,
              foregroundColor: enviarAoEscritorio ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(enviarAoEscritorio ? 'Finalizar e Enviar' : 'Apenas Concluir'),
            onPressed: () async {
              if (relatorioC.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha o relatório do serviço!')));
                return;
              }
              final relatorio = relatorioC.text.trim();

              await ServicoOS.atualizarStatus(
                id: os.id,
                novoStatus: 'Concluída',
                relatorioTecnico: relatorio,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(enviarAoEscritorio ? '✅ O.S. Concluída e enviada para precificação no escritório!' : '✅ O.S. Concluída com sucesso!'),
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
    final meuLogin = widget.usuarioLogado.usuario.trim().toLowerCase().replaceAll('@', '');
    final meuNome = widget.usuarioLogado.nome.trim().toLowerCase();
    final meuPrimeiroNome = meuNome.isNotEmpty ? meuNome.split(' ').first : '';

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
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                final todos = (snap.data ?? []).map((m) => OrdemServico.fromMap(m)).toList();

                // 🛡️ FILTRO RÍGIDO: Cada usuário SÓ enxerga o que foi enviado DIRETAMENTE a ele!
                final minhasOS = todos.where((os) {
                  if (os.status == 'Faturada') return false; // Faturadas vão para o histórico

                  final tec = os.tecnicoDesignado.trim().toLowerCase().replaceAll('@', '');
                  if (tec.isEmpty) return false; // Se não tem técnico definido, não vaza para ninguém

                  // Compara estritamente com o login, nome completo ou primeiro nome
                  return tec == meuLogin ||
                      tec == meuNome ||
                      (meuPrimeiroNome.isNotEmpty && tec == meuPrimeiroNome);
                }).toList();

                _verificarNovasOS(minhasOS);

                if (minhasOS.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhuma Ordem de Serviço pendente para você no momento.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: minhasOS.length,
                  itemBuilder: (_, i) {
                    final os = minhasOS[i];
                    final bool pendente = os.status == 'Pendente';
                    final bool emAndamento = os.status == 'Em Andamento';
                    final bool concluida = os.status == 'Concluída';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: pendente
                              ? _corPrioridade(os.prioridade).withAlpha(120)
                              : (emAndamento ? corCianoEletrico.withAlpha(90) : Colors.transparent),
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
                                Text(
                                  concluida ? 'Aguardando Escritório' : os.status,
                                  style: TextStyle(color: concluida ? Colors.amberAccent : (emAndamento ? corCianoSuave : corVerdeWhats), fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: corTextoClaro)),
                            if (os.endereco.isNotEmpty) Text("📍 ${os.endereco}", style: const TextStyle(fontSize: 11, color: corCianoSuave)),
                            if (os.telefone.isNotEmpty) Text("📞 ${os.telefone}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(6)),
                              child: Text(os.descricaoProblema, style: const TextStyle(fontSize: 12, color: corTextoClaro)),
                            ),
                            if (concluida && os.observacaoTecnico != null && os.observacaoTecnico!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0x2625D366), borderRadius: BorderRadius.circular(6), border: Border.all(color: corVerdeWhats.withAlpha(90))),
                                child: Text("Relatório: ${os.observacaoTecnico}", style: const TextStyle(fontSize: 11, color: corVerdeWhats)),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // CASO 1: SE PENDENTE -> INICIAR ATENDIMENTO
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

                            // CASO 2: SE EM ANDAMENTO -> CONCLUIR E ENVIAR
                            if (emAndamento)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: corCianoSuave),
                                          foregroundColor: corCianoSuave,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.check, size: 15),
                                        label: const Text('Apenas Concluir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () => _modalFinalizarOS(os, enviarAoEscritorio: false),
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
                                        icon: const Icon(Icons.send_rounded, size: 14),
                                        label: const Text('Enviar ao Escritório', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () => _modalFinalizarOS(os, enviarAoEscritorio: true),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // CASO 3: SE CONCLUÍDA -> PERMITE EDITAR RELATÓRIO
                            if (concluida)
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: corCianoEletrico),
                                    foregroundColor: corCianoEletrico,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('Editar / Adicionar Peças', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
}


