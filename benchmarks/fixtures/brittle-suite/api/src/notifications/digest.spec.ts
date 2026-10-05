import { startDigest } from './digest';

describe('startDigest', () => {
  it('flushes the pending returns every five minutes', () => {
    jest.useFakeTimers();
    const flush = jest.fn();
    const queue = { pending: ['ret_1', 'ret_2'], flush };

    startDigest(queue);
    jest.advanceTimersByTime(5 * 60_000);

    expect(flush).toHaveBeenCalledWith(['ret_1', 'ret_2']);
  });

  it('skips an empty interval', () => {
    const flush = jest.fn();
    startDigest({ pending: [], flush });
    jest.advanceTimersByTime(5 * 60_000);
    expect(flush).not.toHaveBeenCalled();
  });
});
