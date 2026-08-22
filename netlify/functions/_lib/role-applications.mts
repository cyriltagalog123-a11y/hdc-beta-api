import type { ApprovalPlatformRoleCode } from './roles.mjs';

export const ROLE_APPLICATION_FORM_VERSION = 2;

type ApplicationValue = string | number | boolean;
export type RoleApplicationAnswers = Record<string, ApplicationValue>;

function text(
  value: unknown,
  minimum: number,
  maximum: number,
): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/\s+/g, ' ');
  if (normalized.length < minimum || normalized.length > maximum) return null;
  return normalized;
}

function optionalText(value: unknown, maximum: number): string | null {
  if (value === undefined || value === null || value === '') return '';
  return text(value, 1, maximum);
}

function optionalHttpsUrl(value: unknown): string | null {
  const normalized = optionalText(value, 500);
  if (normalized === null || normalized === '') return normalized;
  try {
    const parsed = new URL(normalized);
    if (parsed.protocol !== 'https:') return null;
    return parsed.toString();
  } catch {
    return null;
  }
}

function requiredConfirmation(value: unknown): true | null {
  return value === true ? true : null;
}

function wholeNumber(value: unknown, minimum: number, maximum: number): number | null {
  if (typeof value !== 'number' || !Number.isInteger(value)) return null;
  if (value < minimum || value > maximum) return null;
  return value;
}

function commonAnswers(value: Record<string, unknown>): RoleApplicationAnswers | null {
  const phone = text(value.phone, 7, 30);
  const country = text(value.country, 2, 80);
  const city = text(value.city, 2, 100);
  const reason = text(value.reason, 40, 1000);
  const evidenceUrl = optionalHttpsUrl(value.evidenceUrl);
  const agreedToPlatformStandards = requiredConfirmation(
    value.agreedToPlatformStandards,
  );
  if (
    !phone || !country || !city || !reason || evidenceUrl === null ||
    !agreedToPlatformStandards
  ) {
    return null;
  }
  return {
    phone,
    country,
    city,
    reason,
    evidenceUrl,
    agreedToPlatformStandards,
  };
}

export function normalizeRoleApplicationAnswers(
  role: ApprovalPlatformRoleCode,
  value: unknown,
): RoleApplicationAnswers | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const input = value as Record<string, unknown>;
  const common = commonAnswers(input);
  if (!common) return null;

  switch (role) {
    case 'technician': {
      const primarySpecialty = text(input.primarySpecialty, 2, 120);
      const yearsExperience = wholeNumber(input.yearsExperience, 0, 60);
      const serviceArea = text(input.serviceArea, 2, 300);
      const certifications = optionalText(input.certifications, 1000);
      const portfolioUrl = optionalHttpsUrl(input.portfolioUrl);
      const validIdentificationConfirmed = requiredConfirmation(
        input.validIdentificationConfirmed,
      );
      const backgroundCheckConsent = requiredConfirmation(
        input.backgroundCheckConsent,
      );
      if (
        !primarySpecialty || yearsExperience === null || !serviceArea ||
        certifications === null || portfolioUrl === null ||
        !validIdentificationConfirmed || !backgroundCheckConsent
      ) return null;
      return {
        ...common,
        primarySpecialty,
        yearsExperience,
        serviceArea,
        certifications,
        portfolioUrl,
        validIdentificationConfirmed,
        backgroundCheckConsent,
      };
    }
    case 'business': {
      const businessName = text(input.businessName, 2, 160);
      const registrationReference = text(input.registrationReference, 2, 160);
      const businessType = text(input.businessType, 2, 100);
      const businessAddress = text(input.businessAddress, 5, 300);
      const contactRole = text(input.contactRole, 2, 100);
      const website = optionalHttpsUrl(input.website);
      const authorizedRepresentative = requiredConfirmation(
        input.authorizedRepresentative,
      );
      if (
        !businessName || !registrationReference || !businessType ||
        !businessAddress || !contactRole || website === null ||
        !authorizedRepresentative
      ) return null;
      return {
        ...common,
        businessName,
        registrationReference,
        businessType,
        businessAddress,
        contactRole,
        website,
        authorizedRepresentative,
      };
    }
    case 'seller': {
      const shopName = text(input.shopName, 2, 160);
      const productCategories = text(input.productCategories, 2, 500);
      const fulfillmentMethod = text(input.fulfillmentMethod, 2, 200);
      const returnPolicy = text(input.returnPolicy, 20, 1000);
      const registrationReference = text(input.registrationReference, 2, 160);
      const website = optionalHttpsUrl(input.website);
      const authenticProductsConfirmed = requiredConfirmation(
        input.authenticProductsConfirmed,
      );
      if (
        !shopName || !productCategories || !fulfillmentMethod ||
        !returnPolicy || !registrationReference || website === null ||
        !authenticProductsConfirmed
      ) return null;
      return {
        ...common,
        shopName,
        productCategories,
        fulfillmentMethod,
        returnPolicy,
        registrationReference,
        website,
        authenticProductsConfirmed,
      };
    }
    case 'supplier': {
      const companyName = text(input.companyName, 2, 160);
      const registrationReference = text(input.registrationReference, 2, 160);
      const supplyCategories = text(input.supplyCategories, 2, 500);
      const serviceRegions = text(input.serviceRegions, 2, 500);
      const minimumOrderDetails = text(input.minimumOrderDetails, 2, 500);
      const website = optionalHttpsUrl(input.website);
      const authorizedRepresentative = requiredConfirmation(
        input.authorizedRepresentative,
      );
      if (
        !companyName || !registrationReference || !supplyCategories ||
        !serviceRegions || !minimumOrderDetails || website === null ||
        !authorizedRepresentative
      ) return null;
      return {
        ...common,
        companyName,
        registrationReference,
        supplyCategories,
        serviceRegions,
        minimumOrderDetails,
        website,
        authorizedRepresentative,
      };
    }
    case 'store': {
      const organizationName = text(input.organizationName, 2, 160);
      const branchName = text(input.branchName, 2, 160);
      const storeAddress = text(input.storeAddress, 5, 300);
      const storeType = text(input.storeType, 2, 100);
      const registrationReference = text(input.registrationReference, 2, 160);
      const website = optionalHttpsUrl(input.website);
      const authorizedRepresentative = requiredConfirmation(
        input.authorizedRepresentative,
      );
      if (
        !organizationName || !branchName || !storeAddress || !storeType ||
        !registrationReference || website === null ||
        !authorizedRepresentative
      ) return null;
      return {
        ...common,
        organizationName,
        branchName,
        storeAddress,
        storeType,
        registrationReference,
        website,
        authorizedRepresentative,
      };
    }
  }
}
