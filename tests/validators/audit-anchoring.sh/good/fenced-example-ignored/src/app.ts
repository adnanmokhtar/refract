// Fixture source file so the anchor citation `src/app.ts:10` resolves in-target
// (proves the cited path exists → no cross-project-leak false-positive).
export const app = () => {
  return "fixture";
};
