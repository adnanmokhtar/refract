import { IsEmail, IsEnum, IsOptional } from 'class-validator';

export enum TicketPriority { Low, Normal, High, Urgent }

export class UpdateTicketDto {
  @IsOptional()
  @IsEnum(TicketPriority)
  priority?: TicketPriority;

  @IsOptional()
  @IsEmail()
  assigneeEmail?: string;
}
