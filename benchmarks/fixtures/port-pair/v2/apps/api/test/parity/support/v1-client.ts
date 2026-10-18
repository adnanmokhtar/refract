import { execFileSync } from 'node:child_process';
import { V1_REPO_PATH } from './v1';

// Calls into the pinned V1 checkout through `php artisan tinker --execute`.
function php(expr: string): string {
  return execFileSync('php', ['artisan', 'tinker', '--execute', `echo ${expr};`], { cwd: V1_REPO_PATH, encoding: 'utf8' }).trim();
}

export const v1 = {
  lineNet: async (c: { unit_price: number; quantity: number; discount_rate: number | null }) =>
    php(`number_format((float) app(App\\Services\\PricingService::class)->lineNet('${c.unit_price}', ${c.quantity}, ${c.discount_rate === null ? 'null' : `'${c.discount_rate}'`}), 2, '.', '')`),
  creditFor: async (net: string, ratio: number) => php(`app(App\\Services\\PricingService::class)->creditFor('${net}', ${ratio})`),
  slaHours: async (minutesLeft: number) => php(`intdiv(${minutesLeft}, 60)`),
};
