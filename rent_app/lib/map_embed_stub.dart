import 'package:flutter/material.dart';

class MapEmbedView extends StatelessWidget {
  const MapEmbedView({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(Icons.map_outlined, color: Color(0xFF6B7280), size: 42),
    );
  }
}
