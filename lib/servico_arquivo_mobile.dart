import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ServicoArquivoUniversal {
  static Future<void> compartilharOuBaixarPdf(Uint8List bytes, String nomeArquivo, String texto) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$nomeArquivo');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: texto);
    } catch (_) {
      final xfile = XFile.fromData(bytes, name: nomeArquivo, mimeType: 'application/pdf');
      await Share.shareXFiles([xfile], text: texto);
    }
  }
}