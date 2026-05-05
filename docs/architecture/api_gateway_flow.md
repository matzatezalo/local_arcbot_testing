# Architecture Flow: API Gateway Process

**Generated on:** April 28, 2026

**Source Scope:** `src/api_gateway.py`

## Mermaid Diagram

```mermaid
flowchart TD
    A([API Request: Create Order]) --> B[ApiGateway.createOrder]
    B --> C[Order instantiated]
    C --> D[OrderRepository.save]
    D --> E([Order persisted])
    
    F([API Request: Process Payment]) --> G[ApiGateway.processPayment]
    G --> H[OrderRepository.find_by_id]
    H --> I{Order exists?}
    I -- Yes --> J[PaymentService.charge]
    J --> K([Payment recorded & Order.markPaid])
    I -- No --> L([Raise error: Order not found])
    
    M([API Request: Get Order]) --> N[ApiGateway.getOrder]
    N --> O[OrderRepository.find_by_id]
    O --> P{Order exists?}
    P -- Yes --> Q([Return Order])
    P -- No --> R([Raise error: Order not found])
    
    S([API Request: Process Refund]) --> T[ApiGateway.processRefund]
    T --> U[Refund instantiated]
    U --> V[Refund.approve]
    V --> W[PaymentService.refund]
    W --> X{Success?}
    X -- Yes --> Y[Refund.complete]
    Y --> Z([Refund completed])
    X -- No --> AA([Return Refund])
```

## Flow Description

This diagram depicts the primary API Gateway flows:
- Order creation, processing, and storage; payment processing after order validation; retrieval and error handling for non-existent orders; and handling of refund requests involving refund approval, payment service interaction, and status updates.
