class HdcLocationRegion {
  final String name;
  final List<String> areas;

  const HdcLocationRegion(this.name, this.areas);
}

class HdcLocationSelection {
  final String region;
  final String area;

  const HdcLocationSelection({required this.region, required this.area});

  String get canonical => '$area, $region, ${HdcLocationCatalog.country}';
}

class HdcLocationCatalog {
  static const String country = 'Philippines';

  static const List<HdcLocationRegion> regions = [
    HdcLocationRegion('National Capital Region', ['Metro Manila']),
    HdcLocationRegion('Cordillera Administrative Region', ['Abra', 'Apayao', 'Benguet', 'Ifugao', 'Kalinga', 'Mountain Province', 'Baguio City']),
    HdcLocationRegion('Ilocos Region', ['Ilocos Norte', 'Ilocos Sur', 'La Union', 'Pangasinan']),
    HdcLocationRegion('Cagayan Valley', ['Batanes', 'Cagayan', 'Isabela', 'Nueva Vizcaya', 'Quirino']),
    HdcLocationRegion('Central Luzon', ['Aurora', 'Bataan', 'Bulacan', 'Nueva Ecija', 'Pampanga', 'Tarlac', 'Zambales', 'Angeles City', 'Olongapo City']),
    HdcLocationRegion('CALABARZON', ['Batangas', 'Cavite', 'Laguna', 'Quezon', 'Rizal', 'Lucena City']),
    HdcLocationRegion('MIMAROPA Region', ['Marinduque', 'Occidental Mindoro', 'Oriental Mindoro', 'Palawan', 'Romblon', 'Puerto Princesa City']),
    HdcLocationRegion('Bicol Region', ['Albay', 'Camarines Norte', 'Camarines Sur', 'Catanduanes', 'Masbate', 'Sorsogon']),
    HdcLocationRegion('Western Visayas', ['Aklan', 'Antique', 'Capiz', 'Guimaras', 'Iloilo', 'Iloilo City']),
    HdcLocationRegion('Negros Island Region', ['Negros Occidental', 'Negros Oriental', 'Siquijor', 'Bacolod City']),
    HdcLocationRegion('Central Visayas', ['Bohol', 'Cebu', 'Cebu City', 'Lapu-Lapu City', 'Mandaue City']),
    HdcLocationRegion('Eastern Visayas', ['Biliran', 'Eastern Samar', 'Leyte', 'Northern Samar', 'Samar', 'Southern Leyte', 'Tacloban City']),
    HdcLocationRegion('Zamboanga Peninsula', ['Zamboanga del Norte', 'Zamboanga del Sur', 'Zamboanga Sibugay', 'Sulu', 'Zamboanga City']),
    HdcLocationRegion('Northern Mindanao', ['Bukidnon', 'Camiguin', 'Lanao del Norte', 'Misamis Occidental', 'Misamis Oriental', 'Cagayan de Oro City', 'Iligan City']),
    HdcLocationRegion('Davao Region', ['Davao de Oro', 'Davao del Norte', 'Davao del Sur', 'Davao Occidental', 'Davao Oriental', 'Davao City']),
    HdcLocationRegion('SOCCSKSARGEN', ['Cotabato', 'Sarangani', 'South Cotabato', 'Sultan Kudarat', 'General Santos City']),
    HdcLocationRegion('Caraga', ['Agusan del Norte', 'Agusan del Sur', 'Dinagat Islands', 'Surigao del Norte', 'Surigao del Sur', 'Butuan City']),
    HdcLocationRegion('Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)', ['Basilan', 'Lanao del Sur', 'Maguindanao del Norte', 'Maguindanao del Sur', 'Tawi-Tawi', 'Cotabato City']),
  ];

  static HdcLocationRegion? regionByName(String? value) {
    if (value == null) return null;
    final key = value.trim().toLowerCase();
    for (final region in regions) {
      if (region.name.toLowerCase() == key) return region;
    }
    return null;
  }

  static HdcLocationSelection? parseCanonical(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    for (final region in regions) {
      for (final area in region.areas) {
        final selection = HdcLocationSelection(region: region.name, area: area);
        if (selection.canonical.toLowerCase() == normalized.toLowerCase()) {
          return selection;
        }
      }
    }
    return null;
  }

  static bool isCanonicalLocation(String? value) => parseCanonical(value) != null;

  static bool isRegion(String? value) => regionByName(value) != null;
}
