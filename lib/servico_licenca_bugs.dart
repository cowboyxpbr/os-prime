import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_base.dart';
import 'screens/licenca_bloqueada_page.dart';
import 'screens/menu_principal_page.dart';

class ServicoLicencaBugs {
  static const String whatsappSuporteComercial = "5547984553301";
  static bool _alertaVencimentoJaExibidoNaSessao = false;
  static DateTime? _ultimoErroEnviado;

  static String identificarPlano(String? chaveLicenca) {
    final c = (chaveLicenca ?? '').toUpperCase();
    if (c.contains('ANUAL')) return 'ANUAL';
    if (c.contains('SEMESTRAL')) return 'SEMESTRAL';
    if (c.contains('TRIMESTRAL')) return 'TRIMESTRAL';
    if (c.contains('MENSAL')) return 'MENSAL';
    return 'MENSAL';
  }

  static int diasDoPlano(String plano) {
    switch (plano.toUpperCase()) {
      case 'ANUAL':
        return 365;
      case 'SEMESTRAL':
        return 180;
      case 'TRIMESTRAL':
        return 90;
      case 'MENSAL':
      default:
        return 30;
    }
  }

  static void inicializarCapturaDeErrosGlobal() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      registrarErroOuBug(
        erro: details.exceptionAsString(),
        detalhes: details.stack?.toString() ?? 'Sem stacktrace',
        tipo: 'ERRO_AUTOMATICO',
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      registrarErroOuBug(
        erro: error.toString(),
        detalhes: stack.toString(),
        tipo: 'FALHA_SISTEMA',
      );
      return true;
    };
  }

  static Future<void> registrarErroOuBug({
    required String erro,
    String detalhes = '',
    String tipo = 'MANUAL',
    String? usuarioInformado,
    String? empresaInformada,
  }) async {
    try {
      if (tipo != 'MANUAL' && tipo != 'NOVO_CADASTRO' && _ultimoErroEnviado != null) {
        if (DateTime.now().difference(_ultimoErroEnviado!).inSeconds < 20) {
          return;
        }
      }
      _ultimoErroEnviado = DateTime.now();

      String nomeEmpresa = empresaInformada ?? 'Empresa Cliente';
      String loginUsuario = usuarioInformado ?? 'desconhecido';
      String cargoUsuario = '-';

      try {
        final sessao = await CacheOffline.obterSessaoAtiva();
        if (sessao != null) {
          loginUsuario = sessao.usuario;
          cargoUsuario = sessao.cargo;
        }
      } catch (_) {}

      try {
        final emp = await supabase.from('empresas').select('nome').limit(1).maybeSingle();
        if (emp != null && (emp['nome'] ?? '').toString().trim().isNotEmpty) {
          nomeEmpresa = emp['nome'].toString().trim();
        }
      } catch (_) {}

      final payload = jsonEncode({
        'empresa': nomeEmpresa,
        'usuario': loginUsuario,
        'cargo': cargoUsuario,
        'tipo': tipo,
        'erro': erro.length > 350 ? erro.substring(0, 350) : erro,
        'detalhes': detalhes.length > 600 ? detalhes.substring(0, 600) : detalhes,
        'data': DateTime.now().toUtc().toIso8601String(),
      });

      await supabase.from('mensagens_chat').insert({
        'remetente': '__bug_osprime__',
        'destinatario': '__painel_admin__',
        'texto': payload,
        'visualizado': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static void abrirModalReportarBug(BuildContext context, UsuarioApp usuario) {
    final descCtrl = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.orangeAccent),
          ),
          title: const Row(
            children: [
              Icon(Icons.bug_report_rounded, color: Colors.orangeAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Relatar Erro / Bug no App',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descreva o erro ou dificuldade encontrada para enviarmos um alerta imediato ao suporte central:',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descrição do problema *',
                  hintText: 'Ex: Falha ao salvar O.S., tela travou...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
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
              ),
              icon: enviando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Enviar Alerta', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: enviando
                  ? null
                  : () async {
                      if (descCtrl.text.trim().isEmpty) return;
                      setD(() => enviando = true);
                      await registrarErroOuBug(
                        erro: descCtrl.text.trim(),
                        detalhes: 'Relato manual por @${usuario.usuario} (${usuario.cargo})',
                        tipo: 'RELATO_USUARIO',
                        usuarioInformado: usuario.usuario,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.green,
                            content: Text('✅ Alerta enviado ao suporte central!'),
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  static void abrirModalCadastroEmpresaComChave(BuildContext context) {
    final chaveCtrl = TextEditingController();
    final empresaNomeCtrl = TextEditingController();
    final cnpjCtrl = TextEditingController();
    final ramoCtrl = TextEditingController();
    final whatsEmpresaCtrl = TextEditingController();
    final enderecoCtrl = TextEditingController();

    final masterNomeCtrl = TextEditingController();
    final masterUserCtrl = TextEditingController();
    final masterSenhaCtrl = TextEditingController();
    final masterPerguntaCtrl = TextEditingController(text: 'Qual o nome da empresa?');
    final masterRespostaCtrl = TextEditingController();

    bool salvando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: corCardFundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: corCianoEletrico, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.domain_add_rounded, color: corCianoEletrico, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cadastrar Empresa & Chave',
                  style: TextStyle(color: corCianoEletrico, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: corCianoEletrico.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: corCianoEletrico.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Digite a Chave de Acesso fornecida e cadastre sua empresa. Assim que concluir, a administração liberará o seu acesso!',
                      style: TextStyle(fontSize: 11.5, color: corTextoClaro),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chaveCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Chave de Acesso *',
                      hintText: 'Ex: PRIME-MENSAL-2026',
                      prefixIcon: Icon(Icons.vpn_key_rounded, color: Colors.amberAccent, size: 18),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('1. DADOS DA EMPRESA', style: TextStyle(color: corCianoEletrico, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: empresaNomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome da Empresa *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cnpjCtrl,
                    decoration: const InputDecoration(labelText: 'CNPJ ou CPF *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ramoCtrl,
                    decoration: const InputDecoration(labelText: 'Ramo de Atuação', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: whatsEmpresaCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'WhatsApp / Telefone *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: enderecoCtrl,
                    decoration: const InputDecoration(labelText: 'Cidade / Endereço', isDense: true),
                  ),
                  const SizedBox(height: 14),
                  const Text('2. CRIAR LOGIN MASTER DA EMPRESA', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: masterNomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Seu Nome Completo *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: masterUserCtrl,
                    decoration: const InputDecoration(labelText: 'Usuário / Login Master *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: masterSenhaCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: masterPerguntaCtrl,
                    decoration: const InputDecoration(labelText: 'Pergunta Secreta *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: masterRespostaCtrl,
                    decoration: const InputDecoration(labelText: 'Resposta Secreta *', isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corCianoEletrico, foregroundColor: Colors.black),
              onPressed: salvando
                  ? null
                  : () async {
                      final chave = chaveCtrl.text.trim().toUpperCase();
                      final empNome = empresaNomeCtrl.text.trim();
                      final cnpj = cnpjCtrl.text.trim();
                      final whats = whatsEmpresaCtrl.text.trim();
                      final mNome = masterNomeCtrl.text.trim();
                      final mUser = masterUserCtrl.text.trim().toLowerCase().replaceAll('@', '');
                      final mSenha = masterSenhaCtrl.text.trim();
                      final mResp = masterRespostaCtrl.text.trim().toLowerCase();

                      if (chave.isEmpty || empNome.isEmpty || whats.isEmpty || mNome.isEmpty || mUser.isEmpty || mSenha.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ Preencha a Chave, Empresa e Login Master!')),
                        );
                        return;
                      }

                      setD(() => salvando = true);
                      try {
                        final existentePorChave = await supabase
                            .from('empresas')
                            .select()
                            .ilike('chave_licenca', chave)
                            .maybeSingle();

                        if (chave != 'PRIME-2026-MASTER' && existentePorChave == null) {
                          final primeiraEmp = await supabase.from('empresas').select().limit(1).maybeSingle();
                          if (primeiraEmp != null) {
                            final chaveBanco = (primeiraEmp['chave_licenca'] ?? '').toString().trim().toUpperCase();
                            if (chaveBanco.isNotEmpty && chaveBanco != chave) {
                              if (ctx.mounted) {
                                setD(() => salvando = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text('❌ Chave de Acesso inválida! Solicite sua chave ao suporte.'),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                        }

                        final dadosEmpresa = {
                          'nome': empNome,
                          'ramo_atividade': ramoCtrl.text.trim(),
                          'cnpj_cpf': cnpj,
                          'endereco': enderecoCtrl.text.trim(),
                          'telefone': whats,
                          'whatsapp': whats,
                          'chave_licenca': chave,
                          'status': chave == 'PRIME-2026-MASTER' ? 'ativo' : 'pendente',
                        };

                        if (existentePorChave != null) {
                          final stAtual = (existentePorChave['status'] ?? '').toString().toLowerCase();
                          dadosEmpresa['status'] = (stAtual == 'ativo') ? 'ativo' : 'pendente';
                          await supabase.from('empresas').update(dadosEmpresa).eq('id', existentePorChave['id']);
                        } else {
                          await supabase.from('empresas').insert(dadosEmpresa);
                        }

                        final master = UsuarioApp(
                          nome: mNome,
                          usuario: mUser,
                          senha: mSenha,
                          telefone: whats,
                          cargo: 'master',
                          primeiroAcesso: false,
                          perguntaSecreta: masterPerguntaCtrl.text.trim(),
                          respostaSecreta: mResp.isEmpty ? empNome.toLowerCase() : mResp,
                        );

                        await CacheOffline.salvarUsuarioLocal(master);
                        await CacheOffline.salvarSessao(master, true);
                        try {
                          await supabase.from('usuarios').upsert(master.toMap(), onConflict: 'usuario');
                        } catch (_) {}

                        await registrarErroOuBug(
                          erro: 'NOVO CADASTRO DE EMPRESA: $empNome (Chave: $chave)',
                          detalhes: 'Master: $mNome (@$mUser) • WhatsApp: $whats • CNPJ: $cnpj',
                          tipo: 'NOVO_CADASTRO',
                          usuarioInformado: mUser,
                          empresaInformada: empNome,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => TelaMenuPrincipal(usuarioLogado: master)),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setD(() => salvando = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao cadastrar: $e')),
                          );
                        }
                      }
                    },
              child: salvando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('CADASTRAR E CONTINUAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitorLicencaMasterWidget extends StatefulWidget {
  final UsuarioApp usuarioLogado;
  const MonitorLicencaMasterWidget({super.key, required this.usuarioLogado});

  @override
  State<MonitorLicencaMasterWidget> createState() => _MonitorLicencaMasterWidgetState();
}

class _MonitorLicencaMasterWidgetState extends State<MonitorLicencaMasterWidget> {
  StreamSubscription? _sub;
  Map<String, dynamic>? _empresa;
  int? _diasRestantes;
  String _plano = 'MENSAL';
  String _dataFormatada = '';

  @override
  void initState() {
    super.initState();
    _iniciarEscutaEmpresa();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _iniciarEscutaEmpresa() {
    try {
      _sub = supabase
          .from('empresas')
          .stream(primaryKey: ['id'])
          .listen((lista) {
        if (lista.isEmpty || !mounted) return;
        _processarDadosEmpresa(lista.first);
      });
    } catch (_) {}
  }

  void _processarDadosEmpresa(Map<String, dynamic> emp) {
    final status = (emp['status'] ?? 'ativo').toString().toLowerCase().trim();
    final validadeStr = emp['validade']?.toString();
    final chave = emp['chave_licenca']?.toString();
    final plano = ServicoLicencaBugs.identificarPlano(chave);

    DateTime? validade;
    int? diasRest;
    String dataFmt = '';

    if (validadeStr != null && validadeStr.isNotEmpty) {
      validade = DateTime.tryParse(validadeStr)?.toLocal();
      if (validade != null) {
        final agora = DateTime.now();
        diasRest = validade.difference(DateTime(agora.year, agora.month, agora.day)).inDays;
        dataFmt = DateFormat('dd/MM/yyyy').format(validade);
      }
    }

    final bool bloqueadoPorStatus = status == 'bloqueado' || status == 'suspenso' || status == 'pendente' || status == 'aguardando_cadastro';
    final bool expiradoPorData = validade != null && DateTime.now().isAfter(validade);

    if (bloqueadoPorStatus || expiradoPorData) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LicencaBloqueadaPage(
                dadosEmpresa: emp,
                usuarioLogado: widget.usuarioLogado,
              ),
            ),
          );
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _empresa = emp;
        _diasRestantes = diasRest;
        _plano = plano;
        _dataFormatada = dataFmt;
      });
    }

    if (widget.usuarioLogado.isMaster &&
        diasRest != null &&
        diasRest <= 5 &&
        !ServicoLicencaBugs._alertaVencimentoJaExibidoNaSessao &&
        mounted) {
      ServicoLicencaBugs._alertaVencimentoJaExibidoNaSessao = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _exibirDialogAlertaVencimentoMaster(diasRest!, dataFmt, plano, emp['nome']?.toString() ?? 'Sua Empresa');
      });
    }
  }

  Future<void> _chamarSuporteRenovacao() async {
    final nomeEmp = _empresa?['nome'] ?? 'Minha Empresa';
    final msg = "Olá! Sou Master da empresa *$nomeEmp* no O.S. Prime. Meu plano *$_plano* vence em $_dataFormatada e gostaria de renovar!";
    final url = Uri.parse("https://wa.me/${ServicoLicencaBugs.whatsappSuporteComercial}?text=${Uri.encodeComponent(msg)}");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _exibirDialogAlertaVencimentoMaster(int dias, String dataFmt, String plano, String nomeEmpresa) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: corCardFundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.amberAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aviso de Vencimento do Plano',
                style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          dias <= 0
              ? 'Atenção Master! O plano $plano da empresa $nomeEmpresa vence HOJE ($dataFmt).\n\nRenove agora para evitar a suspensão automática do acesso.'
              : 'Atenção Master! O plano $plano da empresa $nomeEmpresa vencerá em $dias dia(s) ($dataFmt).\n\nPrograme sua renovação para manter o acesso ativo.',
          style: const TextStyle(color: corTextoClaro, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: corVerdeWhats,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('Renovar no WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _chamarSuporteRenovacao();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.usuarioLogado.isMaster) return const SizedBox.shrink();
    if (_diasRestantes == null || _diasRestantes! > 7) return const SizedBox.shrink();

    final bool urgente = _diasRestantes! <= 2;
    final Color corAlerta = urgente ? Colors.redAccent : Colors.amberAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: corAlerta.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: corAlerta, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(Icons.notification_important_rounded, color: corAlerta, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _diasRestantes! <= 0
                  ? '⚠️ PLANO $_plano VENCE HOJE ($_dataFormatada)!'
                  : '⚠️ Plano $_plano vence em $_diasRestantes dia(s) ($_dataFormatada)',
              style: TextStyle(color: corAlerta, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: _chamarSuporteRenovacao,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: corAlerta,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'RENOVAR',
                style: TextStyle(
                  color: urgente ? Colors.white : Colors.black,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}