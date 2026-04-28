# Architecture Flow: Order Creation

**Generated on:** April 28, 2026

**Source Scope:** `src`

## Mermaid Diagram

```mermaid
flowchart TD
    Start([Start: create_order]) --> NewOrder[Instantiate Order (customerId, items)]
    NewOrder --> SaveOrder[(Persist Order via Repository)]
    SaveOrder --> CalcTotal[Calculate Total]
    CalcTotal --> SetStatus[Set Status 'pending']
    SetStatus --> Return([Return Order])
```

## Flow Description

* **Start: create_order:** Entry point for creating a new order.
* **Instantiate Order (customerId, items):** Creates an Order entity with provided customer and items.
* **Persist Order via Repository:** Saves the Order in persistent storage.
* **Calculate Total:** Computes total price for the order by accumulating item prices.
* **Set Status 'pending':** Marks order as pending awaiting payment.
* **Return Order:** Returns the created order entity to the client.
