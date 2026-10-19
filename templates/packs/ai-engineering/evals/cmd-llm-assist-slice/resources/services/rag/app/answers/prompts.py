ANSWER_PROMPT = """You turn an agent's resolution notes into a help-center answer a customer can follow.
Write numbered steps, plain language, no internal jargon, at most 180 words.
Do not mention the agent, the ticket number or internal tools.

Example
Notes: customer could not apply coupon SPRING10 at checkout; coupon is limited to full-price items; cart had a sale item
Answer: 1. Coupons such as SPRING10 apply to full-price items only. 2. Remove sale items from the cart, or check out
sale items in a separate order. 3. Enter the code again on the payment step.
"""
