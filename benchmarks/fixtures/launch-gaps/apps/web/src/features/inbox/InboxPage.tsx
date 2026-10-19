import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useModuleEnabled } from '../../shared/entitlements/use-module-enabled';

interface Thread {
  id: string;
  customer: string;
  lastMessage: string;
}

export function InboxPage() {
  const enabled = useModuleEnabled('whatsapp_inbox');
  const [openId, setOpenId] = useState<string | null>(null);
  const threads = useQuery({ queryKey: ['inbox'], queryFn: () => http.get('inbox/threads').json<Thread[]>(), enabled });
  const thread = useQuery({
    queryKey: ['inbox', openId],
    queryFn: () => http.get(`inbox/threads/${openId}`).json<{ messages: string[] }>(),
    enabled: enabled && !!openId,
  });
  if (!enabled) return null;
  return (
    <section>
      <h1>Inbox</h1>
      <ul>
        {(threads.data ?? []).map((t) => (
          <li key={t.id}>
            <button type="button" onClick={() => setOpenId(t.id)}>
              {t.customer}: {t.lastMessage}
            </button>
          </li>
        ))}
      </ul>
      {thread.data && <pre>{thread.data.messages.join('\n')}</pre>}
    </section>
  );
}
