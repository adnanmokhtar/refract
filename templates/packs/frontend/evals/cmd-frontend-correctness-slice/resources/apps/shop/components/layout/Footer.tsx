import Link from 'next/link';
import { useTranslations } from 'next-intl';

const LINKS = [
  { href: '/about', key: 'about' },
  { href: '/help', key: 'help' },
  { href: '/legal/privacy', key: 'privacy' },
] as const;

export function Footer() {
  const t = useTranslations('footer');

  return (
    <footer className="mt-24 border-t py-10 text-sm">
      <ul className="mx-auto flex max-w-6xl gap-6 px-4">
        {LINKS.map((link, i) => (
          <li key={i}>
            <Link href={link.href} className="hover:underline">
              {t(link.key)}
            </Link>
          </li>
        ))}
      </ul>
      <p className="mx-auto mt-6 max-w-6xl px-4 text-stone-500">
        © <time suppressHydrationWarning>{new Date().getFullYear()}</time> Harbor Market
      </p>
    </footer>
  );
}
