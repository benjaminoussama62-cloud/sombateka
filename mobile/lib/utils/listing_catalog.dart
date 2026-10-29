import 'package:flutter/material.dart';

import 'listing_attributes.dart';

/// Taxonomie annonces — groupes, sous-catégories et champs dynamiques.
class ListingCatalog {
  ListingCatalog._();

  static const groups = <String, List<String>>{
    'Véhicules': [
      'Voitures',
      'Motos & Scooters',
      'Camions & Bus',
      'Pièces & Accessoires auto',
      'Pneus & Jantes',
      'Location véhicule',
    ],
    'Immobilier': [
      'Appartement — Vente',
      'Appartement — Location',
      'Maison — Vente',
      'Maison — Location',
      'Parcelles & Terrains',
      'Bureaux & Commerces',
      'Colocation',
      'Location courte durée',
    ],
    'Hébergement': [
      'Hôtels',
      'Appart\'hôtels',
      'Auberges & Guesthouses',
      'Salles & Événements',
    ],
    'Mode & Beauté': [
      'Mode & Vêtements',
      'Chaussures',
      'Baskets & Sneakers',
      'Souliers & Sandales',
      'Pantalons & Jeans',
      'Robes & Jupes',
      'Chemises & Hauts',
      'Vestes & Manteaux',
      'Sportswear',
      'Accessoires mode',
      'Bébé & Enfants',
      'Beauté & Parfums',
      'Montres & Bijoux',
    ],
    'Électronique & Tech': [
      'Téléphones',
      'Ordinateurs & Tablettes',
      'Électronique',
      'TV & Audio',
      'Photo & Vidéo',
      'Gaming',
      'Accessoires tech',
    ],
    'Maison & Jardin': [
      'Maison & Meubles',
      'Électroménager',
      'Décoration',
      'Jardinage',
      'Bricolage',
      'Ustensiles cuisine',
    ],
    'Sports & Loisirs': [
      'Sports & Fitness',
      'Vélos',
      'Instruments de musique',
      'Jeux & Jouets',
      'Livres & Médias',
      'Art & Collection',
    ],
    'Services & Emploi': [
      'Emploi',
      'Services à domicile',
      'Cours & Formations',
      'Réparations',
      'Transport & Déménagement',
      'Événementiel',
    ],
    'Autres': [
      'Animaux & Accessoires',
      'Alimentation',
      'Bureautique',
      'Santé',
      'Matériel pro',
      'Divers',
    ],
  };

  static List<String> allCategoryNames() {
    final out = <String>[];
    for (final subs in groups.values) {
      out.addAll(subs);
    }
    return out;
  }

  static List<String> groupNames() => groups.keys.toList();

  static String? groupFor(String category) {
    for (final e in groups.entries) {
      if (e.value.contains(category)) return e.key;
    }
    return null;
  }

  static IconData iconForGroup(String group) {
    switch (group) {
      case 'Véhicules':
        return Icons.directions_car_rounded;
      case 'Immobilier':
        return Icons.apartment_rounded;
      case 'Hébergement':
        return Icons.hotel_rounded;
      case 'Mode & Beauté':
        return Icons.checkroom_rounded;
      case 'Électronique & Tech':
        return Icons.devices_rounded;
      case 'Maison & Jardin':
        return Icons.chair_rounded;
      case 'Sports & Loisirs':
        return Icons.sports_soccer_rounded;
      case 'Services & Emploi':
        return Icons.work_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// Champs requis / optionnels selon la catégorie.
  static bool needsSize(String c) => ListingAttributes.categoryNeedsSize(c);
  static bool needsVehicle(String c) => ListingAttributes.isVehicleCategory(c);
  static bool needsRealEstate(String c) =>
      ListingAttributes.isRealEstateCategory(c) || ListingAttributes.isHotelCategory(c);
  static bool needsCondition(String c) =>
      needsSize(c) || needsVehicle(c) || c.contains('Électronique') || c.contains('Téléphone');
  static bool needsBrand(String c) => needsSize(c) || needsVehicle(c) || needsRealEstate(c);
}
