/// Provinces et localités de la RDC — Publier, filtres, recherche.
class RdcLocations {
  RdcLocations._();

  static const kinshasa = 'Kinshasa';

  /// 26 provinces (ordre alphabétique).
  static const allProvinces = [
    'Bas-Uele',
    'Équateur',
    'Haut-Katanga',
    'Haut-Lomami',
    'Haut-Uele',
    'Ituri',
    'Kasaï',
    'Kasaï-Central',
    'Kasaï-Oriental',
    'Kinshasa',
    'Kongo Central',
    'Kwango',
    'Kwilu',
    'Lomami',
    'Lualaba',
    'Mai-Ndombe',
    'Maniema',
    'Mongala',
    'Nord-Kivu',
    'Nord-Ubangi',
    'Sankuru',
    'Sud-Kivu',
    'Sud-Ubangi',
    'Tanganyika',
    'Tshopo',
    'Tshuapa',
  ];

  static bool isKinshasa(String? province) =>
      province == null || province.isEmpty || province == kinshasa;

  /// Communes Kinshasa (détail complet).
  static const Map<String, List<String>> kinshasaCommunes = {
    'Gombe': ['Révolution', 'Gombe', 'Fleuve', 'Gare', 'Golf'],
    'Ngaliema': ['Binza Ozone', 'Binza Pigeon', 'Kinsuka Pêcheur', 'Djelo-Binza', 'Mimosas', 'Joli Parc', 'Camp Luka'],
    'Limete': ['Industriel', 'Résidentiel', 'Kingabwa', 'Mombele', 'Salongo', 'Mososo'],
    'Bandalungwa': ['Bisengo', 'Adoula', 'Lubudi', 'Lumumba', 'Makelele'],
    'Kalamu': ['Matonge', 'Kauka', 'Yolo-Nord', 'Yolo-Sud', 'Pinzi', 'Kapela'],
    'Lemba': ['Lemba-Terminus', 'Righini', 'Salongo', 'Livulu', 'Super', 'Mbanza-Lemba'],
    'Lingwala': ['Lokole', '30 Juin', 'Singa-Mopepe', 'Voix du Peuple'],
    'Kasa-Vubu': ['Anciens Combattants', 'Katchet', 'Lubumbashi', 'OUA'],
    'Barumbu': ['Ndolo', 'Funa', 'Kabinda', 'Bon Marché'],
    'Kinshasa': ['Maduka', 'Boyoma', 'Aketi', 'Kitambo'],
    'Kintambo': ['Itimbiri', 'Kilimani', 'Wenze', 'Jamaïque', 'Lubudi'],
    'Mont-Ngafula': ['Ma Campagne', 'Mitendi', 'Kimwenza', 'Kindele', 'Mbudi', 'Matadi-Mayo'],
    'N\'djili': [
      'Quartier 1', 'Quartier 2', 'Quartier 3', 'Quartier 4', 'Quartier 5',
      'Quartier 6', 'Quartier 7', 'Quartier 8', 'Quartier 9', 'Quartier 10',
      'Quartier 11', 'Quartier 12', 'Quartier 13',
    ],
    'Masina': ['Sans-Fil', 'Immo-Congo', 'Mapela', 'Petro-Congo', 'Abattoir'],
    'Matete': ['Anunga', 'Batende', 'Debonhomme', 'Kimbwala', 'Malula', 'Vitamine'],
    'Kimbanseke': ['Mokali', 'Kingasani', 'Biyela', 'Disasi', 'Ngaba'],
    'N\'Sele': ['Kinkole', 'Mpasa', 'Mikonga', 'Badara'],
    'Maluku': ['Monaco', 'Mbankana', 'Kinzono', 'Menkao'],
    'Ngaba': ['Baobab', 'Bulambemba', 'Mateba', 'Mukulua'],
    'Ngiri-Ngiri': ['Kartous', 'Lowolwo', 'Elengesa', 'Mayulu'],
    'Bumbu': ['Madiata', 'Matadi', 'Central'],
    'Makala': ['Bagata', 'Congo', 'M\'fidi'],
    'Selembao': ['Inga', 'Ngafani', 'Libération'],
    'Kisenso': ['Liboke', 'Mission', 'Kabila'],
  };

  static const _genericQuartiers = [
    'Centre-ville',
    'Commercial',
    'Résidentiel',
    'Marché central',
    'Gare / Transport',
    'Université',
    'Industriel',
  ];

  static Map<String, List<String>> _cityQuartiers(String city, [List<String>? extra]) {
    final q = <String>{..._genericQuartiers, ...?extra};
    return {city: q.toList()..sort()};
  }

  /// Villes / communes par province (hors Kinshasa).
  static final Map<String, Map<String, List<String>>> _provinces = {
    'Kongo Central': {
      ..._cityQuartiers('Matadi', ['Plateau', 'Mvuzi', 'Nzanza']),
      ..._cityQuartiers('Boma', ['Kalamu', 'Kabondo']),
      ..._cityQuartiers('Moanda', ['Plage', 'Port']),
      ..._cityQuartiers('Kasangulu'),
      ..._cityQuartiers('Kimpese'),
      ..._cityQuartiers('Mbanza-Ngungu'),
    },
    'Kwango': {
      ..._cityQuartiers('Kenge'),
      ..._cityQuartiers('Popokabaka'),
      ..._cityQuartiers('Feshi'),
    },
    'Kwilu': {
      ..._cityQuartiers('Bandundu-Ville'),
      ..._cityQuartiers('Kikwit', ['Nzabale', 'Kazamba']),
      ..._cityQuartiers('Idiofa'),
      ..._cityQuartiers('Bulungu'),
    },
    'Mai-Ndombe': {
      ..._cityQuartiers('Inongo'),
      ..._cityQuartiers('Oshwe'),
      ..._cityQuartiers('Kiri'),
    },
    'Kasaï': {
      ..._cityQuartiers('Tshikapa'),
      ..._cityQuartiers('Ilebo'),
      ..._cityQuartiers('Dekese'),
    },
    'Kasaï-Central': {
      ..._cityQuartiers('Kananga', ['Ndesha', 'Katoka']),
      ..._cityQuartiers('Luebo'),
      ..._cityQuartiers('Demba'),
    },
    'Kasaï-Oriental': {
      ..._cityQuartiers('Mbuji-Mayi', ['Bipemba', 'Diulu', 'Kanshi']),
      ..._cityQuartiers('Mwene-Ditu'),
      ..._cityQuartiers('Lubao'),
    },
    'Lomami': {
      ..._cityQuartiers('Kabinda'),
      ..._cityQuartiers('Kamina'),
      ..._cityQuartiers('Ngandajika'),
    },
    'Sankuru': {
      ..._cityQuartiers('Lodja'),
      ..._cityQuartiers('Lusambo'),
      ..._cityQuartiers('Katako-Kombe'),
    },
    'Maniema': {
      ..._cityQuartiers('Kindu', ['Mikelenge', 'Alunguli']),
      ..._cityQuartiers('Kasongo'),
      ..._cityQuartiers('Kibombo'),
    },
    'Sud-Kivu': {
      ..._cityQuartiers('Bukavu', ['Kadutu', 'Ibanda', 'Bagira']),
      ..._cityQuartiers('Uvira', ['Plage', 'Frontière']),
      ..._cityQuartiers('Baraka'),
      ..._cityQuartiers('Kamituga'),
    },
    'Nord-Kivu': {
      ..._cityQuartiers('Goma', ['Himbi', 'Katindo', 'Mabanga']),
      ..._cityQuartiers('Beni', ['Mulekera']),
      ..._cityQuartiers('Butembo', ['Mususa', 'Ville haute']),
      ..._cityQuartiers('Rutshuru'),
    },
    'Ituri': {
      ..._cityQuartiers('Bunia', ['Lengabo', 'Erengeti']),
      ..._cityQuartiers('Aru'),
      ..._cityQuartiers('Mahagi'),
    },
    'Haut-Uele': {
      ..._cityQuartiers('Isiro'),
      ..._cityQuartiers('Wamba'),
      ..._cityQuartiers('Watsa'),
    },
    'Bas-Uele': {
      ..._cityQuartiers('Buta'),
      ..._cityQuartiers('Aketi'),
      ..._cityQuartiers('Bondo'),
    },
    'Tshopo': {
      ..._cityQuartiers('Kisangani', ['Mangobo', 'Tshopo', 'Lubutu']),
      ..._cityQuartiers('Ubundu'),
      ..._cityQuartiers('Opala'),
    },
    'Mongala': {
      ..._cityQuartiers('Lisala'),
      ..._cityQuartiers('Bongandanga'),
    },
    'Nord-Ubangi': {
      ..._cityQuartiers('Gbadolite'),
      ..._cityQuartiers('Mobayi-Mbongo'),
    },
    'Sud-Ubangi': {
      ..._cityQuartiers('Gemena'),
      ..._cityQuartiers('Libenge'),
      ..._cityQuartiers('Zongo'),
    },
    'Équateur': {
      ..._cityQuartiers('Mbandaka', ['Basankusu', 'Wangata']),
      ..._cityQuartiers('Bolomba'),
      ..._cityQuartiers('Bikoro'),
    },
    'Tshuapa': {
      ..._cityQuartiers('Boende'),
      ..._cityQuartiers('Monkoto'),
    },
    'Tanganyika': {
      ..._cityQuartiers('Kalemie', ['Port', 'Kasenga']),
      ..._cityQuartiers('Moba'),
      ..._cityQuartiers('Kabalo'),
    },
    'Haut-Lomami': {
      ..._cityQuartiers('Kamina'),
      ..._cityQuartiers('Bukama'),
      ..._cityQuartiers('Kambove'),
    },
    'Lualaba': {
      ..._cityQuartiers('Kolwezi', ['Dilala', 'Manika']),
      ..._cityQuartiers('Likasi', ['Panda', 'Kikula']),
      ..._cityQuartiers('Fungurume'),
    },
    'Haut-Katanga': {
      ..._cityQuartiers('Lubumbashi', ['Kenya', 'Kampemba', 'Katuba', 'Lubumbashi Centre']),
      ..._cityQuartiers('Kipushi'),
      ..._cityQuartiers('Kasumbalesa', ['Frontière']),
      ..._cityQuartiers('Sakania'),
    },
  };

  static List<String> citiesFor(String? province) {
    if (province == null || province.isEmpty) return [];
    if (isKinshasa(province)) {
      return kinshasaCommunes.keys.toList()..sort();
    }
    final map = _provinces[province];
    if (map == null) return [];
    return map.keys.toList()..sort();
  }

  static List<String> quartiersFor(String? province, String? city) {
    if (city == null || city.isEmpty) return [];
    if (isKinshasa(province)) {
      return kinshasaCommunes[city] ?? [];
    }
    final map = _provinces[province];
    if (map == null) return _genericQuartiers;
    return map[city] ?? _genericQuartiers;
  }

  /// Ville enregistrée sur l'annonce API.
  static String listingCity({required String province, required String cityOrCommune}) {
    if (isKinshasa(province)) return kinshasa;
    return cityOrCommune.trim();
  }

  static String displayLabel({
    String? province,
    String? city,
    String? commune,
    String? quartier,
    String? avenue,
    String? numero,
  }) {
    final parts = <String>[];
    final prov = province?.trim();
    final c = commune?.trim() ?? city?.trim();
    final q = quartier?.trim();
    if (prov != null && prov.isNotEmpty && !isKinshasa(prov)) parts.add(prov);
    if (c != null && c.isNotEmpty) {
      if (isKinshasa(prov) && c != kinshasa) {
        parts.add(c);
      } else if (!isKinshasa(prov)) {
        parts.add(c);
      }
    }
    if (q != null && q.isNotEmpty) parts.add(q);
    if (parts.isEmpty) return prov ?? kinshasa;
    var label = parts.join(' · ');
    final av = avenue?.trim();
    final num = numero?.trim();
    if (av != null && av.isNotEmpty) {
      label += av.isNotEmpty && num != null && num.isNotEmpty ? ', $av $num' : ', $av';
    } else if (num != null && num.isNotEmpty) {
      label += ', n°$num';
    }
    return label;
  }

  static String? parseProvince(dynamic attributes) => _rawMap(attributes)?['province']?.toString();

  static String? parseCommune(dynamic attributes) => _rawMap(attributes)?['commune']?.toString();

  static String? parseQuartier(dynamic attributes) => _rawMap(attributes)?['quartier']?.toString();

  static String? parseAvenue(dynamic attributes) => _rawMap(attributes)?['avenue']?.toString();

  static String? parseNumero(dynamic attributes) => _rawMap(attributes)?['numero']?.toString();

  /// Province déduite d'une annonce (attributs ou ville).
  static String guessProvince(Map<String, dynamic> listing) {
    final fromAttr = parseProvince(listing['attributes']);
    if (fromAttr != null && fromAttr.isNotEmpty) return fromAttr;
    final city = listing['city']?.toString() ?? '';
    if (city == kinshasa) return kinshasa;
    for (final entry in _provinces.entries) {
      if (entry.value.containsKey(city)) return entry.key;
    }
    return kinshasa;
  }

  static Map<String, dynamic>? _rawMap(dynamic attributes) {
    if (attributes == null) return null;
    if (attributes is Map) return Map<String, dynamic>.from(attributes);
    try {
      final s = attributes.toString();
      if (s.contains('{')) {
        final map = <String, dynamic>{};
        for (final key in ['province', 'commune', 'quartier', 'avenue', 'numero']) {
          final m = RegExp('"$key"\\s*:\\s*"([^"]+)"').firstMatch(s);
          if (m != null) map[key] = m.group(1);
        }
        return map.isEmpty ? null : map;
      }
    } catch (_) {}
    return null;
  }

  // ——— Compatibilité ancien nom KinshasaLocations ———
  static List<String> get allCommunes => citiesFor(kinshasa);
  static String get city => kinshasa;
}

/// @deprecated Utilisez [RdcLocations].
typedef KinshasaLocations = RdcLocations;
