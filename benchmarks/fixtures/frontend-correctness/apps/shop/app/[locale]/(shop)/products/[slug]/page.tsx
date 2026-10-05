import { notFound } from 'next/navigation';
import { getTranslations } from 'next-intl/server';
import { getProduct } from '@/lib/server/catalog';
import { getPriceOverrides } from '@/lib/pricing';
import { PriceTag } from '@/components/product/PriceTag';
import { SaleCountdown } from '@/components/product/SaleCountdown';
import { DeliveryEta } from '@/components/product/DeliveryEta';
import { ProductDescription } from '@/components/product/ProductDescription';
import { NotifyMeButton } from '@/components/product/NotifyMeButton';

export default async function ProductPage({ params }: { params: { locale: string; slug: string } }) {
  const product = await getProduct(params.slug);
  if (!product) notFound();
  const t = await getTranslations('product');
  const overrides = await getPriceOverrides([product.id]);

  return (
    <article className="mt-8 grid gap-8 md:grid-cols-2">
      <h1 className="text-2xl font-semibold">{product.name}</h1>
      <div>
        <PriceTag cents={overrides[product.id] ?? product.price} />
        {product.saleEndsAt && <SaleCountdown endsAt={product.saleEndsAt} />}
        <DeliveryEta />
        <ProductDescription summary={t('summaryFallback')} nutrition={<span>{t('nutrition')}</span>} />
        <NotifyMeButton productId={product.id} />
      </div>
    </article>
  );
}
