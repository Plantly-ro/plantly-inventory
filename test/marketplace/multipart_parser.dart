import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Minimal multipart/form-data parser for asserting what the client sent.
class ParsedMultipart {
  final Map<String, String> fields = {};
  final List<ParsedFilePart> files = [];
}

class ParsedFilePart {
  ParsedFilePart({required this.name, required this.filename, required this.contentType, required this.bytes});
  final String name;
  final String? filename;
  final String? contentType;
  final List<int> bytes;
}

ParsedMultipart parseMultipart(http.Request req) {
  final ct = req.headers['content-type'] ?? req.headers['Content-Type'] ?? '';
  final boundary = RegExp(r'boundary=([^;]+)').firstMatch(ct)!.group(1)!;
  final body = req.bodyBytes;
  final delimiter = latin1.encode('--$boundary');
  final out = ParsedMultipart();

  final indices = <int>[];
  for (var i = 0; i <= body.length - delimiter.length; i++) {
    var match = true;
    for (var j = 0; j < delimiter.length; j++) {
      if (body[i + j] != delimiter[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      indices.add(i);
      i += delimiter.length - 1;
    }
  }
  for (var k = 0; k + 1 < indices.length; k++) {
    var start = indices[k] + delimiter.length;
    // Skip the CRLF after the boundary line.
    if (body[start] == 13 && body[start + 1] == 10) start += 2;
    var end = indices[k + 1];
    // Strip the CRLF before the next boundary.
    if (body[end - 2] == 13 && body[end - 1] == 10) end -= 2;
    final part = body.sublist(start, end);
    final sep = _indexOf(part, [13, 10, 13, 10]);
    final headerText = latin1.decode(part.sublist(0, sep));
    final content = part.sublist(sep + 4);
    final headers = <String, String>{};
    for (final line in headerText.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) headers[line.substring(0, idx).trim().toLowerCase()] = line.substring(idx + 1).trim();
    }
    final disp = headers['content-disposition'] ?? '';
    final name = RegExp(r'name="([^"]*)"').firstMatch(disp)?.group(1) ?? '';
    final filename = RegExp(r'filename="([^"]*)"').firstMatch(disp)?.group(1);
    if (filename != null) {
      out.files.add(ParsedFilePart(
        name: name,
        filename: filename,
        contentType: headers['content-type'],
        bytes: content,
      ));
    } else {
      out.fields[name] = utf8.decode(content);
    }
  }
  return out;
}

int _indexOf(Uint8List hay, List<int> needle) {
  for (var i = 0; i <= hay.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

/// Tiny helper so tests read naturally.
extension Uint8ListX on Uint8List {
  static Uint8List of(List<int> v) => Uint8List.fromList(v);
}
