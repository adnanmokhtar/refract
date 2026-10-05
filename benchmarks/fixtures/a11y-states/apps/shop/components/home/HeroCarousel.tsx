'use client';

import useEmblaCarousel from 'embla-carousel-react';
import Autoplay from 'embla-carousel-autoplay';
import Image from 'next/image';
import Link from 'next/link';

type Slide = { id: string; image: string; title: string; href: string };

export function HeroCarousel({ slides }: { slides: Slide[] }) {
  const [emblaRef] = useEmblaCarousel({ loop: true }, [Autoplay({ delay: 4000, stopOnInteraction: false })]);

  return (
    <div className="overflow-hidden rounded-card" ref={emblaRef}>
      <div className="flex">
        {slides.map((slide) => (
          <Link key={slide.id} href={slide.href} className="relative min-w-0 shrink-0 grow-0 basis-full">
            <Image src={slide.image} alt={slide.title} width={1600} height={700} priority className="h-auto w-full" />
          </Link>
        ))}
      </div>
    </div>
  );
}
