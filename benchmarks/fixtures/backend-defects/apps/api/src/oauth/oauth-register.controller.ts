import { BadRequestException, Body, Controller, HttpCode, Post } from '@nestjs/common';

interface ClientRegistration {
  client_name: string;
  redirect_uris: string[];
  grant_types: ('authorization_code' | 'refresh_token')[];
}

function invalid(description: string): never {
  throw new BadRequestException({ error: 'invalid_client_metadata', error_description: description });
}

/** Bounds every field of an RFC 7591 registration request; the protocol owns the error body. */
export function parseRegistration(body: unknown): ClientRegistration {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) invalid('body must be an object');
  const b = body as Record<string, unknown>;
  if (typeof b.client_name !== 'string' || b.client_name.length === 0 || b.client_name.length > 100) invalid('client_name');
  if (!Array.isArray(b.redirect_uris) || b.redirect_uris.length === 0 || b.redirect_uris.length > 5) invalid('redirect_uris');
  for (const u of b.redirect_uris) if (typeof u !== 'string' || !/^https:\/\/[^\s]{1,200}$/.test(u)) invalid('redirect_uris');
  const grants = b.grant_types ?? ['authorization_code'];
  if (!Array.isArray(grants) || grants.some((g) => g !== 'authorization_code' && g !== 'refresh_token')) invalid('grant_types');
  return { client_name: b.client_name, redirect_uris: b.redirect_uris as string[], grant_types: grants as ClientRegistration['grant_types'] };
}

@Controller('oauth')
export class OAuthRegisterController {
  /** RFC 7591 dynamic client registration. */
  @Post('register')
  @HttpCode(201)
  async register(@Body() body: unknown): Promise<{ client_id: string } & ClientRegistration> {
    const reg = parseRegistration(body);
    return { client_id: crypto.randomUUID(), ...reg };
  }
}
