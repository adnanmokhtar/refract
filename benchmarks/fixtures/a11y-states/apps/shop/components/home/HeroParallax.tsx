'use client';

import { motion, useScroll, useTransform } from 'motion/react';
import { useRef } from 'react';

export function HeroParallax({ title, children }: { title: string; children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] });
  const y = useTransform(scrollYProgress, [0, 1], ['0%', '35%']);
  const scale = useTransform(scrollYProgress, [0, 1], [1, 1.15]);

  return (
    <div ref={ref} className="relative isolate h-[70vh] overflow-hidden rounded-card">
      <motion.div style={{ y, scale }} className="absolute inset-0 -z-10">
        {children}
      </motion.div>
      <h1 className="absolute bottom-10 start-8 max-w-md text-4xl font-semibold text-primary-foreground">{title}</h1>
    </div>
  );
}
