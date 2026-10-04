export interface AuthUser {
  id: string;
  email: string;
  // Platform roles only; store roles live in store_member.
  roles: ('buyer' | 'support' | 'finance' | 'platform_admin')[];
}
