// lib/screens/city_picker_screen.dart
import 'package:flutter/material.dart';
import '../services/geocode_service.dart';

// Lista estática de UFs para o Dropdown
const List<String> _ufs = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
  'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
  'SP', 'SE', 'TO'
];

class CityPickerScreen extends StatefulWidget {
  final String? initialUf;    // sigla (ex.: SP)
  final String? initialCity;  // nome (ex.: Campinas)

  const CityPickerScreen({super.key, this.initialUf, this.initialCity});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _cityCtl = TextEditingController();

  String? _selectedUf;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    if (widget.initialUf != null && widget.initialUf!.isNotEmpty) {
      _selectedUf = widget.initialUf!.toUpperCase();
    }
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _selectedCity = widget.initialCity!;
      _cityCtl.text = _selectedCity!;
    }
  }

  void _confirm() {
    if (_selectedUf == null || _selectedUf!.isEmpty ||
        _selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione UF e cidade')),
      );
      return;
    }
    Navigator.pop(context, {
      'uf': _selectedUf,
      'city': _selectedCity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escolher cidade")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Estado (Selecione a UF)'),
          const SizedBox(height: 8),
          
          // --- Dropdown para Estado (Lista Estática) ---
          DropdownButtonFormField<String>(
            value: _selectedUf,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Selecione o Estado',
            ),
            items: _ufs.map((String uf) {
              return DropdownMenuItem<String>(
                value: uf,
                child: Text(uf),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedUf = newValue;
                // Limpa cidade ao trocar UF
                _selectedCity = null;
                _cityCtl.clear();
              });
            },
          ),
          // --- Fim Dropdown Estado ---

          const SizedBox(height: 16),
          const Text('Cidade (digite para buscar)'),
          const SizedBox(height: 8),
          
          // --- Autocomplete para Cidade (Busca Dinâmica) ---
          Autocomplete<Map<String, String>>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (_selectedUf == null || _selectedUf!.isEmpty || textEditingValue.text.trim().isEmpty) {
                return const Iterable<Map<String, String>>.empty();
              }
              // Chama o serviço de busca dinâmica (que sabemos que funciona no backend)
              return await GeocodeService.suggestCities(
                query: textEditingValue.text,
                uf: _selectedUf!,
              );
            },
            displayStringForOption: (Map<String, String> option) => option['city'] ?? '',

            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              textEditingController.text = _cityCtl.text;
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                enabled: _selectedUf != null && _selectedUf!.isNotEmpty,
                decoration: InputDecoration(
                  hintText: _selectedUf == null
                      ? 'Escolha primeiro o Estado'
                      : 'Ex.: Campinas',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_city),
                ),
                onChanged: (text) {
                  _cityCtl.text = text;
                  setState(() {});
                },
              );
            },
            
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  child: SizedBox(
                    height: 250.0,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, String> item = options.elementAt(index);
                        return GestureDetector(
                          onTap: () {
                            onSelected(item);
                          },
                          child: ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(item['city'] ?? ''
                            subtitle: Text(item['displayName'] ?? ''
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },

            onSelected: (Map<String, String> item) {
              _selectedCity = item['city'];
              _cityCtl.text = _selectedCity ?? '';
              setState(() {});
            },
          ),
          // --- Fim Autocomplete Cidade ---

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Usar esta cidade'),
          ),
        ],
      ),
    );
  }
}
