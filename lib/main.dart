import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/ongkir_providers.dart';
import 'pages/cek_ongkir.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OngkirProvider(),
      child: MaterialApp(
        title: 'Cek Ongkir',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const CekOngkirScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
