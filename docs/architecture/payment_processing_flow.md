# Architecture Flow: Payment Processing

**Generated on:** April 28, 2026

**Source Scope:** `src`

## Mermaid Diagram

```mermaid
flowchart TD
    Start([Start: process_payment]) --> FindOrder[(Find Order in Repository)]
    FindOrder --> OrderExists{Order found?}
    OrderExists --|No| ErrorNotFound([Throw: Order Not Found])
    OrderExists --|Yes| CreatePayment[Create Payment Record]
    CreatePayment --> SetProviderRef[Generate Payment Provider Reference]
    SetProviderRef --> PaymentCharge[Call PaymentService.charge]
    PaymentCharge --> MarkPaid[Mark Order as Paid]
    MarkPaid --> SetPaymentStatus[Set Payment Status to completed]
    SetPaymentStatus --> ReturnPayment([Return Payment])
```

## Flow Description

* **Start: process_payment:** Initiates payment procedure for an existing order, given orderId and amount.

* **Find Order in Repository:** Looks up Order entity by ID using OrderRepository.

* **Order found?:** Decision point verifying if the order was found; throws error if not found.

* **Throw: Order Not Found:** Halts flow if no record is found for supplied orderId.

* **Create Payment Record:** Creates a Payment entity associated with the order, recording amount and assigning a paymentId.

* **Generate Payment Provider Reference:** Produces external provider reference (e.g., Stripe) for tracking.

* **Call PaymentService.charge:** Calls payment provider logic to process the payment and update Payment entity.

* **Mark Order as Paid:** Marks the relevant Order as paid on successful payment completion.

* **Set Payment Status to completed:** Updates Payment status to 'completed' upon confirmed provider charge.

* **Return Payment:** Returns Payment entity details back to the client.
