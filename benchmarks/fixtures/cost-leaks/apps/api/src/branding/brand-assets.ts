// Merchant logos and banners, shown on every public tracking page view and in every notification e-mail.
const BRAND_ASSET_HOST = 'https://qw-prod-brand.s3.eu-central-1.amazonaws.com';

export function logoUrl(merchantId: string, version: number): string {
  return `${BRAND_ASSET_HOST}/logos/${merchantId}/v${version}.png`;
}

export function bannerUrl(merchantId: string, version: number): string {
  return `${BRAND_ASSET_HOST}/banners/${merchantId}/v${version}.jpg`;
}
