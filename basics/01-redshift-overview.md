# Redshift Overview

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Leader Node                     │
│  - SQL parsing                                   │
│  - Query planning                                │
│  - Result aggregation                            │
└─────────────────────┬───────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌───────────┐  ┌───────────┐  ┌───────────┐
│  Compute  │  │  Compute  │  │  Compute  │
│  Node 1   │  │  Node 2   │  │  Node 3   │
│           │  │           │  │           │
│  Slices   │  │  Slices   │  │  Slices   │
└───────────┘  └───────────┘  └───────────┘
```

### Components

1. **Leader Node**
   - Receives queries from clients
   - Parses and creates execution plans
   - Distributes work to compute nodes
   - Aggregates results and returns to client

2. **Compute Nodes**
   - Store data
   - Execute queries in parallel
   - Each node has multiple "slices"

3. **Slices**
   - Each slice processes a portion of data
   - Parallel processing unit within a node

## Columnar Storage

Traditional row-based vs Redshift columnar:

```
Row-based (OLTP):
┌────┬───────┬─────┬────────┐
│ ID │ Name  │ Age │ Salary │  ← Row 1
├────┼───────┼─────┼────────┤
│ ID │ Name  │ Age │ Salary │  ← Row 2
└────┴───────┴─────┴────────┘

Columnar (Redshift):
┌────┬────┬────┐  ┌───────┬───────┬───────┐
│ ID │ ID │ ID │  │ Name  │ Name  │ Name  │  ...
└────┴────┴────┘  └───────┴───────┴───────┘
   Column 1            Column 2
```

### Benefits of Columnar Storage

1. **Less I/O** - Only read columns needed for query
2. **Better compression** - Same data types compress well
3. **Vectorized processing** - Process column data efficiently

## Node Types

| Type | Use Case |
|------|----------|
| **RA3** | Recommended. Managed storage, pay separately for compute and storage |
| **DC2** | Dense Compute. Fast SSD, good for < 1TB |
| **DS2** | Dense Storage. Legacy, use RA3 instead |

## Redshift Serverless vs Provisioned

| | Provisioned | Serverless |
|---|-------------|------------|
| Management | Manual cluster sizing | Auto-scaling |
| Pricing | Per node per hour | Per RPU (Redshift Processing Unit) |
| Use case | Predictable workloads | Variable/unpredictable workloads |
