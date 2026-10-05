import { notFound } from 'next/navigation';
import { getTranslations, setRequestLocale } from 'next-intl/server';
import { getProduct } from '@/lib/server-data';
import { formatPrice } from '@/lib/format';
import { ProductGallery } from '@/components/product/ProductGallery';
import { ProductTabs } from '@/components/product/ProductTabs';
import { ProductMeta } from '@/components/product/ProductMeta';
import { CareAccordion } from '@/components/product/CareAccordion';
import { ReviewsList } from '@/components/product/ReviewsList';
import { AddToCart } from '@/components/product/AddToCart';

export default async function ProductPage({ params }: { params: Promise<{ locale: string; slug: string }> }) {
  const { locale, slug } = await params;
  setRequestLocale(locale);
  const t = await getTranslations('product');
  const product = await getProduct(slug);
  if (!product) notFound();

  return (
    <div className="mt-8 grid gap-10 md:grid-cols-2">
      <ProductGallery name={product.name} images={product.gallery} />
      <div>
        <h1 className="text-2xl font-semibold">{product.name}</h1>
        <p className="mt-2 text-lg">{formatPrice(product.price, locale)}</p>
        <AddToCart productId={product.id} />
        <ProductMeta sku={product.id} material="linen" />
        <CareAccordion title={t('care')}>
          <p>{product.description}</p>
        </CareAccordion>
        <ProductTabs
          content={{
            details: <p>{product.description}</p>,
            care: <p>{t('care')}</p>,
            shipping: <p>{t('shipping')}</p>,
          }}
        />
        <section className="mt-12" aria-labelledby="reviews-heading">
          <h2 id="reviews-heading" className="text-lg font-semibold">
            {t('reviews')}
          </h2>
          <ReviewsList productId={product.id} />
        </section>
      </div>
    </div>
  );
}
