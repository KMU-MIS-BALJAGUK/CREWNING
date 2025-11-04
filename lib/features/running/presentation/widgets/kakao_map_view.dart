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
    this.hideCurrentMarker = false,
    this.fitPathToBounds = true,
    // optional percent offsets (0.5 = 50%). Specify only percent offsets now.
    this.centerOffsetXPercent = 0.0,
    this.centerOffsetYPercent = 0.0,
  });

  final String kakaoJavascriptKey;
  final List<RunningPathPoint> path;
  final RunningPathPoint? focus;
  final bool interactive;
  final bool hideCurrentMarker;
  final bool fitPathToBounds;
  final double centerOffsetXPercent;
  final double centerOffsetYPercent;

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
      ..loadHtmlString(
        _buildHtml(initialLat, initialLng),
        baseUrl: 'https://localhost',
      );
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
        widget.hideCurrentMarker
            ? 'setFocusOnly(${focus.latitude}, ${focus.longitude});'
            : 'updateLocation(${focus.latitude}, ${focus.longitude});',
      );
      // center with percent offsets only
      final offsetXPercent = widget.centerOffsetXPercent;
      final offsetYPercent = widget.centerOffsetYPercent;
      _controller.runJavaScript(
        'setCenterWithOffset(${focus.latitude}, ${focus.longitude}, ${offsetXPercent}, ${offsetYPercent});',
      );
    } else {
      _controller.runJavaScript('clearLocation();');
    }
  }

  String _buildHtml(double lat, double lng) {
    final draggable = widget.interactive ? 'true' : 'false';
    final centerOffsetXPercent = widget.centerOffsetXPercent.toString();
    final centerOffsetYPercent = widget.centerOffsetYPercent.toString();
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <style>
      html, body, #map { width: 100%; height: 100%; margin: 0; padding: 0; overflow: hidden; }
      .current-location {
        width: 24px;
        height: 24px;
        border-radius: 50%;
        background: rgba(42, 168, 255, 0.8);
        border: 4px solid #ffffff;
        box-shadow: 0 0 12px rgba(42, 168, 255, 0.6);
      }
    </style>
    <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${widget.kakaoJavascriptKey}&autoload=false"></script>
    <script type="text/javascript">
      let map;
      let polyline;
      let locationOverlay;
      let focusMarker;
      let pendingPath = null;
      let pendingLocation = null;
      let pendingFocus = null;
      let pendingCenter = { lat: $lat, lng: $lng };
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
        renderPath();
        renderLocation();
        renderFocus();
        renderCenter();
      });

      var pendingCenterOffsetXPercent = ${centerOffsetXPercent};
      var pendingCenterOffsetYPercent = ${centerOffsetYPercent};

      // Accept only percent offsets (0.0 - 1.0). Values are treated as fractions of container size.
      function setCenterWithOffset(lat, lng, percentX, percentY) {
        pendingCenter = { lat: lat, lng: lng };
        if (typeof percentX === 'number') {
          pendingCenterOffsetXPercent = percentX;
        }
        if (typeof percentY === 'number') {
          pendingCenterOffsetYPercent = percentY;
        }
        renderCenter();
      }

      function setCenter(lat, lng) {
        pendingCenter = { lat: lat, lng: lng };
        renderCenter();
      }

      function renderCenter() {
        if (!map || !pendingCenter) return;
        map.setCenter(new kakao.maps.LatLng(pendingCenter.lat, pendingCenter.lng));
        // Compute final pixel offsets. Percent offsets take precedence when non-zero.
        try {
          var px = Number(pendingCenterOffsetXPercent) || 0;
          var py = Number(pendingCenterOffsetYPercent) || 0;
          var x = 0;
          var y = 0;
          try {
            var container = document.getElementById('map');
            if (px !== 0 && container && container.clientWidth) {
              x = px * container.clientWidth;
            }
            if (py !== 0 && container && container.clientHeight) {
              y = py * container.clientHeight;
            }
          } catch (e) {
            // ignore container measurement failures
          }
          if ((x !== 0) || (y !== 0)) {
            map.panBy(x, y);
          }
        } catch (e) {
          // ignore
        }
      }

      function setPath(pathJson) {
        var data = [];
        try {
          data = JSON.parse(pathJson);
        } catch(e) {
          data = [];
        }
        if (!Array.isArray(data)) {
          data = [];
        }
        pendingPath = data;
        renderPath();
      }

      function renderPath() {
        if (!map || !polyline || !pendingPath) return;
        var points = pendingPath.map(function(p) {
          return new kakao.maps.LatLng(p.lat, p.lng);
        });
        if (points.length === 0) return;
        polyline.setPath(points);
        if (${widget.fitPathToBounds ? 'true' : 'false'}) {
          var bounds = new kakao.maps.LatLngBounds();
          points.forEach(function(p) { bounds.extend(p); });
          map.setBounds(bounds, 32, 32, 32, 32);
        }
      }

      function updateLocation(lat, lng) {
        pendingLocation = { lat: lat, lng: lng };
        renderLocation();
      }

      function renderLocation() {
        if (!map || !pendingLocation) return;
        var position = new kakao.maps.LatLng(pendingLocation.lat, pendingLocation.lng);
        if (!locationOverlay) {
          locationOverlay = new kakao.maps.CustomOverlay({
            position: position,
            yAnchor: 0.5,
            xAnchor: 0.5,
            content: '<div class="current-location"></div>'
          });
        }
        locationOverlay.setPosition(position);
        locationOverlay.setMap(map);
      }

      function setFocusOnly(lat, lng) {
        pendingFocus = { lat: lat, lng: lng };
        renderFocus();
      }

      function renderFocus() {
        if (!map || !pendingFocus) return;
        var position = new kakao.maps.LatLng(pendingFocus.lat, pendingFocus.lng);
        if (!focusMarker) {
          focusMarker = new kakao.maps.CustomOverlay({
            position: position,
            yAnchor: 0.5,
            xAnchor: 0.5,
            content: '<div class="current-location"></div>'
          });
        }
        focusMarker.setPosition(position);
        focusMarker.setMap(map);
      }

      function clearLocation() {
        if (locationOverlay) {
          locationOverlay.setMap(null);
          locationOverlay = null;
        }
        if (focusMarker) {
          focusMarker.setMap(null);
          focusMarker = null;
        }
        pendingLocation = null;
        pendingFocus = null;
        pendingCenter = null;
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
