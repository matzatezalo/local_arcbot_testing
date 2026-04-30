# Architecture Flow: Payment Processing

**Generated on:** April 28, 2026

**Source Scope:** `src/api_gateway.py`, `src/payment_service.py`, `src/models.py`, `src/order_repository.py`

## Mermaid Diagram

```mermaid
flowchart TD
    Start([Start: process_payment]) --> FindOrder[(Find Order in Repository)]
    FindOrder --> CheckOrder{Order exists?}
    CheckOrder -->|No| ErrorNotFound([Throw: Order Not Found])
    CheckOrder -->|Yes| CreatePayment[Create Payment Record]
    CreatePayment --> SetProviderRef[Set Payment Provider Reference]
    SetProviderRef --> CallCharge[Call PaymentService.charge]
    CallCharge --> MarkPaid[Mark Order as Paid]
    MarkPaid --> SetPaymentStatus[Set Payment Status to completed]
    SetPaymentStatus --> ReturnPayment([Return Payment])
```

## Process Dictionary

* **Start: process_payment:** Begins the processing of payment after a client initiates a charge operation with an order ID and amount.
* **Find Order in Repository:** Check order existence and retrieve it for payment.
* **Order exists?:** If not found, throw an error; else, proceed to payment creation.
* **Throw: Order Not Found:** Halt flow, respond with an error to the client.
* **Create Payment Record:** Generate a payment entity tied to the order.
* **Set Payment Provider Reference:** Assign a provider-specific reference for audit/followup.
* **Call PaymentService.charge:** Process the payment with the external provider logic.
* **Mark Order as Paid:** Update order status to reflect successful payment.
* **Set Payment Status to completed:** Confirm payment completion in the payment record.
* **Return Payment:** Output payment details to API client with all relevant identifiers and statuses.
