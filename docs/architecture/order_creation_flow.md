# Architecture Flow: Order Creation

**Generated on:** April 28, 2026

**Source Scope:** `src/api_gateway.py`, `src/models.py`, `src/order_repository.py`

## Mermaid Diagram

```mermaid
flowchart TD
    Start([Start: create_order]) --> CreateOrder[Create Order with customerId and items]
    CreateOrder --> SaveOrder[(Save Order to Repository)]
    SaveOrder --> CalcTotal[Calculate Order Total]
    CalcTotal --> SetStatus[Set Order Status to pending]
    SetStatus --> Return([Return Order])
```

## Process Dictionary

* **Start: create_order:** Entry point invoked when a client requests creation of a new order, supplying customer and item details.
* **Create Order with customerId and items:** Instantiate a new Order domain entity (or subtype), assign unique orderId, set status as pending.
* **Save Order to Repository:** Persist the order using the repository.
* **Calculate Order Total:** Sum item subtotals and add any priority/vip fees.
* **Set Order Status to pending:** Ensure Order’s initial state is pending.
* **Return Order:** Send back the created Order with details filled in.
