import 'dart:typed_data';
import 'package:flutter/material.dart';
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

ImageProvider obterImagemProvider(String caminho) {
  return NetworkImage(caminho);
}

Widget obterWidgetImagemArquivo(String caminho, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  return Image.network(caminho, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => const Icon(Icons.image));
}