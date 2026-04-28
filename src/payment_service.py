from .models import Order, Payment


class PaymentService:
    def __init__(self, provider: str = "stripe") -> None:
        self.provider = provider
        self._payments: dict[str, Payment] = {}

    def charge(self, order: Order, amount: float) -> Payment:
        # Stub: in production this would call the payment provider API
        provider_ref = f"{self.provider}_ref_{order.order_id[:8]}"
        payment = Payment(
            order_id=order.order_id,
            amount=amount,
            provider_ref=provider_ref,
            status="completed",
        )
        self._payments[payment.payment_id] = payment
        order.mark_paid()
        return payment

    def refund(self, payment_id: str) -> bool:
        payment = self._payments.get(payment_id)
        if payment and payment.is_successful():
            payment.status = "refunded"
            return True
        return False

    def get_payment(self, payment_id: str) -> Payment | None:
        return self._payments.get(payment_id)
