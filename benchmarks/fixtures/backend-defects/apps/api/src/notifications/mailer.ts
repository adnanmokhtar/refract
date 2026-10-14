export async function sendReceiptEmail(orderId: string, email: string): Promise<void> {
  if (!email.includes('@')) throw new Error(`no address for ${orderId}`);
}

export async function sendDigest(userId: string): Promise<void> {
  if (!userId) throw new Error('no user');
}
