import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rajaongkir/models/province.dart';
import 'package:rajaongkir/providers/ongkir_providers.dart';
import 'package:rajaongkir/services/service_rajaongkir.dart';

void main() {
  test(
    'Cek ongkir mengirim ID kecamatan serta membaca layanan dan tarif',
    () async {
      var costRequests = 0;
      final client = MockClient((request) async {
        expect(request.headers['key'], 'test-key');
        final data = switch (request.url.path) {
          '/api/v1/destination/city/1' => [
            {'id': 10, 'name': 'Kota Asal'},
            {'id': 20, 'name': 'Kota Tujuan'},
          ],
          '/api/v1/destination/district/10' => [
            {'id': 101, 'name': 'Kecamatan Asal'},
          ],
          '/api/v1/destination/district/20' => [
            {'id': 202, 'name': 'Kecamatan Tujuan'},
          ],
          '/api/v1/calculate/district/domestic-cost' => [
            {
              'name': 'JNE',
              'code': 'jne',
              'service': 'REG',
              'description': 'Reguler',
              'cost': 16000,
              'etd': '2-3 days',
            },
          ],
          _ => throw StateError('Endpoint salah: ${request.url.path}'),
        };
        if (request.url.path.endsWith('/domestic-cost')) {
          costRequests++;
          expect(request.method, 'POST');
          expect(request.bodyFields, {
            'origin': '101',
            'destination': '202',
            'weight': '1500',
            'courier': 'jne',
            'price': 'lowest',
          });
        } else {
          expect(request.method, 'GET');
        }
        return http.Response(jsonEncode({'data': data}), 200);
      });
      final provider = OngkirProvider(
        service: RajaOngkirService(client: client, apiKey: 'test-key'),
      );
      addTearDown(provider.dispose);
      addTearDown(client.close);

      final province = Province(provinceId: '1', province: 'Provinsi');
      await provider.setProvince(provider.origin, province);
      await provider.setProvince(provider.destination, province);
      await provider.setCity(provider.origin, provider.origin.cities.first);
      await provider.setCity(
        provider.destination,
        provider.destination.cities.last,
      );
      provider.setDistrict(provider.origin, provider.origin.districts.single);
      provider.setDistrict(
        provider.destination,
        provider.destination.districts.single,
      );
      provider.setCourier(provider.couriers.first);

      for (final invalid in [null, 0, -1]) {
        provider.setWeight(invalid);
        expect(await provider.checkShippingCost(), contains('minimal 1'));
      }
      expect(costRequests, 0);

      provider.setWeight(1500);
      expect(await provider.checkShippingCost(), isNull);
      expect(costRequests, 1);
      final result = provider.costs.single;
      expect(result.service, 'REG');
      expect(result.formattedPrice, 'Rp 16.000');
      expect(result.etd, '2-3 days');

      await provider.setCity(provider.origin, provider.origin.cities.last);
      expect(provider.origin.district, isNull);
      expect(provider.costs, isEmpty);
      expect(await provider.checkShippingCost(), contains('kecamatan asal'));
      expect(costRequests, 1);
    },
  );
}
