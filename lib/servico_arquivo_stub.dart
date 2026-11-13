import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

class ServicoArquivoUniversal {
  static Future<void> compartilharOuBaixarPdf(Uint8List bytes, String nomeArquivo, String texto) async {
    try {
      final xfile = XFile.fromData(
        bytes,
        name: nomeArquivo,
        mimeType: 'application/pdf',
      );
      await Share.shareXFiles([xfile], text: texto);
    } catch (_) {}
  }
}