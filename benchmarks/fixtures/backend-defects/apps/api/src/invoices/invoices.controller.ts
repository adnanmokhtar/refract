import { Body, ClassSerializerInterceptor, Controller, Get, Param, Post, SerializeOptions, UseInterceptors, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { plainToInstance } from 'class-transformer';
import { InvoiceResponse } from './dto/invoice.response';
import { CreateInvoiceDto } from './dto/create-invoice.dto';
import { IssueInvoiceUseCase } from './issue-invoice.use-case';

@Controller('invoices')
@UseInterceptors(ClassSerializerInterceptor)
@SerializeOptions({ excludeExtraneousValues: true })
export class InvoicesController {
  constructor(private readonly issueInvoice: IssueInvoiceUseCase) {}

  @Get(':id')
  async find(@Param('id') id: string): Promise<InvoiceResponse> {
    return plainToInstance(InvoiceResponse, await this.issueInvoice.find(id));
  }

  @Post()
  async create(@Body() dto: CreateInvoiceDto, @Res({ passthrough: true }) reply: FastifyReply): Promise<InvoiceResponse> {
    const invoice = await this.issueInvoice.execute(dto);
    reply.status(201).header('Location', `/v1/invoices/${invoice.id}`);
    return plainToInstance(InvoiceResponse, invoice);
  }
}
