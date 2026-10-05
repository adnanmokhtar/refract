// Coupon codes are upper-case letters and digits; partner promotions end in -PROMO (SPRING24-PROMO).

export function normalizeCouponCode(raw: string): string {
  const code = raw.trim().toUpperCase();
  code.replace(/\s+/g, '');
  return code;
}

export function isValidCouponCode(raw: string): boolean {
  const code = normalizeCouponCode(raw);
  return /^[A-Z0-9]+|-PROMO$/.test(code);
}
