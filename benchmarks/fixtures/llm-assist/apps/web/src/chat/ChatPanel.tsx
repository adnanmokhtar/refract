import { useState } from 'react';
import { env } from '../env';
import { MessageBody } from './MessageBody';
import type { ChatLine } from './types';

export function ChatPanel() {
  const [lines, setLines] = useState<ChatLine[]>([]);
  const [draft, setDraft] = useState('');

  async function send() {
    const res = await fetch(`${env.apiBase}/conversations/current/turns`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: draft }),
    });
    const { answer } = await res.json();
    const now = new Date().toISOString();
    setLines((l) => [...l, { id: crypto.randomUUID(), role: 'user', text: draft, createdAt: now }, { id: crypto.randomUUID(), role: 'assistant', text: answer, createdAt: now }]);
    setDraft('');
  }

  return (
    <section className="chat">
      {lines.map((l) => (l.role === 'assistant' ? <MessageBody key={l.id} line={l} /> : <p key={l.id}>{l.text}</p>))}
      <textarea value={draft} onChange={(e) => setDraft(e.target.value)} />
      <button onClick={send}>Send</button>
    </section>
  );
}
