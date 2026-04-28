# Architecture Model: Domain

**Generated on:** April 28, 2026

**Source Scope:** `src`

## Mermaid Diagram

```mermaid
classDiagram
    class Order {
        +customerId: string
        +items: list
        +orderId: string
        +status: string
        +total: float
        +calculateTotal(): float
        +markPaid()
    }
    class PriorityOrder {
        +priorityFee: float
        +calculateTotal(): float
    }
    class Payment {
        +orderId: string
        +amount: float
        +providerRef: string
        +paymentId: string
        +status: string
        +isSuccessful(): bool
    }
    class Refund {
        +paymentId: string
        +amount: float
        +reason: string
        +refundId: string
        +status: string
        +approve()
        +complete()
    }
    Order "1" o-- "0..*" Payment
    Payment "1" o-- "0..*" Refund
    PriorityOrder --|> Order
```

## Entity Dictionary

* **Order:** Represents a customer order containing information on customer identifier, items, and order state. Calculates total and tracks payment status.
* **PriorityOrder:** Special order type with priority fee and custom total calculation logic.
* **Payment:** Represents a payment transaction linked to an order, including provider details and transaction status.
* **Refund:** Represents a refund transaction tied to a payment, tracking reason and refund process status.
