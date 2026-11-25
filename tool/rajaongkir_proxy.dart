import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _appOrigin = 'http://localhost:8090';
const _apiBase = 'https://rajaongkir.komerce.id/api/v1';
const _port = 8091;

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Gunakan dart run tool/rajaongkir_proxy.dart <file JSON>.');
    exitCode = 1;
    return;
  }

  String key;
  try {
    final config = jsonDecode(await File(args.single).readAsString());
    key = (config['RAJAONGKIR_API_KEY'] as String).trim();
    if (key.isEmpty || key == 'TEMPEL_API_KEY_DI_SINI') {
      throw const FormatException();
    }
  } catch (_) {
    stderr.writeln('File konfigurasi tidak dapat dibaca atau API key kosong.');
    exitCode = 1;
    return;
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  stdout.writeln('Proxy RajaOngkir aktif di http://127.0.0.1:$_port');
  final client = http.Client();
  await for (final request in server) {
    _forward(request, client, key);
  }
}

Future<void> _forward(
  HttpRequest request,
  http.Client client,
  String key,
) async {
  final response = request.response;
  try {
    if (request.headers.value('origin') != _appOrigin) {
      response.statusCode = HttpStatus.forbidden;
      return;
    }
    response.headers.set('access-control-allow-origin', _appOrigin);
    response.headers.set('vary', 'Origin');
    response.headers.set('cache-control', 'no-store');

    final path = request.uri.path;
    final method = request.method == 'OPTIONS'
        ? request.headers.value('access-control-request-method')
        : request.method;
    final location =
        path == '/destination/province' ||
        RegExp(r'^/destination/(city|district)/[0-9]+$').hasMatch(path);
    final cost = path == '/calculate/district/domestic-cost';
    if (!(location && method == 'GET' || cost && method == 'POST')) {
      response.statusCode = HttpStatus.notFound;
      return;
    }
    if (request.method == 'OPTIONS') {
      response.headers.set('access-control-allow-methods', method!);
      response.headers.set('access-control-allow-headers', 'content-type');
      response.statusCode = HttpStatus.noContent;
      return;
    }

    final upstream = http.Request(method!, Uri.parse('$_apiBase$path'))
      ..followRedirects = false
      ..headers['key'] = key;
    if (cost) {
      if (request.contentLength < 0 || request.contentLength > 4096) {
        response.statusCode = HttpStatus.badRequest;
        return;
      }
      upstream.headers['content-type'] = 'application/x-www-form-urlencoded';
      upstream.body = await utf8.decoder.bind(request).join();
    }

    final result = await client
        .send(upstream)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 12));
    response.statusCode = result.statusCode;
    response.headers.contentType = ContentType.json;
    response.add(result.bodyBytes);
  } catch (_) {
    response.statusCode = HttpStatus.badGateway;
  } finally {
    await response.close();
  }
}
