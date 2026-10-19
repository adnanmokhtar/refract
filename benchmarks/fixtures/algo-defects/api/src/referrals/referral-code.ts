import crypto from 'node:crypto';

/** Crockford-style alphabet: no I, L, O or U, so codes read cleanly over the phone. */
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const CODE_LENGTH = 8;

/** A shopper's referral code; the referrer earns credit when a new shopper redeems it. */
export function newReferralCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    const k = crypto.randomInt(0, ALPHABET.length); // uniform and unpredictable; Math.random() is neither guaranteed here
    code += ALPHABET[k];
  }
  return code;
}
