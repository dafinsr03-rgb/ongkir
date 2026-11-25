import 'package:flutter/foundation.dart';

import '../models/city.dart';
import '../models/cost.dart';
import '../models/district.dart';
import '../models/province.dart';
import '../services/service_rajaongkir.dart';

class ShippingLocation {
  Province? province;
  City? city;
  District? district;
  List<City> cities = [];
  List<District> districts = [];
  bool isLoading = false;
  String? error;
  Object? _request;

  void _clearDistricts() {
    district = null;
    districts = [];
    error = null;
    isLoading = false;
    _request = null;
  }
}

class OngkirProvider with ChangeNotifier {
  OngkirProvider({RajaOngkirService? service})
    : _service = service ?? RajaOngkirService();

  final RajaOngkirService _service;
  final origin = ShippingLocation();
  final destination = ShippingLocation();

  List<Province> provinces = [];
  List<ShippingCost> costs = [];
  Courier? selectedCourier;
  ShippingCost? selectedCost;
  int? weight = 1000;
  bool isLoadingProvinces = false;
  bool isLoadingCosts = false;
  String? provinceError;
  bool _disposed = false;
  Object? _costRequest;

  final couriers = [
    Courier(code: 'jne', name: 'JNE'),
    Courier(code: 'pos', name: 'POS Indonesia'),
    Courier(code: 'tiki', name: 'TIKI'),
    Courier(code: 'lion', name: 'Lion Parcel'),
    Courier(code: 'anteraja', name: 'AnterAja'),
    Courier(code: 'sicepat', name: 'SiCepat'),
    Courier(code: 'jnt', name: 'J&T'),
  ];

  Future<void> fetchProvinces() async {
    if (isLoadingProvinces) return;
    isLoadingProvinces = true;
    provinceError = null;
    notifyListeners();

    try {
      final items = await _service.getProvinces();
      if (!_disposed) provinces = items;
    } on Exception catch (error) {
      provinceError = _message(error, 'Gagal memuat provinsi.');
    } finally {
      isLoadingProvinces = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setProvince(
    ShippingLocation location,
    Province? province,
  ) async {
    location.province = province;
    location.city = null;
    location.cities = [];
    location._clearDistricts();
    _clearCosts();

    await _loadLocation(
      location,
      province == null
          ? null
          : () async {
              final cities = await _service.getCities(province.provinceId);
              return () => location.cities = cities;
            },
      'Gagal memuat kota.',
    );
  }

  Future<void> setCity(ShippingLocation location, City? city) async {
    location.city = city;
    location._clearDistricts();
    _clearCosts();

    await _loadLocation(
      location,
      city == null
          ? null
          : () async {
              final districts = await _service.getDistricts(city.id);
              return () => location.districts = districts;
            },
      'Gagal memuat kecamatan.',
    );
  }

  Future<void> _loadLocation(
    ShippingLocation location,
    Future<VoidCallback> Function()? load,
    String errorMessage,
  ) async {
    final request = Object();
    location._request = request;
    location.isLoading = load != null;
    notifyListeners();
    if (load == null) return;

    try {
      final apply = await load();
      if (!_disposed && location._request == request) apply();
    } on Exception catch (error) {
      if (!_disposed && location._request == request) {
        location.error = _message(error, errorMessage);
      }
    } finally {
      if (!_disposed && location._request == request) {
        location.isLoading = false;
        notifyListeners();
      }
    }
  }

  void setDistrict(ShippingLocation location, District? district) {
    location.district = district;
    _clearCosts();
    notifyListeners();
  }

  void setCourier(Courier? courier) {
    selectedCourier = courier;
    _clearCosts();
    notifyListeners();
  }

  void setWeight(int? grams) {
    weight = grams;
    _clearCosts();
    notifyListeners();
  }

  void setSelectedCost(ShippingCost? cost) {
    selectedCost = cost;
    notifyListeners();
  }

  Future<String?> checkShippingCost() async {
    final grams = weight;
    final originId = origin.district?.id;
    final destinationId = destination.district?.id;
    final courier = selectedCourier;

    if (grams == null || grams < 1) {
      return 'Masukkan berat paket dalam gram, minimal 1.';
    }
    if (originId == null || destinationId == null || courier == null) {
      return 'Pilih kecamatan asal, kecamatan tujuan, dan kurir.';
    }

    _clearCosts();
    final request = Object();
    _costRequest = request;
    isLoadingCosts = true;
    notifyListeners();

    try {
      final results = await _service.checkCost(
        originDistrictId: originId,
        destinationDistrictId: destinationId,
        weight: grams,
        courier: courier.code,
      );
      if (_disposed || _costRequest != request) return null;
      costs = results;
      selectedCost = costs.firstOrNull;
      return costs.isEmpty
          ? 'Layanan kurir tidak tersedia untuk rute ini.'
          : null;
    } on Exception catch (error) {
      if (_disposed || _costRequest != request) return null;
      return _message(error, 'Gagal mengecek ongkir.');
    } finally {
      if (!_disposed && _costRequest == request) {
        isLoadingCosts = false;
        notifyListeners();
      }
    }
  }

  void _clearCosts() {
    _costRequest = null;
    isLoadingCosts = false;
    costs = [];
    selectedCost = null;
  }

  void reset() {
    for (final location in [origin, destination]) {
      location.province = null;
      location.city = null;
      location.cities = [];
      location._clearDistricts();
    }
    selectedCourier = null;
    weight = 1000;
    _clearCosts();
    notifyListeners();
  }

  String _message(Exception error, String fallback) =>
      error is RajaOngkirException ? error.message : fallback;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
