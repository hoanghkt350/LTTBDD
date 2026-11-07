import 'dart:convert';
import 'dart:io';

import 'package:pawpals_app/services/sample_catalog.dart';

void main() {
  File('tools/catalog.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert(sampleProducts.map((p) => p.toJson()).toList()),
  );
  stdout.writeln('Wrote tools/catalog.json');
}
