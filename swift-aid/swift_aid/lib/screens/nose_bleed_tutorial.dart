import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NoseBleedTutorialScreen extends StatefulWidget {
  const NoseBleedTutorialScreen({super.key});

  @override
  State<NoseBleedTutorialScreen> createState() => _NoseBleedTutorialScreenState();
}

class _NoseBleedTutorialScreenState extends State<NoseBleedTutorialScreen> {
  late final WebViewController _controller;
  late FlutterTts flutterTts;

  bool _isLoading = true;
  int _currentStep = 0;

  bool isSpeaking = false;
  bool isPaused = false;
  List<String> _chunks = [];
  int _chunkIndex = 0;

  final List<Map<String, String>> _steps = [
  {
    "title": "Step 1 of 5",
    "desc":
        "Stay calm and have the person sit upright. Lean them slightly forward to prevent blood from flowing into the throat."
  },
  {
    "title": "Step 2 of 5",
    "desc":
        "Pinch the soft part of the nose (just below the bony bridge) using your thumb and index finger. Apply firm, steady pressure."
  },
  {
    "title": "Step 3 of 5",
    "desc":
        "Keep pinching the nose continuously for 10 minutes. Do not release the pressure to check if the bleeding has stopped."
  },
  {
    "title": "Step 4 of 5",
    "desc":
        "Place a cold pack or cloth-wrapped ice on the bridge of the nose to slow bleeding. Ask the person to breathe through their mouth."
  },
  {
    "title": "Step 5 of 5",
    "desc":
        "If bleeding continues for more than 20 minutes, or if it is very heavy, seek medical help immediately."
  },
];


  @override
  void initState() {
    super.initState();

    flutterTts = FlutterTts();
    flutterTts.setSpeechRate(0.48);
    flutterTts.setPitch(1.0);
    flutterTts.setVolume(1.0);

    flutterTts.setStartHandler(() {
      setState(() {
        isSpeaking = true;
        isPaused = false;
      });
    });

    flutterTts.setCompletionHandler(() {
      if (_chunkIndex < _chunks.length - 1 && !isPaused) {
        _chunkIndex++;
        _speakChunk(_chunkIndex);
      } else {
        setState(() {
          isSpeaking = !isPaused;
          if (!isPaused) {
            _chunks = [];
            _chunkIndex = 0;
          }
        });
      }
    });

    flutterTts.setPauseHandler(() {
      setState(() {
        isSpeaking = false;
        isPaused = true;
      });
    });

    flutterTts.setErrorHandler((_) {
      setState(() {
        isSpeaking = false;
        isPaused = false;
      });
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);

    _loadModelAsHtml();
  }

  List<String> _splitIntoChunks(String text) {
    return text.split(RegExp(r'(?<=[.?!])\s+')).map((e) => e.trim()).toList();
  }

  Future<void> speakCurrentStep() async {
    final text = _steps[_currentStep]["desc"]!;
    _chunks = _splitIntoChunks(text);
    _chunkIndex = 0;

    await flutterTts.stop();

    if (_chunks.isEmpty) return;

    setState(() {
      isPaused = false;
      isSpeaking = true;
    });

    await _speakChunk(0);
  }

  Future<void> _speakChunk(int index) async {
    if (index >= _chunks.length) return;

    try {
      await flutterTts.speak(_chunks[index]);
    } catch (_) {
      await flutterTts.stop();
      await flutterTts.speak(_chunks[index]);
    }
  }

  Future<void> pauseSpeech() async {
    try {
      await flutterTts.pause();
    } catch (_) {
      await flutterTts.stop();
    }

    setState(() {
      isPaused = true;
      isSpeaking = false;
    });
  }

  Future<void> resumeSpeech() async {
    if (_chunks.isEmpty) {
      speakCurrentStep();
      return;
    }

    setState(() {
      isPaused = false;
      isSpeaking = true;
    });

    await _speakChunk(_chunkIndex);
  }

  Future<void> stopSpeech() async {
    await flutterTts.stop();
    setState(() {
      isPaused = false;
      isSpeaking = false;
      _chunks = [];
      _chunkIndex = 0;
    });
  }

  // 🔥 FIXED: RESTORED FULL ANIMATION SEQUENCING LIKE CHOKING SCREEN
  Future<void> _loadModelAsHtml() async {
    try {
      final bytes = await rootBundle.load('assets/nose_bleed.glb');
      final base64Model = base64Encode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );

      final html = '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <script type="module" src="https://unpkg.com/@google/model-viewer/dist/model-viewer.min.js"></script>
        <style>
          html, body { margin: 0; height: 100%; overflow: hidden; background: transparent; }
          model-viewer { width: 100%; height: 100%; border-radius: 20px; }
        </style>
      </head>
      <body>

        <model-viewer id="mv"
          src="data:model/gltf-binary;base64,$base64Model"
          camera-controls
          auto-rotate
          exposure="1"
          shadow-intensity="1">
        </model-viewer>

        <script>
          const mv = document.querySelector('#mv');

          mv.addEventListener('load', async () => {
            await mv.updateComplete;

            const animations = mv.availableAnimations || [];
            if (animations.length === 0) return;

            let idx = 0;
            let busy = false;

            async function playNext() {
              if (busy) return;
              busy = true;

              const anim = animations[idx];
              mv.play({ animationName: anim, repetitions: 1 });

              mv.addEventListener('finished', () => {
                idx = (idx + 1) % animations.length;

                setTimeout(() => {
                  busy = false;
                  playNext();
                }, 300);
              }, { once: true });
            }

            playNext();
          });
        </script>

      </body>
      </html>
      ''';

      _controller
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ))
        ..loadHtmlString(html);
    } catch (e) {
      debugPrint("Model Load Error: $e");
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      speakCurrentStep();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      speakCurrentStep();
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps[_currentStep];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () {
            stopSpeech();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Nose Bleed Tutorial',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAFF),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: WebViewWidget(controller: _controller),
              ),
            ),
          ),

          const Spacer(),

          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(current["title"]!,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A202C))),
                const SizedBox(height: 12),
                Text(
                  current["desc"]!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6C7A9C),
                      height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  isSpeaking ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 45,
                  color: isSpeaking ? Colors.orange : Colors.green,
                ),
                onPressed: () {
                  if (isSpeaking) {
                    pauseSpeech();
                  } else if (isPaused) {
                    resumeSpeech();
                  } else {
                    speakCurrentStep();
                  }
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined,
                    size: 45, color: Colors.red),
                onPressed: stopSpeech,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _previousStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
