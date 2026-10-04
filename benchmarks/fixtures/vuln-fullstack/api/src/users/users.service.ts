import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './update-profile.dto';

const SELF_FIELDS = {
  id: true,
  email: true,
  role: true,
  displayName: true,
  bio: true,
  website: true,
  avatarUrl: true,
  createdAt: true,
} as const;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  me(userId: string) {
    return this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: SELF_FIELDS });
  }

  // Public seller page on the storefront: profile plus published listings.
  publicProfile(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { products: { where: { status: 'PUBLISHED' }, take: 24 } },
    });
  }

  updateProfile(userId: string, patch: UpdateProfileDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: patch,
      select: SELF_FIELDS,
    });
  }
}
