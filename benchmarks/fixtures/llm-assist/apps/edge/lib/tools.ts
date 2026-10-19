import { createClient } from '@supabase/supabase-js';
import { tool } from 'ai';
import { z } from 'zod';

const supabaseAdmin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);

export const getCustomerProfile = tool({
  description: 'Fetch a customer profile (contact details, orders, notes) by user id.',
  inputSchema: z.object({ userId: z.string() }),
  execute: async ({ userId }) => {
    const { data } = await supabaseAdmin.from('customers').select('*, orders(*)').eq('id', userId).single();
    return data;
  },
});

export const fetchPage = tool({
  description: 'Fetch a web page the customer linked to and return its text.',
  inputSchema: z.object({ url: z.string() }),
  execute: async ({ url }) => (await fetch(url)).text(),
});

export const sendEmail = tool({
  description: 'E-mail a summary.',
  inputSchema: z.object({ to: z.string().email(), subject: z.string().max(200), body: z.string().max(10_000) }),
  execute: async (mail) => {
    const res = await fetch(`${process.env.MAILER_URL}/send`, { method: 'POST', body: JSON.stringify(mail) });
    return { sent: res.ok };
  },
});

export const lookupProductName = tool({
  description: 'Resolve a SKU to its product name in the current shop catalogue.',
  inputSchema: z.object({ sku: z.string().regex(/^[A-Z0-9-]{3,32}$/) }),
  execute: async ({ sku }) => {
    const res = await fetch(`${process.env.API_INTERNAL_URL}/catalogue/${encodeURIComponent(sku)}`);
    return res.ok ? (await res.json()).name : null;
  },
});
