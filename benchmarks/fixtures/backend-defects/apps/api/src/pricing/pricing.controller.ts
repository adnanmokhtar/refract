import { Body, Controller, Delete, HttpCode, Param, Post, Put } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { WriteCollectionDto } from './dto/write-collection.dto';
import { CollectionsService } from './collections.service';
import { ApplyRateCardDto } from './dto/apply-rate-card.dto';
import { ApplyRateCardUseCase } from './rate-cards.use-case';

@Controller('pricing')
export class PricingController {
  constructor(private readonly collections: CollectionsService, private readonly applyRateCard: ApplyRateCardUseCase) {}

  /** Replace a price collection; a null body clears it. */
  @Put('collections/:id')
  async write(
    @CurrentUser() user: Principal,
    @Param('id') id: string,
    @Body() dto: WriteCollectionDto | null,
  ): Promise<{ id: string }> {
    return this.collections.write(user, id, dto);
  }

  @Delete('collections/:id')
  @HttpCode(204)
  async remove(@Param('id') id: string): Promise<void> {
    await this.collections.remove(id);
  }

  @Post('rate-cards/apply')
  @HttpCode(200)
  async apply(@Body() dto: ApplyRateCardDto): Promise<{ rate: string }> {
    return this.applyRateCard.execute(dto);
  }
}
