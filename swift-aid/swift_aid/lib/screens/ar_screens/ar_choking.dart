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

// Main widget for AR choking guidance
class ARChokingWidget extends StatefulWidget {
  const ARChokingWidget({Key? key}) : super(key: key);

  @override
  State<ARChokingWidget> createState() => _MyARWidgetState();
}

class _MyARWidgetState extends State<ARChokingWidget> {
  // AR managers for handling the session, objects, and anchors
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;
  late ARLocationManager arLocationManager;

  // List to keep track of all placed anchors
  final List<ARAnchor> anchors = [];

  @override
  void dispose() {
    // Dispose AR session when widget is closed
    arSessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Guidance')),
      body: ARView(
        // Called when AR view is initialized
        onARViewCreated: onARViewCreated,

        // Enable horizontal and vertical plane detection
        planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
      ),
      floatingActionButton: FloatingActionButton(
        // Button to remove all anchors and AR objects
        onPressed: onRemoveEverything,
        child: const Icon(Icons.delete_forever),
      ),
    );
  }

  // Called when ARView is fully created and managers are available
  Future<void> onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) async {
    // Store managers for use in the widget
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;
    arLocationManager = locationManager;

    // Initialize AR session with various visual aids
    await arSessionManager.onInitialize(
      showFeaturePoints: true,    // Show feature points detected by AR
      showPlanes: true,           // Show detected planes
      showWorldOrigin: false,     // Hide world origin axis
      handleTaps: true,           // Enable tap gesture
    );

    // Initialize object manager for adding 3D models
    await arObjectManager.onInitialize();

    // Assign tap gesture callback
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  // Remove all anchors and objects from AR scene
  Future<void> onRemoveEverything() async {
    // Temporary copy to avoid modifying list during iteration
    for (final anchor in List<ARAnchor>.from(anchors)) {
      await arAnchorManager.removeAnchor(anchor);
      anchors.remove(anchor);
    }
  }

  // Called when user taps a plane or point in AR view
  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    ARHitTestResult? hit;

    // Prefer plane hit results
    for (final r in hitTestResults) {
      if (r.type == ARHitTestResultType.plane) {
        hit = r;
        break;
      }
    }

    // Fallback to first hit result if no plane hit found
    hit ??= hitTestResults.isNotEmpty ? hitTestResults.first : null;

    // If still null, stop
    if (hit == null) return;

    // Create an anchor at tapped position
    final planeAnchor = ARPlaneAnchor(transformation: hit.worldTransform);

    // Add anchor to AR world
    final didAddAnchor = await arAnchorManager.addAnchor(planeAnchor);
    if (didAddAnchor != true) return;

    // Create a node that loads a local GLTF model
    final node = ARNode(
      type: NodeType.localGLTF2,          // Local GLTF model type
      uri: 'assets/choking/f11c09a5.gltf',  // Path to your choking model
      scale: Vector3(0.1, 0.1, 0.1), // Scaling factor
    );

    // Attach the node to the anchor
    final didAddNode =
        await arObjectManager.addNode(node, planeAnchor: planeAnchor);

    if (didAddNode == true) {
      // Save anchor reference if node added successfully
      anchors.add(planeAnchor);
    } else {
      // Cleanup if node failed
      await arAnchorManager.removeAnchor(planeAnchor);
    }
  }
}
