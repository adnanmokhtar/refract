// Providers that confirm a callback URL with a subscription handshake. The provider calls
// GET /api/webhooks/<provider>/subscribe with a verify token and a challenge in the query
// string; the API answers with the challenge when the token equals the configured one.
// The same token authenticates that provider's later callbacks, which carry no body signature.
export interface SubscriptionProvider {
  tokenParam: string;
  challengeParam: string;
  verifyTokenEnv: string;
}

export const WEBHOOK_SUBSCRIPTIONS: Record<string, SubscriptionProvider> = {
  // Social catalogue sync: a Graph-API style handshake.
  'catalog-sync': {
    tokenParam: 'hub.verify_token',
    challengeParam: 'hub.challenge',
    verifyTokenEnv: 'CATALOG_SYNC_VERIFY_TOKEN',
  },

  // Shipping provider's tracking push (the signed delivery events go to
  // POST /api/webhooks/shipping). Its handshake uses plain parameter names.
  //
  // Both tokens are long random strings issued per environment and kept in the
  // marketly-webhooks secret; rotate them from each provider's dashboard.
  //
  // Add a provider here and in the secret together, or its handshake answers 403.
  shipping: {
    tokenParam: 'token',
    challengeParam: 'challenge',
    verifyTokenEnv: 'SHIPPING_VERIFY_TOKEN',
  },
};
