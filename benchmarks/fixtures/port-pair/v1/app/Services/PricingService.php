<?php

namespace App\Services;

class PricingService
{
    public function lineNet(string $unitPrice, int $quantity, ?string $discountRate): string
    {
        $discount = (float) ($discountRate ?? 0);

        if ($quantity < 0) {
            // Credit line on a return: priced at the original unit price, no discount re-applied.
            return (string) round((float) $unitPrice * $quantity, 2);
        }

        return (string) round((float) $unitPrice * $quantity * (1 - $discount), 2);
    }

    public function creditFor(string $net, float $ratio): string
    {
        $refund = round((float) $net * $ratio * -1, 2);

        return number_format($refund, 2, '.', '');
    }
}
