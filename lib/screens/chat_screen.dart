import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Reusing your simple GoogleFonts class
class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String deviceId;

  const ChatScreen({super.key, this.deviceId = "2"});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Chat History - Initialized in initState to access 'widget'
  late final List<Map<String, String>> _messages;
  
  // Track conversation session for persistent context
  String? _conversationId;
  
  bool _isLoading = false;

  // Production API URL - Removed trailing slash
  final String _apiUrl = "https://kesanai.onrender.com/ask"; 

  // --- List of Sensor Features ---
  final List<String> _sensorFeatures = [
    "Temperature",
    "Rainfall",
    "Light Intensity",
    "Leaf Wetness",
    "Humidity",
    "Wind",
    "Atmospheric Pressure",
    "Soil Health",
  ];

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        'from': 'ai', 
        'text': 'Hello! I am your Grid Sphere Farm Assistant. I have access to your sensor data for Device ID: ${widget.deviceId}. How can I help you today?'
      }
    ];
  }

  Future<void> _sendMessage({String? customMessage}) async {
    final textToSend = customMessage ?? _controller.text.trim();
    if (textToSend.isEmpty) return;

    setState(() {
      _messages.add({'from': 'user', 'text': textToSend});
      _isLoading = true;
    });
    
    _controller.clear();
    _scrollToBottom();

    try {
      debugPrint("Sending request to: $_apiUrl");
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          // Standard Mobile User-Agent to satisfy Render's routing
          "User-Agent": "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36", 
        },
        body: jsonEncode({
          "message": textToSend,
          "device_id": widget.deviceId.toString(),
          "conversation_id": _conversationId, 
        }),
      ).timeout(const Duration(seconds: 60)); 

      debugPrint("Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          final aiResponse = data['response'] ?? "I processed your request but have no response text.";
          _conversationId = data['conversation_id']; 
          
          _messages.add({'from': 'ai', 'text': aiResponse});
        });
      } else if (response.statusCode == 503) {
        // Specific handling for Service Suspended/Unavailable
        setState(() {
          _messages.add({
            'from': 'ai', 
            'text': "The Kisan AI service is currently suspended or undergoing maintenance. Please check back later."
          });
        });
      } else {
        setState(() {
          _messages.add({
            'from': 'ai', 
            'text': "Server Error (${response.statusCode}). The request reached the server but was rejected."
          });
        });
      }
    } catch (e) {
      debugPrint("Chat Exception: $e");
      setState(() {
        _messages.add({
          'from': 'ai', 
          'text': "Connection failed. Error: $e" 
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _onFeatureTap(String feature) {
    _sendMessage(customMessage: "What is the status of $feature for my field?");
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF166534), // Brand Green
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kisan AI",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "Online • Device ${widget.deviceId}",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw, color: Colors.white, size: 20),
            onPressed: () {
              setState(() {
                _messages.clear();
                _conversationId = null; // Clear context
                _messages.add({'from': 'ai', 'text': 'Chat context cleared. How can I help you now?'});
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat History
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadingBubble();
                }
                
                final msg = _messages[index];
                final isUser = msg['from'] == 'user';
                
                return _buildMessageBubble(msg['text']!, isUser);
              },
            ),
          ),
          
          // --- Quick Feature Actions ---
          _buildQuickActions(),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF166534) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.circular(4),
            bottomRight: isUser ? Radius.circular(4) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isUser ? Colors.white : const Color(0xFF374151),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 50,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sensorFeatures.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: ActionChip(
              label: Text(
                _sensorFeatures[index],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF166534),
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              pressElevation: 2,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              onPressed: () => _onFeatureTap(_sensorFeatures[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Ask Kisan AI anything...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey : const Color(0xFF166534),
                shape: BoxShape.circle,
                boxShadow: [
                  if (!_isLoading)
                    BoxShadow(
                      color: const Color(0xFF166534).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14, 
              height: 14, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF166534))
            ),
            const SizedBox(width: 12),
            Text(
              "Kisan AI is thinking...",
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}