# Architecture Flow: Payment Processing

**Generated on:** April 28, 2026
**Source Scope:** `/src/api_gateway.py`, `/src/payment_service.py`, `/src/models.py`, `/src/order_repository.py`

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

* **Start: process_payment:** Entry point when client requests payment processing with order ID and amount.

* **Find Order in Repository:** Query OrderRepository by orderId to retrieve stored Order instance.

* **Order exists?:** Decision branch: verify that requested Order was previously created and stored.

* **Throw: Order Not Found:** Terminal error state if Order lookup fails. Return HTTP 404 error to client.

* **Create Payment Record:** Instantiate new Payment domain entity with order_id, amount, and auto-generated paymentId.

* **Set Payment Provider Reference:** Generate provider reference string (e.g., "stripe_ref_<order_id_prefix>") for audit trail and provider reconciliation.

* **Call PaymentService.charge:** Invoke payment processing service to charge the payment provider and obtain authorization.

* **Mark Order as Paid:** Update Order status to 'paid' via `Order.markPaid()`. Signals downstream that payment was successful.

* **Set Payment Status to completed:** Update Payment status to 'completed' after successful charge authorization.

* **Return Payment:** Send Payment instance back to client with all transaction details including payment ID, amount, and provider reference.
