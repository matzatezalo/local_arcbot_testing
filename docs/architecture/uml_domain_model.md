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

* **ApiGateway:** Facade for order/payment/refund flow coordination, delegates actions to lower-level services and repositories.
* **Order:** Customer order holding order state, items, and calculation logic.
* **PriorityOrder:** Specialized Order with an additional priority fee and override for total calculation.
* **Payment:** Represents a monetary operation against an order with provider references and status evaluation.
* **Refund:** Represents a refund operation associated to a Payment, containing approval/completion logic.
