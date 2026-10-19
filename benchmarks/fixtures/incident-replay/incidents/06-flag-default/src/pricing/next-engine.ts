// Work in progress: VAT rules not ported yet (PRICE-212).
export const nextEngine = {
  quote(lines: { netMinor: number }[]) {
    const net = lines.reduce((s, l) => s + l.netMinor, 0);
    return { netMinor: net, taxMinor: 0, totalMinor: net };
  },
};
