// lib/screens/cam.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import 'package:swift_aid/api.dart';

class FirstAidCamera extends StatefulWidget {
  const FirstAidCamera({super.key});

  @override
  State<FirstAidCamera> createState() => _FirstAidCameraState();
}

class _FirstAidCameraState extends State<FirstAidCamera>
    with WidgetsBindingObserver {
  // --------------------------------------------------------
  // CAMERA
  // --------------------------------------------------------
  CameraController? controller;
  bool cameraReady = false;

  // --------------------------------------------------------
  // AI RESULT
  // --------------------------------------------------------
  String result = "Camera initializing… Tap 'Analyze' when ready.";
  bool isApiCallActive = false;

  bool isCameraFullscreen = false;
  bool isTextFullscreen = false;

  DateTime? lastCall;
  final Duration cooldown = const Duration(seconds: 5);

  // --------------------------------------------------------
  // TTS (robust, no .resume())
  // --------------------------------------------------------
  final FlutterTts _tts = FlutterTts();

  bool _isSpeaking = false;   // true when TTS engine is currently speaking a chunk
  bool _isPaused = false;     // true when user paused (playback stopped but index preserved)
  bool _isStopped = false;    // true after explicit Stop

  List<String> _ttsChunks = [];
  int _currentChunkIndex = 0;
  String _currentFullText = "";

  Completer<void>? _chunkCompleter;
  Completer<void>? _resumeCompleter;
  bool _isPlayingChunks = false;

  bool _wasSpeakingBeforePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTTS();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  // --------------------------------------------------------
  // App lifecycle (pause/resume)
  // --------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isSpeaking && !_isPaused) {
        _wasSpeakingBeforePause = true;
        _pauseSpeaking();
      } else {
        _wasSpeakingBeforePause = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasSpeakingBeforePause && _isPaused) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _resumeSpeaking();
        });
      }
    }
  }

  // --------------------------------------------------------
  // Clean markdown
  // --------------------------------------------------------
  String cleanMarkdown(String input) {
    String text = input;
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'`([^`]*)`'), r'\1');
    text = text.replaceAll(RegExp(r'[*_]{1,3}([^*_]+)[*_]{1,3}'), r'\1');
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+[\.\)]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'[\\#\[\]\(\)]'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.trim();
    return text;
  }

  // --------------------------------------------------------
  // TTS init & handlers
  // --------------------------------------------------------
  Future<void> _initTTS() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    // Called when the engine finishes speaking a chunk
    _tts.setCompletionHandler(() {
      // only proceed if not paused/stopped
      if (!_isPaused && !_isStopped) {
        _currentChunkIndex++;
        if (_currentChunkIndex < _ttsChunks.length) {
          _playCurrentChunk();
        } else {
          // finished all chunks
          _isSpeaking = false;
          _isPlayingChunks = false;
          if (mounted) setState(() {});
        }
      } else {
        // if paused/stopped, ensure speaking flag updated
        if (mounted) setState(() => _isSpeaking = false);
      }

      // ensure any waiting completer is completed so loop doesn't hang
      if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
        _chunkCompleter!.complete();
      }
    });

    _tts.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
      if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
        _chunkCompleter!.complete();
      }
    });
  }

  // --------------------------------------------------------
  // chunking helper
  // --------------------------------------------------------
  List<String> _chunkify(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length == 1 && sentences.first.length > 200) {
      final byComma = sentences.first.split(RegExp(r',\s*'));
      if (byComma.length > 1) return byComma.where((s) => s.trim().isNotEmpty).toList();
      final parts = <String>[];
      final s = sentences.first;
      for (int i = 0; i < s.length; i += 200) {
        parts.add(s.substring(i, i + 200 > s.length ? s.length : i + 200));
      }
      return parts.where((s) => s.trim().isNotEmpty).toList();
    }
    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }

  // --------------------------------------------------------
  // start speaking (from beginning)
  // --------------------------------------------------------
  Future<void> _speak(String text) async {
    // ensure engine stopped first
    try {
      await _tts.stop();
    } catch (_) {}

    _currentFullText = text;
    _ttsChunks = _chunkify(text);
    _currentChunkIndex = 0;
    _isPaused = false;
    _isStopped = false;
    _isPlayingChunks = true;

    if (_ttsChunks.isNotEmpty) {
      _playCurrentChunk();
    } else {
      setState(() {
        _isSpeaking = false;
        _isPlayingChunks = false;
      });
    }
  }

  // --------------------------------------------------------
  // play current chunk (re-speaks the chunk at current index)
  // --------------------------------------------------------
  Future<void> _playCurrentChunk() async {
    if (_currentChunkIndex >= _ttsChunks.length) {
      _isSpeaking = false;
      _isPlayingChunks = false;
      if (mounted) setState(() {});
      return;
    }

    final chunk = _ttsChunks[_currentChunkIndex];
    try {
      // ensure flags
      _isSpeaking = true;
      if (mounted) setState(() {});
      await _tts.speak(chunk);
    } catch (e) {
      debugPrint("TTS play error: $e");
      // if speak throws, increment index to avoid infinite loop
      _currentChunkIndex++;
      if (_currentChunkIndex < _ttsChunks.length && !_isPaused && !_isStopped) {
        _playCurrentChunk();
      } else {
        _isSpeaking = false;
        _isPlayingChunks = false;
        if (mounted) setState(() {});
      }
    }
  }

  // --------------------------------------------------------
  // pause: stop the engine but keep chunk index so we can resume by re-speaking it
  // --------------------------------------------------------
  Future<void> _pauseSpeaking() async {
    if (!_isSpeaking || _isPaused) return;
    _isPaused = true;
    _isSpeaking = false;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint("Pause(stop) error: $e");
    }
    if (mounted) setState(() {});
  }

  // --------------------------------------------------------
  // resume: re-speak the current chunk (no .resume())
  // --------------------------------------------------------
  Future<void> _resumeSpeaking() async {
    if (!_isPaused) return;
    _isPaused = false;
    _isStopped = false;
    if (mounted) setState(() {});
    // re-speak current chunk
    _playCurrentChunk();
  }

  // --------------------------------------------------------
  // stop: stop engine and reset everything so play restarts from beginning
  // --------------------------------------------------------
  Future<void> _stopSpeaking() async {
    // mark stopped so completion handler doesn't advance
    _isStopped = true;
    _isPaused = false;
    _isSpeaking = false;

    try {
      await _tts.stop();
    } catch (e) {
      debugPrint("Stop error: $e");
    }

    // clear arrays and reset index
    _ttsChunks = [];
    _currentChunkIndex = 0;
    _isPlayingChunks = false;

    // complete any awaiting completers to avoid deadlocks
    if (_chunkCompleter != null && !_chunkCompleter!.isCompleted) {
      _chunkCompleter!.complete();
    }
    if (_resumeCompleter != null && !_resumeCompleter!.isCompleted) {
      _resumeCompleter!.complete();
    }

    if (mounted) setState(() {});
  }

  // --------------------------------------------------------
  // CAMERA init
  // --------------------------------------------------------
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      controller = CameraController(
        cams.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller!.initialize();
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          cameraReady = true;
          result =
              "Camera ready.\n\nTap 'Analyze' to detect injuries and get first-aid steps.";
        });
      }
    } catch (e) {
      setState(() => result = "Camera Error: $e");
    }
  }

  // --------------------------------------------------------
  // capture & analyze
  // --------------------------------------------------------
  Future<void> captureAndAnalyze() async {
    if (!cameraReady) return;
    if (isApiCallActive) return;

    if (lastCall != null &&
        DateTime.now().difference(lastCall!) < cooldown) {
      setState(() => result =
          "Please wait ${cooldown.inSeconds}s before re-analyzing.");
      return;
    }

    await _stopSpeaking();

    setState(() {
      isApiCallActive = true;
      result = "Analyzing…";
      isTextFullscreen = false;
    });

    XFile file;
    try {
      file = await controller!.takePicture();
    } catch (e) {
      setState(() {
        result = "Capture Error: $e";
        isApiCallActive = false;
      });
      return;
    }

    final bytes = await file.readAsBytes();

    try {
      final raw = await _sendToGemini(bytes);
      final cleaned = cleanMarkdown(raw);

      setState(() => result = cleaned);

      await _speak(cleaned);

      lastCall = DateTime.now();
    } catch (e) {
      setState(() => result = "AI Error: $e");
    }

    setState(() => isApiCallActive = false);
  }

  // --------------------------------------------------------
  // Gemini API
  // --------------------------------------------------------
  Future<String> _sendToGemini(Uint8List bytes) async {
    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$geminiApiKey");

    final body = {
      "contents": [
        {
          "parts": [
            {
              "text":
                  "Analyze this injury and provide FIRST AID steps in PLAIN TEXT ONLY. No markdown, no lists, no symbols. Use short, spoken instructions."
            },
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Encode(bytes)
              }
            }
          ]
        }
      ]
    };

    final r = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final json = jsonDecode(r.body);

    if (json["error"] != null) {
      return "AI Error: ${json['error']['message']}";
    }

    return json["candidates"][0]["content"]["parts"][0]["text"];
  }

  // --------------------------------------------------------
  // UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    double camH =
        isTextFullscreen ? 0 : (isCameraFullscreen ? h * 0.8 : h * 0.45);

    final ready = controller != null && controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isTextFullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0.3,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black),
                onPressed: () {
                  _stopSpeaking();
                  Navigator.pop(context);
                },
              ),
              title: const Text(
                "First Aid AI",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

      body: Stack(
        children: [
          // camera preview
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: 0,
            left: 0,
            right: 0,
            height: camH,
            child: Container(
              margin:
                  EdgeInsets.symmetric(horizontal: isTextFullscreen ? 0 : 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius:
                    BorderRadius.circular(isTextFullscreen ? 0 : 22),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(isTextFullscreen ? 0 : 22),
                child: ready
                    ? CameraPreview(controller!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),

          // response sheet
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            left: isTextFullscreen ? 0 : 20,
            right: isTextFullscreen ? 0 : 20,
            bottom: 0,
            height: isTextFullscreen ? h : h * 0.38,
            child: GestureDetector(
              onVerticalDragUpdate: (d) {
                if (d.primaryDelta! < -12) {
                  setState(() => isTextFullscreen = true);
                } else if (d.primaryDelta! > 12) {
                  setState(() => isTextFullscreen = false);
                }
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  isTextFullscreen
                      ? MediaQuery.of(context).padding.top + 16
                      : 20,
                  20,
                  20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: isTextFullscreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(18),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTextFullscreen
                              ? "STEP-BY-STEP INSTRUCTIONS"
                              : "AI First Aid Steps",
                          style: TextStyle(
                            fontSize: isTextFullscreen ? 20 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        // show header controls only when not fullscreen
                        if (!isTextFullscreen)
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  (!_isSpeaking && !_isPaused)
                                      ? Icons.play_circle_fill
                                      : (_isPaused ? Icons.play_circle_filled : Icons.pause_circle_filled),
                                  color: Colors.redAccent,
                                  size: 34,
                                ),
                                onPressed: () {
                                  if (!_isSpeaking && !_isPaused) {
                                    // not speaking -> start from beginning
                                    _speak(result);
                                  } else if (_isPaused) {
                                    _resumeSpeaking();
                                  } else {
                                    _pauseSpeaking();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.stop_rounded,
                                  color: Colors.redAccent,
                                  size: 34,
                                ),
                                onPressed: _stopSpeaking,
                              ),
                            ],
                          ),
                      ],
                    ),

                    // when fullscreen, show controls under header
                    if (isTextFullscreen)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                (!_isSpeaking && !_isPaused)
                                    ? Icons.play_circle_fill
                                    : (_isPaused ? Icons.play_circle_filled : Icons.pause_circle_filled),
                                color: Colors.redAccent,
                                size: 40,
                              ),
                              onPressed: () {
                                if (!_isSpeaking && !_isPaused) {
                                  _speak(result);
                                } else if (_isPaused) {
                                  _resumeSpeaking();
                                } else {
                                  _pauseSpeaking();
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(
                                Icons.stop_rounded,
                                color: Colors.redAccent,
                                size: 40,
                              ),
                              onPressed: _stopSpeaking,
                            ),
                          ],
                        ),
                      ),

                    // result text
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          result,
                          style: TextStyle(
                            fontSize: isTextFullscreen ? 18 : 15,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // recapture
                    ElevatedButton(
                      onPressed: isApiCallActive ? null : captureAndAnalyze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isApiCallActive
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "RECAPTURE / ANALYZE AGAIN",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
