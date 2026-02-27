import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API service for connecting to the FastAPI backend.
/// Handles REST calls and WebSocket streaming.
class ApiService {
  // ── Dynamic server IP ──
  // Default to emulator localhost if not set
  String _baseUrl = 'http://10.0.2.2:8000';
  String _wsUrl = 'ws://10.0.2.2:8000/ws';

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _sensorStream;
  Timer? _reconnectTimer;

  ApiService() {
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      _baseUrl = 'http://$savedIp:8000';
      _wsUrl = 'ws://$savedIp:8000/ws';
    }
  }

  void updateIpAddress(String ip) {
    _baseUrl = 'http://$ip:8000';
    _wsUrl = 'ws://$ip:8000/ws';
    
    // Reconnect websocket if it was currently trying or connected
    if (_channel != null || _reconnectTimer != null) {
      _closeWebSocket();
      connectWebSocket();
    }
  }

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
            
            final sensor = decoded['sensor'] as String? ?? '';
            final val = decoded['value'] as num? ?? 0.0;
            String threatLevel = decoded['threat_level'] as String? ?? '';
            
            // Reconcile logic with Web Dashboard
            if (threatLevel.isEmpty || (threatLevel == 'safe' && sensor != 'camera')) {
               threatLevel = _calculateThreatLevel(sensor, val.toDouble());
               decoded['threat_level'] = threatLevel;
            }
            
            if (decoded['alert'] == null && threatLevel != 'safe') {
               decoded['alert'] = {
                  'title': '${sensor.toUpperCase()} ALERT',
                  'message': 'Sensor value $val exceeded threshold.',
                  'severity': threatLevel,
                  'sensor': sensor,
               };
            }

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

  /// Disconnect WebSocket securely (for changing IP)
  void _closeWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Disconnect completely
  void disconnect() {
    _closeWebSocket();
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

  /// Fetch initial sensor data from the backend
  Future<List<Map<String, dynamic>>> fetchInitialSensorData() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/sensor/all-data'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Fetch initial sensor data error: $e');
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

  /// Fetch scenario guidelines
  Future<List<Map<String, dynamic>>> fetchGuidelines() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/guidelines'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Fetch guidelines error: $e');
    }
    return [];
  }

  /// Fetch emergency contacts
  Future<List<Map<String, dynamic>>> fetchEmergencyContacts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/emergency-contacts'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Fetch emergency contacts error: $e');
    }
    return [];
  }
  /// Login User
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }
    return null;
  }

  String _calculateThreatLevel(String type, double value) {
    if (type == 'temperature') {
      if (value <= 30) return 'safe';
      if (value <= 45) return 'warning';
      return 'critical';
    }
    if (type == 'humidity') {
      if (value <= 60) return 'safe';
      if (value <= 85) return 'warning';
      return 'critical';
    }
    if (type == 'gas-leakage') {
      if (value <= 800) return 'safe';
      if (value <= 1200) return 'warning';
      return 'critical';
    }
    if (type == 'ultra-sonic' || type == 'ultrasonic') {
      if (value < 25) return 'critical';
      if (value < 50) return 'warning';
      return 'safe';
    }
    if (type == 'camera') {
      if (value > 6000) return 'critical';
      if (value > 2000) return 'warning';
      return 'safe';
    }
    if (type == 'earthquake') {
      if (value < 2.0) return 'safe';
      if (value < 5.0) return 'warning';
      return 'critical';
    }
    return 'safe';
  }
}
