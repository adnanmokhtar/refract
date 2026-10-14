import { IsBoolean, IsOptional } from 'class-validator';

/** PATCH /v1/me/notification-prefs — merge patch: an absent field keeps its stored value. */
export class UpdateNotificationPrefsDto {
  @IsOptional()
  @IsBoolean()
  orderUpdates?: boolean;

  @IsOptional()
  @IsBoolean()
  marketing?: boolean = false;

  @IsOptional()
  @IsBoolean()
  sms?: boolean;
}
