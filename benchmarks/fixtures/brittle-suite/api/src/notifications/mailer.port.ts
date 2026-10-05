export interface MailMessage {
  to: string;
  template: 'refund-approved' | 'refund-rejected' | 'return-label';
  vars: Record<string, string>;
}

// The transactional mail provider, behind a port the project owns.
export abstract class Mailer {
  abstract send(message: MailMessage): Promise<void>;
}
