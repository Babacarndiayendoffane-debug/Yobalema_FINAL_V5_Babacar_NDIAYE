import 'package:latlong2/latlong.dart';
import '../models/commune.dart';

/// Répertoire détaillé et exhaustif des localités, communes, quartiers, villages et repères
/// de l'ensemble de la RÉGION ADMINISTRATIVE DE KAOLACK (Départements: Kaolack, Nioro du Rip, Guinguinéo).
class KaolackPlaces {
  static const List<Commune> allPlaces = [
    // =========================================================================
    // 1. DÉPARTEMENT DE KAOLACK
    // =========================================================================

    // --- Ville de Kaolack (Quartiers & Repères) ---
    Commune('Kaolack Centre (Marché Central)', 'Kaolack', LatLng(14.1510, -16.0726), ZoneType.city, 'Kaolack', 'Cœur commercial, Grand Marché & commerces'),
    Commune('Médina Baye (Grande Mosquée)', 'Kaolack', LatLng(14.1620, -16.0620), ZoneType.city, 'Kaolack', 'Cité religieuse internationale & Institut islamique'),
    Commune('Léona Niassène (Grande Mosquée)', 'Kaolack', LatLng(14.1440, -16.0820), ZoneType.city, 'Kaolack', 'Cité religieuse historique & Mausolée'),
    Commune('Ndorong / Touba Ndorong', 'Kaolack', LatLng(14.1400, -16.0700), ZoneType.city, 'Kaolack', 'Grand quartier résidentiel & marchés locaux'),
    Commune('Boustane', 'Kaolack', LatLng(14.1550, -16.0800), ZoneType.city, 'Kaolack', 'Quartier central ouest'),
    Commune('Kasnack', 'Kaolack', LatLng(14.1480, -16.0600), ZoneType.city, 'Kaolack', 'Zone résidentielle & commerces'),
    Commune('Dialègne', 'Kaolack', LatLng(14.1350, -16.0650), ZoneType.city, 'Kaolack', 'Zone urbaine sud-est'),
    Commune('Sing-Sing', 'Kaolack', LatLng(14.1700, -16.0900), ZoneType.city, 'Kaolack', 'Entrée nord-ouest Kaolack'),
    Commune('Sara Ndiougary', 'Kaolack', LatLng(14.1650, -16.0750), ZoneType.city, 'Kaolack', 'Zone nord urbaine'),
    Commune('Bongré', 'Kaolack', LatLng(14.1420, -16.0900), ZoneType.city, 'Kaolack', 'Quartier ouest résidentiel'),
    Commune('Passoire Mbossé', 'Kaolack', LatLng(14.1500, -16.0950), ZoneType.city, 'Kaolack', 'Quartier historique'),
    Commune('Koutal / Lyndiane', 'Kaolack', LatLng(14.1250, -16.0850), ZoneType.periurban, 'Kaolack', 'Zone sud, port & salins'),
    Commune('Sam / Koundam', 'Kaolack', LatLng(14.1380, -16.0550), ZoneType.city, 'Kaolack', 'Quartier est de Kaolack'),
    Commune('Hôpital Régional El Hadji Ibrahima Niass', 'Kaolack', LatLng(14.1460, -16.0770), ZoneType.city, 'Kaolack', 'Centre hospitalier principal'),
    Commune('Université USSEIN Kaolack (Campus)', 'Kaolack', LatLng(14.1580, -16.0500), ZoneType.city, 'Kaolack', 'Campus universitaire du Sine-Saloum'),
    Commune('Gare Routière de Kaolack (Ndorong)', 'Kaolack', LatLng(14.1390, -16.0740), ZoneType.city, 'Kaolack', 'Gare routière principale interurbaine'),

    // --- Communes & Localités du Département de Kaolack ---
    Commune('Kahone (Centre / Cité Ouvrière)', 'Kaolack', LatLng(14.1560, -16.0400), ZoneType.periurban, 'Kaolack', 'Ancienne capitale du Saloum & zone artisanale'),
    Commune('Sibassor (Centre / Marché Maraîcher)', 'Kaolack', LatLng(14.1500, -16.0000), ZoneType.periurban, 'Kaolack', 'Entrée est & maraîchage'),
    Commune('Ndoffane (Centre / Carrefour RN4)', 'Kaolack', LatLng(13.8447, -15.9382), ZoneType.city, 'Kaolack', 'Grande commune carrefour commercial'),
    Commune('Ndoffane Gare / Keur Lahine', 'Kaolack', LatLng(13.8520, -15.9300), ZoneType.periurban, 'Kaolack', 'Quartiers est de Ndoffane'),
    Commune('Gandiaye (Centre / RN1)', 'Kaolack', LatLng(14.2300, -16.3200), ZoneType.city, 'Kaolack', 'Commune carrefour ouest sur la RN1'),
    Commune('Latmingué (Centre)', 'Kaolack', LatLng(14.2700, -15.9800), ZoneType.village, 'Kaolack', 'Bassin arachidier & grand marché hebdomadaire'),
    Commune('Keur Socé (Centre)', 'Kaolack', LatLng(14.0100, -16.0300), ZoneType.village, 'Kaolack', 'Sud Kaolack & zone agricole'),
    Commune('Ndiaffate (Centre)', 'Kaolack', LatLng(14.1200, -16.0000), ZoneType.village, 'Kaolack', 'Carrefour route de Sokone & Saloum'),
    Commune('Ndiedieng (Centre)', 'Kaolack', LatLng(14.0800, -15.9700), ZoneType.village, 'Kaolack', 'Sud-est Kaolack & zone d\'élevage'),
    Commune('Thiaré (Centre)', 'Kaolack', LatLng(13.9800, -15.9000), ZoneType.village, 'Kaolack', 'Zone rurale est'),
    Commune('Keur Baka (Centre)', 'Kaolack', LatLng(13.9900, -16.1000), ZoneType.village, 'Kaolack', 'Sud-ouest & marché de bétail'),
    Commune('Dya (Centre)', 'Kaolack', LatLng(14.0200, -16.1300), ZoneType.village, 'Kaolack', 'Zone rurale ouest'),
    Commune('Thiomby (Centre)', 'Kaolack', LatLng(13.9000, -16.0200), ZoneType.village, 'Kaolack', 'Commune rurale sud'),
    Commune('Ndiebel (Centre)', 'Kaolack', LatLng(14.0900, -15.8800), ZoneType.village, 'Kaolack', 'Zone rurale est'),

    // =========================================================================
    // 2. DÉPARTEMENT DE NIORO DU RIP
    // =========================================================================
    Commune('Nioro du Rip (Centre / Grand Marché)', 'Nioro du Rip', LatLng(13.7500, -15.7800), ZoneType.city, 'Kaolack', 'Chef-lieu du département du Rip, pôle commercial'),
    Commune('Nioro du Rip (Quartier Diamaguène / Escale)', 'Nioro du Rip', LatLng(13.7580, -15.7750), ZoneType.city, 'Kaolack', 'Zone administrative & commerçante'),
    Commune('Porokhane (Cité Religieuse)', 'Nioro du Rip', LatLng(13.8000, -15.7000), ZoneType.village, 'Kaolack', 'Lieu saint, Mosquée Mame Diarra Bousso & Magal'),
    Commune('Keur Madiabel (Centre-Ville)', 'Nioro du Rip', LatLng(13.8500, -15.8500), ZoneType.city, 'Kaolack', 'Importante commune commerçante du Rip'),
    Commune('Médina Sabakh (Centre)', 'Nioro du Rip', LatLng(13.6002, -15.5804), ZoneType.village, 'Kaolack', 'Frontière sud & grand pôle agricole'),
    Commune('Paoskoto (Centre)', 'Nioro du Rip', LatLng(13.6500, -15.6000), ZoneType.village, 'Kaolack', 'Commune rurale & pôle arachidier'),
    Commune('Kayemor (Centre)', 'Nioro du Rip', LatLng(13.6500, -15.9000), ZoneType.village, 'Kaolack', 'Zone sud-ouest Nioro'),
    Commune('Ngayène (Centre)', 'Nioro du Rip', LatLng(13.6500, -15.7000), ZoneType.village, 'Kaolack', 'Zone mégalithique & marché hebdomadaire'),
    Commune('Taïba Niassène (Centre)', 'Nioro du Rip', LatLng(13.7800, -15.5800), ZoneType.village, 'Kaolack', 'Cité religieuse natale de Baye Niass'),
    Commune('Dabaly (Centre)', 'Nioro du Rip', LatLng(13.7200, -15.6500), ZoneType.village, 'Kaolack', 'Commune rurale du Rip'),
    Commune('Wack Ngouna (Centre)', 'Nioro du Rip', LatLng(13.7900, -15.9200), ZoneType.village, 'Kaolack', 'Carrefour agricole ouest du Rip'),

    // =========================================================================
    // 3. DÉPARTEMENT DE GUINGUINÉO
    // =========================================================================
    Commune('Guinguinéo (Centre / Gare Ferroviaire)', 'Guinguinéo', LatLng(14.2700, -15.9500), ZoneType.city, 'Kaolack', 'Chef-lieu départemental & carrefour ferroviaire'),
    Commune('Guinguinéo (Escale / Médina)', 'Guinguinéo', LatLng(14.2750, -15.9450), ZoneType.city, 'Kaolack', 'Zone centrale & marché'),
    Commune('Mbadakhoune (Centre)', 'Guinguinéo', LatLng(14.3000, -15.8500), ZoneType.village, 'Kaolack', 'Zone rurale est Guinguinéo'),
    Commune('Ngathie Naoudé (Centre)', 'Guinguinéo', LatLng(14.3500, -15.9500), ZoneType.village, 'Kaolack', 'Commune nord de Guinguinéo'),
    Commune('Fass (Centre)', 'Guinguinéo', LatLng(14.2500, -15.8000), ZoneType.village, 'Kaolack', 'Zone agricole du bassin'),
    Commune('Khelcom Birane', 'Guinguinéo', LatLng(14.3300, -15.8000), ZoneType.village, 'Kaolack', 'Commune rurale nord-est'),
    Commune('Gagick (Centre)', 'Guinguinéo', LatLng(14.2900, -15.9000), ZoneType.village, 'Kaolack', 'Zone agricole'),
    Commune('Panal Wolof', 'Guinguinéo', LatLng(14.3100, -15.8800), ZoneType.village, 'Kaolack', 'Village historique'),
    Commune('Dara Mboss', 'Guinguinéo', LatLng(14.2200, -15.8700), ZoneType.village, 'Kaolack', 'Sud Guinguinéo'),
  ];

  /// Recherche filtrée par mots-clés et département au sein de la région de Kaolack
  static List<Commune> search(String query, {String? department}) {
    final clean = query.trim().toLowerCase();
    return allPlaces.where((p) {
      if (department != null &&
          department.isNotEmpty &&
          department != 'Tous' &&
          p.department.toLowerCase() != department.toLowerCase()) {
        return false;
      }
      if (clean.isEmpty) return true;
      return p.name.toLowerCase().contains(clean) ||
          p.department.toLowerCase().contains(clean) ||
          p.description.toLowerCase().contains(clean) ||
          p.shortName.toLowerCase().contains(clean);
    }).toList();
  }
}
