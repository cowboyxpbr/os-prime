import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_base.dart';
import '../models/os_model.dart';
import 'os_admin_page.dart';

class TelaOficina extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaOficina({super.key, required this.usuarioLogado});

  @override
  State<TelaOficina> createState() => _TelaOficinaState();
}

class _TelaOficinaState extends State<TelaOficina> {
  late final Stream<List<Map<String, dynamic>>> _stream;
  List<UsuarioApp> _tecnicos = [];
  String _filtroStatus = 'Bancada';
  String _filtroTecnico = 'Todos';
  String _filtroTexto = '';

  @override
  void initState() {
    super.initState();
    _stream = Supabase.instance.client
        .from('ordens_servico')
        .stream(primaryKey: ['id'])
        .order('id', ascending: false);
    _carregarTecnicos();
  }

  Future<void> _carregarTecnicos() async {
    try {
      final res = await Supabase.instance.client.from('usuarios').select().order('nome');
      if (mounted) {
        setState(() {
          _tecnicos = (res as List).map((m) => UsuarioApp.fromMap(m)).toList();
        });
      }
    } catch (_) {
      final locais = await CacheOffline.carregarUsuariosLocais();
      if (mounted) setState(() => _tecnicos = locais);
    }
  }

  void _abrirDetalhesOS(OrdemServico os) {
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
                    Text("O.S. #${os.numeroOS}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orangeAccent)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(os.status.toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: corTextoClaro)),
                if (os.telefone.isNotEmpty) Text("📞 ${os.telefone}", style: const TextStyle(fontSize: 12.5, color: corCianoSuave)),
                if (os.endereco.isNotEmpty) Text("📍 ${os.endereco}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text("👤 Técnico Designado: ${os.tecnicoDesignado}", style: const TextStyle(fontSize: 12.5, color: corVerdeWhats, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 20),
                const Text("Problema / Reclamação:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corCianoEletrico)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
                  child: Text(os.descricaoProblema, style: const TextStyle(fontSize: 12.5, color: corTextoClaro)),
                ),
                if (os.observacaoTecnico != null && os.observacaoTecnico!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text("Laudo / Observação Técnica:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: corVerdeWhats)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0x2625D366), borderRadius: BorderRadius.circular(8)),
                    child: Text(os.observacaoTecnico!, style: const TextStyle(fontSize: 12.5, color: corVerdeWhats)),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fechar Detalhes', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BannerOSPrime(subtituloTela: 'Gestão da Oficina (Geral)', exibirBotaoVoltar: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipStatus('Bancada', '🛠️ Em Bancada', Colors.orangeAccent),
                  const SizedBox(width: 6),
                  _chipStatus('Executadas', '🟢 Executadas', corVerdeWhats),
                  const SizedBox(width: 6),
                  _chipStatus('AEnviar', '📋 A Enviar p/ Oficina', Colors.amberAccent),
                  const SizedBox(width: 6),
                  _chipStatus('Todas', 'Todas', corCianoEletrico),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    value: _filtroTecnico,
                    dropdownColor: corCardFundo,
                    decoration: const InputDecoration(
                      labelText: 'Funcionário',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'Todos', child: Text('Todos', style: TextStyle(fontSize: 12))),
                      ..._tecnicos.map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (v) => setState(() => _filtroTecnico = v ?? 'Todos'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar O.S...',
                      prefixIcon: Icon(Icons.search, size: 16, color: corCianoEletrico),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) => setState(() => _filtroTexto = v.toLowerCase()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                final todos = (snap.data ?? []).map((m) => OrdemServico.fromMap(m)).toList();
                final filtrados = todos.where((os) {
                  final st = os.status.trim().toLowerCase();
                  final tec = os.tecnicoDesignado.trim().toLowerCase();

                  if (_filtroTecnico != 'Todos' && tec != _filtroTecnico.toLowerCase()) return false;

                  if (_filtroStatus == 'Bancada') {
                    if (st != 'em reparo de bancada' && !st.contains('bancada')) return false;
                  } else if (_filtroStatus == 'Executadas') {
                    if (!st.contains('entrega') && st != 'pronta para entrega' && !st.contains('concluíd') && !st.contains('concluid')) return false;
                  } else if (_filtroStatus == 'AEnviar') {
                    if (!st.contains('escritório') && !st.contains('escritorio') && st != 'aguardando orçamento') return false;
                  }

                  if (_filtroTexto.isNotEmpty) {
                    final c = os.cliente.toLowerCase();
                    final n = os.numeroOS.toLowerCase();
                    final d = os.descricaoProblema.toLowerCase();
                    return c.contains(_filtroTexto) || n.contains(_filtroTexto) || d.contains(_filtroTexto);
                  }
                  return true;
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
                  padding: const EdgeInsets.all(12),
                  itemCount: filtrados.length,
                  itemBuilder: (_, i) {
                    final os = filtrados[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _abrirDetalhesOS(os),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("O.S. #${os.numeroOS}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent, fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.18), borderRadius: BorderRadius.circular(4)),
                                    child: Text(os.status.toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(os.cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: corTextoClaro)),
                              Text("👤 Técnico: ${os.tecnicoDesignado}", style: const TextStyle(fontSize: 11.5, color: corCianoSuave, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(os.descricaoProblema, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: corTextoClaro)),
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

  Widget _chipStatus(String id, String rotulo, Color cor) {
    final sel = _filtroStatus == id;
    return InkWell(
      onTap: () => setState(() => _filtroStatus = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: sel ? cor.withOpacity(0.22) : corCardFundo,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? cor : Colors.white12, width: sel ? 1.4 : 1),
        ),
        child: Text(rotulo, style: TextStyle(color: sel ? cor : Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }
}