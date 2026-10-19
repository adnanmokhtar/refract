export type Role = 'system' | 'user' | 'assistant';

export interface ChatLine {
  id: string;
  role: Role;
  text: string;
  createdAt: string;
}

export const isFromCustomer = (line: ChatLine) => line.role === 'user';
