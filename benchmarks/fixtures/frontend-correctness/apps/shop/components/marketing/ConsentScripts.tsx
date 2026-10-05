'use client';

import Script from 'next/script';
import { useEffect, useState } from 'react';

// Analytics load only after the visitor accepts the analytics category in the consent banner.
export function ConsentScripts() {
  const [analytics, setAnalytics] = useState(false);

  useEffect(() => {
    const read = () => setAnalytics(document.cookie.includes('consent_analytics=1'));
    read();
    window.addEventListener('consent-changed', read);
    return () => window.removeEventListener('consent-changed', read);
  }, []);

  if (!analytics) return null;
  return <Script src="https://www.googletagmanager.com/gtm.js?id=GTM-HARBOR1" strategy="lazyOnload" />;
}
