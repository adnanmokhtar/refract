package dev.returnsdesk.payouts;

import java.time.DayOfWeek;
import java.time.LocalDate;

/** Payouts run on business days; a weekend settlement moves to the next Monday. */
public final class PayoutSchedule {
    private PayoutSchedule() {}

    public static LocalDate payoutDate(LocalDate settlementDay) {
        DayOfWeek day = settlementDay.getDayOfWeek();
        if (day == DayOfWeek.SATURDAY) return settlementDay.plusDays(2);
        if (day == DayOfWeek.SUNDAY) return settlementDay.plusDays(1);
        return settlementDay;
    }
}
