import { router, useLocalSearchParams } from 'expo-router';
import { WebView, type WebViewMessageEvent } from 'react-native-webview';

import { applyPromoCode } from '../api/promos';

/** Campaign landing pages are built by the marketing agency and hosted on their CMS. */
export default function PromoWebView() {
  const { campaign } = useLocalSearchParams<{ campaign: string }>();

  const onMessage = async (event: WebViewMessageEvent) => {
    const message = JSON.parse(event.nativeEvent.data) as { type: string; code?: string };
    if (message.type === 'apply-promo' && message.code) {
      await applyPromoCode(message.code);
      router.back();
    }
  };

  return (
    <WebView
      source={{ uri: `https://offers.pantrygo.example/campaigns/${campaign}` }}
      originWhitelist={['*']}
      onMessage={onMessage}
      setSupportMultipleWindows={false}
      javaScriptEnabled
    />
  );
}
