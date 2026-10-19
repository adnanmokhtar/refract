"""Weekly demand model per SKU: ordinary least squares on price, promo flag, temperature and day-of-week dummies.
Price and the promo-discounted price are both features, so columns are close to collinear for SKUs that rarely change price."""
import numpy as np


def design_matrix(price: np.ndarray, promo_price: np.ndarray, promo: np.ndarray, temp_c: np.ndarray, dow: np.ndarray) -> np.ndarray:
    dummies = np.eye(7)[dow][:, 1:]
    return np.column_stack([np.ones_like(price), price, promo_price, promo, temp_c, dummies])


def fit_demand(X: np.ndarray, y: np.ndarray) -> np.ndarray:
    beta = np.linalg.inv(X.T @ X) @ X.T @ y
    return beta


def forecast(X_next: np.ndarray, beta: np.ndarray) -> np.ndarray:
    return np.clip(X_next @ beta, 0.0, None)
