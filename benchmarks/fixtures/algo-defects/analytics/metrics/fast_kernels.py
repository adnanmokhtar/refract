"""JIT kernels for the hourly KPI rollup: mean basket value per store, skipping baskets with a missing FX rate (NaN)."""
import numba
import numpy as np


@numba.jit(nopython=True, fastmath=True)
def mean_skipnan(values: np.ndarray) -> float:
    total = 0.0
    count = 0
    for i in range(values.shape[0]):
        v = values[i]
        if np.isnan(v):
            continue
        total += v
        count += 1
    return total / count if count else np.nan


@numba.jit(nopython=True)
def count_over(values: np.ndarray, threshold: float) -> int:
    n = 0
    for i in range(values.shape[0]):
        if values[i] > threshold:
            n += 1
    return n
