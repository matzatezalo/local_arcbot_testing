from dataclasses import dataclass, field
from typing import List
import uuid


@dataclass
class Order:
    customer_id: str
    items: List[dict]
    order_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: str = "pending"
    total: float = 0.0

    def calculate_total(self) -> float:
        self.total = sum(item.get("price", 0) * item.get("qty", 1) for item in self.items)
        return self.total

    def mark_paid(self) -> None:
        self.status = "paid"


@dataclass
class PriorityOrder(Order):
    priority_fee: float = 15.0

    def calculate_total(self) -> float:
        base_total = super().calculate_total()
        self.total = base_total + self.priority_fee
        return self.total


@dataclass
class Payment:
    order_id: str
    amount: float
    provider_ref: str
    payment_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: str = "pending"

    def is_successful(self) -> bool:
        return self.status == "completed"


@dataclass
class Refund:
    payment_id: str
    amount: float
    reason: str
    refund_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: str = "pending"

    def approve(self) -> None:
        self.status = "approved"

    def complete(self) -> None:
        self.status = "completed"
