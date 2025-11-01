import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../running/models/running_models.dart';

class KakaoMapView extends StatefulWidget {
  const KakaoMapView({
    super.key,
    required this.kakaoJavascriptKey,
    required this.path,
    this.focus,
    this.interactive = false,
  });

  final String kakaoJavascriptKey;
  final List<RunningPathPoint> path;
  final RunningPathPoint? focus;
  final bool interactive;

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> {
  late final WebViewController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.focus ?? widget.path.firstOrNull;
    final initialLat = initial?.latitude ?? 37.5665;
    final initialLng = initial?.longitude ?? 126.9780;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _isReady = true;
            _syncPath();
          },
        ),
      )
      ..loadHtmlString(_buildHtml(initialLat, initialLng));
  }

  @override
  void didUpdateWidget(covariant KakaoMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isReady) {
      _syncPath();
    }
  }

  void _syncPath() {
    final focus = widget.focus ?? widget.path.lastOrNull;
    final pathJson = jsonEncode(
      widget.path.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    );
    _controller.runJavaScript('setPath($pathJson);');
    if (focus != null) {
      _controller.runJavaScript(
        'setCenter(${focus.latitude}, ${focus.longitude});',
      );
    }
  }

  String _buildHtml(double lat, double lng) {
    final draggable = widget.interactive ? 'true' : 'false';
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <style>
      html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
    </style>
    <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${widget.kakaoJavascriptKey}&autoload=false"></script>
    <script type="text/javascript">
      let map;
      let polyline;
      kakao.maps.load(function() {
        var container = document.getElementById('map');
        var options = {
          center: new kakao.maps.LatLng($lat, $lng),
          level: 4,
          draggable: $draggable,
        };
        map = new kakao.maps.Map(container, options);
        polyline = new kakao.maps.Polyline({
          map: map,
          strokeWeight: 6,
          strokeColor: '#2AA8FF',
          strokeOpacity: 0.9,
          strokeStyle: 'solid',
        });
      });

      function setCenter(lat, lng) {
        if (!map) return;
        map.setCenter(new kakao.maps.LatLng(lat, lng));
      }

      function setPath(pathJson) {
        if (!map || !polyline) return;
        var data = [];
        try {
          data = JSON.parse(pathJson);
        } catch(e) {
          data = [];
        }
        if (!Array.isArray(data)) {
          data = [];
        }
        var points = data.map(function(p) {
          return new kakao.maps.LatLng(p.lat, p.lng);
        });
        polyline.setPath(points);
        if (points.length > 0) {
          var bounds = new kakao.maps.LatLngBounds();
          points.forEach(function(p) { bounds.extend(p); });
          map.setBounds(bounds, 32, 32, 32, 32);
        }
      }
    </script>
  </head>
  <body>
    <div id="map"></div>
  </body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: WebViewWidget(controller: _controller),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
