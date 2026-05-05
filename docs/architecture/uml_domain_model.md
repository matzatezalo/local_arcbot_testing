# Architecture Model: Domain

**Generated on:** April 28, 2026

**Source Scope:** `src`

## Mermaid Diagram

```mermaid
classDiagram
    class ApiGateway {
        + baseUrl: string
        + createOrder(string, list)
        + processPayment(string, float)
        + getOrder(string)
        + processRefund(string, string)
    }
    class Order {
        + customerId: string
        + items: list
        + orderId: string
        + status: string
        + total: float
        + calculateTotal()
        + markPaid()
    }
    class PriorityOrder {
        + priorityFee: float
        + calculateTotal()
    }
    class Payment {
        + orderId: string
        + amount: float
        + providerRef: string
        + paymentId: string
        + status: string
        + isSuccessful(): bool
    }
    class Refund {
        + paymentId: string
        + amount: float
        + reason: string
        + refundId: string
        + status: string
        + approve()
        + complete()
    }

    PriorityOrder --|> Order
    ApiGateway --> Order
    ApiGateway --> Payment
    ApiGateway --> Refund
    Payment "1" o-- "1" Order
    Refund "1" o-- "1" Payment
```

## Entity Dictionary

* **ApiGateway:** Aggregates business logic for orders, payments, and refunds; exposes facade for external callers.
* **Order:** Represents a customer order, tracks purchased items, total, status, and unique orderId.
* **PriorityOrder:** Specialized Order with additional priorityFee and an overridden total calculation.
* **Payment:** Tracks completion and provider reference of a payment for an order; determines success state.
* **Refund:** Manages refund approvals and completion for a payment, containing reason and unique refundId.
