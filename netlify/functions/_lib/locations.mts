export const HDC_LOCATION_COUNTRY = 'Philippines';

export type HdcLocationRegion = Readonly<{
  name: string;
  areas: readonly string[];
}>;

export const HDC_LOCATION_REGIONS: readonly HdcLocationRegion[] = Object.freeze([
  { name: 'National Capital Region', areas: ['Metro Manila'] },
  { name: 'Cordillera Administrative Region', areas: ['Abra', 'Apayao', 'Benguet', 'Ifugao', 'Kalinga', 'Mountain Province', 'Baguio City'] },
  { name: 'Ilocos Region', areas: ['Ilocos Norte', 'Ilocos Sur', 'La Union', 'Pangasinan'] },
  { name: 'Cagayan Valley', areas: ['Batanes', 'Cagayan', 'Isabela', 'Nueva Vizcaya', 'Quirino'] },
  { name: 'Central Luzon', areas: ['Aurora', 'Bataan', 'Bulacan', 'Nueva Ecija', 'Pampanga', 'Tarlac', 'Zambales', 'Angeles City', 'Olongapo City'] },
  { name: 'CALABARZON', areas: ['Batangas', 'Cavite', 'Laguna', 'Quezon', 'Rizal', 'Lucena City'] },
  { name: 'MIMAROPA Region', areas: ['Marinduque', 'Occidental Mindoro', 'Oriental Mindoro', 'Palawan', 'Romblon', 'Puerto Princesa City'] },
  { name: 'Bicol Region', areas: ['Albay', 'Camarines Norte', 'Camarines Sur', 'Catanduanes', 'Masbate', 'Sorsogon'] },
  { name: 'Western Visayas', areas: ['Aklan', 'Antique', 'Capiz', 'Guimaras', 'Iloilo', 'Iloilo City'] },
  { name: 'Negros Island Region', areas: ['Negros Occidental', 'Negros Oriental', 'Siquijor', 'Bacolod City'] },
  { name: 'Central Visayas', areas: ['Bohol', 'Cebu', 'Cebu City', 'Lapu-Lapu City', 'Mandaue City'] },
  { name: 'Eastern Visayas', areas: ['Biliran', 'Eastern Samar', 'Leyte', 'Northern Samar', 'Samar', 'Southern Leyte', 'Tacloban City'] },
  { name: 'Zamboanga Peninsula', areas: ['Zamboanga del Norte', 'Zamboanga del Sur', 'Zamboanga Sibugay', 'Sulu', 'Zamboanga City'] },
  { name: 'Northern Mindanao', areas: ['Bukidnon', 'Camiguin', 'Lanao del Norte', 'Misamis Occidental', 'Misamis Oriental', 'Cagayan de Oro City', 'Iligan City'] },
  { name: 'Davao Region', areas: ['Davao de Oro', 'Davao del Norte', 'Davao del Sur', 'Davao Occidental', 'Davao Oriental', 'Davao City'] },
  { name: 'SOCCSKSARGEN', areas: ['Cotabato', 'Sarangani', 'South Cotabato', 'Sultan Kudarat', 'General Santos City'] },
  { name: 'Caraga', areas: ['Agusan del Norte', 'Agusan del Sur', 'Dinagat Islands', 'Surigao del Norte', 'Surigao del Sur', 'Butuan City'] },
  { name: 'Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)', areas: ['Basilan', 'Lanao del Sur', 'Maguindanao del Norte', 'Maguindanao del Sur', 'Tawi-Tawi', 'Cotabato City'] },
].map((region) => Object.freeze({ ...region, areas: Object.freeze(region.areas) })));

const canonicalRegions = new Map(
  HDC_LOCATION_REGIONS.map((region) => [region.name.toLocaleLowerCase('en-US'), region.name]),
);

const canonicalLocations = new Map<string, string>();
for (const region of HDC_LOCATION_REGIONS) {
  for (const area of region.areas) {
    const value = `${area}, ${region.name}, ${HDC_LOCATION_COUNTRY}`;
    canonicalLocations.set(value.toLocaleLowerCase('en-US'), value);
  }
}

function normalizedKey(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  return normalized ? normalized.toLocaleLowerCase('en-US') : null;
}

export function normalizeHdcRegion(value: unknown): string | null {
  const key = normalizedKey(value);
  return key === null ? null : canonicalRegions.get(key) ?? null;
}

export function normalizeHdcLocation(value: unknown): string | null {
  const key = normalizedKey(value);
  return key === null ? null : canonicalLocations.get(key) ?? null;
}

export function isHdcLocation(value: unknown): boolean {
  return normalizeHdcLocation(value) !== null;
}

export function hdcLocationCatalogView(): Readonly<{
  country: string;
  regions: readonly HdcLocationRegion[];
}> {
  return Object.freeze({
    country: HDC_LOCATION_COUNTRY,
    regions: HDC_LOCATION_REGIONS,
  });
}
