/** A seasonal campaign the merchant schedules from the dashboard ("Sale runs 2026-11-27 to 2026-11-30"). */
export interface CampaignDto {
  startsOn: string; // 'YYYY-MM-DD' from the date picker
  endsOn: string;
}

export function campaignWindow(dto: CampaignDto): { startsAt: Date; endsAt: Date } {
  const startsAt = new Date(dto.startsOn);
  const endsAt = new Date(`${dto.endsOn}T23:59:59`);
  return { startsAt, endsAt };
}
