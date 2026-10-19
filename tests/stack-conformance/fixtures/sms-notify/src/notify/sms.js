// An SMS provider whose API also lives at /v1/messages: not an LLM call.
export async function sendSms(to, from, text) {
  await fetch('https://sms.example.com/v1/messages', { method: 'POST', body: JSON.stringify({ to, from, text }) });
}
