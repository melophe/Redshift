# Redshift Learning Notes

This repository contains notes and examples for learning Amazon Redshift.

## Contents

- [Basics](./basics/redshift-overview.md) - What is Redshift and core concepts

## What is Amazon Redshift?

Amazon Redshift is a fully managed, petabyte-scale **data warehouse** service in the cloud.

### Key Characteristics

| Feature | Description |
|---------|-------------|
| Type | Columnar data warehouse (OLAP) |
| Scale | Petabyte-scale |
| Based on | PostgreSQL (with modifications) |
| Pricing | Pay-per-use |

### OLTP vs OLAP

| | OLTP | OLAP (Redshift) |
|---|------|-----------------|
| Purpose | Transaction processing | Analytics/Reporting |
| Operations | INSERT, UPDATE, DELETE | SELECT (aggregations) |
| Data Volume | Small per query | Large per query |
| Example | Order system | Sales analysis |
"# Redshift" 
