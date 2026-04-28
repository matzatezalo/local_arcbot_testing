from .models import Order, Payment, Refund
from .order_repository import OrderRepository
from .payment_service import PaymentService


class ApiGateway:
    def __init__(self, base_url: str = "http://localhost:8000") -> None:
        self.base_url = base_url
        self.payment_service = PaymentService()
        self.order_repository = OrderRepository()

    def create_order(self, customer_id: str, items: list[dict]) -> Order:
        order = Order(customer_id=customer_id, items=items)
        return self.order_repository.save(order)

    def process_payment(self, order_id: str, amount: float) -> Payment:
        order = self.order_repository.find_by_id(order_id)
        if order is None:
            raise ValueError(f"Order {order_id} not found")
        return self.payment_service.charge(order, amount)

    def get_order(self, order_id: str) -> Order:
        order = self.order_repository.find_by_id(order_id)
        if order is None:
            raise ValueError(f"Order {order_id} not found")
        return order

    def process_refund(self, payment_id: str, reason: str = "") -> Refund:
        refund = Refund(payment_id=payment_id, amount=0.0, reason=reason)
        refund.approve()
        success = self.payment_service.refund(payment_id)
        if success:
            refund.complete()
        return refund
