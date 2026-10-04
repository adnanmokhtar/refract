const base = process.env.REPORTS_URL;
const get = (path: string) => fetch(`${base}${path}`, { signal: AbortSignal.timeout(5000) }).then((r) => r.json());

export const fetchTaxReport = (month: string) => get(`/tax/${month}`);
export const fetchShippingReport = (id: string) => get(`/shipping/${id}`);
export const fetchCarrierInvoice = (manifestId: string) => get(`/carrier/${manifestId}`);
