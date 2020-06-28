---
title: Database-Internals-Ch-5-Transaction-Processing-and-Recovery
date: 2020-05-28 22:17:57
tags:
- reading_note
- data_engineering
- database_internals
---

A database transaction has to preserve *ACID*
- *Atomicity*
- *Consistency*
- *Isolation*
- *Durability*

Implementing transaction required components
- *transaction manager*
  - coordinates, schedules, tracks transactions and their individual steps
- *log manager*
  - guards access to the resources and prevents concurrent access violating data integrity
- *page cache*
  - serves as an intermediary between persistent storage and the rest of the storage engine
- *log manager*
  - holds a history of operations

## Buffer Management

*page cache* (*buffer pool*)
- keeps cached page contents in memory
- allows modification to be *buffered*
- when a requested page isn't present in memory, it is *paged in* by the page cache
- if an already cached page is requested, its cached version is returned
- if there's not enough space available, some other page is *evicted* and its contents are *flushed* to disk

### Caching Semantics

- many database using `O_DIRECT` flag to bypass the kernal page cache
- as an application specific equivalent of the kernal page cache
- accesses the block device directly
- decouples logical and physical write operations
- if the page is not *pinned* or *referenced*, it can be evicted right away
- *dirty* pages have to be *flushed* before they are evicted
- PostgreSQL has a background flush writer cycles through the dirty pages that are likely to be evicted
- to make sure all the changes are persisted (*durability*), flushes are coordinated by the *checkpoint* process with WAL and page cache

Trade-off objectives:
- Postpone flushed to reduce the number of disk accesses
- Preemptively flush pages to allow quick eviction
- Pick pages for eviction and flush in the optimal order
- Keep cache size within its memory bounds
- Avoid losing data as it is not persisted to the primary storage

#### Locking Pages in Cache

- the higher levels of B-Tree nodes could be *pinned* in cache permanently,
  - since it just a small fraction of the tree
  - saving in every lookup path
  - disk access only required in lower levels nodes

#### Prefetching & Immediate Eviction

- Page cache also allows the storage engine to have fine-grained control over prefetching and eviction
- Prefetching
  - leaf nodes traversed in a range scan
- Immediate Eviction
  - maintenance process, unlikely to be used for the in-flight queries

### Page Replacement

- FIFO (first in, first out)
  - impractical, ex. higher level of page nodes
- LRU (least-recently used)
  - 2Q LRU
  - LRU-K keeping track of the last K accesses
- CLOCK
  - as an approximated, compact version of LRU
  - Linux uses a variant of CLOCK
  - access bit
    - set to `1`, whenever the page is accessed
    - around the circular buffer
      - if access bit is `1`, but the page is unreferenced, then set to `0`
      - if access bit is already `0`, then the page becomes a candidate and is scheduled for eviction
  - advantage
    - use compare-and-swap (CAS) operations, and do not require locking
- LFU (least-frequency used)
  - frequency histogram
- TinyLFU
  - three queues
    - *Admission*: newly added elements with LRU policy
    - *Probation*: holding elements most likely to get evicted
    - *Protected*: holding elements that are to stay for longer

## Recovery

### Write-Ahead Log

WAL (*write-ahead log*), *commit log*
- an append-only auxiliary disk-resident structure
- used for crash and transaction recovery
- functionalities
  - allow page cache to buffer updates while ensuring durability
  - persist all operations on disk until the cache copies of pages are synchronized
  - allow lost in-memory changes to be reconstructed

LSN (*log sequence number*)
- a unique, monotonically increasing number
- with an internal counter or a timestamp
- as the order index of the operation records in the WAL

Checkpoint
- *sync checkpoint*
  - force all dirty pages to be flushed on disk
  - fully synchronizes the primary storage structure
  - impractical, require pausing all operations
- *fuzzy checkpoint*
  - `last_checkpoint` pointer in log header, (with LSN of the `begin_checkpoint` record)
  - `begin_checkpoint` log record
  - info about the dirty pages
  - transaction table
  - `end_checkpoint` log record, until all the specified dirty pages are flushed

### Operation Versus Data Log

- *physical log*
  - before-image <=> after-image
  - store complete page stat or byte-wise changes
- *logical log*
  - redo <=> undo operation
  - store operation that to be performed against the current state

### Steal and Force Policies

| Steal | No-steal |
|---|---|
| allow flushing uncommitted | only flushing committed |
| | could use only *redo* entries in recovery |

| Force | No-force |
|---|---|
| only committing flushed | allow committing unflushed |
| no need additional work on recovery | |
| take longer to commit due to necessary I/O | |

### ARIES (Algorithm for Recovery and Isolation Exploiting Sematics)

- ARIES is a *steal/no-force* recovery algorithm
- uses
  - LSNs for identifying log records
  - dirty page table to track page modified
  - physical redo to improve performance during recovery
  - logical undo to improve concurrency during normal operations
  - fuzzy checkpointing
- three phases in recovery proceeds
  - *analysis phase*: identify dirty pages, identify the starting point for the redo phase
  - *redo phase*: repeat the history up to the point of a crash
  - *undo phase*: roll back all incomplete transactions and restore the database to the last consistent state

## Concurrency Control

- *Optimistic Concurrency Control* (OCC)
  - check conflict "before" the commit
- *Multiversion Concurrency Control* (MVCC)
  - allowing multiple timestamped versions of the record to be present
- *Pessimistic Concurrency Control* (PCC)
  - manage and grant access to shared resources

### Transaction Isolation

- Serializability
  - a *schedule* is a list of operations required to execute a set of transactions
  - to be *serial* for a schedule is when transactions are executed completely independently without any interleaving
  - a schedule is *serializable*, if it's equivalent to some complete serial schedule
- Read & Write Anomalies
  - *read anomalies*
    - *dirty read*
      - a transaction can read uncommitted changes from other transactions
    - *nonrepeatable read* (*fuzzy read*)
      - a transaction queries the same row twice and gets different results
    - *phantom read*
      - a transaction queries the same set of rows twice and gets different results
  - *write anomalies*
    - *lost update*
      - two transactions update the same record without awareness about each other's existence
    - *dirty write*
      - transaction results are based on the values that have never been committed
    - *write skew*
      - the combination of individual transactions does not satisfy the required invariant
- Isolation Levels

| | Dirty | Non-Repeatable | Phantom |
|---|---|---|---|
| Read Uncommitted | Allowed | Allowed | Allowed |
| Read Committed | - | Allowed | Allowed |
| Repeatable Read | - | - | Allowed |
| Serializable | - | - | - |

| | Lost Update | Dirty | Write Skew |
|---|---|---|---|
| Snapshot Isolation | - | - | Allowed |

### Optimistic Concurrency Control

- Transaction execution phases
  - *Read Phase*
    - Identify the *read set* & *write set*
  - *Validation Phase*
    - check serializability
      - if the read set out-of-date
      - if the write set will overwrite the other transactions committing during the read phase
    - if conflict found, restart from the read phase
    - else, start commit and write phase
  - *Write Phase*
    - commit the write set from private context to the database state
- critical section: *Validation Phase* & *Write Phase*
- efficient if the validations usually succeeds and no need to retry

### Multiversion Concurrency Control

- allowing multiple record versions
- using monotonically incremented transaction IDs or timestamps
- distinguishes between *committed* & *uncommitted* versions
  - last committed version: *current*
  - to keep at most one uncommitted value at a time
- major use cases for implementing snapshot isolation

### Pessimistic Concurrency Control

#### Lock-Free Scheme

- *timestamp ordering*
  - `max_read_timestamp` and `max_write_timestamp`
  - if read operations attempt to read value, which timestamp lower than `max_write_timestamp`, then abort
  - if write operations attempt to write value which timestamp lower than `max_read_timestamp`, then abort
  - if write operations attempt to write value which timestamp lower than `max_write_timestamp`, then just ignore the outdated written values

#### Lock-Based Scheme

- *two phase locking* (2PL)
  - *growing phase* (locks acquiring)
  - *shrinking phase* (locks releasing)
- *deadlocks*
  - timeout and abort
  - conservative 2PL
    - requires to acquire all the locks before any execution operations
    - significant limit concurrency
  - *wait-for graph*
    - maintained by the transaction manager
    - applying either one of the restrictions
      - *wait-die*: a transaction can be blocked only by a transaction with lower priority
      - *wounds-wait*: a transaction can be blocked only by a transaction with higher priority

##### Locks & Latches

| Locks | Latches |
|---|---|
| Guard the logical data integrity | Guard the physical data integrity |
| Guard a specific key or key range | Guard a page node in the storage structure |
| Heavyweight | Lightweight |
| | Lock-free concurrency still need latches |

- *reader-writer lock* (RW Lock)

|  | Reader | Writer |
|---|---|---|
| Reader | Shared | Exclusive |
| Writer | Exclusive | Exclusive |

- manage access to pages
  - *busy-wait*
  - *queueing*, *compare-and-swap* (CAS)
- *Latch Crabbing*
  - read path: the parent node's latch can be release, as soon as  the child node's latch is acquired
  - insert path: the parent node's latch can be release, if the child node is not full
  - delete path: the parent node's latch can be release, if the child node holds enough elements
- *Latch Upgrading*
  - acquisition of shared locks along the search path, then upgrading them to exclusive locks when necessary
  - always latch root to avoid the root bottleneck (how?)

##### *B^link-Trees*
  - B*-Trees with *high keys* and *sibling link* pointers
  - allow the state of *half-split*
    - referenced by sibling pointer, not child pointer
    - if the search key larger than the high key, then follow the sibling link
  - therefore,
    - do not have to hold the parent lock when descending to the child level, even if child node splitting
    - reduce the number of locks held
    - allows reads concurrent to tree structural change, and prevents deadlocks
    - slightly less efficient when encounter splitting (relative rare case)
