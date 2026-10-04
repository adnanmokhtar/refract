import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AdminGuard } from '../auth/admin.guard';
import { PrismaService } from '../prisma/prisma.service';

@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('users')
  listUsers(@Query('page') page = '1') {
    const skip = (Math.max(Number(page) || 1, 1) - 1) * 50;
    return this.prisma.user.findMany({
      select: { id: true, email: true, role: true, displayName: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      skip,
      take: 50,
    });
  }

  // Seller onboarding: staff approve a buyer account as a seller.
  @Patch('users/:id/role')
  setRole(@Param('id', ParseUUIDPipe) id: string, @Body() body: { role: Role }) {
    if (!Object.values(Role).includes(body.role)) return { ok: false };
    return this.prisma.user.update({
      where: { id },
      data: { role: body.role },
      select: { id: true, role: true },
    });
  }
}
