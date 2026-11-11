import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_base.dart';
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

  // ⚠️ COLOQUE SEU WHATSAPP AQUI (com DDD, somente números)
  final String _whatsappSuporte = "5547984553301";

  Future<void> _abrirWhatsAppSuporte() async {
    final nomeEmpresa = widget.dadosEmpresa?['nome'] ?? 'Minha Empresa';
    final texto = "Olá! Meu período de acesso ao O.S. Prime para a empresa *$nomeEmpresa* expirou. Gostaria de assinar / renovar a licença.";
    final url = Uri.parse("https://wa.me/$_whatsappSuporte?text=${Uri.encodeComponent(texto)}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  Future<void> _verificarStatusNovamente() async {
    setState(() => _verificando = true);
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
        final expirado = (validade != null && agora.isAfter(validade)) || status == 'bloqueado';

        if (!expirado) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.green, content: Text('✅ Licença ativada com sucesso! Bem-vindo de volta.')),
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
          const SnackBar(backgroundColor: Colors.amber, content: Text('⚠️ A licença ainda consta como pendente/expirada.')),
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
    final chave = _chaveController.text.trim();
    if (chave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('Informe a chave de ativação.')),
      );
      return;
    }

    setState(() => _verificando = true);
    try {
      final res = await supabase.from('empresas').select().limit(1).maybeSingle();
      if (res != null) {
        final chaveCadastrada = (res['chave_licenca'] ?? '').toString().trim();
        
        // Se a chave coincidir com a chave cadastrada ou padrão de ativação
        if (chaveCadastrada.isNotEmpty && chave == chaveCadastrada) {
          // Estende por mais 30 dias automaticamente
          final novaValidade = DateTime.now().add(const Duration(days: 30)).toIso8601String();
          await supabase.from('empresas').update({
            'status': 'ativo',
            'validade': novaValidade,
          }).eq('id', res['id']);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.green, content: Text('✅ Chave validada! Licença renovada por 30 dias.')),
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
          const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ Chave de ativação inválida.')),
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

  @override
  Widget build(BuildContext context) {
    final nomeEmpresa = widget.dadosEmpresa?['nome'] ?? 'O.S. Prime';

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
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 50),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Período de Acesso Expirado',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
                  child: const Text(
                    'Seu período de teste de 30 dias ou assinatura do O.S. Prime encerrou. Para continuar emitindo ordens de serviço, relatórios técnicos e orçamentos, renove sua licença.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
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
                    label: const Text('RENOVAR LICENÇA VIA WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _abrirWhatsAppSuporte,
                  ),
                ),
                const SizedBox(height: 14),
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
                    label: _verificando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: corCianoEletrico))
                        : const Text('JÁ REALIZEI O PAGAMENTO (VERIFICAR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _verificando ? null : _verificarStatusNovamente,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OU ATIVE POR CÓDIGO', style: TextStyle(color: Colors.grey, fontSize: 10))),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _chaveController,
                  decoration: const InputDecoration(
                    labelText: 'Chave de Ativação',
                    hintText: 'Insira o código de liberação fornecido',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key, color: corCianoEletrico),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F1E36),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _verificando ? null : _ativarComChave,
                    child: const Text('ATIVAR COM CHAVE', style: TextStyle(fontWeight: FontWeight.bold)),
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
