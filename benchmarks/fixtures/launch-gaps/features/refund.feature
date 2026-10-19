Feature: Refunds from the order page

  Background:
    Given a signed-in merchant

  @AC-002
  Scenario: A partial refund keeps the order open
    Given a paid order with 3 lines
    When the merchant refunds 1 line
    Then the order status is "partially_refunded"

  @AC-014
  Scenario: A refund puts the stock back
    Given a paid order with 3 lines
    When the merchant refunds 1 line
    Then the refunded line's stock is back on the shelf
