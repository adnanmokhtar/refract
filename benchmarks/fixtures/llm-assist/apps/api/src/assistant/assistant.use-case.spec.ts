import { AssistantUseCase } from './assistant.use-case';

const STUB_REPLY = 'Your order QD-1042 ships on Tuesday.';

describe('AssistantUseCase', () => {
  it('answers a shipping question', async () => {
    const gateway = {
      complete: jest.fn().mockResolvedValue({
        message: { role: 'assistant', content: STUB_REPLY },
        finishReason: 'stop',
        usage: { prompt_tokens: 120, completion_tokens: 9 },
      }),
    };
    const ok = jest.fn().mockResolvedValue(undefined);
    const useCase = new AssistantUseCase(
      gateway as never,
      { debit: ok } as never,
      { load: jest.fn().mockResolvedValue([]), append: ok } as never,
      { rememberFromTurn: ok } as never,
      { build: jest.fn().mockResolvedValue([]) } as never,
      { run: ok } as never,
      { record: ok } as never,
    );

    const reply = await useCase.turn({
      accountId: 'acc_1',
      tenantId: 'ten_1',
      conversationId: 'conv_1',
      turnId: 'turn_1',
      text: 'When does my order ship?',
      mode: 'full',
    });

    expect(reply).toBe(STUB_REPLY);
  });
});
