import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:swift_aid/chat_service.dart';
import 'package:swift_aid/message.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;

  // Speech and TTS
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;

  // TTS playback states
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isStopped = false;

  // Chunk playback helpers
  List<String> _ttsChunks = [];
  int _currentChunkIndex = 0;
  Completer<void>? _chunkCompleter;
  Completer<void>? _resumeCompleter;
  bool _isPlayingChunks = false;

  // Mic animation
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTTS();

    // mic pulse animation
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
          ..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.48);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
        _chunkCompleter!.complete();
      }
    });

    _flutterTts.setCancelHandler(() {
      if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
        _chunkCompleter!.complete();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
      if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
        _chunkCompleter!.complete();
      }
    });
  }

  /// 🧹 Clean Markdown text before TTS so it sounds natural
  String _stripMarkdown(String input) {
    var text = input;

    // Remove Markdown headers (#, ##, etc.)
    text = text.replaceAll(RegExp(r'(^|\s)#{1,6}\s*'), ' ');

    // Remove bold/italic markers
    text = text.replaceAll(RegExp(r'(\*\*|__|\*|_)'), '');

    // Remove inline code and backticks
    text = text.replaceAll(RegExp(r'`([^`]*)`'), r'\1');

    // Remove links [text](url)
    text = text.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (match) => match.group(1) ?? '');

    // Remove images ![alt](url)
    text = text.replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'), (match) => match.group(1) ?? '');

    // Replace list bullets (-, *, +) with small pauses
    text = text.replaceAll(RegExp(r'(^|\n)[\-\*\+]\s+'), '\n• ');

    // Remove blockquotes ("> ")
    text = text.replaceAll(RegExp(r'(^|\n)>\s+'), '\n');

    // Remove extra whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Split text into manageable chunks for smooth playback
  List<String> _splitIntoChunks(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

    if (sentences.length == 1) {
      final longText = sentences.first;
      if (longText.length > 200) {
        final commas = longText.split(RegExp(r',\s*'));
        if (commas.length > 1) return commas;
        final chunks = <String>[];
        for (var i = 0; i < longText.length; i += 200) {
          chunks.add(longText.substring(
            i,
            i + 200 > longText.length ? longText.length : i + 200,
          ));
        }
        return chunks;
      }
    }

    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    _ttsChunks = _splitIntoChunks(text);
    _currentChunkIndex = 0;
    _isPaused = false;
    _isStopped = false;

    if (_ttsChunks.isNotEmpty && !_isPlayingChunks) {
      _playChunks();
    }
  }

  Future<void> _playChunks() async {
    _isPlayingChunks = true;
    if (mounted) setState(() => _isSpeaking = true);

    while (_currentChunkIndex < _ttsChunks.length && !_isStopped) {
      final chunk = _ttsChunks[_currentChunkIndex].trim();
      if (chunk.isEmpty) {
        _currentChunkIndex++;
        continue;
      }

      _chunkCompleter = Completer<void>();
      try {
        await _flutterTts.speak(chunk);
      } catch (e) {
        debugPrint("TTS speak() error: $e");
        if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
          _chunkCompleter!.complete();
        }
      }

      await _chunkCompleter!.future;

      if (_isPaused && !_isStopped) {
        _resumeCompleter = Completer<void>();
        await _resumeCompleter!.future;
        _resumeCompleter = null;
      }

      if (!_isStopped) _currentChunkIndex++;
    }

    _isPlayingChunks = false;
    if (mounted) setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _isStopped = false;
    });
  }

  Future<void> _pauseSpeaking() async {
    if (!_isSpeaking || _isPaused) return;
    if (mounted) setState(() => _isPaused = true);
    await _flutterTts.stop();
  }

  Future<void> _resumeSpeaking() async {
    if (!_isSpeaking || !_isPaused) return;
    if (mounted) setState(() => _isPaused = false);
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    } else if (!_isPlayingChunks && _currentChunkIndex < _ttsChunks.length) {
      _playChunks();
    }
  }

  Future<void> _stopSpeaking() async {
    if (!_isSpeaking && !_isPaused) return;
    _isStopped = true;
    _isPaused = false;
    await _flutterTts.stop();
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    }
    _ttsChunks = [];
    _currentChunkIndex = 0;

    if (mounted) setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _isStopped = false;
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(text, true));
      _isLoading = true;
    });
    _controller.clear();

    final reply = await _chatService.sendMessage(text);
    if (!mounted) return;
    setState(() {
      _messages.add(Message(reply, false));
      _isLoading = false;
    });

    // Clean Markdown before speaking
    final cleanedReply = _stripMarkdown(reply);
    await _speak(cleanedReply);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == "notListening") setState(() => _isListening = false);
        },
        onError: (error) {
          debugPrint("Speech error: $error");
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Assistant", style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Tell me what's happening and I'll guide you.",
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.isUser;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.redAccent : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: isUser
                        ? Text(
                            msg.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          )
                        : MarkdownBody(
                            data: msg.text,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 🎤 Mic with pulse animation
                ScaleTransition(
                  scale: _isListening ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                  child: GestureDetector(
                    onTap: _listen,
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: _isListening
                          ? Colors.redAccent.withOpacity(0.9)
                          : Colors.grey.shade300,
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 🔊 Voice control buttons
                if (_isSpeaking)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: Colors.redAccent,
                        ),
                        tooltip: _isPaused ? "Resume" : "Pause",
                        onPressed: _isPaused ? _resumeSpeaking : _pauseSpeaking,
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_rounded, color: Colors.redAccent),
                        tooltip: "Stop",
                        onPressed: _stopSpeaking,
                      ),
                    ],
                  ),

                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Type or speak your question...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.redAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
