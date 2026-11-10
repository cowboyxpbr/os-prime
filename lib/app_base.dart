// ============================================================================
// ARQUIVO BASE, MODELOS, CACHE OFFLINE, CORES, ONESIGNAL E ENGINE PDF
// lib/app_base.dart (VERSÃO COMPLETA E UNIFICADA: O.S. Prime)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONFIGURAÇÕES SUPABASE OFICIAIS (O.S. Prime)
// ============================================================================
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://rpcptrpczzdrrbquabnh.supabase.co',
);
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_cXRSmhxE7YGoCdK0WMonRg_MB2a5zAp',
);

SupabaseClient get supabase => Supabase.instance.client;

// ============================================================================
// PALETA DE CORES GLOBAL DO APLICATIVO (TODAS COM CONST)
// ============================================================================
const Color corFundoApp = Color(0xFF0B111E);
const Color corCardFundo = Color(0xFF162332);
const Color corCianoEletrico = Color(0xFF00D4FF);
const Color corCianoSuave = Color(0xFF70E1FF);
const Color corVerdeWhats = Color(0xFF25D366);
const Color corTextoClaro = Color(0xFFF1F5F9);
const Color corAmareloSuave = Color(0xFFFFD166);
const Color corLaranjaAlerta = Color(0xFFF77F00);
const Color corRoxoNotas = Color(0xFF9D4EDD);

// ============================================================================
// MODELOS DE DADOS DO SISTEMA
// ============================================================================

class UsuarioApp {
  String? id;
  String nome;
  String usuario;
  String senha;
  String cargo;
  String? telefone;
  String? foto;
  bool primeiroAcesso;
  String perguntaSecreta;
  String respostaSecreta;

  UsuarioApp({
    this.id,
    required this.nome,
    required this.usuario,
    required this.senha,
    required this.cargo,
    this.telefone,
    this.foto,
    this.primeiroAcesso = false,
    this.perguntaSecreta = '',
    this.respostaSecreta = '',
  });

  bool get isMaster => cargo.toLowerCase() == 'master';
  bool get isSenior => cargo.toLowerCase() == 'senior' || cargo.toLowerCase() == 'sênior';
  bool get isAdmin => isMaster || isSenior;
  bool get temAcessoAdmin => isMaster || isSenior;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> dados = {
      'nome': nome.trim(),
      'usuario': usuario.toLowerCase().trim(),
      'senha': senha.trim(),
      'cargo': cargo.toLowerCase().trim(),
    };

    if (id != null && id!.isNotEmpty) dados['id'] = id;
    if (telefone != null && telefone!.trim().isNotEmpty) {
      dados['telefone'] = telefone!.trim();
    }
    if (foto != null && foto!.trim().isNotEmpty) {
      dados['foto'] = foto!.trim();
    }
    if (perguntaSecreta.trim().isNotEmpty) {
      dados['pergunta_secreta'] = perguntaSecreta.trim();
    }
    if (respostaSecreta.trim().isNotEmpty) {
      dados['resposta_secreta'] = respostaSecreta.toLowerCase().trim();
    }

    return dados;
  }

  factory UsuarioApp.fromMap(Map<String, dynamic> m) {
    return UsuarioApp(
      id: m['id']?.toString(),
      nome: m['nome'] ?? '',
      usuario: (m['usuario'] ?? '').toString().toLowerCase().trim(),
      senha: (m['senha'] ?? '').toString().trim(),
      cargo: (m['cargo'] ?? 'funcionario').toString().toLowerCase().trim(),
      telefone: m['telefone']?.toString(),
      foto: m['foto']?.toString(),
      primeiroAcesso: m['primeiro_acesso'] == true,
      perguntaSecreta: (m['pergunta_secreta'] ?? '').toString(),
      respostaSecreta: (m['resposta_secreta'] ?? '').toString().toLowerCase().trim(),
    );
  }
}

class DadosCliente {
  String? id;
  String nome;
  String responsavel;
  String telefone;
  String documento;
  String email;
  String endereco;
  String bairro;
  String cidade;
  String complemento;

  DadosCliente({
    this.id,
    required this.nome,
    this.responsavel = '',
    this.telefone = '',
    this.documento = '',
    this.email = '',
    this.endereco = '',
    this.bairro = '',
    this.cidade = '',
    this.complemento = '',
  });

  String get enderecoCompleto {
    final partes = [endereco, bairro, cidade, complemento].where((p) => p.trim().isNotEmpty);
    return partes.join(', ');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'responsavel': responsavel,
      'telefone': telefone,
      'documento': documento,
      'cpf_cnpj': documento,
      'email': email,
      'endereco': endereco,
      'bairro': bairro,
      'cidade': cidade,
      'complemento': complemento,
    };
  }

  factory DadosCliente.fromMap(Map<String, dynamic> m) {
    return DadosCliente(
      id: m['id']?.toString(),
      nome: m['nome'] ?? '',
      responsavel: m['responsavel'] ?? '',
      telefone: (m['telefone'] ?? m['fone'] ?? '').toString(),
      documento: (m['documento'] ?? m['cpf_cnpj'] ?? m['cnpj'] ?? '').toString(),
      email: m['email'] ?? '',
      endereco: m['endereco'] ?? '',
      bairro: m['bairro'] ?? '',
      cidade: m['cidade'] ?? '',
      complemento: m['complemento'] ?? '',
    );
  }
}

class ItemServico {
  String descricao;
  double quantidade;
  double valorUnitario;

  ItemServico({
    required this.descricao,
    required this.quantidade,
    required this.valorUnitario,
  });

  double get subtotal => quantidade * valorUnitario;

  Map<String, dynamic> toMap() => {
    'descricao': descricao,
    'quantidade': quantidade,
    'valorUnitario': valorUnitario,
  };

  factory ItemServico.fromMap(Map<String, dynamic> m) => ItemServico(
    descricao: m['descricao'] ?? '',
    quantidade: (m['quantidade'] as num?)?.toDouble() ?? 1.0,
    valorUnitario: (m['valorUnitario'] as num?)?.toDouble() ?? 0.0,
  );
}

class EquipamentoRelatorio {
  String tipo;
  String marca;
  String modelo;
  String potencia;
  String tensao;

  EquipamentoRelatorio({
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.potencia,
    required this.tensao,
  });

  Map<String, dynamic> toMap() => {
    'tipo': tipo,
    'marca': marca,
    'modelo': modelo,
    'potencia': potencia,
    'tensao': tensao,
  };

  factory EquipamentoRelatorio.fromMap(Map<String, dynamic> m) => EquipamentoRelatorio(
    tipo: m['tipo'] ?? '',
    marca: m['marca'] ?? '-',
    modelo: m['modelo'] ?? '-',
    potencia: m['potencia'] ?? '-',
    tensao: m['tensao'] ?? '-',
  );
}

class FotoRelatorio {
  String caminhoArquivo;
  String legenda;

  FotoRelatorio({required this.caminhoArquivo, required this.legenda});

  Map<String, dynamic> toMap() => {
    'caminhoArquivo': caminhoArquivo,
    'legenda': legenda,
  };

  factory FotoRelatorio.fromMap(Map<String, dynamic> m) => FotoRelatorio(
    caminhoArquivo: m['caminhoArquivo'] ?? '',
    legenda: m['legenda'] ?? '',
  );
}

class RelatorioCondominioModel {
  String? id;
  String nomeCondominio;
  String sindicoResponsavel;
  String telefone;
  String cnpjCpf;
  String enderecoCompleto;
  String tipoDocumento;
  String tituloLaudo;
  String dataEmissao;
  String tecnico;
  List<EquipamentoRelatorio> equipamentos;
  String diagnosticoTecnico;
  String recomendacoesServicos;
  List<FotoRelatorio> fotos;

  RelatorioCondominioModel({
    this.id,
    required this.nomeCondominio,
    required this.sindicoResponsavel,
    required this.telefone,
    this.cnpjCpf = '',
    required this.enderecoCompleto,
    required this.tipoDocumento,
    required this.tituloLaudo,
    required this.dataEmissao,
    String? tecnico,
    String? tecnicoResponsavel,
    required this.equipamentos,
    required this.diagnosticoTecnico,
    required this.recomendacoesServicos,
    required this.fotos,
  }) : tecnico = tecnico ?? tecnicoResponsavel ?? '';

  String get tecnicoResponsavel => tecnico;
  set tecnicoResponsavel(String v) => tecnico = v;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'nomeCondominio': nomeCondominio,
    'sindicoResponsavel': sindicoResponsavel,
    'telefone': telefone,
    'cnpjCpf': cnpjCpf,
    'enderecoCompleto': enderecoCompleto,
    'tipoDocumento': tipoDocumento,
    'tituloLaudo': tituloLaudo,
    'dataEmissao': dataEmissao,
    'tecnico': tecnico,
    'equipamentos': equipamentos.map((e) => e.toMap()).toList(),
    'diagnosticoTecnico': diagnosticoTecnico,
    'recomendacoesServicos': recomendacoesServicos,
    'fotos': fotos.map((f) => f.toMap()).toList(),
  };

  factory RelatorioCondominioModel.fromMap(Map<String, dynamic> m) => RelatorioCondominioModel(
    id: m['id']?.toString(),
    nomeCondominio: m['nomeCondominio'] ?? '',
    sindicoResponsavel: m['sindicoResponsavel'] ?? '',
    telefone: m['telefone'] ?? '',
    cnpjCpf: (m['cnpjCpf'] ?? m['cnpj'] ?? m['cpf_cnpj'] ?? '').toString(),
    enderecoCompleto: m['enderecoCompleto'] ?? '',
    tipoDocumento: m['tipoDocumento'] ?? 'RELATÓRIO TÉCNICO DE CAMPO',
    tituloLaudo: m['tituloLaudo'] ?? 'LAUDO TÉCNICO',
    dataEmissao: m['dataEmissao'] ?? '',
    tecnico: (m['tecnico'] ?? m['tecnicoResponsavel'] ?? '').toString(),
    equipamentos: (m['equipamentos'] as List? ?? []).map((e) => EquipamentoRelatorio.fromMap(Map<String, dynamic>.from(e))).toList(),
    diagnosticoTecnico: m['diagnosticoTecnico'] ?? '',
    recomendacoesServicos: m['recomendacoesServicos'] ?? '',
    fotos: (m['fotos'] as List? ?? []).map((f) => FotoRelatorio.fromMap(Map<String, dynamic>.from(f))).toList(),
  );
}

class NotaApp {
  String id;
  String titulo;
  String conteudo;
  String dataHora;

  NotaApp({
    required this.id,
    required this.titulo,
    required this.conteudo,
    required this.dataHora,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'conteudo': conteudo,
    'dataHora': dataHora,
  };

  factory NotaApp.fromMap(Map<String, dynamic> m) => NotaApp(
    id: m['id'] ?? '',
    titulo: m['titulo'] ?? '',
    conteudo: m['conteudo'] ?? '',
    dataHora: m['dataHora'] ?? '',
  );
}

// ============================================================================
// CACHE OFFLINE E PERSISTÊNCIA LOCAL
// ============================================================================
class CacheOffline {
  static const _kSessao = 'eh_sessao_ativa';
  static const _kUsuarios = 'eh_usuarios_locais';
  static const _kClientes = 'eh_clientes_locais';
  static const _kNotas = 'eh_notas_locais';
  static const _kFilaServicos = 'eh_fila_servicos_offline';
  static const _kSeguranca = 'eh_seguranca_gestao_master';
  static const _kRelatoriosCondominio = 'eh_relatorios_condominio';

  static Future<void> salvarSessao(UsuarioApp u, bool manterLogado) async {
    final prefs = await SharedPreferences.getInstance();
    if (manterLogado) {
      await prefs.setString(_kSessao, jsonEncode(u.toMap()));
    } else {
      await prefs.remove(_kSessao);
    }
  }

  static Future<UsuarioApp?> obterSessaoAtiva() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kSessao);
    if (s == null || s.isEmpty) return null;
    try {
      return UsuarioApp.fromMap(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  static Future<void> encerrarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessao);
  }

  static Future<List<UsuarioApp>> carregarUsuariosLocais() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kUsuarios);
    if (str == null || str.isEmpty) return [];
    try {
      final List dec = jsonDecode(str);
      return dec.map((e) => UsuarioApp.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarUsuarioLocal(UsuarioApp u, {String? usuarioAntigo}) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await carregarUsuariosLocais();
    lista.removeWhere((item) =>
        item.usuario.trim().toLowerCase() == u.usuario.trim().toLowerCase() ||
        (usuarioAntigo != null && item.usuario.trim().toLowerCase() == usuarioAntigo.trim().toLowerCase()));
    lista.add(u);
    await prefs.setString(_kUsuarios, jsonEncode(lista.map((x) => x.toMap()).toList()));
  }

  static Future<void> excluirUsuarioLocal(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await carregarUsuariosLocais();
    lista.removeWhere((u) => u.usuario.trim().toLowerCase() == usuario.trim().toLowerCase());
    await prefs.setString(_kUsuarios, jsonEncode(lista.map((x) => x.toMap()).toList()));
  }

  static Future<List<DadosCliente>> carregarClientesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kClientes);
    if (str == null || str.isEmpty) return [];
    try {
      final List dec = jsonDecode(str);
      return dec.map((e) => DadosCliente.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarClientesLocal(List<DadosCliente> clientes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClientes, jsonEncode(clientes.map((c) => c.toMap()).toList()));
  }

  static Future<List<NotaApp>> carregarNotasLocal({String? usuarioKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = usuarioKey != null ? '${_kNotas}_$usuarioKey' : _kNotas;
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return [];
    try {
      final List dec = jsonDecode(str);
      return dec.map((e) => NotaApp.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarNotasLocal(List<NotaApp> notas, {String? usuarioKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = usuarioKey != null ? '${_kNotas}_$usuarioKey' : _kNotas;
    await prefs.setString(key, jsonEncode(notas.map((n) => n.toMap()).toList()));
  }

  static Future<List<Map<String, dynamic>>> obterFilaServicosOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kFilaServicos);
    if (str == null || str.isEmpty) return [];
    try {
      final List dec = jsonDecode(str);
      return dec.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarServicoFilaOffline(Map<String, dynamic> dados) async {
    final prefs = await SharedPreferences.getInstance();
    final fila = await obterFilaServicosOffline();
    fila.add(dados);
    await prefs.setString(_kFilaServicos, jsonEncode(fila));
  }

  static Future<int> sincronizarFilaComNuvem() async {
    final fila = await obterFilaServicosOffline();
    if (fila.isEmpty) return 0;
    int sucessos = 0;
    final List<Map<String, dynamic>> restantes = [];

    for (var s in fila) {
      try {
        await supabase.from('servicos').insert(s).timeout(const Duration(seconds: 6));
        sucessos++;
      } catch (_) {
        restantes.add(s);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFilaServicos, jsonEncode(restantes));
    return sucessos;
  }

  static Future<Map<String, String>?> obterSegurancaGestao() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kSeguranca);
    if (str == null || str.isEmpty) return null;
    try {
      final Map dec = jsonDecode(str);
      return Map<String, String>.from(dec);
    } catch (_) {
      return null;
    }
  }

  static Future<void> salvarSegurancaGestao(String senha, String pergunta, String resposta) async {
    final prefs = await SharedPreferences.getInstance();
    final m = {'senha': senha, 'pergunta': pergunta, 'resposta': resposta.toLowerCase().trim()};
    await prefs.setString(_kSeguranca, jsonEncode(m));
  }

  static Future<List<RelatorioCondominioModel>> carregarRelatoriosCondominioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kRelatoriosCondominio);
    if (str == null || str.isEmpty) return [];
    try {
      final List dec = jsonDecode(str);
      return dec.map((e) => RelatorioCondominioModel.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvarRelatoriosCondominioLocal(List<RelatorioCondominioModel> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRelatoriosCondominio, jsonEncode(lista.map((r) => r.toMap()).toList()));
  }
}

// ============================================================================
// SERVIÇOS AUXILIARES: CLIENTES HÍBRIDOS (NUVEM + CACHE LOCAL OFFLINE)
// ============================================================================
class ServicoClientes {
  // 🔄 CARREGA DO SUPABASE E ATUALIZA A MEMÓRIA AUTOMATICAMENTE
  static Future<List<DadosCliente>> carregarClientes() async {
    final locais = await CacheOffline.carregarClientesLocal();

    try {
      final res = await supabase
          .from('clientes')
          .select()
          .order('nome')
          .timeout(const Duration(seconds: 6));

      if (res.isNotEmpty) {
        final nuvem = res.map((m) => DadosCliente.fromMap(m)).toList();

        // Mescla nuvem com locais sem duplicar
        final Map<String, DadosCliente> mapa = {};
        for (var c in nuvem) {
          final chave = (c.id != null && c.id!.isNotEmpty) ? c.id! : c.nome.toLowerCase().trim();
          mapa[chave] = c;
        }
        for (var c in locais) {
          final chave = (c.id != null && c.id!.isNotEmpty) ? c.id! : c.nome.toLowerCase().trim();
          mapa.putIfAbsent(chave, () => c);
        }

        final listaFinal = mapa.values.toList();
        listaFinal.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        // Salva na memória do celular para funcionar offline
        await CacheOffline.salvarClientesLocal(listaFinal);
        return listaFinal;
      }
    } catch (_) {}

    return locais;
  }
}

// ============================================================================
// SERVIÇOS AUXILIARES E NOTIFICAÇÕES ONESIGNAL COM SOM, ÍCONE E CATEGORIAS
// ============================================================================
class ServicoNotificacaoOneSignal {
  // 🔔 ID OFICIAL (4708) E CHAVE REST ATIVA
  static const String _appId = '04552b74-f865-437f-94b6-4b07dc65d901';
  static const String _restApiKey =
      'os_v2_app_arksw5hymvbx7ffwjmd5yzozafjznbggzvjezlf6nbkk326xqwn7z5pe4zyhqpt7cw2ddk3oxcm6zjfdp6e73kzhwrurudj6ywzwomi';

  static Future<void> _dispararREST({
    required List<String> logins,
    required String titulo,
    required String mensagem,
    Map<String, dynamic>? dados,
  }) async {
    final destinos = logins
        .map((l) => l.trim().toLowerCase().replaceAll('@', ''))
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();

    if (destinos.isEmpty) return;

    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('https://api.onesignal.com/notifications'));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Key $_restApiKey');

      final payload = {
        'app_id': _appId,
        'target_channel': 'push',
        'include_aliases': {'external_id': destinos},
        'headings': {'pt': titulo, 'en': titulo},
        'contents': {'pt': mensagem, 'en': mensagem},
        'small_icon': 'ic_launcher',
        'large_icon': 'ic_launcher',
        'android_accent_color': 'FF00D4FF',
        'priority': 10,
        'android_visibility': 1,
        'android_sound': 'default',
        'ios_sound': 'default',
        'ios_badgeType': 'Increase',
        'ios_badgeCount': 1,
        if (dados != null) 'data': dados,
      };

      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint("🔔 Push OneSignal (${response.statusCode}): $responseBody");
      client.close();
    } catch (e) {
      debugPrint("❌ Erro ao enviar notificação OneSignal: $e");
    }
  }

  // 1. NOTIFICAÇÃO DE CHAT COM ÍCONE DO APP
  static Future<void> enviarNotificacaoChat({
    required String destinatarioLogin,
    required String remetenteNome,
    required String texto,
  }) async {
    await _dispararREST(
      logins: [destinatarioLogin],
      titulo: '💬 $remetenteNome (O.S. Prime)',
      mensagem: texto,
      dados: {'tipo': 'chat', 'remetente': remetenteNome},
    );
  }

  // 2. RECEBIMENTO DE O.S. COM IDENTIFICAÇÃO E CATEGORIA
  static Future<void> enviarNotificacaoOS({
    required String tecnicoLogin,
    required String numeroOS,
    required String cliente,
    String categoria = 'Padrão',
  }) async {
    String emoji = '📋';
    final catLimpa = categoria.trim();
    final catLower = catLimpa.toLowerCase();

    if (catLower.contains('emerg')) {
      emoji = '🚨';
    } else if (catLower.contains('urg')) {
      emoji = '⚡';
    } else if (catLower.contains('plant')) {
      emoji = '🌙';
    }

    final titulo = '$emoji O.S. Recebida ($numeroOS) • ${catLimpa.toUpperCase()}';
    final mensagem = 'Cliente: $cliente\nPrioridade: $catLimpa. Toque para abrir os detalhes.';

    await _dispararREST(
      logins: [tecnicoLogin],
      titulo: titulo,
      mensagem: mensagem,
      dados: {
        'tipo': 'ordem_servico',
        'os_id': numeroOS,
        'categoria': catLimpa,
      },
    );
  }

  // 3. DEVOLUTIVA DE O.S. FINALIZADA: AVISO "O.S. LIBERADA PARA FATURAMENTO"
  static Future<void> enviarNotificacaoDevolutivaOS({
    required String numeroOS,
    required String cliente,
    required String tecnicoNome,
  }) async {
    try {
      final res = await supabase
          .from('usuarios')
          .select('usuario, cargo')
          .or('cargo.ilike.master,cargo.ilike.senior,usuario.ilike.admin');

      final List<String> gestores = [];
      for (var u in res) {
        final login = (u['usuario'] ?? '').toString().trim().toLowerCase().replaceAll('@', '');
        if (login.isNotEmpty) gestores.add(login);
      }

      if (gestores.isNotEmpty) {
        await _dispararREST(
          logins: gestores,
          titulo: '💰 O.S. Liberada para Faturamento ($numeroOS)',
          mensagem: '$tecnicoNome finalizou a O.S. de $cliente. Pronta para precificação e faturamento!',
          dados: {
            'tipo': 'devolutiva_os',
            'os_id': numeroOS,
            'status_tela': 'O.S. liberada para faturamento',
          },
        );
      }
    } catch (_) {}
  }

  // 4. DISPARO GERAL DE PUSH
  static Future<void> enviarPush({
    required String destinatarioLogin,
    required String titulo,
    required String mensagem,
    Map<String, dynamic>? dados,
  }) async {
    await _dispararREST(
      logins: [destinatarioLogin],
      titulo: titulo,
      mensagem: mensagem,
      dados: dados,
    );
  }
}

// ============================================================================
// WIDGETS VISUAIS GLOBAIS: BANNER COMPLETO 100% LARGURA COM cabecalho.png
// ============================================================================
class BannerOSPrime extends StatelessWidget {
  final String subtituloTela;
  final bool exibirBotaoVoltar;
  final Widget? acaoDireita;

  const BannerOSPrime({
    super.key,
    required this.subtituloTela,
    this.exibirBotaoVoltar = false,
    this.acaoDireita,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF071426),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              child: Image.asset(
                'assets/cabecalho.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'cabecalho.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 65,
                    color: const Color(0xFF071E3D),
                    alignment: Alignment.center,
                    child: const Text(
                      'O.S. PRIME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                color: Color(0xFF071426),
                border: Border(bottom: BorderSide(color: Color(0x3300D4FF), width: 1.2)),
              ),
              child: Row(
                children: [
                  if (exibirBotaoVoltar) ...[
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F354A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: corCianoEletrico.withOpacity(0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new, color: corCianoEletrico, size: 12),
                            SizedBox(width: 4),
                            Text('Voltar', style: TextStyle(color: corCianoEletrico, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (subtituloTela.trim().isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x1F00D4FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: corCianoEletrico.withOpacity(0.55), width: 1.2),
                        ),
                        child: Text(
                          subtituloTela.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: corCianoSuave,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  if (acaoDireita != null) ...[
                    const SizedBox(width: 8),
                    acaoDireita!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FundoComArteApp extends StatelessWidget {
  final Widget child;
  const FundoComArteApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: corFundoApp,
      child: child,
    );
  }
}

// ============================================================================
// ÍCONE OFICIAL DO WHATSAPP (BALÃO VERDE + TELEFONE BRANCO INCLINADO)
// ============================================================================
class IconeWhatsAppOficial extends StatelessWidget {
  final double size;
  const IconeWhatsAppOficial({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _WhatsAppLogoPainter(),
          ),
          Transform.rotate(
            angle: -0.18,
            child: Icon(
              Icons.phone,
              color: Colors.white,
              size: size * 0.52,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final r = w / 2;

    final pathCircle = Path()
      ..addOval(Rect.fromCircle(center: Offset(r, r), radius: r * 0.92));

    final pathTail = Path()
      ..moveTo(w * 0.24, h * 0.74)
      ..lineTo(w * 0.04, h * 0.95)
      ..lineTo(w * 0.38, h * 0.88)
      ..close();

    final combined = Path.combine(PathOperation.union, pathCircle, pathTail);
    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// MOTOR DE GERAÇÃO E COMPARTILHAMENTO DE PDF (VERSÃO OFICIAL: O.S. Prime)
// ============================================================================
class PdfEngine {
  static const PdfColor _corAzulMarinho = PdfColor.fromInt(0xFF071E3D);
  static const PdfColor _corCiano = PdfColor.fromInt(0xFF00A8CC);
  static const PdfColor _corCianoValor = PdfColor.fromInt(0xFF00D4FF);
  static const PdfColor _corLaranja = PdfColor.fromInt(0xFFE67E22);
  static const PdfColor _corTextoCinza = PdfColor.fromInt(0xFF4A5568);
  static const PdfColor _corFundoCinza = PdfColor.fromInt(0xFFF7FAFC);
  static const PdfColor _corBorda = PdfColor.fromInt(0xFFCBD5E1);

  static String _gerarCodigoAutenticidade(String prefixo) {
    final ano = DateTime.now().year;
    final hash = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    return '$prefixo-$ano-$hash';
  }

  static pw.Widget _construirCabecalhoEmpresa() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _corCiano, width: 1.5)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 58,
            height: 48,
            decoration: pw.BoxDecoration(
              color: _corAzulMarinho,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'EH',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'O.S. PRIME',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _corAzulMarinho,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Comandos Elétricos • Motobombas • Saunas • Aquecedores • SPA',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _corCiano,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'CNPJ: 25.454.483/0001-25 | Rua São Pedro, 234 - Perequê, Porto Belo - SC',
                  style: const pw.TextStyle(fontSize: 7.5, color: _corTextoCinza),
                ),
                pw.Text(
                  'Fone: (47) 3050-7931 | Cel/WhatsApp: (47) 98455-3301 (Plantão)',
                  style: const pw.TextStyle(fontSize: 7.5, color: _corTextoCinza),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirAssinaturas({
    required String nomeEmpresaResponsavel,
    required String cargoEmpresa,
    required String nomeCliente,
    required String cargoCliente,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Container(height: 1, width: 180, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text(
                  nomeEmpresaResponsavel.toUpperCase(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  cargoEmpresa,
                  style: const pw.TextStyle(fontSize: 8, color: _corTextoCinza),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 30),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Container(height: 1, width: 180, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text(
                  nomeCliente.toUpperCase(),
                  maxLines: 1,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  cargoCliente,
                  style: const pw.TextStyle(fontSize: 8, color: _corTextoCinza),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<File> apenasGerarPdf({
    dynamic cliente,
    dynamic servico,
    List<ItemServico>? itens,
    String? tipoDoc,
    String? destaque,
    String? obs,
    String? laudoDescritivo,
    List<EquipamentoRelatorio>? equipamentos,
    List<FotoRelatorio>? fotos,
    String? observacoes,
    double? valorTotal,
    String? tecnico,
    dynamic dados,
  }) async {
    final pdf = pw.Document();
    final tipoDocumento = (tipoDoc ?? 'ORÇAMENTO').toUpperCase();
    final codigoAutenticidade = _gerarCodigoAutenticidade('EH');
    final dataEmissaoFormatada = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String nomeCli = '';
    String foneCli = '';
    String enderecoCli = '';
    String docCli = '';

    if (cliente is DadosCliente) {
      nomeCli = cliente.nome;
      foneCli = cliente.telefone;
      enderecoCli = cliente.enderecoCompleto;
      docCli = cliente.documento;
    } else if (cliente is Map) {
      nomeCli = cliente['nome'] ?? '';
      foneCli = cliente['telefone'] ?? '';
      enderecoCli = cliente['endereco'] ?? '';
      docCli = cliente['documento'] ?? cliente['cpf_cnpj'] ?? cliente['cnpj'] ?? '';
    }

    double totalCalculado = valorTotal ?? 0.0;
    if (totalCalculado == 0 && itens != null && itens.isNotEmpty) {
      totalCalculado = itens.fold(0.0, (acc, item) => acc + item.subtotal);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _construirCabecalhoEmpresa(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _corLaranja, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(16),
                    ),
                    child: pw.Text(
                      tipoDocumento,
                      style: pw.TextStyle(
                        color: _corLaranja,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'EMISSÃO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.TextSpan(text: dataEmissaoFormatada, style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'AUTENTICIDADE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.TextSpan(text: codigoAutenticidade, style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _corBorda),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'CLIENTE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                                pw.TextSpan(text: nomeCli.toUpperCase(), style: const pw.TextStyle(fontSize: 8.5)),
                              ],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'CPF/CNPJ: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                                pw.TextSpan(text: docCli, style: const pw.TextStyle(fontSize: 8.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'ENDEREÇO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                                pw.TextSpan(text: enderecoCli, style: const pw.TextStyle(fontSize: 8.5)),
                              ],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'FONE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                                pw.TextSpan(text: foneCli, style: const pw.TextStyle(fontSize: 8.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              if (itens != null && itens.isNotEmpty) ...[
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(5.5),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(2.0),
                    3: pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _corAzulMarinho),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                          child: pw.Text('DESCRIÇÃO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                          child: pw.Text('QTD', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                          child: pw.Text('VALOR UNIT.', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                          child: pw.Text('SUBTOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                      ],
                    ),
                    ...itens.map((it) {
                      return pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: _corBorda, width: 0.5)),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Text(it.descricao, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: pw.Text(it.quantidade.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: pw.Text(
                              it.valorUnitario > 0 ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(it.valorUnitario) : '-',
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: pw.Text(
                              it.subtotal > 0 ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(it.subtotal) : '-',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
              if ((obs != null && obs.isNotEmpty) || (observacoes != null && observacoes.isNotEmpty)) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: _corFundoCinza,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Obs/Garantia: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.black)),
                        pw.TextSpan(text: (obs ?? observacoes ?? ''), style: const pw.TextStyle(fontSize: 8, color: _corTextoCinza)),
                      ],
                    ),
                  ),
                ),
              ],
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: _corAzulMarinho,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL GERAL:',
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                    pw.Text(
                      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(totalCalculado),
                      style: pw.TextStyle(color: _corCianoValor, fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              _construirAssinaturas(
                nomeEmpresaResponsavel: 'O.S. PRIME',
                cargoEmpresa: tecnico != null && tecnico.isNotEmpty ? tecnico : 'Técnico Responsável',
                nomeCliente: nomeCli.isNotEmpty ? nomeCli : 'Assinatura do Cliente',
                cargoCliente: 'Assinatura do Cliente / Aceite',
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Assinado digitalmente por O.S. PRIME • Autenticidade: $codigoAutenticidade',
                    style: const pw.TextStyle(fontSize: 7, color: _corTextoCinza),
                  ),
                  pw.Text(
                    fotos != null && fotos.isNotEmpty ? 'Página 1 de 2' : 'Página 1 de 1',
                    style: const pw.TextStyle(fontSize: 7, color: _corTextoCinza),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (fotos != null && fotos.isNotEmpty) {
      final List<pw.Widget> fotosWidgets = [];

      for (var f in fotos) {
        try {
          final arq = File(f.caminhoArquivo);
          if (arq.existsSync()) {
            final bytes = arq.readAsBytesSync();
            final imagemPdf = pw.MemoryImage(bytes);

            fotosWidgets.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    height: 175,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _corBorda),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(imagemPdf, fit: pw.BoxFit.cover),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    f.legenda.isNotEmpty ? f.legenda : 'Registro Fotográfico',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                ],
              ),
            );
          }
        } catch (_) {}
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'O.S. PRIME | LAUDO FOTOGRÁFICO DE CAMPO',
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _corAzulMarinho),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Comprovação técnica de serviços, equipamentos e peças da obra',
                          style: const pw.TextStyle(fontSize: 7.5, color: _corTextoCinza),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _corCiano, width: 1.2),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'CÓDIGO: $codigoAutenticidade',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _corAzulMarinho),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Container(height: 1.5, color: _corCiano),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: fotosWidgets,
                  ),
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Anexo integrante do documento $tipoDocumento • Autenticidade pericial vinculada',
                      style: const pw.TextStyle(fontSize: 7, color: _corTextoCinza),
                    ),
                    pw.Text('Página 2 de 2', style: const pw.TextStyle(fontSize: 7, color: _corTextoCinza)),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${tipoDocumento.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> gerarECompartilhar({
    dynamic cliente,
    dynamic servico,
    List<ItemServico>? itens,
    String? tipoDoc,
    String? destaque,
    String? obs,
    String? laudoDescritivo,
    List<EquipamentoRelatorio>? equipamentos,
    List<FotoRelatorio>? fotos,
    String? observacoes,
    double? valorTotal,
    String? tecnico,
    dynamic dados,
    BuildContext? context,
  }) async {
    final file = await apenasGerarPdf(
      cliente: cliente,
      servico: servico,
      itens: itens,
      tipoDoc: tipoDoc,
      destaque: destaque,
      obs: obs,
      laudoDescritivo: laudoDescritivo,
      equipamentos: equipamentos,
      fotos: fotos,
      observacoes: observacoes,
      valorTotal: valorTotal,
      tecnico: tecnico,
      dados: dados,
    );
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Documento O.S. Prime');
    } catch (_) {}
  }

  static Future<File> gerarPdfRelatorioCompleto(RelatorioCondominioModel r) async {
    final pdf = pw.Document();
    final codigoLaudo = _gerarCodigoAutenticidade('EH-REL');
    final dataEmissaoTexto = r.dataEmissao.isNotEmpty
        ? r.dataEmissao
        : DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now());

    final List<pw.Widget> listaFotosRender = [];
    for (var foto in r.fotos) {
      try {
        final f = File(foto.caminhoArquivo);
        if (f.existsSync()) {
          final imgBytes = f.readAsBytesSync();
          listaFotosRender.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  height: 110,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _corBorda),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  foto.legenda.isNotEmpty ? foto.legenda : 'Registro Fotográfico',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          );
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (pw.Context context) => _construirCabecalhoEmpresa(),
        footer: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Laudo Técnico Oficial O.S. PRIME • Cód: $codigoLaudo',
                style: const pw.TextStyle(fontSize: 7, color: _corTextoCinza),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: _corTextoCinza),
              ),
            ],
          ),
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _corCiano, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Text(
                  r.tipoDocumento.toUpperCase(),
                  style: pw.TextStyle(
                    color: _corCiano,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'EMISSÃO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.TextSpan(text: dataEmissaoTexto, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _corBorda),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'CONDOMÍNIO / LOCAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.TextSpan(text: r.nomeCondominio.toUpperCase(), style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'RESPONSÁVEL / SÍNDICO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.TextSpan(text: r.sindicoResponsavel, style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'FONE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.TextSpan(text: r.telefone, style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'ENDEREÇO: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.TextSpan(text: r.enderecoCompleto, style: const pw.TextStyle(fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
              color: _corAzulMarinho,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              r.tituloLaudo.isNotEmpty ? r.tituloLaudo.toUpperCase() : 'LAUDO TECNICO',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9.5),
            ),
          ),
          pw.SizedBox(height: 6),
          if (r.equipamentos.isNotEmpty) ...[
            pw.Text(
              'EQUIPAMENTOS AVALIADOS / OBJETO DO LAUDO:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _corAzulMarinho),
            ),
            pw.SizedBox(height: 3),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(2.0),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _corAzulMarinho),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TIPO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('MARCA', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('MODELO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('POTÊNCIA', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TENSÃO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5))),
                  ],
                ),
                ...r.equipamentos.map((eq) {
                  return pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: _corBorda, width: 0.5)),
                    ),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(eq.tipo, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(eq.marca, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(eq.modelo, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(eq.potencia, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(eq.tensao, style: const pw.TextStyle(fontSize: 7.5))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 8),
          ],
          if (r.diagnosticoTecnico.isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _corCiano, width: 1.2),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DIAGNÓSTICO TÉCNICO E CONSTATAÇÕES:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _corAzulMarinho),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    r.diagnosticoTecnico,
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
          if (r.recomendacoesServicos.isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _corLaranja, width: 1.2),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RECOMENDAÇÕES E SERVIÇOS PROPOSTOS:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _corLaranja),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    r.recomendacoesServicos,
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          _construirAssinaturas(
            nomeEmpresaResponsavel: 'O.S. PRIME',
            cargoEmpresa: r.tecnico.isNotEmpty ? r.tecnico : 'Administrador',
            nomeCliente: r.nomeCondominio.isNotEmpty ? r.nomeCondominio : 'Condomínio',
            cargoCliente: 'Assinatura do Síndico / Condomínio',
          ),
          pw.SizedBox(height: 12),
          if (listaFotosRender.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _corCiano, width: 1.5)),
              ),
              child: pw.Text(
                'LAUDO FOTOGRÁFICO DE REGISTRO (ATÉ 10 FOTOS)',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _corAzulMarinho),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.GridView(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.88,
              children: listaFotosRender,
            ),
          ],
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> gerarRelatorioFaturamentoPdf({
    required String tipoRelatorio,
    required List servicos,
    dynamic usuarioLogado,
    dynamic filtroData,
  }) async {
    final pdf = pw.Document();
    final dataEmissaoTexto = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    double somaTotal = 0.0;
    for (var s in servicos) {
      final val = double.tryParse((s['valor'] ?? s['valor_total'] ?? s['valor_unitario'] ?? 0).toString()) ?? 0.0;
      somaTotal += val;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (pw.Context context) => _construirCabecalhoEmpresa(),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _corCiano, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Text(
                  'RELATÓRIO DE ${tipoRelatorio.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _corCiano),
                ),
              ),
              pw.Text('EMISSÃO: $dataEmissaoTexto', style: const pw.TextStyle(fontSize: 8, color: _corTextoCinza)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FlexColumnWidth(4.5),
              3: pw.FlexColumnWidth(2.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _corAzulMarinho),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('DATA', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('CLIENTE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('DESCRIÇÃO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('VALOR', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                ],
              ),
              ...servicos.map((s) {
                final d = (s['data'] ?? s['data_execucao'] ?? '').toString();
                final c = (s['cliente'] ?? s['nome_cliente'] ?? '').toString();
                final desc = (s['descricao'] ?? '').toString();
                final val = double.tryParse((s['valor'] ?? s['valor_total'] ?? s['valor_unitario'] ?? 0).toString()) ?? 0.0;
                return pw.TableRow(
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _corBorda, width: 0.5))),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(d, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(c, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(desc, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(val),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(color: _corAzulMarinho, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL DO PERÍODO:', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(
                  NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(somaTotal),
                  style: pw.TextStyle(color: _corCianoValor, fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/faturamento_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}



