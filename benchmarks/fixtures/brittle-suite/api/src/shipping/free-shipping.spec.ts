import { RETURN_LABEL_CENTS, returnLabelCharge } from './free-shipping';

describe('returnLabelCharge', () => {
  it('charges the label on a small order', () => {
    expect(returnLabelCharge(2_000)).toBe(RETURN_LABEL_CENTS);
  });

  it('ships the return free on a large order', () => {
    expect(returnLabelCharge(9_000)).toBe(0);
  });
});
