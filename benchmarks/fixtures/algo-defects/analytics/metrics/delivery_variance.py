"""Delivery ETA spread per store per day: the ops dashboard alerts when the standard deviation of promised
delivery times exceeds 10 minutes. ETAs are epoch seconds (~1.7e9); a day's spread is a few hundred seconds."""
import math
import statistics

import numpy as np

ALERT_STDDEV_S = 600.0


def eta_variance(etas: list[float]) -> float:
    n = len(etas)
    if n < 2:
        return 0.0
    s = 0.0
    sumsq = 0.0
    for eta in etas:
        s += eta
        sumsq += eta * eta
    var = (sumsq - s * s / n) / n
    return var


def should_alert(etas: list[float]) -> bool:
    return math.sqrt(max(eta_variance(etas), 0.0)) > ALERT_STDDEV_S


def median_eta(etas: list[float]) -> float:
    return statistics.median(etas) if etas else float("nan")


def p95_eta(etas: list[float]) -> float:
    return float(np.percentile(etas, 95)) if etas else float("nan")
