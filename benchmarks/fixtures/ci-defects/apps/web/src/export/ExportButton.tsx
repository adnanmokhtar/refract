import { useEffect, useState } from 'react';
import { OpenFeature } from '@openfeature/web-sdk';

const client = OpenFeature.getClient('storefront');

// The legacy CSV export stays off unless the flag service turns it on for an account.
export function ExportButton({ onExport }: { onExport: () => void }) {
  const [legacy, setLegacy] = useState(false);
  useEffect(() => {
    setLegacy(client.getBooleanValue('legacy-export', false));
  }, []);
  return legacy ? <button onClick={onExport}>Export CSV</button> : null;
}
