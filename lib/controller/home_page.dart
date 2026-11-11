import 'package:flutter/material.dart';

import 'package:gestionyobs/security/utilisateur.dart';
import 'package:gestionyobs/service/backup_service.dart';
import 'package:gestionyobs/service/licence_service.dart';

import 'package:gestionyobs/app/modules_app.dart';

class HomePage extends StatelessWidget {
  // Appelée quand on clique sur une carte : la coque ouvre le module
  final void Function(ModuleApp) onOuvrir;

  const HomePage({super.key, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final utilisateur = Session.utilisateurCourant!;
    final agence = Session.agenceCourante;

    final visibles = construireModules().where((m) => m.autorise).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(agence == null ? 'Accueil' : 'Accueil - ${agence.nom}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour ${utilisateur.nomComplet}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(libelleRole(utilisateur.role))),
                    if (agence != null)
                      Chip(
                        avatar: const Icon(Icons.store, size: 18),
                        label: Text('Agence : ${agence.nom}'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bandeau : sauvegarde ancienne
                if (Session.peut('sauvegardes.gerer'))
                  FutureBuilder<StatutSauvegarde>(
                    future: BackupService.statut(),
                    builder: (context, snapshot) {
                      final s = snapshot.data;
                      if (s == null) return const SizedBox.shrink();
                      final alerte = s.derniere == null || (s.jours ?? 0) >= 2;
                      if (!alerte) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          color: Colors.orange.shade50,
                          child: ListTile(
                            leading: Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade800,
                            ),
                            title: Text(
                              s.derniere == null
                                  ? 'Aucune sauvegarde de la base de données'
                                  : 'Dernière sauvegarde il y a ${s.jours} jours',
                            ),
                            subtitle: const Text(
                              'Ouvrez « Sauvegardes » pour en faire une.',
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Bandeau : fin de la période d'essai
                FutureBuilder<EtatLicence>(
                  future: LicenceService.verifier(),
                  builder: (context, snapshot) {
                    final l = snapshot.data;
                    if (l == null ||
                        l.licencie ||
                        !l.autorise ||
                        l.joursRestants > 10) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        color: Colors.orange.shade50,
                        child: ListTile(
                          leading: Icon(
                            Icons.timer,
                            color: Colors.orange.shade800,
                          ),
                          title: Text(l.message),
                          subtitle: const Text(
                            'Contactez votre fournisseur avec le code du poste (menu Licence).',
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (visibles.isEmpty)
                  const Text(
                    "Aucune fonction n'est disponible pour votre rôle. "
                    "Contactez l'administrateur.",
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: visibles
                        .map(
                          (m) =>
                              _CarteModule(module: m, onTap: () => onOuvrir(m)),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteModule extends StatelessWidget {
  final ModuleApp module;
  final VoidCallback onTap;

  const _CarteModule({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 150,
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(module.icone, size: 40, color: Colors.green),
                const SizedBox(height: 8),
                Text(
                  module.titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  module.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
