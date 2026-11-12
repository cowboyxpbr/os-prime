// ============================================================================
// ARQUIVO: MENU PRINCIPAL COM MARCA D'ÁGUA E BORDAS TRANSLÚCIDAS
// lib/screens/menu_principal_page.dart (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_base.dart';
import '../main.dart';
import '../modulo_financeiro.dart' hide TelaOSFuncionario;
import '../modulo_cadastros.dart';
import '../tela_chat.dart';

import 'os_admin_page.dart';
import 'os_funcionario_page.dart';
import 'relatorio_condominio_page.dart';
import 'historico_funcionario_page.dart';
import 'menu_telas_auxiliares.dart';
import 'dados_empresa_page.dart';
import 'licenca_bloqueada_page.dart';
import '../servico_licenca_bugs.dart';

// HELPER: DISPARADOR DIRETO DO WHATSAPP
Future<void> _abrirWhatsApp(String telefone, {String mensagem = ''}) async {
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

// ============================================================================
// MENU PRINCIPAL
// ============================================================================
class TelaMenuPrincipal extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const TelaMenuPrincipal({super.key, required this.usuarioLogado});
  @override
  State<TelaMenuPrincipal> createState() => _TelaMenuPrincipalState();
}

class _TelaMenuPrincipalState extends State<TelaMenuPrincipal> {
  int _pendentesOffline = 0;
  StreamSubscription? _vigilanteSessaoSub;

  @override
  void initState() {
    super.initState();
    _sincronizar();
    _iniciarVigilanteSessao();
    _verificarLicenca();
  }

  @override

  Future<void> _verificarLicenca() async {
    try {
      final res = await supabase.from('empresas').select().limit(1).maybeSingle();
      if (res != null) {
        final status = (res['status'] ?? 'ativo').toString().toLowerCase();
        final validadeStr = res['validade']?.toString();
        DateTime? validade;
        if (validadeStr != null) {
          validade = DateTime.tryParse(validadeStr);
        }
        final agora = DateTime.now();
        final expirado = (validade != null && agora.isAfter(validade)) || status == 'bloqueado' || status == 'suspenso' || status == 'pendente' || status == 'aguardando_cadastro';

        if (expirado && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LicencaBloqueadaPage(
                dadosEmpresa: res,
                usuarioLogado: widget.usuarioLogado,
              ),
            ),
          );
        }
      }
    } catch (_) {}
  }

  void dispose() {
    _vigilanteSessaoSub?.cancel();
    super.dispose();
  }

  // ==========================================================================
  // 🚨 VIGILANTE DE SESSÃO: EXPULSA NA HORA SE EXCLUÍDO OU SENHA MUDADA
  // ==========================================================================
  void _iniciarVigilanteSessao() {
    if (widget.usuarioLogado.usuario.trim().toLowerCase() == 'admin') return;

    try {
      _vigilanteSessaoSub = supabase
          .from('usuarios')
          .stream(primaryKey: ['id'])
          .listen((lista) async {
        if (lista.isEmpty) return;

        final meuLogin = widget.usuarioLogado.usuario.trim().toLowerCase();

        final meuUsuarioBanco = lista.where((u) {
          final uNome = (u['usuario'] ?? '').toString().trim().toLowerCase();
          return uNome == meuLogin;
        }).firstOrNull;

        final bool foiExcluido = meuUsuarioBanco == null;
        final bool senhaAlterada = meuUsuarioBanco != null &&
            meuUsuarioBanco['senha'].toString().trim() != widget.usuarioLogado.senha.trim();

        if (foiExcluido || senhaAlterada) {
          _vigilanteSessaoSub?.cancel();
          await CacheOffline.excluirUsuarioLocal(widget.usuarioLogado.usuario);
          await CacheOffline.encerrarSessao();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const TelaLogin()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 5),
                content: Text(
                  foiExcluido
                      ? '🚫 Seu acesso foi revogado pelo Administrador.'
                      : '⚠️ Sua senha foi alterada pelo Administrador. Faça login novamente.',
                ),
              ),
            );
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _sincronizar() async {
    final ok = await CacheOffline.sincronizarFilaComNuvem();
    if (ok > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text('⚡ $ok serviço(s) sincronizado(s)!')),
      );
    }
    final f = await CacheOffline.obterFilaServicosOffline();
    if (mounted) setState(() => _pendentesOffline = f.length);
  }

  Widget _construirAvatarUsuario(UsuarioApp u, {double raio = 22}) {
    if (u.foto != null && u.foto!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(u.foto!.trim());
        return CircleAvatar(
          radius: raio,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    final String inicial = u.nome.isNotEmpty ? u.nome[0].toUpperCase() : 'U';
    final Color corDestaque = u.isMaster ? Colors.amberAccent : (u.isSenior ? corCianoEletrico : corCianoSuave);

    return CircleAvatar(
      radius: raio,
      backgroundColor: const Color(0xFF0F354A),
      child: Text(
        inicial,
        style: TextStyle(color: corDestaque, fontWeight: FontWeight.bold, fontSize: raio * 0.9),
      ),
    );
  }

  void _modalWhatsAppEquipe() async {
    List<UsuarioApp> equipe = [];
    try {
      final res = await supabase.from('usuarios').select().order('nome').timeout(const Duration(seconds: 4));
      if (res.isNotEmpty) {
        equipe = res.map((m) => UsuarioApp.fromMap(m)).toList();
      }
    } catch (_) {}

    if (equipe.isEmpty) {
      equipe = await CacheOffline.carregarUsuariosLocais();
    }

    final souGestor = widget.usuarioLogado.temAcessoAdmin;

    final contatos = equipe.where((u) {
      if (u.usuario.trim().toLowerCase() == widget.usuarioLogado.usuario.trim().toLowerCase()) return false;
      if (!souGestor) {
        return u.isMaster || u.isSenior;
      }
      return true;
    }).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: corCardFundo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: corVerdeWhats, width: 1.5),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                IconeWhatsAppOficial(size: 22),
                SizedBox(width: 8),
                Text(
                  'WhatsApp da Equipe',
                  style: TextStyle(color: corVerdeWhats, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contatos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('Nenhum contato disponível no momento.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: contatos.length,
                  itemBuilder: (_, i) {
                    final m = contatos[i];
                    final temWhats = m.telefone != null && m.telefone!.trim().isNotEmpty;
                    final cargoTxt = m.isMaster ? 'Master' : (m.isSenior ? 'Sênior' : 'Técnico');
                    final cargoCor = m.isMaster ? Colors.amberAccent : (m.isSenior ? corCianoEletrico : Colors.grey);

                    return Card(
                      color: corCardFundo.withOpacity(0.70),
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF0F354A),
                          child: Icon(m.isMaster ? Icons.workspace_premium : (m.isSenior ? Icons.stars : Icons.person), color: cargoCor, size: 16),
                        ),
                        title: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corTextoClaro)),
                        subtitle: Text('$cargoTxt • ${temWhats ? m.telefone : 'Sem telefone'}', style: TextStyle(color: cargoCor, fontSize: 11)),
                        trailing: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corVerdeWhats,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                          label: const Text('Conversar', style: TextStyle(fontSize: 11)),
                          onPressed: temWhats ? () => _abrirWhatsApp(m.telefone!) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _abrirPerfilComValidacaoSenha() async {
    final bool souMaster = widget.usuarioLogado.isMaster;
    final senhaInputC = TextEditingController();

    if (souMaster) {
      final seguranca = await CacheOffline.obterSegurancaGestao();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent)),
          title: const Row(
            children: [
              Icon(Icons.shield, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text('2ª Senha Master Obrigatória', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Por segurança, digite a 2ª SENHA MASTER para alterar seus dados:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(controller: senhaInputC, obscureText: true, decoration: const InputDecoration(labelText: '2ª Senha Master *', isDense: true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Validar'),
              onPressed: () {
                final digitada = senhaInputC.text.trim();
                final correta = seguranca?['senha'];

                if (correta != null && digitada == correta) {
                  Navigator.pop(ctx);
                  _dialogEditarPerfil();
                } else if (correta == null && digitada.isNotEmpty) {
                  Navigator.pop(ctx);
                  _dialogEditarPerfil();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ 2ª Senha Master incorreta!')));
                }
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amberAccent)),
          title: const Row(
            children: [
              Icon(Icons.lock_person, color: Colors.amberAccent, size: 22),
              SizedBox(width: 8),
              Text('Confirmar Senha Atual', style: TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirme sua senha antes de alterar seus dados de perfil:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(controller: senhaInputC, obscureText: true, decoration: const InputDecoration(labelText: 'Senha Atual', isDense: true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              child: const Text('Confirmar'),
              onPressed: () {
                if (senhaInputC.text.trim() == widget.usuarioLogado.senha) {
                  Navigator.pop(ctx);
                  _dialogEditarPerfil();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Senha incorreta!')));
                }
              },
            ),
          ],
        ),
      );
    }
  }

  void _dialogEditarPerfil() {
    final nomeC = TextEditingController(text: widget.usuarioLogado.nome);
    final loginC = TextEditingController(text: widget.usuarioLogado.usuario);
    final foneC = TextEditingController(text: widget.usuarioLogado.telefone ?? '');
    final senhaC = TextEditingController(text: widget.usuarioLogado.senha);
    final perguntaC = TextEditingController(text: widget.usuarioLogado.perguntaSecreta);
    final respostaC = TextEditingController(text: widget.usuarioLogado.respostaSecreta);

    String? fotoBase64Temp = widget.usuarioLogado.foto;
    bool senhaOculta = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> escolherFoto(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final XFile? foto = await picker.pickImage(
                source: source,
                maxWidth: 240,
                maxHeight: 240,
                imageQuality: 60,
              );
              if (foto != null) {
                final bytes = await foto.readAsBytes();
                setD(() {
                  fotoBase64Temp = base64Encode(bytes);
                });
              }
            } catch (e) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao carregar imagem: $e')),
              );
            }
          }

          Widget renderFotoPreview() {
            if (fotoBase64Temp != null && fotoBase64Temp!.trim().isNotEmpty) {
              try {
                final bytes = base64Decode(fotoBase64Temp!.trim());
                return CircleAvatar(
                  radius: 36,
                  backgroundImage: MemoryImage(bytes),
                );
              } catch (_) {}
            }
            return const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFF0F354A),
              child: Icon(Icons.person, color: corCianoEletrico, size: 36),
            );
          }

          return AlertDialog(
            backgroundColor: corCardFundo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
            title: const Row(
              children: [
                Icon(Icons.badge_rounded, color: corCianoEletrico, size: 22),
                SizedBox(width: 8),
                Text('Meu Perfil & Foto', style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Column(
                      children: [
                        renderFotoPreview(),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.camera_alt, size: 15, color: corCianoEletrico),
                              label: const Text('Câmera', style: TextStyle(fontSize: 11, color: corCianoEletrico)),
                              onPressed: () => escolherFoto(ImageSource.camera),
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.photo_library, size: 15, color: corCianoSuave),
                              label: const Text('Galeria', style: TextStyle(fontSize: 11, color: corCianoSuave)),
                              onPressed: () => escolherFoto(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: nomeC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome Completo *', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: loginC, decoration: const InputDecoration(labelText: 'Usuário / Login *', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: foneC,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Meu WhatsApp / Celular *',
                      hintText: '(47) 99999-9999',
                      prefixIcon: Icon(Icons.phone, color: corVerdeWhats, size: 18),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: senhaC,
                    obscureText: senhaOculta,
                    decoration: InputDecoration(
                      labelText: 'Senha *',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(senhaOculta ? Icons.visibility : Icons.visibility_off, color: corCianoSuave, size: 18),
                        onPressed: () => setD(() => senhaOculta = !senhaOculta),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: perguntaC, decoration: const InputDecoration(labelText: 'Pergunta Secreta', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: respostaC, decoration: const InputDecoration(labelText: 'Resposta Secreta', isDense: true)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
                child: const Text('Salvar'),
                onPressed: () async {
                  final novoNome = nomeC.text.trim();
                  final novoUser = loginC.text.trim().toLowerCase();
                  final novoFone = foneC.text.trim();
                  final novaSenha = senhaC.text.trim();
                  if (novoNome.isEmpty || novoUser.isEmpty || novaSenha.isEmpty) return;

                  final antigoUser = widget.usuarioLogado.usuario.trim().toLowerCase();

                  widget.usuarioLogado.nome = novoNome;
                  widget.usuarioLogado.usuario = novoUser;
                  widget.usuarioLogado.telefone = novoFone;
                  widget.usuarioLogado.senha = novaSenha;
                  widget.usuarioLogado.foto = fotoBase64Temp;
                  widget.usuarioLogado.perguntaSecreta = perguntaC.text.trim();
                  widget.usuarioLogado.respostaSecreta = respostaC.text.trim().toLowerCase();

                  await CacheOffline.salvarUsuarioLocal(widget.usuarioLogado, usuarioAntigo: antigoUser);
                  if (antigoUser != novoUser) {
                    await CacheOffline.excluirUsuarioLocal(antigoUser);
                  }
                  await CacheOffline.salvarSessao(widget.usuarioLogado, true);

                  try {
                    final checar = await supabase.from('usuarios').select('id').ilike('usuario', antigoUser);
                    if (checar.isNotEmpty) {
                      final idBanco = checar.first['id'];
                      await supabase.from('usuarios').update(widget.usuarioLogado.toMap()).eq('id', idBanco);
                    } else {
                      if (widget.usuarioLogado.isMaster) {
                        final checarMaster = await supabase.from('usuarios').select('id').ilike('cargo', 'master');
                        if (checarMaster.isNotEmpty) {
                          await supabase.from('usuarios').update(widget.usuarioLogado.toMap()).eq('id', checarMaster.first['id']);
                        } else {
                          await supabase.from('usuarios').upsert(widget.usuarioLogado.toMap(), onConflict: 'usuario');
                        }
                      } else {
                        await supabase.from('usuarios').upsert(widget.usuarioLogado.toMap(), onConflict: 'usuario');
                      }
                    }

                    if (antigoUser != novoUser && antigoUser.isNotEmpty) {
                      await supabase.from('usuarios').delete().ilike('usuario', antigoUser);
                    }
                  } catch (_) {}

                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Colors.green, content: Text('✅ Perfil atualizado com sucesso!')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _abrirGestaoComSegundaSenha() async {
    final seguranca = await CacheOffline.obterSegurancaGestao();
    if (!mounted) return;

    if (seguranca == null) {
      final sC = TextEditingController();
      final pC = TextEditingController();
      final rC = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.blueAccent)),
          title: const Text('🛡️ Criar 2ª Senha Master', style: TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Esta 2ª Senha Master protege o cadastro de usuários e a alteração dos seus dados:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(controller: sC, obscureText: true, decoration: const InputDecoration(labelText: 'Criar 2ª Senha Master *', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: pC, decoration: const InputDecoration(labelText: 'Pergunta Secreta *', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: rC, decoration: const InputDecoration(labelText: 'Resposta Secreta *', isDense: true)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text('Gravar 2ª Senha e Entrar'),
              onPressed: () async {
                if (sC.text.trim().isEmpty || rC.text.trim().isEmpty || pC.text.trim().isEmpty) return;
                await CacheOffline.salvarSegurancaGestao(sC.text.trim(), pC.text.trim(), rC.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaGestaoUsuarios()));
              },
            ),
          ],
        ),
      );
    } else {
      final sC = TextEditingController();
      final respostaC = TextEditingController();
      final novaSenhaC = TextEditingController();
      bool modoRecuperacao = false;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            backgroundColor: corCardFundo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.blueAccent)),
            title: Text(modoRecuperacao ? '🔑 Recuperar 2ª Senha' : '🛡️ Digite a 2ª Senha Master', style: const TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!modoRecuperacao) ...[
                    const Text('Área protegida da Gestão de Equipe (Apenas Master):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextField(controller: sC, obscureText: true, decoration: const InputDecoration(labelText: '2ª Senha Master', isDense: true)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setD(() => modoRecuperacao = true),
                        child: const Text('Esqueceu a 2ª senha?', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                      ),
                    ),
                  ] else ...[
                    Text("Pergunta: ${seguranca['pergunta'] ?? 'Pergunta de segurança'}", style: const TextStyle(fontSize: 12, color: corTextoClaro)),
                    const SizedBox(height: 8),
                    TextField(controller: respostaC, decoration: const InputDecoration(labelText: 'Resposta Secreta *', isDense: true)),
                    const SizedBox(height: 8),
                    TextField(controller: novaSenhaC, obscureText: true, decoration: const InputDecoration(labelText: 'Nova 2ª Senha Master *', isDense: true)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                child: Text(!modoRecuperacao ? 'Acessar' : 'Salvar Nova 2ª Senha'),
                onPressed: () async {
                  if (!modoRecuperacao) {
                    if (sC.text.trim() == seguranca['senha']) {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaGestaoUsuarios()));
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ 2ª Senha Master incorreta!')));
                    }
                  } else {
                    final resp = respostaC.text.trim().toLowerCase();
                    final salva = (seguranca['resposta'] ?? '').toString().toLowerCase();

                    if (resp != salva) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Resposta secreta incorreta!')));
                      return;
                    }

                    if (novaSenhaC.text.trim().isEmpty) return;
                    await CacheOffline.salvarSegurancaGestao(novaSenhaC.text.trim(), seguranca['pergunta'] ?? '', resp);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaGestaoUsuarios()));
                  }
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _sair() async {
    try {
      final conf = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: corCianoEletrico),
          ),
          title: const Text('🚪 Desconectar?', style: TextStyle(color: corCianoEletrico, fontSize: 16)),
          content: const Text('Tem certeza que deseja sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, Sair'),
            ),
          ],
        ),
      );

      if (conf == true && mounted) {
        try {
          await _vigilanteSessaoSub?.cancel();
        } catch (_) {}
        await CacheOffline.encerrarSessao();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const TelaLogin()),
            (route) => false,
          );
        }
      }
    } catch (_) {}
  }

  Widget _tituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
      child: Text(
        titulo,
        style: const TextStyle(
          color: corCianoEletrico,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMaster = widget.usuarioLogado.isMaster;
    final bool isSenior = widget.usuarioLogado.isSenior;
    final bool temAcessoAdmin = widget.usuarioLogado.temAcessoAdmin;

    final String cargoDescricao = isMaster ? "Master" : (isSenior ? "Sênior" : "Técnico");
    final meuLogin = widget.usuarioLogado.usuario.trim().toLowerCase();

    return Scaffold(
      backgroundColor: corFundoApp,
      // ======================================================================
      // 💬 BOTÃO DO CHAT EM CÁPSULA MODERNA COM O TEXTO "CHAT"
      // ======================================================================
      floatingActionButton: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('mensagens_chat')
            .stream(primaryKey: ['id'])
            .order('id', ascending: false)
            .limit(100),
        builder: (context, snapshot) {
          final msgs = snapshot.data ?? [];

          final int naoLidas = msgs.where((m) {
            final d = (m['destinatario'] ?? '').toString().trim().toLowerCase();
            final r = (m['remetente'] ?? '').toString().trim().toLowerCase();
            final visualizado = m['visualizado'] == true;
            return d == meuLogin && r != meuLogin && !visualizado;
          }).length;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaChat(usuarioLogado: widget.usuarioLogado),
                    ),
                  ).then((_) => setState(() {}));
                },
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: corCardFundo,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: corCianoEletrico, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: corCianoEletrico.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'icone_chat.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.forum_rounded, color: corCianoEletrico, size: 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CHAT',
                        style: TextStyle(
                          color: corCianoEletrico,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (naoLidas > 0)
                Positioned(
                  top: -5,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.8),
                      boxShadow: const [
                        BoxShadow(color: Colors.redAccent, blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Center(
                      child: Text(
                        naoLidas > 99 ? '99+' : '$naoLidas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      body: Column(
        children: [
          // 1. CABEÇALHO COM BANNER 100% LARGURA
          BannerOSPrime(
            subtituloTela: isMaster
                ? "Painel Master - Direção Geral"
                : (isSenior ? "Painel Sênior - Gestão Operacional" : "Área do Técnico de Campo"),
            acaoDireita: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMaster)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DadosEmpresaPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: corCianoEletrico.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: corCianoEletrico.withOpacity(0.7), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, color: corCianoEletrico, size: 13),
                        SizedBox(width: 4),
                        Text('Empresa', style: TextStyle(color: corCianoEletrico, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _sair,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.7), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent, size: 13),
                        SizedBox(width: 4),
                        Text('Sair', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. CORPO COM A MARCA D'ÁGUA E BORDAS TRANSLÚCIDAS
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.25,
                    child: Image.asset(
                      'fundo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const SizedBox(),
                    ),
                  ),
                ),

                Column(
                  children: [
                    MonitorLicencaMasterWidget(usuarioLogado: widget.usuarioLogado),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: corCardFundo.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: corCianoEletrico.withOpacity(0.35), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: corCianoEletrico.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _abrirPerfilComValidacaoSenha,
                            borderRadius: BorderRadius.circular(30),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isMaster ? Colors.amberAccent : (isSenior ? corCianoEletrico : corCianoSuave),
                                      width: 2,
                                    ),
                                  ),
                                  child: _construirAvatarUsuario(widget.usuarioLogado, raio: 22),
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF07192C),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: isMaster ? Colors.amberAccent : corCianoEletrico,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: InkWell(
                              onTap: _abrirPerfilComValidacaoSenha,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.usuarioLogado.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: corTextoClaro, fontSize: 13.5, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '@${widget.usuarioLogado.usuario} • $cargoDescricao',
                                    style: TextStyle(
                                      color: isMaster ? Colors.amberAccent : (isSenior ? corCianoEletrico : Colors.grey),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // BOTÃO COM O ÍCONE DO WHATSAPP OFICIAL
                          IconButton(
                            iconSize: 26,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: const IconeWhatsAppOficial(size: 24),
                            tooltip: 'WhatsApp da Equipe',
                            onPressed: _modalWhatsAppEquipe,
                          ),
                          const SizedBox(width: 4),

                          // BOTÃO DE SINCRONIZAR
                          IconButton(
                            iconSize: 26,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.sync, color: corCianoEletrico),
                            tooltip: 'Sincronizar Dados',
                            onPressed: _sincronizar,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            iconSize: 24,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.bug_report_outlined, color: Colors.orangeAccent),
                            tooltip: 'Relatar Erro / Bug',
                            onPressed: () => ServicoLicencaBugs.abrirModalReportarBug(context, widget.usuarioLogado),
                          ),

                          // BOTÃO DE GESTÃO DE EQUIPE E SENHAS (MANTIDO AQUI AO LADO DO SINCRONIZAR)
                          if (isMaster) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              iconSize: 26,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.blueAccent),
                              tooltip: 'Cadastro de Funcionários & Senhas',
                              onPressed: _abrirGestaoComSegundaSenha,
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (_pendentesOffline > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFC107),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amberAccent),
                        ),
                        child: Row(children: [
                          const Icon(Icons.cloud_off, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_pendentesOffline serviço(s) salvos no celular.',
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _sincronizar,
                            child: const Text('ENVIAR', style: TextStyle(color: corCianoEletrico, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ]),
                      ),

                                        Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        children: [
                          if (!temAcessoAdmin) ...[
                            _tituloSecao("SERVIÇOS DE CAMPO & CONTROLE"),
                            Row(
                              children: [
                                Expanded(
                                  child: _cardCompacto(
                                    "Ordem de Serviço",
                                    "Ordens recebidas",
                                    Icons.assignment_ind_rounded,
                                    corVerdeWhats,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => TelaOSFuncionario(usuarioLogado: widget.usuarioLogado)),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _cardCompacto(
                                    "Trabalho sem O.S",
                                    "Serviço de campo",
                                    Icons.build_circle_rounded,
                                    corCianoEletrico,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaLancamentoTrabalhoFuncionario(
                                          usuarioLogado: widget.usuarioLogado,
                                          modoAdmin: false,
                                        ),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _cardHorizontal(
                              "Meu Histórico e Relatório",
                              "Prestação de contas e histórico",
                              Icons.history_edu_rounded,
                              corAmareloSuave,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TelaHistoricoFuncionario(usuarioLogado: widget.usuarioLogado),
                                ),
                              ),
                            ),
                          ] else ...[
                            _tituloSecao("OPERAÇÃO & FATURAMENTO"),

                            // 2 CURTOS: LANÇAR + FATURAR
                            Row(
                              children: [
                                Expanded(
                                  child: _cardCompacto(
                                    "Lançar",
                                    "Trabalho pronto",
                                    Icons.add_shopping_cart_rounded,
                                    corVerdeWhats,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaPrecificacaoOS(
                                          usuarioLogado: widget.usuarioLogado,
                                        ),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _cardCompacto(
                                    "Faturar",
                                    "Precificar",
                                    Icons.cloud_sync_rounded,
                                    corCianoEletrico,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaFaturamento(),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 1 LONGO: ORDENS DE SERVIÇO (O.S.)
                            _cardHorizontal(
                              "Ordens de Serviço (O.S.)",
                              "Criar, despachar e acompanhar atendimentos",
                              Icons.assignment_rounded,
                              corAmareloSuave,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TelaOSAdmin()),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 2 CURTOS: MINHAS O.S. + TRABALHO SEM O.S
                            Row(
                              children: [
                                Expanded(
                                  child: _cardCompacto(
                                    "Minhas O.S.",
                                    "Atendimento campo",
                                    Icons.assignment_ind_rounded,
                                    corVerdeWhats,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaOSFuncionario(usuarioLogado: widget.usuarioLogado),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _cardCompacto(
                                    "Trabalho sem O.S",
                                    "Serviço de campo",
                                    Icons.build_circle_rounded,
                                    corCianoEletrico,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TelaLancamentoTrabalhoFuncionario(
                                          usuarioLogado: widget.usuarioLogado,
                                          modoAdmin: false,
                                        ),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                              ],
                            ),

                            _tituloSecao("DOCUMENTOS & LAUDOS TÉCNICOS"),

                            // 1 LONGO: RELATÓRIOS DE CONDOMÍNIO
                            _cardHorizontal(
                              "Relatórios de Condomínio",
                              "Laudos periciais com equipamentos, até 10 fotos e WhatsApp",
                              Icons.apartment_rounded,
                              corCianoEletrico,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TelaRelatoriosCondominio(usuarioLogado: widget.usuarioLogado),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 2 CURTOS: ORÇAMENTO (SEM SUBTEXTO) + RECIBO
                            Row(
                              children: [
                                Expanded(
                                  child: _cardCompacto(
                                    "Orçamento",
                                    "",
                                    Icons.request_quote_outlined,
                                    corAmareloSuave,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaEmissaoDoc(tipoDoc: 'ORÇAMENTO'),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _cardCompacto(
                                    "Recibo",
                                    "Quitado",
                                    Icons.receipt_long_rounded,
                                    corCianoEletrico,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TelaEmissaoDoc(tipoDoc: 'RECIBO'),
                                      ),
                                    ).then((_) => _sincronizar()),
                                  ),
                                ),
                              ],
                            ),

                            _tituloSecao("CADASTROS & NOTAS"),

                            // 1 LONGO: MEU HISTÓRICO E RELATÓRIO
                            _cardHorizontal(
                              "Meu Histórico e Relatório",
                              "Prestação de contas e histórico de produção",
                              Icons.history_edu_rounded,
                              corAmareloSuave,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TelaHistoricoFuncionario(usuarioLogado: widget.usuarioLogado),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 2 CURTOS: CLIENTES + DIÁRIO / NOTAS
                            Row(
                              children: [
                                Expanded(
                                  child: _cardCompacto(
                                    "Clientes",
                                    "Contatos & Locais",
                                    Icons.people_alt_rounded,
                                    corLaranjaAlerta,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const TelaClientes()),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _cardCompacto(
                                    "Diário / Notas",
                                    "Anotações",
                                    Icons.note_alt_rounded,
                                    corRoxoNotas,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const TelaNotas()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardCompacto(String tit, String sub, IconData ic, Color cor, VoidCallback fn) {
    return InkWell(
      onTap: fn,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 94,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: corCardFundo.withOpacity(0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.28), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: cor.withOpacity(0.12),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: cor.withOpacity(0.24),
                  child: Icon(ic, size: 20, color: cor),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: cor.withOpacity(0.55)),
              ],
            ),
            const SizedBox(height: 6),
            Text(tit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: corTextoClaro)),
            if (sub.trim().isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _cardHorizontal(String tit, String sub, IconData ic, Color cor, VoidCallback fn) {
    final bool temSub = sub.trim().isNotEmpty;

    return InkWell(
      onTap: fn,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: temSub ? 13 : 15),
        decoration: BoxDecoration(
          color: corCardFundo.withOpacity(0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.28), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: cor.withOpacity(0.12),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cor.withOpacity(0.24),
              child: Icon(ic, size: 22, color: cor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tit, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: corTextoClaro)),
                  if (temSub) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cor.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}



