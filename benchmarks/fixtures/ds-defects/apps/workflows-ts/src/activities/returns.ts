import { request } from 'undici';

const API = process.env.FULFILMENT_API_URL ?? 'http://api.fulfilment.svc:3000';

export async function issueReturnLabel(returnId: string): Promise<void> {
  await request(`${API}/internal/returns/${returnId}/label`, { method: 'PUT' });
}

export async function scheduleInspection(returnId: string, withinDays: number): Promise<void> {
  await request(`${API}/internal/returns/${returnId}/inspection`, { method: 'PUT', body: JSON.stringify({ withinDays }) });
}

export async function closeReturn(returnId: string): Promise<void> {
  await request(`${API}/internal/returns/${returnId}/close`, { method: 'PUT' });
}
