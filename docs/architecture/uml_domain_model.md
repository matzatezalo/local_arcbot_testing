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
```

## Entity Dictionary

* **ApiGateway:** Serves as the primary facade for all order, payment, and refund processes. It coordinates requests and delegates underlying logic to the appropriate internal logic and models.
* **Order:** Represents a customer's purchase order, maintaining purchased items, identifiers, status, and total value calculation logic.
* **Payment:** Records payment transactions for an order, holding amount, external provider info, and current status. Includes a method to determine if payment was successful.
* **Refund:** Details refund operations tied to a specific payment, holding refund status, amount, and business logic for approval and completion.
