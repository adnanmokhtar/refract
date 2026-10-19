import { Body, Controller, NotFoundException, Param, Post } from '@nestjs/common';
import { GatewayClient } from '../llm/gateway.client';
import { TrackingService } from '../tracking/tracking.service';

class AskDto {
  question!: string;
}

// Public: the tracking page is opened from an SMS link, so there is no login.
@Controller('track')
export class AssistantController {
  constructor(private readonly gateway: GatewayClient, private readonly tracking: TrackingService) {}

  @Post(':code/assistant')
  async ask(@Param('code') code: string, @Body() dto: AskDto): Promise<{ answer: string }> {
    const shipment = await this.tracking.findPublic(code);
    if (!shipment) {
      throw new NotFoundException();
    }
    const answer = await this.gateway.complete(
      [
        { role: 'system', content: this.tracking.assistantPrompt(shipment) },
        { role: 'user', content: dto.question.slice(0, 2_000) },
      ],
      { tenantId: shipment.tenantId, feature: 'tracking-assistant' },
    );
    return { answer };
  }
}
