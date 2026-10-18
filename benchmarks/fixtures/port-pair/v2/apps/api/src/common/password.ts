import { compare } from 'bcryptjs';

// V1 stores bcrypt hashes ($2y$); bcryptjs verifies them unchanged.
export function verify(password: string, hash: string): Promise<boolean> {
  return compare(password, hash.replace(/^\$2y\$/, '$2a$'));
}
