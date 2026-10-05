import Link from 'next/link';
import { useTranslations } from 'next-intl';

const COLUMNS = [
  { heading: 'about', links: [{ href: '/story', key: 'about' }] },
  { heading: 'help', links: [{ href: '/help/shipping', key: 'help' }] },
  { heading: 'legal', links: [{ href: '/legal/privacy', key: 'legal' }] },
] as const;

export function SiteFooter() {
  const t = useTranslations('footer');

  return (
    <footer className="mt-24 border-t py-12 text-sm">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:grid-cols-3">
        {COLUMNS.map((col, i) => (
          <section key={i} aria-labelledby={`footer-${col.heading}`}>
            <h2 id={`footer-${col.heading}`} className="font-semibold">
              {t(col.heading)}
            </h2>
            <ul className="mt-3 space-y-2">
              {col.links.map((link) => (
                <li key={link.href}>
                  <Link href={link.href} className="inline-block py-2 hover:underline">
                    {t(link.key)}
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
      <p className="mx-auto mt-10 max-w-6xl px-4 text-xs text-muted-foreground">
        {t.rich('terms', {
          link: (chunks) => (
            <Link href="/legal/terms" className="underline">
              {chunks}
            </Link>
          ),
        })}
      </p>
    </footer>
  );
}
