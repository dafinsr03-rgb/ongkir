import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/city.dart';
import '../models/cost.dart';
import '../models/district.dart';
import '../models/province.dart';

class RajaOngkirService {
  RajaOngkirService({this.client, String? apiKey})
    : _apiKey = (apiKey ?? const String.fromEnvironment('RAJAONGKIR_API_KEY'))
          .trim();

  final http.Client? client;
  final String _apiKey;
  static const _baseUrl = kIsWeb
      ? 'http://127.0.0.1:8091'
      : 'https://rajaongkir.komerce.id/api/v1';
  static const _timeout = Duration(seconds: 15);

  Map<String, String> get _headers {
    if (kIsWeb) return const {};
    if (_apiKey.isEmpty) {
      throw const RajaOngkirException(
        'Konfigurasi RAJAONGKIR_API_KEY belum diisi.',
      );
    }
    return {'key': _apiKey};
  }

  Future<List<Province>> getProvinces() => _get('province', Province.fromJson);

  Future<List<City>> getCities(String provinceId) =>
      _get('city/$provinceId', City.fromJson);

  Future<List<District>> getDistricts(String cityId) =>
      _get('district/$cityId', District.fromJson);

  Future<List<T>> _get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final uri = Uri.parse('$_baseUrl/destination/$path');
    final headers = _headers;
    final response = await _send(
      () =>
          (client?.get(uri, headers: headers) ??
          http.get(uri, headers: headers)),
    );
    return _decode(response, fromJson);
  }

  Future<List<ShippingCost>> checkCost({
    required String originDistrictId,
    required String destinationDistrictId,
    required int weight,
    required String courier,
  }) async {
    final uri = Uri.parse('$_baseUrl/calculate/district/domestic-cost');
    final headers = _headers;
    final body = {
      'origin': originDistrictId,
      'destination': destinationDistrictId,
      'weight': weight.toString(),
      'courier': courier,
      'price': 'lowest',
    };
    final response = await _send(
      () =>
          (client?.post(uri, headers: headers, body: body) ??
          http.post(uri, headers: headers, body: body)),
    );
    return _decode(response, ShippingCost.fromJson);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on http.ClientException {
      throw RajaOngkirException(
        kIsWeb
            ? 'Proxy RajaOngkir tidak terjangkau. Jalankan proxy lokal dan buka aplikasi di http://localhost:8090.'
            : 'Koneksi ke RajaOngkir gagal.',
      );
    }
  }

  List<T> _decode<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode != 200) {
      throw RajaOngkirException(
        'RajaOngkir mengembalikan HTTP ${response.statusCode}.',
      );
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload case {'data': final List<dynamic> data}) {
      return data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Format data RajaOngkir tidak valid.');
        }
        return fromJson(item);
      }).toList();
    }
    throw const FormatException('Format respons RajaOngkir tidak valid.');
  }
}

class RajaOngkirException implements Exception {
  const RajaOngkirException(this.message);

  final String message;
}
