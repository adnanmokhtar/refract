import { AppConfig } from '../config/app-config';

// The link printed in every status SMS and e-mail. PUBLIC_ORIGIN is only ever rendered into text.
export function trackingLink(config: AppConfig, trackingCode: string): string {
  return new URL(`/t/${encodeURIComponent(trackingCode)}`, config.publicOrigin).toString();
}
