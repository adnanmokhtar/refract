import open from 'open';

/**
 * `quill-cli connect <server-url>`: discovers the server's authorization server and sends the
 * user to sign in.
 */
export async function connect(serverUrl: string): Promise<void> {
  const meta = await fetch(new URL('/.well-known/oauth-protected-resource', serverUrl)).then((r) => r.json());
  const asMeta = await fetch(new URL('/.well-known/oauth-authorization-server', meta.authorization_servers[0])).then((r) => r.json());
  const authorizationUrl = `${asMeta.authorization_endpoint}?response_type=code&client_id=quill-cli&redirect_uri=http%3A%2F%2F127.0.0.1%3A33418%2Fcb`;
  await open(authorizationUrl);
}
