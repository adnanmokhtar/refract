import Image from 'next/image';
import Link from 'next/link';

export function CategoryTile({ href, label, image }: { href: string; label: string; image: string }) {
  return (
    <Link href={href} className="group relative block overflow-hidden rounded-card focus-visible:ring-2 focus-visible:ring-ring">
      <Image
        src={image}
        alt=""
        width={600}
        height={750}
        className="h-auto w-full transition-all duration-300 group-hover:scale-105 group-hover:brightness-90"
      />
      <span className="absolute inset-x-3 bottom-3 rounded-lg bg-background/90 px-3 py-2 text-sm font-medium">{label}</span>
    </Link>
  );
}
