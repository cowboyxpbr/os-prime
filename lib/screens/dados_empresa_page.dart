import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_base.dart';

class DadosEmpresaPage extends StatefulWidget {
  const DadosEmpresaPage({super.key});

  @override
  State<DadosEmpresaPage> createState() => _DadosEmpresaPageState();
}

class _DadosEmpresaPageState extends State<DadosEmpresaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _ramoCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _chaveCtrl = TextEditingController();

  bool _carregando = true;
  bool _salvando = false;
  String _logoUrl = '';
  String _statusLicenca = 'ativo';
  String _validadeLicenca = '';
  int? _empresaId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final res = await supabase.from('empresas').select().limit(1).maybeSingle();
      if (res != null) {
        _empresaId = res['id'];
        _nomeCtrl.text = res['nome'] ?? '';
        _ramoCtrl.text = res['ramo_atividade'] ?? '';
        _cnpjCtrl.text = res['cnpj_cpf'] ?? '';
        _enderecoCtrl.text = res['endereco'] ?? '';
        _telefoneCtrl.text = res['telefone'] ?? '';
        _whatsappCtrl.text = res['whatsapp'] ?? '';
        _chaveCtrl.text = res['chave_licenca'] ?? '';
        _logoUrl = res['logo_url'] ?? '';
        _statusLicenca = res['status'] ?? 'ativo';
        if (res['validade'] != null) {
          final dt = DateTime.tryParse(res['validade'].toString());
          if (dt != null) {
            _validadeLicenca = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolherESubirLogo() async {
    final picker = ImagePicker();
    final imagem = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (imagem == null) return;

    setState(() => _salvando = true);
    try {
      final bytes = await imagem.readAsBytes();
      final extensao = imagem.path.split('.').last.toLowerCase();
      final nomeArquivo = 'logo_${DateTime.now().millisecondsSinceEpoch}.$extensao';

      await supabase.storage.from('logos_empresas').uploadBinary(
            nomeArquivo,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extensao', upsert: true),
          );

      final urlPublica = supabase.storage.from('logos_empresas').getPublicUrl(nomeArquivo);

      setState(() {
        _logoUrl = urlPublica;
      });

      if (_empresaId != null) {
        await supabase.from('empresas').update({'logo_url': urlPublica}).eq('id', _empresaId!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('✅ Logo atualizada com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erro ao subir imagem: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvarDados() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final dados = {
      'nome': _nomeCtrl.text.trim(),
      'ramo_atividade': _ramoCtrl.text.trim(),
      'cnpj_cpf': _cnpjCtrl.text.trim(),
      'endereco': _enderecoCtrl.text.trim(),
      'telefone': _telefoneCtrl.text.trim(),
      'whatsapp': _whatsappCtrl.text.trim(),
      'chave_licenca': _chaveCtrl.text.trim(),
      'logo_url': _logoUrl,
    };

    try {
      if (_empresaId != null) {
        await supabase.from('empresas').update(dados).eq('id', _empresaId!);
      } else {
        await supabase.from('empresas').insert(dados);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.green, content: Text('✅ Dados da empresa salvos com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Empresa & Licença'),
        backgroundColor: const Color(0xFF0F1E36),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('Logo para Orçamentos e Relatórios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            if (_logoUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_logoUrl, height: 90, fit: BoxFit.contain),
                              )
                            else
                              Container(
                                height: 80,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade400, strokeAlign: BorderSide.strokeAlignInside),
                                ),
                                child: const Icon(Icons.business, size: 40, color: Colors.grey),
                              ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _salvando ? null : _escolherESubirLogo,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Selecionar Logo da Galeria'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A3E0)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dados Cadastrais da Empresa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nomeCtrl,
                              decoration: const InputDecoration(labelText: 'Nome Fantasia / Razão Social', border: OutlineInputBorder()),
                              validator: (v) => v == null || v.isEmpty ? 'Informe o nome da empresa' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ramoCtrl,
                              decoration: const InputDecoration(labelText: 'Ramo de Atuação (ex: Climatização • Elétrica)', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _cnpjCtrl,
                              decoration: const InputDecoration(labelText: 'CNPJ ou CPF', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _enderecoCtrl,
                              decoration: const InputDecoration(labelText: 'Endereço Completo (Rua, Número, Cidade - UF)', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _telefoneCtrl,
                                    decoration: const InputDecoration(labelText: 'Telefone Fixo', border: OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _whatsappCtrl,
                                    decoration: const InputDecoration(labelText: 'Celular / WhatsApp', border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      color: Colors.blueGrey.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Chave de Acesso / Licença', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Chip(
                                  label: Text(_statusLicenca.toUpperCase()),
                                  backgroundColor: _statusLicenca == 'ativo' ? Colors.green.shade100 : Colors.red.shade100,
                                  labelStyle: TextStyle(
                                    color: _statusLicenca == 'ativo' ? Colors.green.shade800 : Colors.red.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_validadeLicenca.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Validade: $_validadeLicenca', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _chaveCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Chave de Liberação do O.S. Prime',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.key),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _salvando ? null : _salvarDados,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F1E36),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _salvando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SALVAR CONFIGURAÇÕES DA EMPRESA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
