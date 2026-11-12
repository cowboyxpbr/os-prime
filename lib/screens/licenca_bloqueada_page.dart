import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_base.dart';
import '../servico_licenca_bugs.dart';
import 'menu_principal_page.dart';

class LicencaBloqueadaPage extends StatefulWidget {
  final Map<String, dynamic>? dadosEmpresa;
  final dynamic usuarioLogado;

  const LicencaBloqueadaPage({
    super.key,
    this.dadosEmpresa,
    this.usuarioLogado,
  });

  @override
  State<LicencaBloqueadaPage> createState() => _LicencaBloqueadaPageState();
}

class _LicencaBloqueadaPageState extends State<LicencaBloqueadaPage> {
  final _chaveController = TextEditingController();
  bool _verificando = false;
  StreamSubscription? _sub;
  Map<String, dynamic>? _empAtual;

  final String _whatsappSuporte = "5547984553301";

  @override
  void initState() {
    super.initState();
    _empAtual = widget.dadosEmpresa;
    _escutarLiberacaoEmTempoReal();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _escutarLiberacaoEmTempoReal() {
    try {
      _sub = supabase.from('empresas').stream(primaryKey: ['id']).listen((lista) {
        if (lista.isEmpty || !mounted) return;
        final res = lista.first;
        setState(() => _empAtual = res);

        final status = (res['status'] ?? 'ativo').toString().toLowerCase();
        final validadeStr = res['validade']?.toString();
        DateTime? validade = validadeStr != null ? DateTime.tryParse(validadeStr) : null;
        final expirado = (validade != null && DateTime.now().isAfter(validade)) ||
            status == 'bloqueado' ||
            status == 'suspenso' ||
            status == 'pendente' ||
            status == 'aguardando_cadastro';

        if (!expirado && mounted && widget.usuarioLogado != null) {
          _sub?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text('✅ Acesso liberado pela Administração!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TelaMenuPrincipal(usuarioLogado: widget.usuarioLogado)),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _abrirWhatsAppSuporte() async {
    final nomeEmpresa = _empAtual?['nome'] ?? 'Minha Empresa';
    final status = (_empAtual?['status'] ?? '').toString().toLowerCase();
    final chave = (_empAtual?['chave_licenca'] ?? '').toString();
    final texto = status == 'pendente'
        ? "Olá! Acabei de cadastrar a empresa *$nomeEmpresa* com a chave *$chave* no O.S. Prime e aguardo a liberação do acesso."
        : "Olá! O acesso da empresa *$nomeEmpresa* no O.S. Prime está bloqueado/vencido. Gostaria de renovar a licença.";
    final url = Uri.parse("https://wa.me/$_whatsappSuporte?text=${Uri.encodeComponent(texto)}");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _verificarStatusNovamente() async {
    setState(() => _verificando = true);
    try {
      final res = await supabase.from('empresas').select().limit(1).maybeSingle();
      if (res != null) {
        final status = (res['status'] ?? 'ativo').toString().toLowerCase();
        final validadeStr = res['validade']?.toString();
        DateTime? validade = validadeStr != null ? DateTime.tryParse(validadeStr) : null;
        final expirado = (validade != null && DateTime.now().isAfter(validade)) ||
            status == 'bloqueado' ||
            status == 'suspenso' ||
            status == 'pendente' ||
            status == 'aguardando_cadastro';

        if (!expirado) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.green, content: Text('✅ Licença ativa! Bem-vindo.')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => TelaMenuPrincipal(usuarioLogado: widget.usuarioLogado)),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.amber, content: Text('⏳ Aguardando liberação pelo Administrador...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _ativarComChave() async {
    final chave = _chaveController.text.trim().toUpperCase();
    if (chave.isEmpty) return;

    setState(() => _verificando = true);
    try {
      final res = await supabase.from('empresas').select().limit(1).maybeSingle();
      if (res != null) {
        final chaveCadastrada = (res['chave_licenca'] ?? '').toString().trim().toUpperCase();
        if (chaveCadastrada.isNotEmpty && chave == chaveCadastrada) {
          final plano = ServicoLicencaBugs.identificarPlano(chave);
          final dias = ServicoLicencaBugs.diasDoPlano(plano);
          final novaValidade = DateTime.now().add(Duration(days: dias)).toUtc().toIso8601String();
          await supabase.from('empresas').update({
            'status': 'ativo',
            'validade': novaValidade,
          }).eq('id', res['id']);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Chave inválida.')),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomeEmpresa = _empAtual?['nome'] ?? 'O.S. Prime';
    final status = (_empAtual?['status'] ?? '').toString().toLowerCase();
    final isPendente = status == 'pendente' || status == 'aguardando_cadastro';

    return Scaffold(
      backgroundColor: corFundoApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: (isPendente ? Colors.amberAccent : Colors.redAccent).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: isPendente ? Colors.amberAccent : Colors.redAccent, width: 2),
                  ),
                  child: Icon(
                    isPendente ? Icons.hourglass_top_rounded : Icons.lock_clock_rounded,
                    color: isPendente ? Colors.amberAccent : Colors.redAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isPendente ? 'Aguardando Liberação de Acesso' : 'Licença Suspensa ou Expirada',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Empresa: $nomeEmpresa',
                  style: const TextStyle(fontSize: 14, color: corCianoEletrico, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: corCardFundo,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    isPendente
                        ? 'O cadastro da sua empresa foi enviado com sucesso! Assim que o Administrador confirmar a liberação no Painel Central, esta tela abrirá automaticamente.'
                        : 'O período de acesso da sua empresa no O.S. Prime encerrou ou encontra-se suspenso. Entre em contato com o suporte para liberar seu plano (Mensal, Trimestral, Semestral ou Anual).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      isPendente ? 'SOLICITAR LIBERAÇÃO NO WHATSAPP' : 'RENOVAR LICENÇA VIA WHATSAPP',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: _abrirWhatsAppSuporte,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: corCianoEletrico),
                      foregroundColor: corCianoEletrico,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('VERIFICAR LIBERAÇÃO AGORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _verificando ? null : _verificarStatusNovamente,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _chaveController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Ativar com Nova Chave',
                    prefixIcon: Icon(Icons.key, color: corCianoEletrico),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F1E36), foregroundColor: Colors.white),
                    onPressed: _verificando ? null : _ativarComChave,
                    child: const Text('VALIDAR CHAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}