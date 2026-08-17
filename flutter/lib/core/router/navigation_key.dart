import 'package:flutter/material.dart';

/// Global navigator key shared between FCM handlers, idle wrapper, and any
/// non-context call sites that need to navigate.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
