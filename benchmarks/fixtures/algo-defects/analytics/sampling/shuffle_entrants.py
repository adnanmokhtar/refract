"""Draw order for the in-store tasting sign-up: the first `seats` entrants after the shuffle get a seat."""
import random


def shuffle_entrants(xs: list[str]) -> list[str]:
    for i in range(len(xs)):
        j = random.randrange(len(xs))
        xs[i], xs[j] = xs[j], xs[i]
    return xs


def seat_list(entrants: list[str], seats: int) -> list[str]:
    return shuffle_entrants(list(entrants))[:seats]
