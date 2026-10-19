import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { http } from '../../shared/api/http';
import { useTracking } from '../../shared/tracking/TrackingProvider';
import { Button } from '../../components/Button';

export function CouponField() {
  const { trackEvent } = useTracking();
  const [code, setCode] = useState('');
  const validate = useMutation({
    mutationFn: (c: string) => http.post('billing/coupons/validate', { json: { code: c } }).json<{ valid: boolean; percentOff: number | null }>(),
  });

  async function apply() {
    const res = await validate.mutateAsync(code);
    if (res.valid) trackEvent('Coupon Applied', { code, percent_off: res.percentOff });
  }

  return (
    <div className="coupon">
      <input value={code} onChange={(e) => setCode(e.target.value)} aria-label="Coupon code" />
      <Button variant="secondary" onClick={() => void apply()}>
        Apply
      </Button>
      {validate.data && !validate.data.valid && <p role="alert">That code is not valid.</p>}
    </div>
  );
}
