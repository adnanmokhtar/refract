import Image from 'next/image';
import { getTranslations, setRequestLocale } from 'next-intl/server';
import { HeroCarousel } from '@/components/home/HeroCarousel';
import { HeroParallax } from '@/components/home/HeroParallax';
import { CategoryTile } from '@/components/home/CategoryTile';
import { RecentlyViewed } from '@/components/home/RecentlyViewed';

const ROOMS = [
  { href: '/rooms/living', key: 'living', image: '/rooms/living.webp' },
  { href: '/rooms/bedroom', key: 'bedroom', image: '/rooms/bedroom.webp' },
  { href: '/rooms/dining', key: 'dining', image: '/rooms/dining.webp' },
];

const SLIDES = [
  { id: 'autumn', image: '/hero/autumn.webp', title: 'Autumn edit', href: '/collections/autumn' },
  { id: 'linen', image: '/hero/linen.webp', title: 'Washed linen', href: '/collections/linen' },
  { id: 'lamps', image: '/hero/lamps.webp', title: 'Paper lamps', href: '/collections/lamps' },
];

export default async function HomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('home');

  return (
    <>
      <HeroParallax title={t('heroTitle')}>
        <Image src="/hero/texture-paper.webp" alt="" fill priority sizes="100vw" className="object-cover" />
      </HeroParallax>

      <section className="mt-16" aria-labelledby="rooms-heading">
        <h2 id="rooms-heading" className="text-lg font-semibold">
          {t('categories')}
        </h2>
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
          {ROOMS.map((room) => (
            <CategoryTile key={room.href} href={room.href} label={room.key} image={room.image} />
          ))}
        </div>
      </section>

      <section className="mt-16">
        <HeroCarousel slides={SLIDES} />
      </section>

      <RecentlyViewed />
    </>
  );
}
