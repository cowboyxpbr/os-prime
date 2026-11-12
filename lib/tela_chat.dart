// ============================================================================
// BATE-PAPO DA EQUIPE: SELEÇÃO MÚLTIPLA DE MENSAGENS, EXCLUSÃO EM MASSA E PUSH
// lib/tela_chat.dart (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_base.dart';

Future<void> _abrirWhatsAppChat(String telefone, {String mensagem = ''}) async {
  final limpo = telefone.replaceAll(RegExp(r'[^\d]'), '');
  if (limpo.isEmpty) return;
  final numeroCompleto = limpo.startsWith('55') ? limpo : '55$limpo';
  final url = Uri.parse("https://wa.me/$numeroCompleto?text=${Uri.encodeComponent(mensagem)}");
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(url);
    }
  } catch (_) {}
}

Widget _avatarChatHelper({String? fotoBase64, required String nome, required Color corDestaque, double raio = 20}) {
  if (fotoBase64 != null && fotoBase64.trim().isNotEmpty) {
    try {
      final bytes = base64Decode(fotoBase64.trim());
      return CircleAvatar(
        radius: raio,
        backgroundImage: MemoryImage(bytes),
      );
    } catch (_) {}
  }

  final String inicial = nome.trim().isNotEmpty ? nome.trim()[0].toUpperCase() : '?';
  return CircleAvatar(
    backgroundColor: const Color(0xFF003840),
    radius: raio,
    child: Text(
      inicial,
      style: TextStyle(color: corDestaque, fontWeight: FontWeight.bold, fontSize: raio * 0.85),
    ),
  );
}

// ============================================================================
// 1. IDENTIFICAÇÃO DO USUÁRIO LOGADO + AUTO-EXPURGO 48 HORAS NO BANCO
// ============================================================================
class TelaChat extends StatefulWidget {
  final UsuarioApp? usuarioLogado;
  const TelaChat({super.key, this.usuarioLogado});

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  UsuarioApp? _usuario;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  // 🧹 AUTO-LIMPEZA: Apaga do Supabase mensagens com mais de 48 horas
  Future<void> _limparMensagensAntigas48h() async {
    try {
      final limite48h = DateTime.now().toUtc().subtract(const Duration(hours: 48)).toIso8601String();
      await Supabase.instance.client
          .from('mensagens_chat')
          .delete()
          .lt('created_at', limite48h);
    } catch (_) {}
  }

  Future<void> _carregarUsuario() async {
    Future.delayed(const Duration(seconds: 5), () => _limparMensagensAntigas48h());

    if (widget.usuarioLogado != null) {
      _usuario = widget.usuarioLogado;
    } else {
      _usuario = await CacheOffline.obterSessaoAtiva();
    }
    if (mounted) setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando || _usuario == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: corCianoEletrico)),
      );
    }

    return TelaListaContatosChat(usuarioLogado: _usuario!);
  }
}

// ============================================================================
// 2. LISTA DE CONTATOS (HIERARQUIA RÍGIDA E CONTAGEM INDIVIDUAL)
// ============================================================================
class TelaListaContatosChat extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaListaContatosChat({super.key, required this.usuarioLogado});

  @override
  State<TelaListaContatosChat> createState() => _TelaListaContatosChatState();
}

class _TelaListaContatosChatState extends State<TelaListaContatosChat> {
  final Set<String> _contatosZeradosLocalmente = {};
  late final Stream<List<Map<String, dynamic>>> _usuariosStream;
  late final Stream<List<Map<String, dynamic>>> _mensagensStream;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    _usuariosStream = supabase.from('usuarios').stream(primaryKey: ['id']).order('nome');
    _mensagensStream = supabase.from('mensagens_chat').stream(primaryKey: ['id']).order('id', ascending: false).limit(80);
  }

  bool _ehLideranca(Map<String, dynamic> u) {
    final cargo = (u['cargo'] ?? '').toString().toLowerCase().trim();
    final login = (u['usuario'] ?? '').toString().toLowerCase().trim();
    return cargo == 'master' || cargo == 'senior' || login == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final meuLogin = widget.usuarioLogado.usuario.trim().toLowerCase();
    final bool souLideranca = widget.usuarioLogado.isMaster ||
        widget.usuarioLogado.isSenior ||
        widget.usuarioLogado.isAdmin ||
        meuLogin == 'admin';

    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: corCianoEletrico),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              souLideranca ? 'Bate-Papo da Equipe' : 'Falar com a Gestão',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              souLideranca
                  ? 'Acesso com Todos os Membros'
                  : 'Falar com Masters e Sêniors',
              style: const TextStyle(fontSize: 11, color: corCianoSuave),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _usuariosStream,
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) return const Center(child: CircularProgressIndicator(color: corCianoEletrico));
          final todosUsuarios = userSnap.data ?? [];

          final contatosPermitidos = todosUsuarios.where((u) {
            final uLogin = (u['usuario'] ?? '').toString().trim().toLowerCase();
            if (uLogin == meuLogin) return false;

            if (souLideranca) {
              return true;
            } else {
              return _ehLideranca(u);
            }
          }).toList();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _mensagensStream,
            builder: (context, msgSnap) {
              final todasMsgs = msgSnap.data ?? [];

              if (contatosPermitidos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      souLideranca
                          ? 'Nenhum outro membro cadastrado no sistema.'
                          : 'Nenhum Sênior ou Master disponível no momento.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: contatosPermitidos.length,
                itemBuilder: (context, index) {
                  final c = contatosPermitidos[index];
                  final String cLogin = (c['usuario'] ?? '').toString().trim().toLowerCase();
                  final String cNome = (c['nome'] ?? cLogin).toString().trim();
                  final String cCargo = (c['cargo'] ?? 'funcionario').toString().trim().toLowerCase();
                  final String? cFoto = c['foto']?.toString();
                  final String cTelefone = (c['telefone'] ?? '').toString().trim();
                  final bool temWhats = cTelefone.isNotEmpty;

                  final bool acabouDeLer = _contatosZeradosLocalmente.contains(cLogin);

                  final int naoLidasCalculadas = todasMsgs.where((m) {
                    final r = (m['remetente'] ?? '').toString().trim().toLowerCase();
                    final d = (m['destinatario'] ?? '').toString().trim().toLowerCase();
                    final visualizado = m['visualizado'] == true;
                    return r == cLogin && d == meuLogin && !visualizado;
                  }).length;

                  final int naoLidas = acabouDeLer ? 0 : naoLidasCalculadas;

                  final ultimas = todasMsgs.where((m) {
                    final r = (m['remetente'] ?? '').toString().trim().toLowerCase();
                    final d = (m['destinatario'] ?? '').toString().trim().toLowerCase();
                    return (r == meuLogin && d == cLogin) || (r == cLogin && d == meuLogin);
                  }).toList();

                  final String ultimaMsgTexto = ultimas.isNotEmpty
                      ? (ultimas.first['texto'] ?? '')
                      : 'Toque para iniciar conversa';

                  String cargoDesc = "Técnico";
                  Color cargoCor = Colors.grey;
                  if (cCargo == 'master' || cLogin == 'admin') {
                    cargoDesc = "Master";
                    cargoCor = Colors.amberAccent;
                  } else if (cCargo == 'senior') {
                    cargoDesc = "Sênior";
                    cargoCor = corCianoEletrico;
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: naoLidas > 0 ? Colors.redAccent : Colors.white10,
                        width: naoLidas > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: _avatarChatHelper(
                        fotoBase64: cFoto,
                        nome: cNome,
                        corDestaque: cargoCor,
                        raio: 20,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cNome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: cargoCor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: cargoCor.withOpacity(0.5)),
                            ),
                            child: Text(
                              cargoDesc.toUpperCase(),
                              style: TextStyle(color: cargoCor, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          ultimaMsgTexto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: naoLidas > 0 ? Colors.white : Colors.grey.shade400,
                            fontWeight: naoLidas > 0 ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (temWhats)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const IconeWhatsAppOficial(size: 20),
                              tooltip: 'Chamar no WhatsApp',
                              onPressed: () => _abrirWhatsAppChat(cTelefone),
                            ),
                          if (naoLidas > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(color: Colors.redAccent, blurRadius: 6),
                                ],
                              ),
                              child: Text(
                                '$naoLidas',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 13),
                        ],
                      ),
                      onTap: () async {
                        setState(() {
                          _contatosZeradosLocalmente.add(cLogin);
                        });

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TelaConversaPrivada(
                              meuLogin: meuLogin,
                              meuNome: widget.usuarioLogado.nome,
                              outroLogin: cLogin,
                              outroNome: cNome,
                              outroFoto: cFoto,
                              outroTelefone: cTelefone,
                              isMasterOuAdmin: souLideranca,
                            ),
                          ),
                        );

                        if (mounted) {
                          setState(() {
                            _contatosZeradosLocalmente.remove(cLogin);
                          });
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// 3. CONVERSA DIRETA (SELEÇÃO MÚLTIPLA, APAGAR EM MASSA E PUSH)
// ============================================================================
class TelaConversaPrivada extends StatefulWidget {
  final String meuLogin;
  final String meuNome;
  final String outroLogin;
  final String outroNome;
  final String? outroFoto;
  final String? outroTelefone;
  final bool isMasterOuAdmin;

  const TelaConversaPrivada({
    super.key,
    required this.meuLogin,
    required this.meuNome,
    required this.outroLogin,
    required this.outroNome,
    this.outroFoto,
    this.outroTelefone,
    this.isMasterOuAdmin = false,
  });

  @override
  State<TelaConversaPrivada> createState() => _TelaConversaPrivadaState();
}

class _TelaConversaPrivadaState extends State<TelaConversaPrivada> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final supabase = Supabase.instance.client;

  Set<String> _mensagensOcultasLocalmente = {};
  final Map<dynamic, Map<String, dynamic>> _mensagensSelecionadas = {};
  bool _enviando = false;

  bool get _modoSelecao => _mensagensSelecionadas.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _carregarMensagensOcultas();
    _zerarNoBanco();
  }

  @override
  void dispose() {
    _zerarNoBanco();
    super.dispose();
  }

  Future<void> _carregarMensagensOcultas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList('ocultas_${widget.meuLogin}') ?? [];
      if (mounted) {
        setState(() {
          _mensagensOcultasLocalmente = lista.toSet();
        });
      }
    } catch (_) {}
  }

  // Alterna a seleção de uma mensagem
  void _alternarSelecao(Map<String, dynamic> item) {
    final id = item['id'];
    setState(() {
      if (_mensagensSelecionadas.containsKey(id)) {
        _mensagensSelecionadas.remove(id);
      } else {
        _mensagensSelecionadas[id] = item;
      }
    });
  }

  // Copia o texto de todas as mensagens selecionadas
  void _copiarSelecionadas() {
    if (_mensagensSelecionadas.isEmpty) return;
    final textos = _mensagensSelecionadas.values
        .map((m) => (m['texto'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .join('\n');

    Clipboard.setData(ClipboardData(text: textos));
    final qtd = _mensagensSelecionadas.length;
    setState(() => _mensagensSelecionadas.clear());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(qtd == 1 ? '📋 Mensagem copiada!' : '📋 $qtd mensagens copiadas!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Exclui todas as selecionadas "Para mim"
  Future<void> _apagarSelecionadasParaMim() async {
    final ids = _mensagensSelecionadas.keys.map((id) => id.toString()).toList();
    final qtd = ids.length;

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _mensagensOcultasLocalmente.addAll(ids);
        _mensagensSelecionadas.clear();
      });
      await prefs.setStringList('ocultas_${widget.meuLogin}', _mensagensOcultasLocalmente.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(qtd == 1 ? '🗑️ Mensagem apagada para você!' : '🗑️ $qtd mensagens apagadas para você!'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (_) {}
  }

  // Exclui todas as selecionadas no Supabase "Para todos"
  Future<void> _apagarSelecionadasParaTodos() async {
    final ids = _mensagensSelecionadas.keys.toList();
    final qtd = ids.length;

    setState(() => _mensagensSelecionadas.clear());

    try {
      await supabase.from('mensagens_chat').delete().inFilter('id', ids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(qtd == 1 ? '🚨 Mensagem apagada para todos!' : '🚨 $qtd mensagens apagadas para todos!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao apagar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Modal de confirmação da exclusão em massa
  void _modalConfirmarExclusaoEmMassa() {
    final eu = widget.meuLogin.trim().toLowerCase();
    final qtd = _mensagensSelecionadas.length;

    // Pode apagar para todos se for Master/Admin OU se todas as mensagens foram enviadas pelo usuário
    final bool todasMinhas = _mensagensSelecionadas.values.every((m) {
      final rem = (m['remetente'] ?? '').toString().trim().toLowerCase();
      return rem == eu;
    });
    final bool podeApagarParaTodos = widget.isMasterOuAdmin || todasMinhas;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF00E5FF), width: 1.2),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Excluir $qtd mensagem(ns)?',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 1. APAGAR PARA MIM
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.amberAccent, size: 22),
                title: Text('Apagar para mim ($qtd)', style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Remove apenas da sua tela', style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _apagarSelecionadasParaMim();
                },
              ),

              // 2. APAGAR PARA TODOS
              if (podeApagarParaTodos)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                  title: Text('Apagar para todos ($qtd)', style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Exclui permanentemente do banco para ambos', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _apagarSelecionadasParaTodos();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _zerarNoBanco() async {
    try {
      final rem = widget.outroLogin.trim().toLowerCase();
      final dest = widget.meuLogin.trim().toLowerCase();

      await supabase
          .from('mensagens_chat')
          .update({'visualizado': true})
          .eq('remetente', rem)
          .eq('destinatario', dest);
    } catch (_) {}
  }

  void _enviarMensagem() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty || _enviando) return;

    _msgController.clear();
    _enviando = true;

    final rem = widget.meuLogin.trim().toLowerCase();
    final dest = widget.outroLogin.trim().toLowerCase();

    try {
      await supabase.from('mensagens_chat').insert({
        'remetente': rem,
        'destinatario': dest,
        'texto': texto,
        'visualizado': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      ServicoNotificacaoOneSignal.enviarNotificacaoChat(
        destinatarioLogin: dest,
        remetenteNome: widget.meuNome,
        texto: texto,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _enviando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const corNeon = Color(0xFF00E5FF);
    final bool temWhats = widget.outroTelefone != null && widget.outroTelefone!.trim().isNotEmpty;
    final eu = widget.meuLogin.trim().toLowerCase();
    final outro = widget.outroLogin.trim().toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),

      // ======================================================================
      // APP BAR: ALTERNA ENTRE MODO NORMAL E MODO DE SELEÇÃO MÚLTIPLA
      // ======================================================================
      appBar: _modoSelecao
          ? AppBar(
              backgroundColor: const Color(0xFF0E2238),
              elevation: 3,
              leading: IconButton(
                icon: const Icon(Icons.close, color: corNeon),
                tooltip: 'Cancelar Seleção',
                onPressed: () => setState(() => _mensagensSelecionadas.clear()),
              ),
              title: Text(
                '${_mensagensSelecionadas.length} selecionada(s)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 21),
                  tooltip: 'Copiar Mensagens',
                  onPressed: _copiarSelecionadas,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 24),
                  tooltip: 'Excluir Mensagens Selecionadas',
                  onPressed: _modalConfirmarExclusaoEmMassa,
                ),
                const SizedBox(width: 4),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF161B22),
              elevation: 2,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: corNeon),
                onPressed: () {
                  _zerarNoBanco();
                  Navigator.pop(context);
                },
              ),
              title: Row(
                children: [
                  _avatarChatHelper(
                    fotoBase64: widget.outroFoto,
                    nome: widget.outroNome,
                    corDestaque: corNeon,
                    raio: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.outroNome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Conversa Privada • @$outro',
                          style: TextStyle(fontSize: 11, color: corNeon.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (temWhats)
                  IconButton(
                    icon: const IconeWhatsAppOficial(size: 22),
                    tooltip: 'Chamar no WhatsApp',
                    onPressed: () => _abrirWhatsAppChat(widget.outroTelefone!),
                  ),
              ],
            ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _mensagensStream,
              builder: (context, snapshot) {
                final todas = snapshot.data ?? [];

                final conversa = todas.where((m) {
                  final String idStr = (m['id'] ?? '').toString();
                  if (_mensagensOcultasLocalmente.contains(idStr)) return false;

                  final r = (m['remetente'] ?? '').toString().trim().toLowerCase();
                  final d = (m['destinatario'] ?? '').toString().trim().toLowerCase();
                  return (r == eu && d == outro) || (r == outro && d == eu);
                }).toList();

                final temNaoLidas = conversa.any((m) {
                  final r = (m['remetente'] ?? '').toString().trim().toLowerCase();
                  return r == outro && m['visualizado'] != true;
                });

                if (temNaoLidas) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _zerarNoBanco();
                  });
                }

                if (conversa.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma mensagem ainda com ${widget.outroNome}.\nEnvie a primeira mensagem!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: conversa.length,
                  itemBuilder: (context, index) {
                    final item = conversa[index];
                    final rem = (item['remetente'] ?? '').toString().trim().toLowerCase();
                    final souEu = rem == eu;
                    final bool selecionada = _mensagensSelecionadas.containsKey(item['id']);

                    String hora = '';
                    if (item['created_at'] != null) {
                      try {
                        hora = DateFormat('HH:mm').format(DateTime.parse(item['created_at']).toLocal());
                      } catch (_) {}
                    }

                    return Align(
                      alignment: souEu ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        // 👆 SEGURE O DEDO PARA INICIAR A SELEÇÃO
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _alternarSelecao(item);
                        },
                        // 👆 SE ESTIVER EM MODO SELEÇÃO, TOQUE PARA MARCAR/DESMARCAR
                        onTap: () {
                          if (_modoSelecao) {
                            _alternarSelecao(item);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: selecionada
                                ? (souEu ? const Color(0xFF007A87) : const Color(0xFF2E3B4E))
                                : (souEu ? const Color(0xFF005A64) : const Color(0xFF1F242C)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(souEu ? 16 : 0),
                              bottomRight: Radius.circular(souEu ? 0 : 16),
                            ),
                            border: Border.all(
                              color: selecionada
                                  ? corNeon
                                  : (souEu ? corNeon.withOpacity(0.5) : Colors.white12),
                              width: selecionada ? 2.0 : 1.0,
                            ),
                            boxShadow: selecionada
                                ? [
                                    BoxShadow(
                                      color: corNeon.withOpacity(0.35),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: souEu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['texto'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(hora, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                                  if (souEu) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.done_all,
                                      size: 13,
                                      color: item['visualizado'] == true ? corNeon : Colors.white38,
                                    ),
                                  ],
                                  if (selecionada) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_circle, size: 14, color: corNeon),
                                  ],
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

          // CAMPO DE DIGITAÇÃO E ENVIO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        filled: true,
                        fillColor: const Color(0xFF0D1117),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: corNeon, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _enviarMensagem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _enviarMensagem,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: corNeon,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: corNeon, blurRadius: 8, spreadRadius: 1),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                    ),
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



