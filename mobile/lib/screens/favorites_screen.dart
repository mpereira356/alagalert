import 'package:flutter/material.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _items = <String>["Campinas/SP","São Paulo/SP"];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favoritos")),
      body: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (_, i) => ListTile(
          title: Text(_items[i]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context, _items[i]),
        ),
      ),
    );
  }
}
