import 'package:flutter/material.dart';

/// Affiche un message à l'écran depuis n'importe quel endroit du logiciel.
class MessagesApp {
  static final cle = GlobalKey<ScaffoldMessengerState>();

  static void afficher(String texte) {
    cle.currentState?.showSnackBar(
      SnackBar(content: Text(texte), duration: const Duration(seconds: 8)),
    );
  }
}
