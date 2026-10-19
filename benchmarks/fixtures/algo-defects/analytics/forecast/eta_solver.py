"""Solves for the dispatch time that meets a promised ETA under the travel-time model t(d) = a*d + b*d**1.5 + c."""
import numpy as np


def travel_minutes(depart_offset: float, a: float, b: float, c: float) -> float:
    return a * depart_offset + b * np.power(max(depart_offset, 0.0), 1.5) + c


def dispatch_offset(target: float, a: float, b: float, c: float, x0: float = 10.0) -> float:
    x = x0
    err = travel_minutes(x, a, b, c) - target
    while abs(err) > 1e-9:
        slope = a + 1.5 * b * np.sqrt(max(x, 0.0))
        x = x - err / slope
        err = travel_minutes(x, a, b, c) - target
    return x
