import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Centralized API service for connecting to the FastAPI backend.
/// Handles REST calls and WebSocket streaming.
class ApiService {
  // ── Set your server IP here ──
  // On Android emulator use 10.0.2.2, on real device use LAN IP
  static const String _baseUrl = 'http://10.0.2.2:8000';
  static const String _wsUrl = 'ws://10.0.2.2:8000/ws';

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _sensorStream;
  Timer? _reconnectTimer;

  /// Stream of real-time sensor data from WebSocket
  Stream<Map<String, dynamic>> get sensorStream {
    _sensorStream ??= StreamController<Map<String, dynamic>>.broadcast();
    return _sensorStream!.stream;
  }

  /// Connect to WebSocket for live sensor updates
  void connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data) as Map<String, dynamic>;
            _sensorStream?.add(decoded);
          } catch (e) {
            debugPrint('WS decode error: $e');
          }
        },
        onDone: () {
          debugPrint('WS closed, reconnecting in 3s...');
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(const Duration(seconds: 3), connectWebSocket);
        },
        onError: (e) {
          debugPrint('WS error: $e');
          _channel?.sink.close();
        },
      );
      debugPrint('WebSocket connected to $_wsUrl');
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), connectWebSocket);
    }
  }

  /// Disconnect WebSocket
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _sensorStream?.close();
    _sensorStream = null;
  }

  /// Fetch sensor positions from the backend
  Future<List<Map<String, dynamic>>> fetchPositions() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/positions'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Fetch positions error: $e');
    }
    return [];
  }

  /// Fetch active alerts from the backend
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/alerts/active'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Fetch alerts error: $e');
    }
    return [];
  }

  /// Fetch all alerts (including historical safe ones)
  Future<List<Map<String, dynamic>>> fetchAllAlerts({int limit = 20}) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/alerts?limit=$limit'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Fetch all alerts error: $e');
    }
    return [];
  }

  /// Fetch evacuation route from danger zone
  Future<Map<String, dynamic>?> fetchEvacuationRoute(
      double dangerLat, double dangerLng) async {
    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl/evacuation/route?danger_lat=$dangerLat&danger_lng=$dangerLng'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Fetch evacuation route error: $e');
    }
    return null;
  }
}
