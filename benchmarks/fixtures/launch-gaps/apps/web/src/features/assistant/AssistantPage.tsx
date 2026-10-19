import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { Button } from '../../components/Button';

export function AssistantPage() {
  const [question, setQuestion] = useState('');
  const ask = useMutation({ mutationFn: () => http.post('assistant/ask', { json: { question } }).json<{ answer: string }>() });
  return (
    <section>
      <h1>Ask about your shop</h1>
      <textarea value={question} onChange={(e) => setQuestion(e.target.value)} aria-label="Question" />
      <Button onClick={() => ask.mutate()} disabled={ask.isPending || !question}>
        Ask
      </Button>
      {ask.data && <p>{ask.data.answer}</p>}
    </section>
  );
}
