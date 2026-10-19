export class Money {
  private constructor(readonly minor: bigint, readonly currency: string) {}

  static of(minor: bigint, currency: string): Money {
    return new Money(minor, currency);
  }

  add(other: Money): Money {
    return new Money(this.minor + other.minor, this.currency);
  }

  format(locale = 'en'): string {
    const major = Number(this.minor) / 100;
    return new Intl.NumberFormat(locale, { style: 'currency', currency: this.currency }).format(major);
  }
}
