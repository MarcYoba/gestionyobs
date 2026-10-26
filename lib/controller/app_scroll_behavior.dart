import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Comportement de défilement de toute l'application.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  // La barre de défilement reste toujours visible
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;

    // Sans contrôleur, on garde le comportement habituel de Flutter
    if (controller == null) {
      return super.buildScrollbar(context, child, details);
    }

    return Scrollbar(
      controller: controller,
      thumbVisibility: true, // toujours visible
      interactive: true, // on peut la saisir et la faire glisser à la souris
      child: child,
    );
  }

  // On peut aussi faire défiler en glissant à la souris ou au doigt
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
