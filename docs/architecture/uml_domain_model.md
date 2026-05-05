# Architecture Model: Domain

**Generated on:** April 28, 2026

**Source Scope:** `src`

## Mermaid Diagram

```mermaid
classDiagram
    class ApiGateway {
        +baseUrl: str
        +createOrder(customerId: str, items: list)
        +processPayment(orderId: str, amount: float)
        +getOrder(orderId: str)
        +processRefund(paymentId: str, reason: str)
    }
    class Order {
        +customerId: str
        +items: list
        +orderId: str
        +status: str
        +total: float
        +calculateTotal()
        +markPaid()
    }
    class PriorityOrder {
        +order: Order
        +priorityFee: float
        +calculateTotal()
    }
    class Payment {
        +orderId: str
        +amount: float
        +providerRef: str
        +paymentId: str
        +status: str
        +isSuccessful()
    }
    class Refund {
        +paymentId: str
        +amount: float
        +reason: str
        +refundId: str
        +status: str
        +approve()
        +complete()
    }
    
    ApiGateway --> Order : creates/gets
    ApiGateway --> Payment : processes
    ApiGateway --> Refund : processes
    PriorityOrder *-- Order : base order
    Payment --> Order : for order
    Refund --> Payment : for payment
```

## Entity Dictionary

* **ApiGateway:** Main access point for API actions, orchestrates order, payment and refund flows.
* **Order:** Aggregate root for a purchase; tracks customer, items, total, and status.
* **PriorityOrder:** Decorates an Order with priority processing and extra fee.
* **Payment:** Represents a payment transaction for an order with status and external reference.
* **Refund:** Represents a refund transaction tied to a payment, with status control.
