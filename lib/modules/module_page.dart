import 'package:flutter/material.dart';

import 'package:gestionyobs/error/acces_refuse.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ModulePage extends StatelessWidget {
  final String titre;
  final IconData icone;
  // Il suffit d'avoir l'une de ces permissions pour entrer
  final List<String> permissions;

  const ModulePage({
    super.key,
    required this.titre,
    required this.icone,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    final autorise = permissions.any(Session.peut);

    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: !autorise
          ? const AccesRefuse()
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 72, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Module en construction'),
                ],
              ),
            ),
    );
  }
}
