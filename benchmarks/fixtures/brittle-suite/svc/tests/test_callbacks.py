import hashlib
import hmac

from app.callbacks import handle_merchant_callback


def test_records_a_signed_approval_from_the_merchant():
    body = b'{"refund_id": "rf_1", "decision": "approve"}'
    signature = hmac.new(b"", body, hashlib.sha256).hexdigest()
    assert handle_merchant_callback(body, signature) == "approve"
