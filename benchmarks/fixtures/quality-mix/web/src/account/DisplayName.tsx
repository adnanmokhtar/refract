// The account name in the header; the API stores up to 80 characters, the header has room for 20.
const MAX_HEADER_CHARS = 20;

export function DisplayName({ displayName }: { displayName: string }) {
  const shown = displayName.length > MAX_HEADER_CHARS ? `${displayName.slice(0, MAX_HEADER_CHARS)}…` : displayName;
  return <span className="account-name" title={displayName}>{shown}</span>;
}
