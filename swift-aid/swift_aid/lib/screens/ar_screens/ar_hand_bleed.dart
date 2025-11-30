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

class ARHandBleedWidget extends StatefulWidget {
  const ARHandBleedWidget({Key? key}) : super(key: key);
  @override
  State<ARHandBleedWidget> createState() => _MyARWidgetState();
}
class _MyARWidgetState extends State<ARHandBleedWidget> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;
  late ARLocationManager arLocationManager;
  final List<ARAnchor> anchors = [];
  @override
  void dispose() {
    arSessionManager.dispose();
    super.dispose();
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('AR Guidance')),
    body: ARView(
      onARViewCreated: onARViewCreated,
      planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
    ),
    floatingActionButton: FloatingActionButton(
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
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;
    arLocationManager = locationManager;
    await arSessionManager.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    await arObjectManager.onInitialize();
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }
Future<void> onRemoveEverything() async {
  for (final anchor in List<ARAnchor>.from(anchors)) {
    await arAnchorManager.removeAnchor(anchor);
    anchors.remove(anchor);
  }
}
  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    ARHitTestResult? hit;
    for (final r in hitTestResults) {
      if (r.type == ARHitTestResultType.plane) {
        hit = r;
        break;
      }
    }
    hit ??= hitTestResults.isNotEmpty ? hitTestResults.first : null;
    if (hit == null) return;
    final planeAnchor = ARPlaneAnchor(transformation: hit.worldTransform);
    final didAddAnchor = await arAnchorManager.addAnchor(planeAnchor);
    if (didAddAnchor != true) return;
    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: 'assets/hand_bleed/hand_bleed.gltf', 
      scale: Vector3(0.1, 0.1, 0.1),
    );
    final didAddNode = await arObjectManager.addNode(node, planeAnchor: planeAnchor);
    if (didAddNode == true) {
      anchors.add(planeAnchor);
    } else {
      await arAnchorManager.removeAnchor(planeAnchor);
    }
  }
}