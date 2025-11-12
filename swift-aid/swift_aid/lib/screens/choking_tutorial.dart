import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChokingTutorialScreen extends StatefulWidget {
  const ChokingTutorialScreen({super.key});

  @override
  State<ChokingTutorialScreen> createState() => _ChokingTutorialScreenState();
}

class _ChokingTutorialScreenState extends State<ChokingTutorialScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _currentStep = 0;

  // ✅ Step-by-step choking first aid instructions
  final List<Map<String, String>> _steps = [
    {
      "title": "Step 1 of 5",
      "desc":
          "Ask the person, 'Are you choking?' If they can’t speak, cough, or breathe, proceed immediately."
    },
    {
      "title": "Step 2 of 5",
      "desc":
          "Stand behind the person and wrap your arms around their waist. Lean them slightly forward."
    },
    {
      "title": "Step 3 of 5",
      "desc":
          "Make a fist and place it just above their navel. Grasp your fist with your other hand."
    },
    {
      "title": "Step 4 of 5",
      "desc":
          "Perform quick, inward and upward thrusts (Heimlich maneuver) to try to expel the object."
    },
    {
      "title": "Step 5 of 5",
      "desc":
          "If the person becomes unresponsive, start CPR immediately and call for emergency help."
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

  // ✅ Sequential animation loader for choking.glb
  Future<void> _loadModelAsHtml() async {
    try {
      final bytes = await rootBundle.load('assets/choking.glb');
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
          alt="Choking First Aid 3D Animated Model"
          ar
          auto-rotate
          camera-controls
          exposure="1"
          shadow-intensity="1">
        </model-viewer>

        <script>
          const mv = document.querySelector('#mv');

          mv.addEventListener('load', async () => {
            await mv.updateComplete;
            const animations = mv.availableAnimations || [];
            console.log('Animations found:', animations);

            if (animations.length === 0) return;

            let currentIndex = 0;
            let isTransitioning = false;

            async function playNext() {
              if (isTransitioning) return;
              isTransitioning = true;

              const name = animations[currentIndex];
              console.log('Playing animation:', name);
              
              mv.play({ animationName: name, repetitions: 1 });

              // Listen for when the animation ends
              mv.addEventListener('finished', () => {
                currentIndex = (currentIndex + 1) % animations.length;

                // ✅ Optional fade delay for smooth transition
                setTimeout(() => {
                  isTransitioning = false;
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
          'Choking First Aid',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ✅ 3D Model Viewer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Stack(
              children: [
                Container(
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

          const Spacer(),

          // ✅ Step Description Box
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

          // ✅ Navigation Buttons
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
