import 'package:flutter/material.dart';

/// Global key attached to MaterialApp so any service can show a SnackBar
/// without needing a BuildContext.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
