import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../providers/ongkir_providers.dart';
import '../models/province.dart';
import '../models/city.dart';
import '../models/district.dart';
import '../models/cost.dart';

class CekOngkirScreen extends StatefulWidget {
  const CekOngkirScreen({super.key});

  @override
  State<CekOngkirScreen> createState() => _CekOngkirScreenState();
}

class _CekOngkirScreenState extends State<CekOngkirScreen> {
  final TextEditingController _weightController = TextEditingController(
    text: '1000',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OngkirProvider>().fetchProvinces();
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cek Ongkos Kirim'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              context.read<OngkirProvider>().reset();
              _weightController.text = '1000';
            },
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Consumer<OngkirProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (provider.isLoadingProvinces)
                  const LinearProgressIndicator(),
                if (provider.provinceError case final message?)
                  ListTile(
                    title: Text(message),
                    trailing: TextButton(
                      onPressed: provider.fetchProvinces,
                      child: const Text('Coba lagi'),
                    ),
                  ),
                _buildLocation(provider, provider.origin, isOrigin: true),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 24),
                _buildLocation(provider, provider.destination, isOrigin: false),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 24),
                _buildWeightAndCourier(provider),
                SizedBox(height: 24),
                _buildCheckButton(provider),
                SizedBox(height: 24),
                _buildResults(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocation(
    OngkirProvider provider,
    ShippingLocation location, {
    required bool isOrigin,
  }) {
    final label = isOrigin ? 'Asal' : 'Tujuan';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isOrigin ? Icons.location_on : Icons.place,
              color: isOrigin ? Colors.blue : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              isOrigin ? 'Dari' : 'Ke',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _locationDropdown<Province>(
          label: 'Provinsi $label',
          icon: Icons.map,
          items: provider.provinces,
          selected: location.province,
          onChanged: (value) => provider.setProvince(location, value),
        ),
        const SizedBox(height: 12),
        _locationDropdown<City>(
          label: 'Kota $label',
          prerequisite: location.province == null
              ? 'Pilih provinsi dahulu'
              : null,
          icon: Icons.location_city,
          items: location.cities,
          selected: location.city,
          onChanged: (value) => provider.setCity(location, value),
        ),
        const SizedBox(height: 12),
        _locationDropdown<District>(
          label: 'Kecamatan $label',
          prerequisite: location.city == null ? 'Pilih kota dahulu' : null,
          icon: Icons.place_outlined,
          items: location.districts,
          selected: location.district,
          onChanged: (value) => provider.setDistrict(location, value),
        ),
        if (location.isLoading) const LinearProgressIndicator(),
        if (location.error case final message?)
          ListTile(
            title: Text(message),
            trailing: TextButton(
              onPressed: () => location.city == null
                  ? provider.setProvince(location, location.province)
                  : provider.setCity(location, location.city),
              child: const Text('Coba lagi'),
            ),
          ),
      ],
    );
  }

  Widget _locationDropdown<T>({
    required String label,
    required IconData icon,
    required List<T> items,
    required T? selected,
    required ValueChanged<T?> onChanged,
    String? prerequisite,
  }) {
    return DropdownSearch<T>(
      items: items,
      selectedItem: selected,
      enabled: items.isNotEmpty,
      onChanged: onChanged,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: label,
          helperText: prerequisite,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
      popupProps: PopupProps.modalBottomSheet(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Cari $label',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightAndCourier(OngkirProvider provider) {
    return Column(
      children: [
        TextField(
          controller: _weightController,
          decoration: InputDecoration(
            labelText: 'Berat Paket (gram)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.scale),
            helperText: 'Minimal 1 gram',
            errorText: provider.weight == null || provider.weight! < 1
                ? 'Masukkan bilangan bulat positif'
                : null,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final grams = value.trim();
            final weight = RegExp(r'^\d+$').hasMatch(grams)
                ? int.tryParse(grams)
                : null;
            provider.setWeight(weight);
          },
        ),
        SizedBox(height: 16),
        DropdownSearch<Courier>(
          items: provider.couriers,
          selectedItem: provider.selectedCourier,
          onChanged: provider.setCourier,
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              labelText: 'Pilih Kurir',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_shipping),
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: false,
            itemBuilder: (context, item, isSelected) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.local_shipping, color: Colors.blue),
                ),
                title: Text(item.name),
                selected: isSelected,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCheckButton(OngkirProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: provider.isLoadingCosts
            ? null
            : () async {
                final error = await provider.checkShippingCost();
                if (mounted && error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                  );
                }
              },
        icon: provider.isLoadingCosts
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.search),
        label: Text(
          provider.isLoadingCosts ? 'Mengecek...' : 'Cek Ongkir',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildResults(OngkirProvider provider) {
    if (provider.costs.isEmpty) return const SizedBox.shrink();
    final selectedCost = provider.selectedCost;
    final grams = provider.weight;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Hasil Perhitungan Ongkir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownSearch<ShippingCost>(
              items: provider.costs,
              selectedItem: provider.selectedCost,
              onChanged: provider.setSelectedCost,
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Pilih Layanan Kurir',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping),
                ),
              ),
              popupProps: PopupProps.modalBottomSheet(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'Cari paket (service/kurir)...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                modalBottomSheetProps: ModalBottomSheetProps(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),
                itemBuilder: (context, item, isSelected) {
                  return ListTile(
                    title: Text('${item.courierName} - ${item.service}'),
                    subtitle: Text(
                      '${item.formattedPrice} • Estimasi: ${item.etd.isEmpty ? '-' : item.etd}',
                    ),
                    selected: isSelected,
                  );
                },
              ),
              filterFn: (item, filter) =>
                  item.label.toLowerCase().contains(filter.toLowerCase()),
            ),

            if (selectedCost != null && grams != null) ...[
              const SizedBox(height: 16),
              _buildCostBreakdown(selectedCost, grams),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdown(ShippingCost selectedCost, int grams) {
    final total = selectedCost.cost + grams;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedCost.courierName} - ${selectedCost.service}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (selectedCost.description.isNotEmpty)
            Text(
              selectedCost.description,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          const SizedBox(height: 8),
          Text(
            'Estimasi Tiba: ${selectedCost.etd.isEmpty ? '-' : selectedCost.etd}',
            style: TextStyle(fontSize: 12, color: Colors.blue[800]),
          ),
          const Divider(),
          _buildCostRow(
            'Ongkir:',
            '${selectedCost.formattedPrice} (${selectedCost.cost})',
            valueColor: Colors.green[700],
          ),
          const SizedBox(height: 4),
          _buildCostRow(
            'Berat Barang:',
            '${formatShippingNumber(grams)} gram ($grams)',
          ),
          const Divider(),
          _buildCostRow(
            'Total (Ongkir + Berat):',
            formatShippingNumber(total),
            valueColor: Colors.blue[700],
            emphasize: true,
          ),
          const SizedBox(height: 4),
          Text(
            'Rumus: ${selectedCost.cost} + $grams = $total',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(
    String label,
    String value, {
    Color? valueColor,
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: emphasize ? FontWeight.bold : null),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
