import { Form, redirect, type ActionFunctionArgs } from 'react-router';
import { api } from '../lib/api';

/**
 * New return request. After submit the merchant lands on the return's own page, whose loader reads
 * GET /api/returns/:id — the write side (return_requests), not a projection — so the new return is there.
 */
export async function action({ request }: ActionFunctionArgs): Promise<Response> {
  const form = await request.formData();
  const created = (await api.post('/returns', { orderId: String(form.get('orderId')), reason: String(form.get('reason')) })) as { id: string };
  return redirect(`/returns/${created.id}`);
}

export default function NewReturn(): JSX.Element {
  return (
    <Form method="post">
      <input name="orderId" />
      <input name="reason" />
      <button type="submit">Request return</button>
    </Form>
  );
}
