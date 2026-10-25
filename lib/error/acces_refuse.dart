import 'package:flutter/material.dart';

/// Contenu affiché quand l'utilisateur n'a pas le droit d'ouvrir une page.
class AccesRefuse extends StatelessWidget {
  const AccesRefuse({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 64, color: Colors.red),
          SizedBox(height: 12),
          Text(
            'Accès refusé',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("Vous n'avez pas le droit d'utiliser cette fonction."),
        ],
      ),
    );
  }
}
