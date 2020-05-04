---
title: Database Internals Ch.1 Introduction and Overview
date: 2020-05-02 04:15:27
tags:
- reading_note
- data_engineering
- database_internals
---

- storage medium
  - Memory- vs. Disk-Based
- layout
  - Column- vs. Row-Oriented
- other taxonomy (not discussed)
  - OLTP vs. OLAP vs. HTAP (Hybrid Transactional & Analytical Processing)
  - k-v store, relational, document-oriented, graph databases

## DBMS Architecture

- Transport
  - Cluster Communication
  - Client Communication
- Query Processor
  - Query Parser
    - parse, interpret, validate, access control
  - Query Optimizer
    - based on internal statistics, index cardinality, approx. intersection size
    - data placement
    - usually presented as dependency tree for execution plan/query plan
- Execution Engine
  - Remote Execution
    - read/write, replication
  - Local Execution
- Storage Engine
  - Transaction Manager
    - schedule transaction
    - ensure logical consistent
  - Lock Manager
    - ensure physical data integrity
  - Access Methods
    - manage access and organizing data on disk
    - heap file, B-Trees, LSM Trees (discussed later)
  - Buffer Manager
    - cache data pages
  - Recovery Manager
    - operation logs and restoring


## Memory- Versus Disk-Based DBMS

| main memory | disk-based |
|---|---|
| primary in memory | primary in disk |
| use disk for recovery & logging | use memory for caching |
| usually simpler, because OS abstract memory management | have to manage data references, serialization, freed memory, fragmentation |
| limit by volatility, might change while NVM (Non-Volatile Memory) grow | |
| because the random access capacity, can choose from a larger pool of data structures | usually use wide and short tree |
| make durability by backup copy, batch compaction, snapshot, checkpointing |

## Column- Versus Row-Oriented DBMS

- According to how the data store on disk

| column-oriented | row-oriented | wide column store |
|---|---|---|
| partition vertically | partition horizontally | group into column families, row-wise in each column family |
| Parquet, ORC, RCFile, Kudu, ClickHouse | MySQL, PostgreSQL | BigTable, HBase |
| analytical workloads | transactional workloads | retrieving by a sequence of keys |
| reconstruct with implicit identifiers / or offset | identified by key | identified by key & qualifier |
| computational efficiency with CPU's vectorized instructions | |
| compression efficiency | |

## Data Files and Index Files

DBMS use specialized file organization for the purposes of:
- storage efficiency
- access efficiency
- update efficiency

Some terminologies:
- *data records*: consisting of multiple fields
- *index*:efficiently locate data records without scanning
- *data files* & *index files*: usually separated
- *page*: files are partitioned into pages, as size of one or multiple disk blocks
- *deletion markers* (*tombstones*): *shadow* the deleted record until reclaiming during garbage collection

### Data Files

Also called *primary files*.

Implemented as:

- *heap-organized tables*
  - no ordering required
  - append with new records
  - require additional index structures to be searchable
- *hash-organized tables*
  - records are stored in buckets
  - inside the bucket, could be sorted or not
- *index-organized tables* (IOTs)
  - store data records in the index
  - range scan could be done by sequentially scan
  - reduce the disk seek by one

### Index Files

*Primary index* & *Secondary index*
- Primary index
  - is built over a primary key or a set of keys identified as primary
  - unique entry per search key
- Secondary index
  - all other indexes
  - may holds several entries per search key
  - may point to the same record from multiple secondary indexes

*Clustered* & *Non-clustered*
- Clustered
  - the order of data records follows the search key order
  - primary indexes are most often clustered
  - IOTs are clustered by definition
  - secondary indexes are non-clustered by definition

Referencing *directly* or *primary index as an indirection* (when search by secondary index)
- Referencing directly
  - reduce the number of disk seek
- Indirection
  - reduce the cost of pointer updates while the record relocate
  - ex. MySQL InnoDB
- Hybrid
  - store both data file offset and primary keys
  - try directly offset, if failed, go by primary key
  - update index after finding a new offset

## Buffering, Immutability, and Ordering

Three common variables for storage structures.

- *Buffering*
  - ex. in-memory buffers to B-Tree nodes to amortize the I/O costs
  - ex. two components LSM Trees combine buffering with immutability
- *Immutability*
  - modifications are appended
  - *copy-on-write*
  - distinction between LSM and B-Trees is drawn as immutable against in-place update storage
- *Ordering*
  - whether could efficiently range scan
