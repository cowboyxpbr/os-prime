import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_base.dart';
import 'servico_licenca_bugs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final prefs = await SharedPreferences.getInstance();
  final logado = prefs.getBool('super_admin_logado') ?? false;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'O.S. Prime Admin',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF080C14),
      primaryColor: corCianoEletrico,
      cardColor: const Color(0xFF121A28),
      colorScheme: const ColorScheme.dark(
        primary: corCianoEletrico,
        secondary: Colors.amberAccent,
        surface: Color(0xFF121A28),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D1420),
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
    home: logado ? const PainelSuperAdminPage() : const LoginSuperAdminPage(),
  ));
}

Future<void> _abrirWhatsAdmin(String telefone, String mensagem) async {
  final limpo = telefone.replaceAll(RegExp(r'[^\d]'), '');
  if (limpo.isEmpty) return;
  final numero = limpo.startsWith('55') ? limpo : '55$limpo';
  final url = Uri.parse("https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}");
  try {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class LoginSuperAdminPage extends StatefulWidget {
  const LoginSuperAdminPage({super.key});

  @override
  State<LoginSuperAdminPage> createState() => _LoginSuperAdminPageState();
}

class _LoginSuperAdminPageState extends State<LoginSuperAdminPage> {
  final _pinCtrl = TextEditingController();
  bool _manter = true;

  Future<void> _entrar() async {
    final digitado = _pinCtrl.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final senhaSalva = prefs.getString('pin_super_admin') ?? '3301';

    if (digitado == senhaSalva || digitado.toUpperCase() == 'PRIME-2026-MASTER' || digitado == 'admin') {
      if (_manter) {
        await prefs.setBool('super_admin_logado', true);
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PainelSuperAdminPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.redAccent, content: Text('❌ PIN / Chave de Dono incorreta!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF121A28),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amberAccent, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.amberAccent.withOpacity(0.15), blurRadius: 16),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.amberAccent, size: 54),
                  const SizedBox(height: 10),
                  const Text(
                    'O.S. PRIME • CENTRAL DO DONO',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Controle Comercial de Empresas, Planos e Bugs',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN ou Chave Mestra do Dono',
                      hintText: 'Padrão: 3301',
                      prefixIcon: Icon(Icons.key_rounded, color: Colors.amberAccent),
                    ),
                    onSubmitted: (_) => _entrar(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _manter,
                        activeColor: Colors.amberAccent,
                        checkColor: Colors.black,
                        onChanged: (v) => setState(() => _manter = v ?? true),
                      ),
                      const Text('Manter conectado neste aparelho', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('ACESSAR GERENCIADOR', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _entrar,
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

class PainelSuperAdminPage extends StatefulWidget {
  const PainelSuperAdminPage({super.key});

  @override
  State<PainelSuperAdminPage> createState() => _PainelSuperAdminPageState();
}

class _PainelSuperAdminPageState extends State<PainelSuperAdminPage> {
  int _abaAtual = 0;
  late final Stream<List<Map<String, dynamic>>> _empresasStream;
  late final Stream<List<Map<String, dynamic>>> _bugsStream;
  late final Stream<List<Map<String, dynamic>>> _usuariosStream;

  @override
  void initState() {
    super.initState();
    _empresasStream = supabase.from('empresas').stream(primaryKey: ['id']).order('id', ascending: false);
    _bugsStream = supabase.from('mensagens_chat').stream(primaryKey: ['id']).order('id', ascending: false).limit(120);
    _usuariosStream = supabase.from('usuarios').stream(primaryKey: ['id']).order('nome');
  }

    Future<void> _aplicarPlanoEmpresa(Map<String, dynamic> emp, String plano, int dias) async {
    final nome = emp['nome'] ?? 'Empresa';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121A28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.amberAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.amberAccent, size: 22),
            SizedBox(width: 8),
            Text('Confirmar Plano', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja definir o plano $plano ($dias dias a partir de hoje) para a empresa "$nome"?',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final id = emp['id'];
    final chaveAtual = (emp['chave_licenca'] ?? '').toString().trim();
    final sufixo = chaveAtual.isNotEmpty && chaveAtual.split('-').length >= 3
        ? chaveAtual.split('-').last
        : (1000 + Random().nextInt(8999)).toString();
    final novaChave = 'PRIME-$plano-$sufixo';

        // 🔒 CALCULA PRAZO EXATO A PARTIR DE HOJE (NUNCA ACUMULA DIAS ANTERIORES)
    final novaValidade = DateTime.now().toUtc().add(Duration(days: dias)).toIso8601String();

    try {
      await supabase.from('empresas').update({
        'status': 'ativo',
        'chave_licenca': novaChave,
        'validade': novaValidade,
      }).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('✅ Plano $plano ($dias dias) definido para $nome!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _alternarStatusEmpresa(Map<String, dynamic> emp, String novoStatus) async {
    final nome = emp['nome'] ?? 'Empresa';
    final isAtivando = novoStatus == 'ativo';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121A28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isAtivando ? Colors.greenAccent : Colors.redAccent),
        ),
        title: Row(
          children: [
            Icon(isAtivando ? Icons.check_circle_outline : Icons.block_rounded, color: isAtivando ? Colors.greenAccent : Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(isAtivando ? 'Liberar Acesso?' : 'Suspender Uso?', style: TextStyle(color: isAtivando ? Colors.greenAccent : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isAtivando
              ? 'Tem certeza que deseja LIBERAR o acesso da empresa "$nome"?'
              : 'Tem certeza que deseja SUSPENDER o acesso da empresa "$nome"? O aplicativo deles será bloqueado imediatamente.',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isAtivando ? Colors.green : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAtivando ? 'Sim, Liberar' : 'Sim, Suspender', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final Map<String, dynamic> dados = {'status': novoStatus};
      if (novoStatus == 'ativo' && emp['validade'] == null) {
        final plano = ServicoLicencaBugs.identificarPlano(emp['chave_licenca']?.toString());
        final dias = ServicoLicencaBugs.diasDoPlano(plano);
        dados['validade'] = DateTime.now().add(Duration(days: dias)).toUtc().toIso8601String();
      }
      await supabase.from('empresas').update(dados).eq('id', emp['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: novoStatus == 'ativo' ? Colors.green : Colors.redAccent,
            content: Text(
              novoStatus == 'ativo'
                  ? '✅ Acesso LIBERADO para $nome!'
                  : '🚫 Acesso SUSPENSO para $nome!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro: $e')),
        );
      }
    }
  }

  void _modalGerarNovaChave() {
    final nomeCtrl = TextEditingController();
    final whatsCtrl = TextEditingController();
    String planoSelecionado = 'MENSAL';
    bool aguardarCadastroParaLiberar = true;

    final codigoAleatorio = (1000 + Random().nextInt(8999)).toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final chaveGerada = 'PRIME-$planoSelecionado-$codigoAleatorio';
          return AlertDialog(
            backgroundColor: const Color(0xFF121A28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.amberAccent, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: Colors.amberAccent, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gerar Chave p/ Nova Empresa',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amberAccent),
                    ),
                    child: Column(
                      children: [
                        const Text('CHAVE DE ACESSO GERADA:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 4),
                        SelectableText(
                          chaveGerada,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Escolha o Plano:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corCianoEletrico)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['MENSAL', 'TRIMESTRAL', 'SEMESTRAL', 'ANUAL'].map((p) {
                      final sel = planoSelecionado == p;
                      return ChoiceChip(
                        label: Text(p, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.black : Colors.white)),
                        selected: sel,
                        selectedColor: corCianoEletrico,
                        onSelected: (_) => setD(() => planoSelecionado = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Empresa / Cliente (Opcional)',
                      hintText: 'O cliente preencherá no cadastro',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: whatsCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp do Cliente (p/ enviar a chave)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: Colors.amberAccent,
                    title: const Text('Aguardar meu comando p/ liberar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Ele cadastra com a chave e você clica em Liberar Acesso', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                    value: aguardarCadastroParaLiberar,
                    onChanged: (v) => setD(() => aguardarCadastroParaLiberar = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('CRIAR E ENVIAR CHAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final dias = ServicoLicencaBugs.diasDoPlano(planoSelecionado);
                  final nome = nomeCtrl.text.trim().isEmpty ? 'Aguardando Cadastro ($chaveGerada)' : nomeCtrl.text.trim();
                  final whats = whatsCtrl.text.trim();

                  try {
                    await supabase.from('empresas').insert({
                      'nome': nome,
                      'whatsapp': whats,
                      'telefone': whats,
                      'chave_licenca': chaveGerada,
                      'status': aguardarCadastroParaLiberar ? 'pendente' : 'ativo',
                      'validade': DateTime.now().add(Duration(days: dias)).toUtc().toIso8601String(),
                    });

                    await Clipboard.setData(ClipboardData(text: chaveGerada));
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (whats.isNotEmpty) {
                      final msg = "Olá! Aqui está sua Chave de Acesso oficial ao sistema *O.S. Prime*:\n\n🔑 Chave: *$chaveGerada*\n📅 Plano: *$planoSelecionado*\n\nBasta abrir o aplicativo, tocar em *Cadastrar Empresa com Chave* e informar esse código!";
                      _abrirWhatsAdmin(whats, msg);
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green,
                          content: Text('📋 Chave $chaveGerada criada e copiada!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.redAccent, content: Text('Erro ao criar chave: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _abaEmpresas() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _empresasStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: corCianoEletrico));
        }
        final empresas = snapshot.data!;

        int ativas = 0;
        int pendentes = 0;
        int bloqueadas = 0;

        for (final e in empresas) {
          final st = (e['status'] ?? 'ativo').toString().toLowerCase();
          final val = e['validade'] != null ? DateTime.tryParse(e['validade'].toString()) : null;
          final exp = val != null && DateTime.now().isAfter(val);
          if (st == 'pendente' || st == 'aguardando_cadastro') {
            pendentes++;
          } else if (st == 'bloqueado' || st == 'suspenso' || exp) {
            bloqueadas++;
          } else {
            ativas++;
          }
        }

        return Column(
          children: [
            // RESUMO SUPERIOR
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  _cardMetrica('ATIVAS', '$ativas', Colors.greenAccent),
                  const SizedBox(width: 8),
                  _cardMetrica('PENDENTES', '$pendentes', Colors.amberAccent),
                  const SizedBox(width: 8),
                  _cardMetrica('SUSPENSAS/VENC.', '$bloqueadas', Colors.redAccent),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text('GERAR NOVA CHAVE DE ACESSO P/ CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  onPressed: _modalGerarNovaChave,
                ),
              ),
            ),

            Expanded(
              child: empresas.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma empresa cadastrada ainda.\nClique acima para gerar uma Chave de Acesso!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: empresas.length,
                      itemBuilder: (context, i) {
                        final emp = empresas[i];
                        final nome = (emp['nome'] ?? 'Sem Nome').toString();
                        final cnpj = (emp['cnpj_cpf'] ?? 'Sem CNPJ').toString();
                        final whats = (emp['whatsapp'] ?? emp['telefone'] ?? '').toString();
                        final chave = (emp['chave_licenca'] ?? 'SEM-CHAVE').toString();
                        final status = (emp['status'] ?? 'ativo').toString().toLowerCase();
                        final plano = ServicoLicencaBugs.identificarPlano(chave);

                        DateTime? validade;
                        int? diasRestantes;
                        String validadeFmt = 'Sem data definida';

                        if (emp['validade'] != null) {
                          validade = DateTime.tryParse(emp['validade'].toString())?.toLocal();
                          if (validade != null) {
                            final hoje = DateTime.now();
                            diasRestantes = validade.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
                            validadeFmt = DateFormat('dd/MM/yyyy').format(validade);
                          }
                        }

                        final bool expirado = validade != null && DateTime.now().isAfter(validade);
                        final bool isPendente = status == 'pendente' || status == 'aguardando_cadastro';
                        final bool isBloqueado = status == 'bloqueado' || status == 'suspenso' || expirado;

                        Color corStatus = Colors.greenAccent;
                        String textoStatus = 'ATIVO ($plano)';
                        if (isPendente) {
                          corStatus = Colors.amberAccent;
                          textoStatus = 'AGUARDANDO SUA LIBERAÇÃO';
                        } else if (isBloqueado) {
                          corStatus = Colors.redAccent;
                          textoStatus = expirado ? 'VENCIDO ($plano)' : 'SUSPENSO / BLOQUEADO';
                        } else if (diasRestantes != null && diasRestantes <= 5) {
                          corStatus = Colors.orangeAccent;
                          textoStatus = 'VENCENDO EM $diasRestantes DIA(S)';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121A28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: corStatus.withOpacity(0.75), width: isPendente ? 2 : 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isPendente
                                        ? Icons.new_releases_rounded
                                        : (isBloqueado ? Icons.lock_rounded : Icons.verified_rounded),
                                    color: corStatus,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nome,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: corStatus.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: corStatus),
                                    ),
                                    child: Text(
                                      textoStatus,
                                      style: TextStyle(color: corStatus, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'CNPJ/CPF: $cnpj  •  Whats: ${whats.isEmpty ? "Não informado" : whats}',
                                style: const TextStyle(color: Colors.grey, fontSize: 11.5),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '🔑 Chave: $chave',
                                      style: const TextStyle(color: corCianoEletrico, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: chave));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('📋 Chave copiada!'), backgroundColor: Colors.green),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.copy, size: 15, color: corCianoSuave),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                diasRestantes != null
                                    ? '📅 Vencimento: $validadeFmt (${diasRestantes >= 0 ? "Faltam $diasRestantes dias" : "Venceu há ${diasRestantes.abs()} dias"})'
                                    : '📅 Vencimento: $validadeFmt',
                                style: TextStyle(
                                  color: (diasRestantes != null && diasRestantes <= 5) ? Colors.amberAccent : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Divider(color: Colors.white12, height: 18),
                              const Text(
                                'ATIVAR / RENOVAR PLANO COM 1 TOQUE:',
                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _botaoPlanoRapido(emp, 'MENSAL', '+30d', 30, corCianoEletrico),
                                  const SizedBox(width: 6),
                                  _botaoPlanoRapido(emp, 'TRIMESTRAL', '+90d', 90, Colors.blueAccent),
                                  const SizedBox(width: 6),
                                  _botaoPlanoRapido(emp, 'SEMESTRAL', '+180d', 180, Colors.purpleAccent),
                                  const SizedBox(width: 6),
                                  _botaoPlanoRapido(emp, 'ANUAL', '+365d', 365, Colors.amberAccent),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (isPendente || isBloqueado)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.check_circle, size: 16),
                                        label: const Text('LIBERAR ACESSO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        onPressed: () => _alternarStatusEmpresa(emp, 'ativo'),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.block, size: 16),
                                        label: const Text('SUSPENDER USO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        onPressed: () => _alternarStatusEmpresa(emp, 'bloqueado'),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  if (whats.isNotEmpty)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: corVerdeWhats,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.chat_bubble_outline, size: 15),
                                      label: const Text('WhatsApp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        final msg = isPendente || !isBloqueado
                                            ? "Olá *$nome*! Seu acesso ao sistema *O.S. Prime* (Plano $plano) está LIBERADO!\n🔑 Chave: *$chave*\n📅 Vencimento: *$validadeFmt*"
                                            : "Olá *$nome*! Notamos que a licença do sistema *O.S. Prime* venceu em *$validadeFmt*. Como deseja renovar seu plano (Mensal, Trimestral, Semestral ou Anual)?";
                                        _abrirWhatsAdmin(whats, msg);
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                    tooltip: 'Excluir Registro',
                                    onPressed: () async {
                                      await supabase.from('empresas').delete().eq('id', emp['id']);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _botaoPlanoRapido(Map<String, dynamic> emp, String plano, String sub, int dias, Color cor) {
    return Expanded(
      child: InkWell(
        onTap: () => _aplicarPlanoEmpresa(emp, plano, dias),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              Text(plano, style: TextStyle(color: cor, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardMetrica(String titulo, String valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF121A28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(valor, style: TextStyle(color: cor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 9.5, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _abaBugsErros() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bugsStream,
      builder: (context, snapshot) {
        final todos = snapshot.data ?? [];
        final logs = todos.where((m) => m['remetente'] == '__bug_osprime__').toList();

        if (logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 54),
                SizedBox(height: 10),
                Text('Nenhum erro ou bug registrado nos aplicativos!', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${logs.length} Alerta(s) / Log(s)', style: const TextStyle(color: corCianoEletrico, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                    label: const Text('Limpar Todos', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    onPressed: () async {
                      final ids = logs.map((e) => e['id']).toList();
                      await supabase.from('mensagens_chat').delete().inFilter('id', ids);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, i) {
                  final item = logs[i];
                  Map<String, dynamic> dados = {};
                  try {
                    dados = jsonDecode(item['texto'] ?? '{}');
                  } catch (_) {
                    dados = {'erro': item['texto'] ?? ''};
                  }

                  final empresa = (dados['empresa'] ?? 'Empresa').toString();
                  final usuario = (dados['usuario'] ?? '-').toString();
                  final cargo = (dados['cargo'] ?? '-').toString();
                  final tipo = (dados['tipo'] ?? 'ERRO').toString();
                  final erro = (dados['erro'] ?? '').toString();
                  final detalhes = (dados['detalhes'] ?? '').toString();
                  final lido = item['visualizado'] == true;

                  String dataHora = '';
                  if (item['created_at'] != null) {
                    try {
                      dataHora = DateFormat('dd/MM HH:mm').format(DateTime.parse(item['created_at']).toLocal());
                    } catch (_) {}
                  }

                  final bool isNovoCadastro = tipo == 'NOVO_CADASTRO';
                  final Color corCard = isNovoCadastro
                      ? Colors.amberAccent
                      : (tipo == 'RELATO_USUARIO' ? Colors.orangeAccent : Colors.redAccent);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121A28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lido ? Colors.white12 : corCard, width: lido ? 1 : 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isNovoCadastro ? Icons.domain_add_rounded : Icons.bug_report_rounded,
                              color: corCard,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$empresa • @$usuario ($cargo)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                            ),
                            Text(dataHora, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          erro,
                          style: TextStyle(color: corCard, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        if (detalhes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detalhes,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!lido)
                              TextButton.icon(
                                icon: const Icon(Icons.done_all, size: 15, color: Colors.greenAccent),
                                label: const Text('Marcar Resolvido', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                onPressed: () async {
                                  await supabase.from('mensagens_chat').update({'visualizado': true}).eq('id', item['id']);
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () async {
                                await supabase.from('mensagens_chat').delete().eq('id', item['id']);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _abaUsuariosMaster() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _usuariosStream,
      builder: (context, snapshot) {
        final usuarios = snapshot.data ?? [];
        if (usuarios.isEmpty) {
          return const Center(child: Text('Nenhum usuário encontrado.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: usuarios.length,
          itemBuilder: (context, i) {
            final u = usuarios[i];
            final nome = (u['nome'] ?? '').toString();
            final login = (u['usuario'] ?? '').toString();
            final senha = (u['senha'] ?? '').toString();
            final cargo = (u['cargo'] ?? 'funcionario').toString().toUpperCase();
            final fone = (u['telefone'] ?? '').toString();
            final isMaster = cargo == 'MASTER';

            return Card(
              color: const Color(0xFF121A28),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isMaster ? Colors.amberAccent.withOpacity(0.6) : Colors.white12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isMaster ? Colors.amberAccent.withOpacity(0.2) : Colors.white10,
                  child: Icon(isMaster ? Icons.workspace_premium : Icons.person, color: isMaster ? Colors.amberAccent : corCianoEletrico),
                ),
                title: Text('$nome ($cargo)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: Text('Login: @$login  •  Senha: $senha\nWhats: ${fone.isEmpty ? "-" : fone}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                isThreeLine: true,
                trailing: fone.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: corVerdeWhats),
                        onPressed: () => _abrirWhatsAdmin(fone, "Olá *$nome*! Seus dados de acesso ao O.S. Prime:\n👤 Usuário: *@$login*\n🔑 Senha: *$senha*"),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121A28),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.amberAccent, size: 22),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O.S. PRIME • GERENCIADOR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                Text('Controle de Empresas, Planos & Bugs', style: TextStyle(fontSize: 10.5, color: corCianoSuave)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Sair',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('super_admin_logado', false);
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginSuperAdminPage()));
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _abaAtual,
        children: [
          _abaEmpresas(),
          _abaBugsErros(),
          _abaUsuariosMaster(),
        ],
      ),
      bottomNavigationBar: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bugsStream,
        builder: (context, snap) {
          final naoLidos = (snap.data ?? []).where((m) => m['remetente'] == '__bug_osprime__' && m['visualizado'] != true).length;

          return BottomNavigationBar(
            currentIndex: _abaAtual,
            backgroundColor: const Color(0xFF121A28),
            selectedItemColor: Colors.amberAccent,
            unselectedItemColor: Colors.grey,
            onTap: (i) => setState(() => _abaAtual = i),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.business_rounded),
                label: 'Empresas & Planos',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.bug_report_rounded),
                    if (naoLidos > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                          child: Text('$naoLidos', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                label: 'Erros & Cadastros',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.supervisor_account_rounded),
                label: 'Usuários & Senhas',
              ),
            ],
          );
        },
      ),
    );
  }
}