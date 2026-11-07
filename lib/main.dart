import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const DLNACasterApp());
}

class DLNACasterApp extends StatelessWidget {
  const DLNACasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DLNA Caster GUI',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DLNACasterGUI(),
    );
  }
}

class DLNACasterGUI extends StatefulWidget {
  const DLNACasterGUI({super.key});

  @override
  State<DLNACasterGUI> createState() => _DLNACasterGUIState();
}

class _DLNACasterGUIState extends State<DLNACasterGUI> {
  final TextEditingController _urlController = TextEditingController();
  String _statusMessage = "Status: Ready. Enter a YouTube URL below.";
  bool _isCastButtonDisabled = false;
  
  // Your target DLNA TV addresses
  final String _primaryUri = 'http://192.168.1.2:49565/description.xml';
  final String _fallbackUri = 'http://192.168.1.18:60099';

  // Helper function to update status securely across UI frames
  void _updateStatus(String message, {bool enableButton = false}) {
    setState(() {
      _statusMessage = message;
      if (enableButton) _isCastButtonDisabled = false;
    });
  }

  // CORE WORKER: Replaces your threading.Thread and yt_dlp extractor logic
  Future<void> _startCastingProcess() async {
    final youtubeUrl = _urlController.text.trim();
    if (youtubeUrl.isEmpty) {
      _updateStatus("Status: Error - URL input field is empty!");
      return;
    }

    setState(() {
      _isCastButtonDisabled = true;
      _statusMessage = "Status: Extracting YouTube formats...";
    });

    try {
      // Initialize the lightweight YouTube Explode extractor engine
      final yt = YoutubeExplode();
      final videoId = VideoId.parseVideoId(youtubeUrl);
      
      if (videoId == null) throw Exception("Invalid YouTube URL ID");

      // Fetch the manifest data (Replaces ydl.extract_info)
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      
      // Filter for progressive MP4 formats (combining audio/video like formats 18/94)
      final streamInfo = manifest.muxed.sortByVideoQuality().first;
      final String playUri = streamInfo.url.toString();
      
      yt.close(); // Clean up memory

      _updateStatus("Transmitting media payload to device...");

      // Send the native DLNA SOAP command directly to your TV over the network
      await _sendDlnaAction('SetAVTransportURI', '''
        <CurrentURI>$playUri</CurrentURI>
        <CurrentURIMetaData></CurrentURIMetaData>
      ''');

      // Instantly fire the play instruction
      await _sendDlnaAction('Play', '<Speed>1</Speed>');

      _updateStatus("Status: Done!!! Playing on device.", enableButton: true);
    } catch (e) {
      _updateStatus("Status: Failed - ${e.toString()}", enableButton: true);
    }
  }

  // TRANSPORT CONTROL WORKER: Handles Play, Pause, Stop asynchronously
  Future<void> _triggerDlnaCommand(String action) async {
    _updateStatus("Status: Sending $action command...");
    try {
      if (action == 'Play') {
        await _sendDlnaAction('Play', '<Speed>1</Speed>');
        _updateStatus("Status: Resumed playback.");
      } else if (action == 'Pause') {
        await _sendDlnaAction('Pause', '');
        _updateStatus("Status: Paused.");
      } else if (action == 'Stop') {
        await _sendDlnaAction('Stop', '');
        _updateStatus("Status: Stopped.");
      }
    } catch (e) {
      _updateStatus("Status: Control Failed - ${e.toString()}");
    }
  }

  // Native raw DLNA/UPnP network transmitter hook
  Future<void> _sendDlnaAction(String action, String arguments) async {
    // Standard UPnP header template wrapper mapping to your Python d.AVTransport endpoints
    final url = Uri.parse('http://192.168.1'); // Change if device endpoint differs
    
    final soapBody = '''<?xml version="1.0" encoding="utf-8"?>
    <s:Envelope xmlns:s="http://xmlsoap.org" s:encodingStyle="http://xmlsoap.org">
      <s:Body>
        <u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
          <InstanceID>0</InstanceID>
          $arguments
        </u:$action>
      </s:Body>
    </s:Envelope>''';

    await http.post(
      url,
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPACTION': '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
      },
      body: soapBody,
    ).timeout(const Duration(seconds: 8));
  }

  // VISUAL LAYOUT GENERATOR: Mirrors your exact visual design
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DLNA Caster GUI')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Device Info Header
            Text(
              "Target Device: $_primaryUri",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            
            // 2. Status Label
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // 3. YouTube URL Text Input Field
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'Paste YouTube video URL here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            
            // 4. Horizontal Control Row for Buttons
            Row(
              children: [
                // Cast Trigger Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                    onPressed: _isCastButtonDisabled ? null : _startCastingProcess,
                    child: const Text('Cast Video', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Pause Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () => _triggerDlnaCommand('Pause'),
                    child: const Text('Pause', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Resume Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _triggerDlnaCommand('Play'),
                    child: const Text('Resume', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Stop Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _triggerDlnaCommand('Stop'),
                    child: const Text('Stop', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
