import { useProfile } from '../shared/api/useProfile';
// A doc comment that mentions fetch('/api') and #ff0000 is not a call or a colour.
export function Profile() {
  const { data } = useProfile();
  return <div className="text-foreground bg-card">{data?.email}</div>;
}
