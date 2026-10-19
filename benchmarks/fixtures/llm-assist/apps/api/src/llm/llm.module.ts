import { Global, Module } from '@nestjs/common';
import { EmbeddingsClient } from './embeddings.client';
import { LlmGatewayPort } from './llm-gateway.port';
import { OpenAiCompatGateway } from './openai-compat.gateway';
import { ResponsesGateway } from './responses.gateway';
import { SecondaryGateway } from './secondary.gateway';

@Global()
@Module({
  providers: [
    SecondaryGateway,
    ResponsesGateway,
    EmbeddingsClient,
    { provide: LlmGatewayPort, useClass: OpenAiCompatGateway },
  ],
  exports: [LlmGatewayPort, ResponsesGateway, EmbeddingsClient],
})
export class LlmModule {}
