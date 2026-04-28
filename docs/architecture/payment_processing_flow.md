# Architecture Flow: Payment Processing

**Generated on:** April 28, 2026

**Source Scope:** `src`

## Mermaid Diagram

```mermaid
flowchart TD
    Start([Start: process_payment]) --> FindOrder[(Repository: Find Order by ID)]
    FindOrder --> CheckExists{Does Order Exist?}
    CheckExists --|No| Error([Throw: Order Not Found])
    CheckExists --|Yes| MakePayment[Instantiate Payment]
    MakePayment --> GenRef[Generate Provider Ref]
    GenRef --> Charge[PaymentService.charge]
    Charge --> MarkPaid[Order.markPaid()]
    MarkPaid --> SetPaidStatus[Set Payment Status 'completed']
    SetPaidStatus --> Return([Return Payment])
```

## Flow Description

* **Start: process_payment:** Initiates payment processing for a specified order.
* **Repository: Find Order by ID:** Looks up order in storage by orderId.
* **Does Order Exist?:** Checks if order lookup succeeded.
* **Throw: Order Not Found:** Returns error if order not found.
* **Instantiate Payment:** Creates a new Payment entity for the order.
* **Generate Provider Ref:** Assigns external payment provider reference.
* **PaymentService.charge:** Processes payment with provider, updates status.
* **Order.markPaid():** Marks order as paid upon successful charge.
* **Set Payment Status 'completed':** Finalizes payment status.
* **Return Payment:** Returns payment record to client.
