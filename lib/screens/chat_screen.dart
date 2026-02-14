import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/home_back_button.dart';
import '../widgets/home_pop_scope.dart'; // Import HomePopScope

// Simple GoogleFonts fallback
class GoogleFonts {
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
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

  late final List<Map<String, String>> _messages;
  String? _conversationId;
  bool _isLoading = false;

  final String _apiUrl = "https://kesan.onrender.com/api/chat";

  final List<String> _sensorFeatures = [
    "Temperature",
    "Rainfall",
    "Light Intensity",
    "Leaf Wetness",
    "Humidity",
    "Wind",
    "Soil Health",
  ];

  @override
  void initState() {
    super.initState();
    // A much friendlier, welcoming starting message
    _messages = [
      {
        'from': 'ai',
        'text':
            "Namaste! 剌 I'm your Kisan AI companion from Grid Sphere. 言\n\nI'm here to help you keep a close eye on your farm. I have your real-time data for Device ${widget.deviceId} ready! \n\nHow is your field doing today? Would you like me to check the soil health or recent rainfall for you?"
      }
    ];
  }

  Future<void> _sendMessage({String? customMessage}) async {
    final textToSend = customMessage ?? _controller.text.trim();
    if (textToSend.isEmpty) return;

    if (mounted) {
      setState(() {
        _messages.add({'from': 'user', 'text': textToSend});
        _isLoading = true;
      });
    }

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              "Content-Type": "application/json",
              "User-Agent":
                  "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
            },
            body: jsonEncode({
              "message": textToSend,
              "device_id": widget.deviceId.toString(),
              "conversation_id": _conversationId,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          final aiResponse = data['response'] ??
              "I've processed your data but couldn't generate a text response. Please try again.";
          _conversationId = data['conversation_id'];
          _messages.add({'from': 'ai', 'text': aiResponse});
        });
      } else {
        setState(() {
          _messages.add({
            'from': 'ai',
            'text':
                "I'm having a little trouble connecting to the field experts right now. Please try again in a moment! 囿"
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'from': 'ai',
            'text':
                "It seems I've lost my connection to the sensors. Let me check my signal and try again soon! 藤"
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom();
    }
  }

  void _onFeatureTap(String feature) {
    _sendMessage(
        customMessage: "Can you give me a summary of the $feature data?");
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
    // --- UPDATED: Use HomePopScope Wrapper ---
    return HomePopScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Light background
        appBar: AppBar(
          backgroundColor: const Color(0xFF166534),
          elevation: 0,
          leading: const HomeBackButton(),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(LucideIcons.bot, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Kisan AI",
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  Text(
                    "Smart Farm Assistant",
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.rotateCcw,
                  color: Colors.white, size: 20),
              tooltip: "Clear Chat",
              onPressed: () {
                setState(() {
                  _messages.clear();
                  _conversationId = null;
                  _messages
                      .add({'from': 'ai', 'text': 'How can I help you now?'});
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Decorative Background Elements
            Positioned(
              bottom: 100,
              right: -50,
              child: Icon(LucideIcons.leaf,
                  size: 300, color: const Color(0xFF166534).withOpacity(0.03)),
            ),
            Positioned(
              top: 50,
              left: -30,
              child: Icon(LucideIcons.sprout,
                  size: 150, color: const Color(0xFF166534).withOpacity(0.03)),
            ),

            Column(
              children: [
                // Chat History
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
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

                // Quick Actions
                _buildQuickActions(),

                // Input Area
                _buildInputArea(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot icon container removed to simplify the chat box UI
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF166534) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft:
                      isUser ? const Radius.circular(20) : Radius.circular(4),
                  bottomRight:
                      isUser ? Radius.circular(4) : const Radius.circular(20),
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
                  color: isUser ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sensorFeatures.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
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
              pressElevation: 0,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              onPressed: () => _onFeatureTap(_sensorFeatures[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Type your farm query...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey[300] : const Color(0xFF166534),
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
              child: Icon(_isLoading ? LucideIcons.loader2 : LucideIcons.send,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 5,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF166534))),
                const SizedBox(width: 12),
                Text(
                  "Analyzing field data...",
                  style:
                      GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
