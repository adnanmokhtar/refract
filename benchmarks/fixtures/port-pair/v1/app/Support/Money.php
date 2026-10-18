<?php

namespace App\Support;

final class Money
{
    /**
     * Split $total into $count parts that sum back to $total exactly; the remainder cents go
     * to the first parts.
     */
    public static function allocate(string $total, int $count): array
    {
        $cents = (int) round(((float) $total) * 100);
        $base = intdiv($cents, $count);
        $remainder = $cents - $base * $count;

        $parts = [];
        for ($i = 0; $i < $count; $i++) {
            $parts[] = number_format(($base + ($i < $remainder ? 1 : 0)) / 100, 2, '.', '');
        }

        return $parts;
    }
}
