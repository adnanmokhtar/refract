"""Experiment arms for the checkout experiments. A shopper must stay in one arm for the life of the experiment."""

VARIANTS = ("control", "one_page_checkout", "express_pay_first")


def arm_for(user_id: str) -> str:
    return VARIANTS[hash(user_id) % len(VARIANTS)]


def exposure_event(user_id: str, experiment: str) -> dict:
    return {"user_id": user_id, "experiment": experiment, "arm": arm_for(user_id)}
