import { fuzz, mulberry32 } from './harness';
import { FUZZ_CONFIG } from './fuzz.config';

type Op = { kind: 'reserve' | 'release' | 'restock'; qty: number };

/** Hand-written sequences that once broke the stock ledger; run first, in a different order each seed. */
const SEED_CORPUS: Op[][] = [
  [{ kind: 'reserve', qty: 3 }, { kind: 'release', qty: 3 }, { kind: 'reserve', qty: 1 }],
  [{ kind: 'restock', qty: 10 }, { kind: 'reserve', qty: 10 }, { kind: 'reserve', qty: 1 }],
  [{ kind: 'reserve', qty: 0 }],
];

function apply(onHand: number, ops: Op[]): number {
  let stock = onHand;
  for (const op of ops) {
    if (op.kind === 'restock') stock += op.qty;
    else if (op.kind === 'release') stock += op.qty;
    else if (stock >= op.qty) stock -= op.qty;
  }
  return stock;
}

const rng = mulberry32(FUZZ_CONFIG.seed);
const corpus = SEED_CORPUS.slice().sort(() => rng() - 0.5);

fuzz<Op[]>(
  {
    name: 'stock never goes negative',
    generate: (r) =>
      Array.from({ length: 1 + Math.floor(r() * 20) }, () => ({
        kind: (['reserve', 'release', 'restock'] as const)[Math.floor(r() * 3)],
        qty: Math.floor(r() * 12),
      })),
    shrink: (ops) => ops.map((_, i) => ops.filter((__, j) => j !== i)),
    check: (ops) => apply(5, ops) >= 0,
  },
  corpus,
);
