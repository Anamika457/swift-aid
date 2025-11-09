import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CPRTutorialScreen extends StatefulWidget {
  const CPRTutorialScreen({super.key});

  @override
  State<CPRTutorialScreen> createState() => _CPRTutorialScreenState();
}

class _CPRTutorialScreenState extends State<CPRTutorialScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _currentStep = 0;

  final List<Map<String, String>> _steps = [
    {
      "title": "Step 1 of 5",
      "desc":
          "Place your hands in the center of the chest, one on top of the other. Keep your arms straight."
    },
    {
      "title": "Step 2 of 5",
      "desc":
          "Push hard and fast at a rate of about 100–120 compressions per minute. Allow the chest to rise completely after each push."
    },
    {
      "title": "Step 3 of 5",
      "desc":
          "After 30 compressions, tilt the person’s head back and lift their chin. Pinch their nose shut."
    },
    {
      "title": "Step 4 of 5",
      "desc":
          "Give 2 rescue breaths, watching for the chest to rise. Continue with 30 compressions followed by 2 breaths."
    },
    {
      "title": "Step 5 of 5",
      "desc":
          "Repeat cycles of compressions and breaths until emergency help arrives or the person shows signs of life."
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);
    _loadModelAsHtml();
  }

  Future<void> _loadModelAsHtml() async {
    try {
      final bytes = await rootBundle.load('assets/cpr_final3.glb');
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
          html, body {
            margin: 0;
            height: 100%;
            overflow: hidden;
            background-color: transparent;
          }
          model-viewer {
            width: 100%;
            height: 100%;
            border-radius: 20px;
          }
        </style>
      </head>
      <body>
        <model-viewer id="mv"
          src="data:model/gltf-binary;base64,$base64Model"
          alt="CPR 3D Animated Model"
          autoplay
          ar
          auto-rotate
          camera-controls
          animation-loop
          exposure="1"
          shadow-intensity="1">
        </model-viewer>

        <script>
          const mv = document.querySelector('#mv');
          mv.addEventListener('load', () => {
            const animations = mv.availableAnimations || [];
            if (animations.length > 0) {
              animations.forEach(name => {
                mv.play({ animationName: name, repetitions: Infinity });
              });
            }
          });
        </script>
      </body>
      </html>
      ''';

      _controller
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => setState(() => _isLoading = false),
          ),
        )
        ..loadHtmlString(html);
    } catch (e) {
      debugPrint('Error loading model: $e');
    }
  }

  void _nextStep() {
    setState(() {
      if (_currentStep < _steps.length - 1) {
        _currentStep++;
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CPR Tutorial',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Bigger 3D model container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.45, // ✅ Bigger
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
                const Positioned(
                  right: 16,
                  top: 14,
                  child: Text(
                    '360° View',
                    style: TextStyle(
                      color: Color(0xFF8A94A6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(), // Push everything below downwards

          // Step description box near bottom
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
                Text(
                  current["title"]!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  current["desc"]!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6C7A9C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Navigation Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _previousStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
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
