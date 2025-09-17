import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class CityPickerResult { final String uf; final String city; CityPickerResult(this.uf,this.city); }

class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});
  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _ufs = <String>["SP","RJ","MG","PR"];
  Map<String, List<String>> _citiesByUf = {
    "SP": ["Campinas","São Paulo"],
    "RJ": ["Rio de Janeiro"],
    "MG": ["Belo Horizonte"],
    "PR": ["Curitiba"],
  };

  String _uf = "SP";
  String _city = "Campinas";
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssetsIfAny(); // tenta carregar assets/ibge/*.json se existirem
  }

  Future<void> _loadAssetsIfAny() async {
    try {
      final ufJson = await rootBundle.loadString('assets/ibge/uf.json');
      final munJson = await rootBundle.loadString('assets/ibge/municipios.json');
      final ufsData = (jsonDecode(ufJson)['features'] as List).map((f) => (f['properties']['UF'] ?? f['properties']['sigla'])).cast<String>().toList();
      final munData = (jsonDecode(munJson) as List).map((e) => {"uf": e['uf'], "nome": e['nome']}).toList();
      final byUf = <String,List<String>>{};
      for (final uf in ufsData) { byUf[uf] = []; }
      for (final m in munData) { byUf[m['uf']] = (byUf[m['uf']] ?? [])..add(m['nome']); }
      setState(() {
        _ufs
          ..clear()
          ..addAll(ufsData);
        _citiesByUf = byUf.map((k, v) => MapEntry(k, v..sort()));
        if (!_ufs.contains(_uf)) _uf = _ufs.first;
        if (!_citiesByUf[_uf]!.contains(_city)) _city = _citiesByUf[_uf]!.first;
      });
    } catch (_) {
      // mantém amostra embutida
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = _citiesByUf[_uf] ?? [];
    final filtered = _search.text.isEmpty
        ? cities
        : cities.where((c) => c.toLowerCase().contains(_search.text.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Escolha a cidade")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _uf,
            decoration: const InputDecoration(labelText: "Estado (UF)"),
            items: _ufs.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (v) => setState(() { _uf = v!; _search.clear(); }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "Buscar cidade"),
            onChanged: (_) => setState((){}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                return ListTile(
                  title: Text(c),
                  onTap: () => Navigator.pop(context, CityPickerResult(_uf, c)),
                );
              },
            ),
          )
        ]),
      ),
    );
  }
}
