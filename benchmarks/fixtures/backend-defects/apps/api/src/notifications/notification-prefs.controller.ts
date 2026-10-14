import { Body, Controller, Patch } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { UpdateNotificationPrefsDto } from './dto/update-notification-prefs.dto';

@Controller('me/notification-prefs')
export class NotificationPrefsController {
  constructor(private readonly em: EntityManager) {}

  @Patch()
  async update(@CurrentUser() user: Principal, @Body() dto: UpdateNotificationPrefsDto): Promise<UpdateNotificationPrefsDto> {
    const patch = Object.fromEntries(Object.entries(dto).filter(([, v]) => v !== undefined));
    await this.em.getConnection().execute('update notification_prefs set prefs = prefs || ?::jsonb where user_id = ?', [JSON.stringify(patch), user.userId]);
    return dto;
  }
}
