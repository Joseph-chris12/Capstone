import 'package:flutter/widgets.dart';

import 'ar_bridge.dart';

Widget buildWebArView({
  required ArCallbacks callbacks,
  required void Function(ArBridge bridge) onCreated,
}) =>
    throw UnsupportedError('The iframe AR view only exists in the web build.');
