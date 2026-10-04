import { Injectable, NotFoundException } from '@nestjs/common';
import { template } from 'lodash';
import { PrismaService } from '../prisma/prisma.service';

export interface TemplateDraft {
  kind: 'order-confirmation' | 'shipping-update';
  subject: string;
  body: string;
}

const SAMPLE_ORDER = {
  number: 10423,
  totalCents: 4599,
  items: [{ title: 'Linen tote bag', quantity: 1, unitPriceCents: 4599 }],
  buyer: { displayName: 'Sample Buyer' },
};

@Injectable()
export class EmailTemplatesService {
  constructor(private readonly prisma: PrismaService) {}

  // Sellers write their own transactional emails in the dashboard, using <%= order.number %>
  // style placeholders. Preview renders the draft against a sample order before saving.
  async preview(sellerId: string, draft: TemplateDraft) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { displayName: true, website: true },
    });
    if (!seller) throw new NotFoundException();

    const render = template(draft.body);
    return { subject: draft.subject, html: render({ order: SAMPLE_ORDER, seller }) };
  }

  async save(sellerId: string, draft: TemplateDraft) {
    return this.prisma.emailTemplate.upsert({
      where: { sellerId_kind: { sellerId, kind: draft.kind } },
      create: { sellerId, kind: draft.kind, subject: draft.subject, body: draft.body },
      update: { subject: draft.subject, body: draft.body },
    });
  }
}
