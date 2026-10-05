package dev.returnsdesk.payouts;

import static org.junit.Assert.assertEquals;

import java.time.LocalDate;
import org.junit.Test;

public class PayoutScheduleTest {
    @Test
    public void saturdayMovesToMonday() {
        assertEquals(LocalDate.of(2026, 10, 12), PayoutSchedule.payoutDate(LocalDate.of(2026, 10, 10)));
    }

    @Test
    public void sundayMovesToMonday() {
        assertEquals(LocalDate.of(2026, 10, 12), PayoutSchedule.payoutDate(LocalDate.of(2026, 10, 11)));
    }

    @Test
    public void weekdayStays() {
        assertEquals(LocalDate.of(2026, 10, 7), PayoutSchedule.payoutDate(LocalDate.of(2026, 10, 7)));
    }
}
