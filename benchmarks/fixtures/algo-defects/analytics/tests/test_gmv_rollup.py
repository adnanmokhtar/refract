import math

from analytics.metrics.gmv_rollup import RECONCILE_RTOL, group_gmv_nzd, reconciles


def test_small_month_reconciles():
    amounts = [12.5, 0.35, 104_990.0, 7.2]
    assert reconciles(group_gmv_nzd(amounts), math.fsum(amounts))


def test_tolerance_is_finance_threshold():
    assert RECONCILE_RTOL == 1e-9
