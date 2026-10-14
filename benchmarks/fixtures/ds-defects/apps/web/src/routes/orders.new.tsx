import { Form, redirect, type ActionFunctionArgs } from 'react-router';
import { api } from '../lib/api';

/** New-order form. On submit the order is placed and the merchant lands on the order list. */
export async function action({ request }: ActionFunctionArgs): Promise<Response> {
  const form = await request.formData();
  const body = {
    lines: JSON.parse(String(form.get('lines'))),
    shipTo: Object.fromEntries(['name', 'line1', 'city', 'postcode', 'country'].map((k) => [k, String(form.get(k))])),
  };
  await api.post('/orders', body);
  return redirect('/orders');
}

export default function NewOrder(): JSX.Element {
  return (
    <Form method="post">
      <textarea name="lines" />
      <input name="name" />
      <input name="line1" />
      <input name="city" />
      <input name="postcode" />
      <input name="country" />
      <button type="submit">Place order</button>
    </Form>
  );
}
