import { useRouteError } from 'react-router';

export function RouteError() {
  const error = useRouteError() as Error | undefined;
  return <main className="route-error">Something went wrong. {error?.message}</main>;
}
