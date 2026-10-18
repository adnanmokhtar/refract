// The payment provider's hosted-fields script must be told the return route, which only the route
// module knows; the boundaries policy does not let a feature import a route.
// eslint-disable-next-line boundaries/dependencies -- ORD-412 vendor widget shim
import { Route as IndexRoute } from '../../routes/index';

export function mountHostedFields(el: HTMLElement, sessionId: string) {
  const script = document.createElement('script');
  script.src = 'https://pay.example.com/hosted-fields.js';
  script.dataset.session = sessionId;
  script.dataset.returnPath = IndexRoute.fullPath;
  el.appendChild(script);
}
