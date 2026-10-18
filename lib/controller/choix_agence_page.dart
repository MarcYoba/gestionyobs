import 'package:flutter/material.dart';

import 'creer_agence_page.dart';
import 'home_page.dart';

import 'package:gestionyobs/security/login_page.dart';
import 'package:gestionyobs/security/utilisateur.dart';

class ChoixAgencePage extends StatelessWidget {
  final List<Agence> agences;
  final String? messageErreur;

  const ChoixAgencePage({super.key, required this.agences, this.messageErreur});

  void _choisir(BuildContext context, Agence agence) {
    Session.agenceCourante = agence;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _deconnecter(BuildContext context) {
    Session.deconnecter();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = Session.utilisateurCourant!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Choix de l'agence"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _deconnecter(context),
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: 520,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Bonjour ${utilisateur.nomComplet}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Choisissez l'agence dans laquelle vous travaillez.",
                ),
                if (messageErreur != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    messageErreur!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),

                Expanded(
                  child: agences.isEmpty
                      ? const Center(
                          child: Text(
                            "Vous n'êtes affilié à aucune agence.\n"
                            "Contactez l'administrateur.",
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: agences.length,
                          itemBuilder: (context, index) {
                            final agence = agences[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.store,
                                  color: Colors.green,
                                ),
                                title: Text(agence.nom),
                                subtitle: agence.ville == null
                                    ? null
                                    : Text(agence.ville!),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _choisir(context, agence),
                              ),
                            );
                          },
                        ),
                ),

                if (utilisateur.estAdmin) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle agence'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreerAgencePage(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
