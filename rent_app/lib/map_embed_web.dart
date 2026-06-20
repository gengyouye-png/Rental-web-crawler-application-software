// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class MapEmbedView extends StatefulWidget {
  const MapEmbedView({super.key, required this.query});

  final String query;

  @override
  State<MapEmbedView> createState() => _MapEmbedViewState();
}

class _MapEmbedViewState extends State<MapEmbedView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    final encoded = Uri.encodeComponent(widget.query);
    final url = 'https://maps.google.com/maps?q=$encoded&output=embed';
    _viewType = 'rent-map-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute('loading', 'lazy')
        ..referrerPolicy = 'no-referrer-when-downgrade';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
