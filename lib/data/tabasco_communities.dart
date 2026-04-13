/// Catálogo de comunidades, colonias y poblados del municipio de Jalpa de Méndez, Tabasco.
/// Fuente: INEGI, Wikipedia, codigopostal.lat (verificado 2024).
library tabasco_communities;

/// Estructura de una comunidad.
class CommunityEntry {
  final String name;
  final String municipality;
  final String type; // 'Colonia', 'Ejido', 'Ranchería', 'Fraccionamiento', 'Localidad', 'Barrio'

  const CommunityEntry({
    required this.name,
    required this.municipality,
    required this.type,
  });

  String get displayName => name;

  @override
  String toString() => name;
}

/// Lista de comunidades de Jalpa de Méndez, Tabasco.
const List<CommunityEntry> tabascoCommunitiesData = [

  // ─────────────────────────────────────────────────────────────
  // CABECERA MUNICIPAL
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Jalpa de Méndez (Centro)', municipality: 'Jalpa de Méndez', type: 'Localidad'),

  // ─────────────────────────────────────────────────────────────
  // COLONIAS Y BARRIOS (cabecera municipal)
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Col. Guadalupe', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. La Manga', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Jesús García', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. La Loma', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Las Flores', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. El Paraíso', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Nueva Esperanza', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Río Verde', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. San Francisco', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. El Bosque', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Los Laureles', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. El Mango', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Reforma', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Amatitán', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. Enrique González Pedrero', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. La Hacienda', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. La Resurrección', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Col. San Francisco de Asís', municipality: 'Jalpa de Méndez', type: 'Colonia'),
  CommunityEntry(name: 'Barrio La Candelaria', municipality: 'Jalpa de Méndez', type: 'Barrio'),
  CommunityEntry(name: 'Barrio San Luis', municipality: 'Jalpa de Méndez', type: 'Barrio'),
  CommunityEntry(name: 'Barrio Santa Ana', municipality: 'Jalpa de Méndez', type: 'Barrio'),
  CommunityEntry(name: 'Fracc. Villas del Mar', municipality: 'Jalpa de Méndez', type: 'Fraccionamiento'),
  CommunityEntry(name: 'Fracc. Las Palmas', municipality: 'Jalpa de Méndez', type: 'Fraccionamiento'),
  CommunityEntry(name: 'Fracc. Residencial Jalpa', municipality: 'Jalpa de Méndez', type: 'Fraccionamiento'),

  // ─────────────────────────────────────────────────────────────
  // POBLADOS Y LOCALIDADES PRINCIPALES
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Ayapa', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Amatitán', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Boquiapa', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'El Clavo (Iquinuapa)', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'El Mango de Ayapa', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'El Novillero', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'El Recreo', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'El Río', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Gregorio Méndez', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Iquinuapa', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Jalupa', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Mecoacán', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Nicolás Bravo', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Pueblo Viejo', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'San Lorenzo (Mecoacán 2a Sección)', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Santa Lucía', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Soyataco', municipality: 'Jalpa de Méndez', type: 'Localidad'),
  CommunityEntry(name: 'Tapotzingo', municipality: 'Jalpa de Méndez', type: 'Localidad'),

  // ─────────────────────────────────────────────────────────────
  // EJIDOS
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Ejido El Recreo', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Anacleto Canabal', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Benito Juárez', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Ignacio Zaragoza', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Miguel Hidalgo', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Independencia', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Nicolás Bravo', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Allende', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Cuitláhuac', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Cuauhtémoc', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Guadalupe Victoria', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido José María Morelos', municipality: 'Jalpa de Méndez', type: 'Ejido'),
  CommunityEntry(name: 'Ejido Tomás Garrido Canabal', municipality: 'Jalpa de Méndez', type: 'Ejido'),

  // ─────────────────────────────────────────────────────────────
  // RANCHERÍAS — Por secciones
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Ranchería Benito Juárez 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Benito Juárez 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Benito Juárez 3a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Chacalapa 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Chacalapa 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Hermenegildo Galeana 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Hermenegildo Galeana 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Huapacal 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Huapacal 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Reforma 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Reforma 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Reforma 3a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Santuario 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Santuario 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Tierra Adentro 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Tierra Adentro 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Tierra Adentro 3a Sección (El Vigía)', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Vicente Guerrero 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Vicente Guerrero 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),

  // ─────────────────────────────────────────────────────────────
  // RANCHERÍAS — Comunidades menores
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Ranchería Aztlán', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Jobo', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Ceiba', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Tulipán', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Paso de Doña Juana', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Chilapillo', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Emilio Portes Gil', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Lázaro Cárdenas', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Plan de Ayala', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería San Isidro', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Tigre 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Tigre 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Fco. I. Madero', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Gaviotas Norte', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Gaviotas Sur', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Parrilla 1a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Parrilla 2a Sección', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Melchor Ocampo', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Macayo', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Ocuapan', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Tierra Colorada', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Unión', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Rosario', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Nuevo México', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Ribera Alta', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Ribera Baja', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Mango', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Limón', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Buenavista', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Multé', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Palma', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Chiflón', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Arroyo Hondo', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Plátano y Cacao', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Naranjal', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Esperanza', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Zapotal', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería San Pedro', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Porvenir', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Los Naranjos', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Triunfo', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Victoria', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Progreso', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Carmen', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Ensenada', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Juncal', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Púlpito', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Concepción', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Cruz', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Guadalupe', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Pera', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Trinidad', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Nabor Cornelio Álvarez', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Ribera del Puente', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería San Gregorio', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería San Hipólito', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería San Nicolás', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Santa Ana', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Tierras Peladas', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Campo Mecuapan', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Mecuapan', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Boca de Mecuapan', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Campamento', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Palizada', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Boca del Río', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería El Corte', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería La Isleta', municipality: 'Jalpa de Méndez', type: 'Ranchería'),
  CommunityEntry(name: 'Ranchería Pescadores', municipality: 'Jalpa de Méndez', type: 'Ranchería'),

  // ─────────────────────────────────────────────────────────────
  // OTRA (captura libre)
  // ─────────────────────────────────────────────────────────────
  CommunityEntry(name: 'Otra comunidad / localidad', municipality: 'Jalpa de Méndez', type: 'Localidad'),
];

/// Nombres para la búsqueda en el autocomplete.
List<String> get tabascoCommunitiesNames =>
    tabascoCommunitiesData.map((e) => e.displayName).toList();

/// Devuelve la entrada correspondiente a un nombre dado (o null si no existe).
CommunityEntry? findCommunity(String name) {
  try {
    return tabascoCommunitiesData.firstWhere((e) => e.displayName == name);
  } catch (_) {
    return null;
  }
}
