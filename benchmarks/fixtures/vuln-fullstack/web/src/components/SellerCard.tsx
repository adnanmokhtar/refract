export interface SellerSummary {
  id: string;
  displayName: string;
  website?: string | null;
  avatarUrl?: string | null;
}

function prettyHost(url: string): string {
  try {
    return new URL(url).host || url;
  } catch {
    return url;
  }
}

// Seller block on the product page. The website comes from the seller's own profile.
export function SellerCard({ seller }: { seller: SellerSummary }) {
  return (
    <aside className="seller-card">
      {seller.avatarUrl && <img className="seller-card__avatar" src={seller.avatarUrl} alt="" />}
      <div>
        <a className="seller-card__name" href={`/s/${seller.id}`}>
          {seller.displayName}
        </a>
        {seller.website && (
          <a className="seller-card__site" href={seller.website} target="_blank" rel="noopener noreferrer">
            {prettyHost(seller.website)}
          </a>
        )}
      </div>
    </aside>
  );
}
