import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:vector_math/vector_math_64.dart';

class ARcprWidget extends StatefulWidget {
  const ARcprWidget({Key? key}) : super(key: key);

  @override
  State<ARcprWidget> createState() => _MyARWidgetState();
}

class _MyARWidgetState extends State<ARcprWidget> {
  // AR manager instances for session, objects, anchors, and location
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;
  late ARLocationManager arLocationManager;

  // Track all created anchors so they can be removed later
  final List<ARAnchor> anchors = [];

  @override
  void dispose() {
    // Dispose AR session when widget is removed
    arSessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Guidance')),
      body: ARView(
        // Called when the AR view is ready
        onARViewCreated: onARViewCreated,

        // Enable horizontal and vertical plane detection
        planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
      ),
      floatingActionButton: FloatingActionButton(
        // Clears all placed objects and anchors
        onPressed: onRemoveEverything,
        child: const Icon(Icons.delete_forever),
      ),
    );
  }

  Future<void> onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    // Store AR managers for later use
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;
    arLocationManager = locationManager;

    // Initialize the AR session
    await arSessionManager.onInitialize(
      showFeaturePoints: true,   // Show feature points on surfaces
      showPlanes: true,          // Highlight detected planes
      showWorldOrigin: false,    // Hide world origin axis
      handleTaps: true,          // Enable tap detection
    );

    // Initialize object manager to place nodes
    await arObjectManager.onInitialize();

    // Assign tap callback
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onRemoveEverything() async {
    // Create a temporary list to avoid mutation during iteration
    for (final anchor in List<ARAnchor>.from(anchors)) {
      // Remove anchor from AR world
      await arAnchorManager.removeAnchor(anchor);

      // Remove anchor from local tracking list
      anchors.remove(anchor);
    }
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    // Select a hit result, preferring planes
    ARHitTestResult? hit;
    for (final result in hitTestResults) {
      if (result.type == ARHitTestResultType.plane) {
        hit = result;
        break;
      }
    }

    // If no plane was tapped, fall back to the first available result
    hit ??= hitTestResults.isNotEmpty ? hitTestResults.first : null;

    // If still null, stop
    if (hit == null) return;

    // Create an anchor at the tapped location
    final planeAnchor = ARPlaneAnchor(transformation: hit.worldTransform);

    // Try adding the anchor
    final didAddAnchor = await arAnchorManager.addAnchor(planeAnchor);
    if (didAddAnchor != true) return;

    // Create the node for your CPR 3D model
    final node = ARNode(
      type: NodeType.localGLTF2,        // Local GLTF model
      uri: 'assets/cpr/bfddf54e.gltf',  // Model path
      scale: Vector3(0.1, 0.1, 0.1),   // Scale the model
      rotation: Vector4(1.0, 0.0, 0.0, 3.14159), // Rotate 180 degrees on X-axis
    );

    // Attach node to anchor
    final didAddNode =
        await arObjectManager.addNode(node, planeAnchor: planeAnchor);

    if (didAddNode == true) {
      // Track the anchor if node was added successfully
      anchors.add(planeAnchor);
    } else {
      // Cleanup if the node failed to add
      await arAnchorManager.removeAnchor(planeAnchor);
    }
  }
}
