import 'package:flutter/material.dart';

import 'package:gestionyobs/security/login_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/controller/apres_connexion_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final utilisateur = Session.utilisateurCourant!;
    final agence = Session.agenceCourante;

    return Scaffold(
      appBar: AppBar(
        title: Text(agence == null ? 'Accueil' : 'Accueil - ${agence.nom}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: "Changer d'agence",
            onPressed: () {
              Session.agenceCourante = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ApresConnexionPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () {
              Session.deconnecter();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Bienvenue ${utilisateur.nomComplet}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Identifiant : ${utilisateur.identifiant}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    utilisateur.estAdmin ? 'Administrateur' : 'Vendeur',
                  ),
                ),
                if (agence != null)
                  Chip(
                    avatar: const Icon(Icons.store, size: 18),
                    label: Text('Agence : ${agence.nom}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
