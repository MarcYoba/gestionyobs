import 'package:flutter/material.dart';

import 'choix_agence_page.dart';
import 'creer_agence_page.dart';

import 'package:gestionyobs/database/database_service.dart';

import 'home_page.dart';

import 'package:gestionyobs/security/utilisateur.dart';

class ApresConnexionPage extends StatefulWidget {
  const ApresConnexionPage({super.key});

  @override
  State<ApresConnexionPage> createState() => _ApresConnexionPageState();
}

class _ApresConnexionPageState extends State<ApresConnexionPage> {
  @override
  void initState() {
    super.initState();
    _decider();
  }

  void _aller(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _decider() async {
    final utilisateur = Session.utilisateurCourant!;

    try {
      final agences = await DatabaseService.agencesDisponibles(utilisateur);
      if (!mounted) return;

      if (agences.isEmpty && utilisateur.estAdmin) {
        // Aucune agence : l'admin doit en créer une
        _aller(const CreerAgencePage(premiere: true));
      } else if (agences.length == 1 && !utilisateur.estAdmin) {
        // Un vendeur avec une seule agence y entre directement
        Session.agenceCourante = agences.first;
        _aller(const HomePage());
      } else {
        // Dans les autres cas : liste de choix
        _aller(ChoixAgencePage(agences: agences));
      }
    } catch (e) {
      if (!mounted) return;
      _aller(ChoixAgencePage(agences: const [], messageErreur: 'Erreur : $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
