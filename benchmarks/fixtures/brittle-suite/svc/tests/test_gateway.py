from unittest.mock import MagicMock

import pytest

from app.refunds import RefundRejected, issue_refund


def test_issues_a_partial_refund_through_the_gateway():
    gw = MagicMock()
    gw.capture_refund.return_value = "re_778"

    ref = issue_refund(gw, "pi_1", 1_200, 4_800)

    assert ref == "re_778"
    gw.capture_refund.assert_called_once_with("pi_1", 1_200)


def test_refuses_to_refund_more_than_was_captured():
    with pytest.raises(RefundRejected):
        issue_refund(MagicMock(), "pi_1", 5_000, 4_800)
