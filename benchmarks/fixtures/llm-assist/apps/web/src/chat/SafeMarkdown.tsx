import ReactMarkdown from 'react-markdown';

/**
 * Markdown for the customer-facing help widget. Images are never loaded: an image in a model answer
 * becomes a plain link the customer can choose to open.
 */
export function SafeMarkdown({ text }: { text: string }) {
  return (
    <ReactMarkdown
      components={{
        img: ({ src, alt }) => (
          <a href={typeof src === 'string' ? src : undefined} target="_blank" rel="noopener noreferrer nofollow">
            {alt || 'image'}
          </a>
        ),
      }}
    >
      {text}
    </ReactMarkdown>
  );
}
