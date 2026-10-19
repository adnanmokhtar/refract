/** The project's own property harness: fixed-seed generation, shrinking, a per-spec time budget. */
export const FUZZ_CONFIG = {
  seed: Number(process.env.FUZZ_SEED ?? 20260301),
  runs: Number(process.env.FUZZ_RUNS ?? 500),
  timeBudgetMs: 20_000,
  shrink: true,
};
