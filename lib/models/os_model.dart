import '../app_base.dart';
import 'dart:convert';
import '../universal_io.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdemServico {
  String? id;
  String numeroOS;
  String cliente;
  String telefone;
  String endereco;
  String descricaoProblema;
  String tecnicoDesignado;
  String status;
  String prioridade;
  String dataAbertura;
  String? dataConclusao;
  String? observacaoTecnico;
  bool visualizadoPeloTecnico;
  List<EquipamentoRelatorio> equipamentos;

  OrdemServico({
    this.id,
    required this.numeroOS,
    required this.cliente,
    required this.telefone,
    required this.endereco,
    required this.descricaoProblema,
    required this.tecnicoDesignado,
    this.status = 'Pendente',
    this.prioridade = 'Normal',
    required this.dataAbertura,
    this.dataConclusao,
    this.observacaoTecnico,
    this.visualizadoPeloTecnico = false,
    List<EquipamentoRelatorio>? equipamentos,
  }) : equipamentos = equipamentos ?? [];

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'numero_os': numeroOS,
    'cliente': cliente,
    'telefone': telefone,
    'endereco': endereco,
    'descricao_problema': descricaoProblema,
    'tecnico_designado': tecnicoDesignado.trim().toLowerCase(),
    'status': status,
    'prioridade': prioridade,
    'data_abertura': dataAbertura,
    'observacao_tecnico': observacaoTecnico ?? '',
    'visualizado_pelo_tecnico': visualizadoPeloTecnico,
  };

  factory OrdemServico.fromMap(Map<String, dynamic> m) {
    List<EquipamentoRelatorio> eqs = [];
    if (m['equipamentos'] != null) {
      try {
        final raw = m['equipamentos'];
        final List list = raw is String ? jsonDecode(raw) : raw;
        eqs = list.map((e) => EquipamentoRelatorio(
          tipo: (e['tipo'] ?? '').toString(),
          marca: (e['marca'] ?? '').toString(),
          modelo: (e['modelo'] ?? '').toString(),
          potencia: (e['potencia'] ?? '').toString(),
          tensao: (e['tensao'] ?? '').toString(),
        )).toList();
      } catch (_) {}
    }

    return OrdemServico(
      id: m['id']?.toString(),
      numeroOS: (m['numero_os'] ?? '').toString(),
      cliente: m['cliente'] ?? '',
      telefone: m['telefone'] ?? '',
      endereco: m['endereco'] ?? '',
      descricaoProblema: m['descricao_problema'] ?? '',
      tecnicoDesignado: (m['tecnico_designado'] ?? '').toString().trim().toLowerCase(),
      status: m['status'] ?? 'Pendente',
      prioridade: m['prioridade'] ?? 'Normal',
      dataAbertura: m['data_abertura'] ?? DateFormat('dd/MM/yyyy • HH:mm').format(DateTime.now()),
      dataConclusao: m['data_conclusao']?.toString(),
      observacaoTecnico: m['observacao_tecnico']?.toString(),
      visualizadoPeloTecnico: m['visualizado_pelo_tecnico'] == true,
      equipamentos: eqs,
    );
  }
}

class ServicoOS {
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<File> _getFileLocal() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/cache_ordens_servico.json');
  }

  static Future<void> salvarLocal(List<OrdemServico> lista) async {
    try {
      final f = await _getFileLocal();
      await f.writeAsString(jsonEncode(lista.map((x) => x.toMap()).toList()));
    } catch (_) {}
  }

  static Future<List<OrdemServico>> carregarLocal() async {
    try {
      final f = await _getFileLocal();
      if (await f.exists()) {
        final List l = jsonDecode(await f.readAsString());
        return l.map((m) => OrdemServico.fromMap(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> criarOS(OrdemServico os) async {
    try {
      await _supabase.from('ordens_servico').insert(os.toMap()).timeout(const Duration(seconds: 6));
      return true;
    } catch (_) {
      final locais = await carregarLocal();
      locais.insert(0, os);
      await salvarLocal(locais);
      return false;
    }
  }

  static Future<void> atualizarStatus({
    required dynamic id,
    required String novoStatus,
    String? relatorioTecnico,
    List<EquipamentoRelatorio>? equipamentos,
  }) async {
    String relatorioFinal = relatorioTecnico?.trim() ?? '';
    if (equipamentos != null && equipamentos.isNotEmpty) {
      final eqTexto = equipamentos.map((e) => "${e.tipo} ${e.marca} ${e.modelo} ${e.potencia}".trim()).join(', ');
      if (relatorioFinal.isNotEmpty && !relatorioFinal.contains(eqTexto)) {
        relatorioFinal = "$relatorioFinal [Equip: $eqTexto]";
      } else if (relatorioFinal.isEmpty) {
        relatorioFinal = "[Equip: $eqTexto]";
      }
    }

    // 1. Atualiza as colunas garantidas do banco (status e observacao_tecnico)
    final dadosUpdate = <String, dynamic>{
      'status': novoStatus,
      'visualizado_pelo_tecnico': true,
    };

    if (relatorioFinal.isNotEmpty) {
      dadosUpdate['observacao_tecnico'] = relatorioFinal;
    }

    try {
      final idNum = int.tryParse(id.toString()) ?? id;
      await _supabase.from('ordens_servico').update(dadosUpdate).eq('id', idNum).timeout(const Duration(seconds: 6));
    } catch (_) {
      try {
        await _supabase.from('ordens_servico').update(dadosUpdate).eq('id', id.toString()).timeout(const Duration(seconds: 6));
      } catch (_) {}
    }

    // 2. Tenta atualizar colunas opcionais separadamente sem travar o status
    if (novoStatus == 'Concluída' || novoStatus == 'Aguardando Orçamento') {
      try {
        final idNum = int.tryParse(id.toString()) ?? id;
        await _supabase.from('ordens_servico').update({
          'data_conclusao': DateFormat('dd/MM/yyyy • HH:mm').format(DateTime.now()),
        }).eq('id', idNum);
      } catch (_) {}
    }
  }

  static Future<void> marcarVisualizado(dynamic id) async {
    try {
      final idNum = int.tryParse(id.toString()) ?? id;
      await _supabase.from('ordens_servico').update({'visualizado_pelo_tecnico': true}).eq('id', idNum);
    } catch (_) {}
  }
}