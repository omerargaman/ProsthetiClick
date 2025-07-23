// main.dart – גרסה מלאה עם ActionChip במקום Chip, כולל שליטה בעכבר, גלילה וקיצורי מקלדת

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() => runApp(MouseControllerApp());

class MouseControllerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tablet Mouse Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MouseControlScreen(),
    );
  }
}

class MouseControlScreen extends StatefulWidget {
  @override
  _MouseControlScreenState createState() => _MouseControlScreenState();
}

class _MouseControlScreenState extends State<MouseControlScreen> {
  RawDatagramSocket? _udpSocket;
  Offset? _lastPosition, _lastScrollPosition;
  String? _currentIP;
  bool _discovered = false;
  bool _manualOverride = false;
  List<String> _recentIPs = [];
  double _currentScale = 1.6667;
  bool _selectionMode = false;
  static const int COMMAND_PORT = 5000;
  static const int DISCOVERY_PORT = 5001;
  static const String DISCOVER_MSG = 'DISCOVER';
  static const String SERVER_RESP = 'MOUSE_SERVER';
  
  @override
  void initState() {
    super.initState();
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
      socket.broadcastEnabled = true;
      setState(() => _udpSocket = socket);
      _startListening();
      _discoverServer();
    });
  }

  void _startListening() {
    _udpSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _udpSocket!.receive();
        if (dg != null) {
          final msg = utf8.decode(dg.data).trim();
          if (msg == SERVER_RESP && !_discovered && !_manualOverride) {
            setState(() {
              _currentIP = dg.address.address;
              _discovered = true;
            });
            print('► Discovered server at $_currentIP');
          }
        }
      }
    });
  }

  void _discoverServer() {
    if (_udpSocket == null || _discovered || _manualOverride) return;
    final data = utf8.encode(DISCOVER_MSG);
    _udpSocket!.send(data, InternetAddress('255.255.255.255'), DISCOVERY_PORT);
    print('◉ Broadcasted DISCOVER');
    Future.delayed(Duration(seconds: 2), () {
      if (!_discovered && !_manualOverride) _discoverServer();
    });
  }

  void _onRescan() {
    setState(() {
      _discovered = false;
      _manualOverride = false;
      _currentIP = null;
    });
    _discoverServer();
  }

  void _openSettings() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initialIP: _currentIP ?? '',
          recentIPs: _recentIPs,
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      final ip = result.trim();
      setState(() {
        _manualOverride = true;
        _discovered = true;
        _currentIP = ip;
        _recentIPs.remove(ip);
        _recentIPs.insert(0, ip);
        if (_recentIPs.length > 3) _recentIPs.removeLast();
      });
    }
  }

  void _openHotkeysPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HotkeysScreen(sendHotkey: _sendCommand)));
  }

  void _sendCommand(String cmd) {
    if (_udpSocket != null && _currentIP != null) {
      final data = utf8.encode(cmd + '\n');
      _udpSocket!.send(data, InternetAddress(_currentIP!), COMMAND_PORT);
      print('[UDP ➤ $_currentIP] $cmd');
    }
  }
  void _toggleSelection() {
    if (!_selectionMode) {
      _sendCommand('LEFT_DOWN');
    } else {
      _sendCommand('LEFT_UP');
    }
    setState(() => _selectionMode = !_selectionMode);
  }
  void _handlePanUpdate(DragUpdateDetails d) {
    final p = d.localPosition;
    if (_lastPosition != null) {
      final dx = p.dx - _lastPosition!.dx;
      final dy = p.dy - _lastPosition!.dy;
      _sendCommand('MOVE_DELTA:$dx,$dy');
    }
    _lastPosition = p;
  }

  void _handlePanEnd(DragEndDetails _) => _lastPosition = null;

  void _handleScrollUpdate(DragUpdateDetails d) {
    final p = d.localPosition;
    if (_lastScrollPosition != null) {
      final dy = p.dy - _lastScrollPosition!.dy;
      _sendCommand(dy < 0 ? 'SCROLL_UP' : 'SCROLL_DOWN');
    }
    _lastScrollPosition = p;
  }

  void _handleScrollEnd(DragEndDetails _) => _lastScrollPosition = null;

  void _leftClick() => _sendCommand('LEFT_CLICK');
  void _rightClick() => _sendCommand('RIGHT_CLICK');

  @override
  void dispose() {
    _udpSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _currentIP != null ? 'Connected to $_currentIP' : 'Not connected';
    return Scaffold(
      appBar: AppBar(
        title: Text('Tablet Mouse Controller'),
        actions: [
          IconButton(icon: Icon(Icons.bolt), onPressed: _openHotkeysPage),
          IconButton(icon: Icon(Icons.refresh), onPressed: _onRescan),
          IconButton(icon: Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          Container(color: Colors.grey[300], padding: EdgeInsets.all(8), child: Text(statusText)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: GestureDetector(
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: _handlePanEnd,
                    child: Container(
                      color: Colors.grey[200],
                      child: Center(child: Text('Move your finger to control the mouse', style: TextStyle(fontSize: 18))),
                    ),
                  ),
                ),
                Container(
                  width: 150,
                  decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2), color: Colors.blue[100]),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: _handleScrollUpdate,
                    onPanEnd: _handleScrollEnd,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text('Scroll Area', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.grey[300],
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Scale: ${_currentScale.toStringAsFixed(2)}", style: TextStyle(fontSize: 16)),
                Slider(
                  value: _currentScale,
                  min: 0.2,
                  max: 5.0,
                  divisions: 48,
                  label: _currentScale.toStringAsFixed(2),
                  onChanged: (v) {
                    setState(() => _currentScale = v);
                    _sendCommand('SET_SCALE:$v');
                  },
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _leftClick,
                  child: Container(
                    color: Colors.green[200],
                    height: 60,
                    child: Center(child: Text('Left Click', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _rightClick,
                  child: Container(
                    color: Colors.red[200],
                    height: 60,
                    child: Center(child: Text('Right Click', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectionMode ? Colors.orange : Colors.blueGrey,
                    minimumSize: Size.fromHeight(60),
                  ),
                  child: Text(
                    _selectionMode ? 'Stop Select' : 'Start Select',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class HotkeysScreen extends StatefulWidget {
  final void Function(String) sendHotkey;
  HotkeysScreen({required this.sendHotkey});

  @override
  _HotkeysScreenState createState() => _HotkeysScreenState();
}

class _HotkeysScreenState extends State<HotkeysScreen> {
  final TextEditingController _customKeyController = TextEditingController();
  final List<String> _savedKeys = [
    'Ctrl+C', 'Ctrl+V', 'Ctrl+S', 'Ctrl+Z', 'Ctrl+Y',
    'Ctrl+Shift+Z', 'Alt+Tab', 'Ctrl+Alt+Del', 'Ctrl+A', 'F5'
  ];

  Offset? _lastMovePosition;
  Offset? _lastScrollPosition;
  double _currentScale = 1.0;
  bool _selectionMode = false; // מצב סימון טקסט

  void _sendHotkey(String cmd) => widget.sendHotkey(cmd);

  void _sendKey(String label) {
    final key = label.toUpperCase().replaceAll('+', '_').replaceAll(' ', '_');
    _sendHotkey('HOTKEY_$key');
  }

  void _addCustomKey() {
    final raw = _customKeyController.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      if (!_savedKeys.contains(raw)) _savedKeys.insert(0, raw);
      _customKeyController.clear();
    });
  }

  void _removeKey(String key) => setState(() => _savedKeys.remove(key));

  // Toggle ווליאני למצב סימון טקסט
  void _toggleSelection() {
    if (!_selectionMode) {
      _sendHotkey('LEFT_DOWN');
    } else {
      _sendHotkey('LEFT_UP');
    }
    setState(() {
      _selectionMode = !_selectionMode;
    });
  }

  // Move handlers
  void _handleMoveUpdate(DragUpdateDetails d) {
    final p = d.localPosition;
    if (_lastMovePosition != null) {
      final dx = p.dx - _lastMovePosition!.dx;
      final dy = p.dy - _lastMovePosition!.dy;
      _sendHotkey('MOVE_DELTA:$dx,$dy');
    }
    _lastMovePosition = p;
  }
  void _handleMoveEnd(DragEndDetails _) => _lastMovePosition = null;

  // Scroll handlers
  void _handleScrollUpdate(DragUpdateDetails d) {
    final p = d.localPosition;
    if (_lastScrollPosition != null) {
      final dy = p.dy - _lastScrollPosition!.dy;
      _sendHotkey(dy < 0 ? 'SCROLL_UP' : 'SCROLL_DOWN');
    }
    _lastScrollPosition = p;
  }
  void _handleScrollEnd(DragEndDetails _) => _lastScrollPosition = null;

  void _leftClick() => _sendHotkey('LEFT_CLICK');
  void _rightClick() => _sendHotkey('RIGHT_CLICK');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Custom Keyboard Shortcuts')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. שורת הוספת קיצור
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customKeyController,
                    decoration: InputDecoration(
                      labelText: 'New hotkey (e.g. Ctrl+Shift+X)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCustomKey(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _addCustomKey, child: Text('Add')),
              ],
            ),
            SizedBox(height: 16),

            // 2. רשימת הקיצורים
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _savedKeys.map((k) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionChip(
                      label: Text(k),
                      onPressed: () => _sendKey(k),
                      backgroundColor: Colors.blue[100],
                      labelStyle: TextStyle(fontSize: 14),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () => _removeKey(k),
                    ),
                  ],
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // 3. Move + Scroll בצדדים, עם גובה מוגדל
            Text('Control Area', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Row(
              children: [
                // Move Area גבוה יותר
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: _handleMoveUpdate,
                    onPanEnd: _handleMoveEnd,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black54, width: 1),
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('Move', style: TextStyle(fontSize: 14))),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Scroll Area גבוה יותר
                Container(
                  width: 80,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black54, width: 1),
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: _handleScrollUpdate,
                    onPanEnd: _handleScrollEnd,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text('Scroll', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 4. Scale slider קטן
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Scale: ${_currentScale.toStringAsFixed(2)}", style: TextStyle(fontSize: 14)),
                  Slider(
                    value: _currentScale,
                    min: 0.2,
                    max: 5.0,
                    divisions: 48,
                    label: _currentScale.toStringAsFixed(2),
                    onChanged: (v) {
                      setState(() => _currentScale = v);
                      _sendHotkey('SET_SCALE:$v');
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // 5. כפתור Toggle לסימון טקסט
            ElevatedButton(
              onPressed: _toggleSelection,
              child: Text(_selectionMode ? 'Stop Selecting' : 'Start Selecting'),
            ),
            SizedBox(height: 16),

            // 6. לחצני Left ו-Right Click רגילים
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _leftClick,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('Left Click', style: TextStyle(fontSize: 16))),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _rightClick,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('Right Click', style: TextStyle(fontSize: 16))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class SettingsScreen extends StatefulWidget {
  final String initialIP;
  final List<String> recentIPs;

  SettingsScreen({required this.initialIP, required this.recentIPs});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.initialIP);
  }

  void _save() => Navigator.pop(context, _ipController.text.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Server Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter server IP address:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            if (widget.recentIPs.isNotEmpty) ...[
              Text("Recent IPs:"),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.recentIPs.map((ip) {
                  return ElevatedButton(
                    onPressed: () => _ipController.text = ip,
                    child: Text(ip),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
            ],
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Server IP',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: Text('Save')),
          ],
        ),
      ),
    );
  }
}