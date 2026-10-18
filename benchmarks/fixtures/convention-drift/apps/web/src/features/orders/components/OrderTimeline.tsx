import { useEffect, useState } from 'react';
import { formatDate } from '@acme/format';

type OrderTimelineProps = { events: Array<{ id: string; label: string; at: string }> };

export function OrderTimeline({ events }: OrderTimelineProps) {
  const [relative, setRelative] = useState<Record<string, string>>({});

  useEffect(() => {
    let isCancelled = false;
    (async () => {
      const { default: dayjs } = await import('dayjs');
      const { default: relativeTime } = await import('dayjs/plugin/relativeTime');
      dayjs.extend(relativeTime);
      if (!isCancelled) setRelative(Object.fromEntries(events.map((e) => [e.id, dayjs(e.at).fromNow()])));
    })();
    return () => {
      isCancelled = true;
    };
  }, [events]);

  return (
    <ol>
      {events.map((e) => (
        <li key={e.id}>
          {e.label} · <time dateTime={e.at} title={formatDate(e.at)}>{relative[e.id] ?? formatDate(e.at)}</time>
        </li>
      ))}
    </ol>
  );
}
