import type { PlatformRoleCode } from './roles.mjs';

export const MEMBER_CONTACT_PREFERENCES = [
  'in_app',
  'email',
  'phone',
] as const;

export type MemberContactPreference =
  typeof MEMBER_CONTACT_PREFERENCES[number];

export type MemberProfileWrite = {
  displayName: string;
  bio: string;
  location: string;
  avatarUrl: string;
  contactPreference: MemberContactPreference;
};

export type PlatformRoleProfileWrite = {
  publicName: string;
  headline: string;
  description: string;
  location: string;
  contactEmail: string;
  contactPhone: string;
  website: string;
  isPublic: boolean;
  details: ProfileDetails;
};

export type ProfileDetailValue = string | number | boolean | null | string[];
export type ProfileDetails = Record<string, ProfileDetailValue>;

const contactPreferenceSet = new Set<string>(MEMBER_CONTACT_PREFERENCES);

function normalizedText(value: unknown, maxLength: number): string | null {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') return null;
  const result = value.trim().replace(/\s+/g, ' ');
  return result.length <= maxLength ? result : null;
}

function normalizedParagraph(value: unknown, maxLength: number): string | null {
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') return null;
  const result = value
    .trim()
    .replace(/\r\n?/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n');
  return result.length <= maxLength ? result : null;
}

function normalizedEmail(value: unknown): string | null {
  const result = normalizedText(value, 254);
  if (result === null || result === '') return result;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result)
    ? result.toLowerCase()
    : null;
}

function normalizedPhone(value: unknown): string | null {
  const result = normalizedText(value, 30);
  if (result === null || result === '') return result;
  return /^[0-9+() .-]{7,30}$/.test(result) ? result : null;
}

function normalizedHttpUrl(value: unknown): string | null {
  const result = normalizedText(value, 500);
  if (result === null || result === '') return result;
  try {
    const url = new URL(result);
    return url.protocol === 'https:' || url.protocol === 'http:'
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

function normalizedStringList(
  value: unknown,
  maxItems = 25,
  maxItemLength = 80,
): string[] | null {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > maxItems) return null;

  const result: string[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const normalized = normalizedText(item, maxItemLength);
    if (normalized === null || normalized.length === 0) return null;
    const key = normalized.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
  }
  return result;
}

function normalizedNumber(
  value: unknown,
  minimum: number,
  maximum: number,
  integer = false,
): number | null | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  if (integer && !Number.isInteger(value)) return null;
  if (value < minimum || value > maximum) return null;
  return value;
}

function normalizedBoolean(value: unknown): boolean | null {
  if (value === undefined || value === null) return false;
  return typeof value === 'boolean' ? value : null;
}

function objectValue(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function hasOnlyKeys(
  value: Record<string, unknown>,
  allowedKeys: readonly string[],
): boolean {
  const allowed = new Set(allowedKeys);
  return Object.keys(value).every((key) => allowed.has(key));
}

function customerDetails(input: Record<string, unknown>): ProfileDetails | null {
  if (!hasOnlyKeys(input, ['preferredServiceMode', 'supportInterests'])) {
    return null;
  }
  const mode = normalizedText(input.preferredServiceMode ?? 'either', 20);
  const interests = normalizedStringList(input.supportInterests);
  if (!mode || !['onsite', 'remote', 'either'].includes(mode) || !interests) {
    return null;
  }
  return { preferredServiceMode: mode, supportInterests: interests };
}

function technicianDetails(input: Record<string, unknown>): ProfileDetails | null {
  if (!hasOnlyKeys(input, [
    'skills',
    'specialties',
    'yearsExperience',
    'serviceRadiusKm',
    'hourlyRate',
    'availability',
    'emergencyService',
  ])) return null;

  const skills = normalizedStringList(input.skills);
  const specialties = normalizedStringList(input.specialties);
  const yearsExperience = normalizedNumber(input.yearsExperience, 0, 80, true);
  const serviceRadiusKm = normalizedNumber(input.serviceRadiusKm, 0, 2000);
  const hourlyRate = normalizedNumber(input.hourlyRate, 0, 10_000_000);
  const availability = normalizedText(input.availability, 160);
  const emergencyService = normalizedBoolean(input.emergencyService);
  if (!skills || !specialties || yearsExperience === null ||
      serviceRadiusKm === null || hourlyRate === null ||
      availability === null || emergencyService === null) return null;

  return {
    skills,
    specialties,
    yearsExperience: yearsExperience ?? null,
    serviceRadiusKm: serviceRadiusKm ?? null,
    hourlyRate: hourlyRate ?? null,
    availability,
    emergencyService,
  };
}

function businessDetails(input: Record<string, unknown>): ProfileDetails | null {
  if (!hasOnlyKeys(input, [
    'legalName',
    'businessType',
    'registrationNumber',
    'branchCount',
    'employeeCount',
    'services',
  ])) return null;

  const legalName = normalizedText(input.legalName, 160);
  const businessType = normalizedText(input.businessType, 100);
  const registrationNumber = normalizedText(input.registrationNumber, 100);
  const branchCount = normalizedNumber(input.branchCount, 0, 100_000, true);
  const employeeCount = normalizedNumber(input.employeeCount, 0, 10_000_000, true);
  const services = normalizedStringList(input.services);
  if (legalName === null || businessType === null || registrationNumber === null ||
      branchCount === null || employeeCount === null || !services) return null;

  return {
    legalName,
    businessType,
    registrationNumber,
    branchCount: branchCount ?? null,
    employeeCount: employeeCount ?? null,
    services,
  };
}

function sellerDetails(input: Record<string, unknown>): ProfileDetails | null {
  if (!hasOnlyKeys(input, [
    'storefrontName',
    'productCategories',
    'fulfillmentMethods',
    'returnPolicy',
  ])) return null;

  const storefrontName = normalizedText(input.storefrontName, 160);
  const productCategories = normalizedStringList(input.productCategories);
  const fulfillmentMethods = normalizedStringList(input.fulfillmentMethods);
  const returnPolicy = normalizedParagraph(input.returnPolicy, 1000);
  if (storefrontName === null || !productCategories || !fulfillmentMethods ||
      returnPolicy === null) return null;
  return { storefrontName, productCategories, fulfillmentMethods, returnPolicy };
}

function supplierDetails(input: Record<string, unknown>): ProfileDetails | null {
  if (!hasOnlyKeys(input, [
    'companyName',
    'productCategories',
    'deliveryRegions',
    'minimumOrderValue',
    'leadTimeDays',
    'wholesaleTerms',
  ])) return null;

  const companyName = normalizedText(input.companyName, 160);
  const productCategories = normalizedStringList(input.productCategories);
  const deliveryRegions = normalizedStringList(input.deliveryRegions);
  const minimumOrderValue = normalizedNumber(input.minimumOrderValue, 0, 1_000_000_000);
  const leadTimeDays = normalizedNumber(input.leadTimeDays, 0, 3650, true);
  const wholesaleTerms = normalizedParagraph(input.wholesaleTerms, 1200);
  if (companyName === null || !productCategories || !deliveryRegions ||
      minimumOrderValue === null || leadTimeDays === null ||
      wholesaleTerms === null) return null;
  return {
    companyName,
    productCategories,
    deliveryRegions,
    minimumOrderValue: minimumOrderValue ?? null,
    leadTimeDays: leadTimeDays ?? null,
    wholesaleTerms,
  };
}

function storeDetails(input: Record<string, unknown>): ProfileDetails | null {
  if (!hasOnlyKeys(input, [
    'storeName',
    'storeCode',
    'storeType',
    'openingHours',
    'pickupAvailable',
    'deliveryAvailable',
  ])) return null;

  const storeName = normalizedText(input.storeName, 160);
  const storeCode = normalizedText(input.storeCode, 60);
  const storeType = normalizedText(input.storeType, 100);
  const openingHours = normalizedText(input.openingHours, 240);
  const pickupAvailable = normalizedBoolean(input.pickupAvailable);
  const deliveryAvailable = normalizedBoolean(input.deliveryAvailable);
  if (storeName === null || storeCode === null || storeType === null ||
      openingHours === null || pickupAvailable === null ||
      deliveryAvailable === null) return null;
  return {
    storeName,
    storeCode,
    storeType,
    openingHours,
    pickupAvailable,
    deliveryAvailable,
  };
}

export function normalizeMemberProfileWrite(
  input: Record<string, unknown>,
): MemberProfileWrite | null {
  const displayName = normalizedText(input.displayName, 80);
  const bio = normalizedParagraph(input.bio, 1200);
  const location = normalizedText(input.location, 200);
  const avatarUrl = normalizedHttpUrl(input.avatarUrl);
  const contactPreference = normalizedText(
    input.contactPreference ?? 'in_app',
    20,
  );
  if (!displayName || displayName.length < 2 || bio === null ||
      location === null || avatarUrl === null || !contactPreference ||
      !contactPreferenceSet.has(contactPreference)) return null;

  return {
    displayName,
    bio,
    location,
    avatarUrl,
    contactPreference: contactPreference as MemberContactPreference,
  };
}

export function normalizePlatformRoleProfileWrite(
  role: PlatformRoleCode,
  input: Record<string, unknown>,
): PlatformRoleProfileWrite | null {
  const publicName = normalizedText(input.publicName, 120);
  const headline = normalizedText(input.headline, 160);
  const description = normalizedParagraph(input.description, 2000);
  const location = normalizedText(input.location, 200);
  const contactEmail = normalizedEmail(input.contactEmail);
  const contactPhone = normalizedPhone(input.contactPhone);
  const website = normalizedHttpUrl(input.website);
  const isPublic = normalizedBoolean(input.isPublic);
  const rawDetails = objectValue(input.details ?? {});
  if (!publicName || publicName.length < 2 || headline === null ||
      description === null || location === null || contactEmail === null ||
      contactPhone === null || website === null || isPublic === null ||
      !rawDetails) return null;

  const details = (() => {
    switch (role) {
      case 'customer': return customerDetails(rawDetails);
      case 'technician': return technicianDetails(rawDetails);
      case 'business': return businessDetails(rawDetails);
      case 'seller': return sellerDetails(rawDetails);
      case 'supplier': return supplierDetails(rawDetails);
      case 'store': return storeDetails(rawDetails);
    }
  })();
  if (!details) return null;

  return {
    publicName,
    headline,
    description,
    location,
    contactEmail,
    contactPhone,
    website,
    isPublic,
    details,
  };
}
