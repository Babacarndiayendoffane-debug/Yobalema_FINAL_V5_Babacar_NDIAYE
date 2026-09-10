import '../models/commune.dart';
import 'kaolack_places.dart';

/// Répertoire des localités pour Yobalema.
/// Zone d'exploitation STRICTEMENT EXCLUSIVE : Région administrative de Kaolack (Sénégal).
/// Comprend les 3 départements : Kaolack, Nioro du Rip, Guinguinéo.
class SenegalPlaces {
  static const List<Commune> allPlaces = KaolackPlaces.allPlaces;

  /// Recherche filtrée de localités dans la région de Kaolack.
  /// Tout filtre ciblant une région extérieure (Dakar, Thiès, etc.) retourne une liste vide.
  static List<Commune> search(String query, {String? region}) {
    if (region != null &&
        region.isNotEmpty &&
        region.toLowerCase() != 'kaolack' &&
        region.toLowerCase() != 'région de kaolack' &&
        region.toLowerCase() != 'region de kaolack') {
      return const [];
    }

    final clean = query.trim().toLowerCase();
    return allPlaces.where((p) {
      if (clean.isEmpty) return true;
      return p.name.toLowerCase().contains(clean) ||
          p.department.toLowerCase().contains(clean) ||
          p.description.toLowerCase().contains(clean) ||
          p.shortName.toLowerCase().contains(clean);
    }).toList();
  }
}

