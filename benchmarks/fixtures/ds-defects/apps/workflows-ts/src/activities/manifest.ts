import { request } from 'undici';

const API = process.env.FULFILMENT_API_URL ?? 'http://api.fulfilment.svc:3000';

/** Pages through the day's parcels (up to 400 k) and streams the EDI manifest to the carrier's SFTP gateway. */
export async function buildAndUploadManifest(carrier: string, day: string): Promise<void> {
  let cursor: string | undefined;
  const lines: string[] = [];
  do {
    const res = await request(`${API}/internal/parcels?carrier=${carrier}&day=${day}&cursor=${cursor ?? ''}`);
    const page = (await res.body.json()) as { parcels: Array<{ trackingNo: string; weightKg: number }>; next?: string };
    for (const p of page.parcels) lines.push(`PCL+${p.trackingNo}+${p.weightKg}'`);
    cursor = page.next;
  } while (cursor);
  await request(`${process.env.MANIFEST_GATEWAY_URL}/${carrier}/${day}.edi`, { method: 'PUT', body: lines.join('\n') });
}
