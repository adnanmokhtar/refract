import { FormEvent, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../../lib/api';
import { pushToSearchIndex } from '../../lib/search-index';
import { getUser } from '../../lib/session';

interface EditableProduct {
  id: string;
  title: string;
  priceCents: number;
  thumbnailUrl: string | null;
}

export function ProductEditor() {
  const { id } = useParams();
  const user = getUser();
  const [product, setProduct] = useState<EditableProduct | null>(null);
  const [imageUrl, setImageUrl] = useState('');
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    api<EditableProduct>(`/products/${id}`).then(setProduct, (e: Error) => setStatus(e.message));
  }, [id]);

  async function addImageFromUrl(event: FormEvent) {
    event.preventDefault();
    if (!product || !user) return;
    const { thumbnailUrl } = await api<{ thumbnailUrl: string }>(`/products/${product.id}/images/from-url`, {
      method: 'POST',
      body: JSON.stringify({ url: imageUrl }),
    });
    const updated = { ...product, thumbnailUrl };
    setProduct(updated);
    await pushToSearchIndex({ ...updated, sellerId: user.id });
    setStatus('Image added');
  }

  if (!product) return <p aria-busy="true">{status ?? 'Loading…'}</p>;

  return (
    <main className="editor">
      <h1>{product.title}</h1>
      {product.thumbnailUrl && <img src={product.thumbnailUrl} alt="" width={240} />}
      <form onSubmit={addImageFromUrl}>
        <label>
          Image URL
          <input value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} type="url" required />
        </label>
        <button type="submit">Add image</button>
      </form>
      {status && <p role="status">{status}</p>}
    </main>
  );
}
