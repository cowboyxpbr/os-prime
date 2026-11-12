// ============================================================================
// ARQUIVO: INICIALIZAÇÃO, TEMA, LOGIN, RECUPERAÇÃO E NOTIFICAÇÕES ONESIGNAL
// lib/main.dart (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'app_base.dart';
import 'screens/menu_principal_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // CONFIGURAÇÃO ONESIGNAL (COM SOM E PERMISSÃO ATIVA - ID CORRIGIDO COM 4708)
  try {
    OneSignal.initialize("04552b74-f865-437f-94b6-4b07dc65d901");
    
    // Solicita permissão no Android 13+ e iOS
    await OneSignal.Notifications.requestPermission(true);

    // Exibe o banner na tela com alerta
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });
  } catch (_) {}

  final usuario = await CacheOffline.obterSessaoAtiva();

  // Sincroniza sessão ativa no OneSignal com login e nome
  if (usuario != null) {
    try {
      final userLimpo = usuario.usuario.trim().toLowerCase().replaceAll('@', '');
      await OneSignal.login(userLimpo);
      OneSignal.User.addTagWithKey("usuario", userLimpo);
      OneSignal.User.addTagWithKey("nome", usuario.nome.trim().toLowerCase());
      OneSignal.User.addTagWithKey("cargo", usuario.cargo);
    } catch (_) {}
  }

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'O.S. Prime',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: corFundoApp,
      primaryColor: corCianoEletrico,
      cardColor: corCardFundo,
      colorScheme: const ColorScheme.dark(
        primary: corCianoEletrico,
        secondary: corCianoSuave,
        surface: corCardFundo,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: corCardFundo,
        labelStyle: const TextStyle(color: corCianoSuave, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0x4D00D4FF)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: corCianoEletrico, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    ),
    home: usuario != null ? TelaMenuPrincipal(usuarioLogado: usuario) : const TelaLogin(),
  ));
}

// ============================================================================
// TELA DE LOGIN COM RECUPERAÇÃO DE SENHA POR PERGUNTA SECRETA
// ============================================================================
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _usuarioCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _manterLogado = true, _senhaVisivel = false, _carregando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarPrimeiroAcesso());
  }

  Future<void> _verificarPrimeiroAcesso() async {
    try {
      final res = await Supabase.instance.client.from('usuarios').select('id').ilike('cargo', 'master').limit(1);
      if (res.isEmpty && mounted) _solicitarChavePrimeiroAcesso();
    } catch (_) {}
  }

  void _solicitarChavePrimeiroAcesso() {
    final chaveCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: const Row(children: [Icon(Icons.vpn_key_rounded, color: corCianoEletrico, size: 22), SizedBox(width: 8), Text('Chave de Primeiro Acesso', style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Para configurar o primeiro Administrador Master, digite a Chave Mestra oficial:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 14),
          TextField(controller: chaveCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Chave Mestra *', hintText: 'PRIME-2026-MASTER', isDense: true, prefixIcon: Icon(Icons.key, color: corCianoEletrico, size: 18))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
            child: const Text('Liberar Acesso', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              if (chaveCtrl.text.trim() == 'PRIME-2026-MASTER') {
                Navigator.pop(ctx);
                _dialogConfigurarAdmin();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Chave Mestra inválida!')));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final userDigitado = _usuarioCtrl.text.trim().toLowerCase();
    final userLimpo = userDigitado.replaceAll('@', '');
    final pass = _senhaCtrl.text.trim();

    if (userLimpo.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Digite o usuário e a senha.')),
      );
      return;
    }

    setState(() => _carregando = true);
    UsuarioApp? autenticado;

    // 1. Caso admin padrão
    if (userLimpo == 'admin' && pass == 'admin') {
      autenticado = UsuarioApp(
        nome: 'Administrador',
        usuario: 'admin',
        senha: 'admin',
        cargo: 'master',
        primeiroAcesso: false,
      );
    }

    // 2. Busca no Supabase
    if (autenticado == null) {
      try {
        final res = await supabase
            .from('usuarios')
            .select()
            .or('usuario.ilike.$userLimpo,usuario.ilike.@$userLimpo')
            .timeout(const Duration(seconds: 8));

        if (res.isNotEmpty) {
          final dados = res.first;
          final senhaBanco = (dados['senha'] ?? '').toString().trim();
          if (senhaBanco == pass) {
            autenticado = UsuarioApp.fromMap(dados);
            await CacheOffline.salvarUsuarioLocal(autenticado);
          } else {
            if (!mounted) return;
            setState(() => _carregando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Senha incorreta!')),
            );
            return;
          }
        }
      } catch (_) {}
    }

    // 3. Busca no Cache Local
    if (autenticado == null) {
      final locais = await CacheOffline.carregarUsuariosLocais();
      for (var u in locais) {
        final uCadastrado = u.usuario.trim().toLowerCase().replaceAll('@', '');
        if (uCadastrado == userLimpo) {
          if (u.senha.trim() == pass) {
            autenticado = u;
          } else {
            if (!mounted) return;
            setState(() => _carregando = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Senha incorreta!')),
            );
            return;
          }
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() => _carregando = false);

    if (autenticado != null) {
      // 🔔 Registra no OneSignal com som e tags ativas
      try {
        final loginOneSignal = autenticado.usuario.trim().toLowerCase().replaceAll('@', '');
        await OneSignal.login(loginOneSignal);
        OneSignal.User.addTagWithKey("usuario", loginOneSignal);
        OneSignal.User.addTagWithKey("nome", autenticado.nome.trim().toLowerCase());
        OneSignal.User.addTagWithKey("cargo", autenticado.cargo);
      } catch (_) {}

      await CacheOffline.salvarSessao(autenticado, _manterLogado);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TelaMenuPrincipal(usuarioLogado: autenticado!)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Usuário não cadastrado ou sem conexão!')),
      );
    }
  }

  void _modalEsqueceuSenha() {
    final userC = TextEditingController();
    UsuarioApp? userEncontrado;
    final respostaC = TextEditingController();
    final novaSenhaC = TextEditingController();
    bool etapaResposta = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amberAccent)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.amberAccent, size: 22),
              SizedBox(width: 8),
              Text('Recuperar Senha', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!etapaResposta) ...[
                  const Text('Digite o seu nome de usuário/login cadastrado:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextField(controller: userC, decoration: const InputDecoration(labelText: 'Usuário / Login', isDense: true)),
                ] else ...[
                  Text("Usuário: @${userEncontrado!.usuario.replaceAll('@', '')}", style: const TextStyle(fontWeight: FontWeight.bold, color: corCianoSuave)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0x1F00D4FF), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      "Pergunta: ${userEncontrado!.perguntaSecreta.isNotEmpty ? userEncontrado!.perguntaSecreta : 'Qual o nome da empresa?'}",
                      style: const TextStyle(fontSize: 12, color: corTextoClaro, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: respostaC, decoration: const InputDecoration(labelText: 'Sua Resposta Secreta *', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: novaSenhaC, obscureText: true, decoration: const InputDecoration(labelText: 'Digite a Nova Senha *', isDense: true)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              child: Text(!etapaResposta ? 'Avançar' : 'Redefinir Senha'),
              onPressed: () async {
                if (!etapaResposta) {
                  final uText = userC.text.trim().toLowerCase().replaceAll('@', '');
                  if (uText.isEmpty) return;

                  try {
                    final res = await supabase.from('usuarios').select().or('usuario.ilike.$uText,usuario.ilike.@$uText');
                    if (res.isNotEmpty) userEncontrado = UsuarioApp.fromMap(res.first);
                  } catch (_) {}

                  if (userEncontrado == null) {
                    final locais = await CacheOffline.carregarUsuariosLocais();
                    for (var u in locais) {
                      if (u.usuario.toLowerCase().replaceAll('@', '') == uText) {
                        userEncontrado = u;
                        break;
                      }
                    }
                  }

                  if (userEncontrado == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Usuário não encontrado!')));
                    return;
                  }

                  setM(() => etapaResposta = true);
                } else {
                  final respDigitada = respostaC.text.trim().toLowerCase();
                  final respSalva = userEncontrado!.respostaSecreta.trim().toLowerCase();

                  if (respSalva.isNotEmpty && respDigitada != respSalva) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Resposta secreta incorreta!')));
                    return;
                  }

                  if (novaSenhaC.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Digite a nova senha!')));
                    return;
                  }

                  userEncontrado!.senha = novaSenhaC.text.trim();
                  await CacheOffline.salvarUsuarioLocal(userEncontrado!);

                  try {
                    await supabase.from('usuarios').update({'senha': userEncontrado!.senha}).ilike('usuario', userEncontrado!.usuario);
                  } catch (_) {}

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('✅ Senha redefinida com sucesso! Faça login.')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _dialogConfigurarAdmin() {
    final nomeCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final foneCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final perguntaCtrl = TextEditingController();
    final respostaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: corCianoEletrico)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: corCianoEletrico, size: 22),
            SizedBox(width: 8),
            Text('Cadastrar Administrador', style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Defina os dados de acesso do Administrador:', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(controller: nomeCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome Completo *', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Usuário / Login *', isDense: true)),
              const SizedBox(height: 8),
              TextField(
                controller: foneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'WhatsApp / Telefone *', isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(controller: senhaCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Senha *', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: perguntaCtrl, decoration: const InputDecoration(labelText: 'Pergunta Secreta (p/ recuperar senha) *', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: respostaCtrl, decoration: const InputDecoration(labelText: 'Resposta Secreta *', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
            child: const Text('Salvar e Entrar'),
            onPressed: () async {
              final nome = nomeCtrl.text.trim();
              final novoUser = userCtrl.text.trim().toLowerCase().replaceAll('@', '');
              final fone = foneCtrl.text.trim();
              final novaSenha = senhaCtrl.text.trim();
              final pergunta = perguntaCtrl.text.trim();
              final resposta = respostaCtrl.text.trim().toLowerCase();

              if (nome.isEmpty || novoUser.isEmpty || novaSenha.isEmpty || fone.isEmpty || pergunta.isEmpty || resposta.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha todos os campos obrigatórios!')),
                );
                return;
              }

              final master = UsuarioApp(
                nome: nome,
                usuario: novoUser,
                senha: novaSenha,
                telefone: fone,
                cargo: 'master',
                primeiroAcesso: false,
                perguntaSecreta: pergunta,
                respostaSecreta: resposta,
              );

              try {
                await OneSignal.login(master.usuario);
                OneSignal.User.addTagWithKey("cargo", "master");
              } catch (_) {}

              await CacheOffline.salvarUsuarioLocal(master);
              await CacheOffline.salvarSessao(master, true);

              try {
                await supabase.from('usuarios').upsert(master.toMap(), onConflict: 'usuario');
              } catch (_) {}

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => TelaMenuPrincipal(usuarioLogado: master)),
                );
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
      backgroundColor: corFundoApp,
      body: FundoComArteApp(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const BannerOSPrime(subtituloTela: 'Acesso ao Sistema'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: corCardFundo,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x6600D4FF)),
                    ),
                    child: Column(
                      children: [
                        const Text('Entrar no Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: corCianoEletrico)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _usuarioCtrl,
                          decoration: const InputDecoration(labelText: 'Usuário', prefixIcon: Icon(Icons.person, color: corCianoEletrico, size: 20), isDense: true),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _senhaCtrl,
                          obscureText: !_senhaVisivel,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            isDense: true,
                            prefixIcon: const Icon(Icons.lock, color: corCianoEletrico, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_senhaVisivel ? Icons.visibility : Icons.visibility_off, color: corCianoSuave, size: 18),
                              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Checkbox(
                                value: _manterLogado,
                                activeColor: corCianoEletrico,
                                checkColor: Colors.black,
                                onChanged: (v) => setState(() => _manterLogado = v ?? true),
                              ),
                              const Text('Lembrar', style: TextStyle(color: corTextoClaro, fontSize: 12)),
                            ]),
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: _modalEsqueceuSenha,
                              child: const Text('Esqueceu a senha?', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: corCianoEletrico,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _carregando ? null : _entrar,
                            child: _carregando
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Text('ENTRAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



