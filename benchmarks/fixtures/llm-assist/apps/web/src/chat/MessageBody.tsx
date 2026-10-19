import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import type { ChatLine } from './types';

/** Renders one assistant message in the agent's chat panel. */
export function MessageBody({ line }: { line: ChatLine }) {
  return (
    <div className="message-body">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{line.text}</ReactMarkdown>
      <time dateTime={line.createdAt}>{new Date(line.createdAt).toLocaleTimeString()}</time>
    </div>
  );
}
