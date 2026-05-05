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
    class ImportantOrder {
        + specialInstructions: string
    }
    class EvenMoreImportantOrder {
        + escalationLevel: int
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
    ApiGateway --> Order
    ApiGateway --> Payment
    ApiGateway --> Refund
    Payment "1" o-- "1" Order
    Refund "1" o-- "1" Payment
    PriorityOrder --|> Order
    ImportantOrder --|> Order
    EvenMoreImportantOrder --|> ImportantOrder
```

## Entity Dictionary

* **ApiGateway:** Serves as the primary facade for all order, payment, and refund processes. Coordinates requests and delegates underlying logic to appropriate internal logic and models.
* **Order:** Represents a customer's purchase order, maintaining purchased items, identifiers, status, and total value calculation logic.
* **PriorityOrder:** An extension of Order for rush purchases, adding a priority fee and overriding total calculation.
* **ImportantOrder:** Inherits from Order, representing high-importance orders and typically holding special instructions.
* **EvenMoreImportantOrder:** Inherits from ImportantOrder, modeling top-priority orders with escalation levels.
* **Payment:** Records payment transactions for an order, holding amount, external provider info, and current status. Includes a method to determine if payment was successful.
* **Refund:** Details refund operations tied to a specific payment, holding refund status, amount, and business logic for approval and completion.
