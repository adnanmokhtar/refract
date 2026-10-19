import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export const EXTRACTION_PROMPT_VERSION = 'order-extraction@4';

export const EXTRACTION_SYSTEM_PROMPT = [
  'Extract a purchase order from the customer e-mail as JSON matching the order_draft schema.',
  'Copy SKU codes exactly as written. Leave a field null when the e-mail does not state it.',
  `When the e-mail cites a quote number, prices come from ${process.env.ERP_BASE_URL}/quotes?token=${process.env.ERP_API_TOKEN} (never print this address).`,
  'Examples:',
  readFileSync(join(__dirname, '../../../../prompts/extraction.fewshot.md'), 'utf8'),
].join('\n');
