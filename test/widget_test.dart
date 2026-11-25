import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rajaongkir/models/city.dart';
import 'package:rajaongkir/models/cost.dart';
import 'package:rajaongkir/models/district.dart';
import 'package:rajaongkir/models/province.dart';
import 'package:rajaongkir/pages/cek_ongkir.dart';
import 'package:rajaongkir/services/service_rajaongkir.dart';
import 'package:rajaongkir/providers/ongkir_providers.dart';

class _TestOngkirProvider extends OngkirProvider {
  @override
  Future<void> fetchProvinces() async {}
}

class _LocationService extends RajaOngkirService {
  @override
  Future<List<Province>> getProvinces() async => [
    Province(provinceId: '1', province: 'Jawa Timur'),
    Province(provinceId: '2', province: 'Jawa Barat'),
  ];

  @override
  Future<List<City>> getCities(String provinceId) async => [
    City(id: '10$provinceId', name: 'Kota $provinceId', zipCode: ''),
  ];

  @override
  Future<List<District>> getDistricts(String cityId) async => [
    District(id: '20$cityId', name: 'Kecamatan $cityId'),
  ];
}

void main() {
  testWidgets('Tombol Reset mengembalikan berat paket ke 1000 gram', (
    WidgetTester tester,
  ) async {
    final provider = _TestOngkirProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<OngkirProvider>(
        create: (_) => provider,
        child: MaterialApp(home: CekOngkirScreen()),
      ),
    );

    expect(find.text('Cek Ongkos Kirim'), findsOneWidget);
    final weightField = find.byType(TextField);
    expect(tester.widget<TextField>(weightField).controller!.text, '1000');

    await tester.ensureVisible(weightField);
    await tester.enterText(weightField, '2000');
    expect(provider.weight, 2000);

    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();

    expect(tester.widget<TextField>(weightField).controller!.text, '1000');
    expect(provider.weight, 1000);
  });

  testWidgets('Provinsi membuka pilihan kota dan kecamatan di kedua sisi', (
    tester,
  ) async {
    final provider = OngkirProvider(service: _LocationService());
    await tester.pumpWidget(
      ChangeNotifierProvider<OngkirProvider>(
        create: (_) => provider,
        child: const MaterialApp(home: CekOngkirScreen()),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> choose<T>(int side, String option) async {
      final dropdown = find.byType(DropdownSearch<T>).at(side);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    for (final side in [0, 1]) {
      final city = find.byType(DropdownSearch<City>).at(side);
      final district = find.byType(DropdownSearch<District>).at(side);
      expect(tester.widget<DropdownSearch<City>>(city).enabled, isFalse);
      expect(
        tester.widget<DropdownSearch<District>>(district).enabled,
        isFalse,
      );
      await choose<Province>(side, side == 0 ? 'Jawa Timur' : 'Jawa Barat');
      expect(tester.widget<DropdownSearch<City>>(city).enabled, isTrue);
      await choose<City>(side, 'Kota ${side + 1}');
      expect(tester.widget<DropdownSearch<District>>(district).enabled, isTrue);
      await choose<District>(side, 'Kecamatan 10${side + 1}');
    }
    expect(provider.origin.district?.id, '20101');
    expect(provider.destination.district?.id, '20102');
  });

  testWidgets('Rumus diperbarui ketika layanan kurir diganti', (tester) async {
    final provider = _TestOngkirProvider();
    provider.setWeight(4000);
    provider.costs = [
      ShippingCost(
        courierName: 'JNE',
        courierCode: 'jne',
        service: 'JTR',
        description: 'JNE Trucking',
        cost: 205000,
        etd: '16 day',
      ),
      ShippingCost(
        courierName: 'JNE',
        courierCode: 'jne',
        service: 'REG',
        description: 'Reguler',
        cost: 100000,
        etd: '3 day',
      ),
    ];
    provider.setSelectedCost(provider.costs.first);
    await tester.pumpWidget(
      ChangeNotifierProvider<OngkirProvider>(
        create: (_) => provider,
        child: const MaterialApp(home: CekOngkirScreen()),
      ),
    );

    expect(find.text('Rp 205.000 (205000)'), findsOneWidget);
    expect(find.text('4.000 gram (4000)'), findsOneWidget);
    expect(find.text('209.000'), findsOneWidget);
    expect(find.text('Rumus: 205000 + 4000 = 209000'), findsOneWidget);

    final service = find.byType(DropdownSearch<ShippingCost>);
    await tester.ensureVisible(service);
    await tester.tap(service);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('JNE - REG')));
    await tester.pumpAndSettle();

    expect(find.text('104.000'), findsOneWidget);
    expect(find.text('Rumus: 100000 + 4000 = 104000'), findsOneWidget);
  });
}
