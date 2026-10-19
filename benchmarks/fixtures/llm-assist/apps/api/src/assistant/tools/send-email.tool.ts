import type { Transporter } from 'nodemailer';

interface EmailArgs {
  to: string;
  subject: string;
  body: string;
}

export async function sendCustomerEmail(mailer: Transporter, args: EmailArgs): Promise<string> {
  const info = await mailer.sendMail({ from: 'support@quilldesk.example', to: args.to, subject: args.subject, text: args.body });
  return JSON.stringify({ sent: true, messageId: info.messageId });
}
