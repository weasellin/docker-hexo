---
title: Database-Internals-Ch-7-Log-Strutured-Storage
date: 2020-07-01 23:27:38
tags:
- reading_note
- data_engineering
- database_internals
---

| B-Tree | LSM Tree |
|---|---|
| in-place update | append-only |
| optimized for read performance | optimized for write performance |

- RUM Conjecture
  - trade-off between Read, Update, & Memory


## LSM Trees

- immutable on-disk storage structure
- introduced by Patrick O'Neil & Edward Cheng '96
- sequential write, prevent fragmentation, have higher density

| Amplification | Source |
|---|---|
| Read Amplification | From needing to read the duplication from multiple tables |
| Write Amplification | From the multiple runs of the compactions |
| Space Amplification | From the duplication in multiple tables |


### LSM Tree Structure

- *memtable*
  - mutable in-memory
  - serves read & write
  - triggered periodically or size threshold, flush to disk
  - recoverable with WAL
- *Two-component LSM Tree*
  - disk-resident tree & memory-resident tree
  - drawback: frequent merge by *memtable* flush
- *Multicomponent LSM Trees*
  - multiple disk-resident tables (components)
  - periodic *compaction* for several tables
- life cycles
  - current memtable: receives writes & serves reads
  - flushing memtable: still available for read, but not writable
  - on-disk flushing target: not readable, since still incomplete
  - flushed tables: available for read as soon as the flushed memtable is discarded
  - compacting tables: currently merging disk-resident tables
  - compacted tables: created from flushed or other compacted tables
- *Deletion*
  - just remove records from memtable will cause *resurrect*
  - done by *delete entry* / *tombstone* / *dormant certificate*
  - range delete: *predicate deletes* / *range tombstones*, ex. Cassandra
- *Lookups*
  - from each components, merge & reconcile the contents
- *Merge-Iteration*
  - given a *cursor* or *iterator* to navigate through file contents
  - use *multiway merge-sort* / *priority queue* / *min-heap*
- *Reconciliation*
  - *reconciliation* & *conflict resolution* of the data records associated with the same key
  - with records holding metadata, ex. timestamps

### Compaction

- *Maintenance*
  - has memory usage upper bond since it only holds iterator heads
  - multiple compactions can be executed (nonintersecting)
  - not only for merge but also allow repartition
  - preserve tombstones during compaction, only remove when no associated records assure, ex. RockDB's bottommost level, Cassandra's GC
- *Leveled Compaction*
  - one of the compaction strategies used by RockDB
  - *Level 0*: flushed from memtable, tables range may overlapping, when reaching the size threshold, **merge** and **partition** into level 1
  - *Level 1*: partitioned into different key ranges, when reaching the size threshold, **merge** and **partition** into level 2
  - *Level k*: exponential enlarge the size threshold, bottommost is the oldest data
- *Size-tiered Compaction*
  - decide level by tables size
  - merge small tables to become larger one to be promoted to the higher levels
- *Time-Window Compaction*
  - if records' ttl (time-to-live) have been set, ex. Cassandra, the expired tables can be dropped directly

### Implementation Details

##### Sorted String Tables

- SSTables
- consist of index files and data files
- index file for lookup, ex. B-Trees or hash tables
- data records, concatenation of key-value, are ordered by key, so allows the sequential reading
- immutable dist-resident contents
- *SSTables-Attached Secondary Indexes* (SASI), implemented in Cassandra, the secondary index files are created along with the SSTable primary key index

##### Bloom Filter

- conceived by Burton Howard Bloom in 1970
- uses a large bits array and multiple hash functions apply on keys
- bitwise `or` to compose as a filter to indicate whether the test key *might* in the set

##### Skiplist

- probabilistic complexity guarantees are close to search tree
- randomly assign the height
- link by / to each equal or lower height level's next node
- `fully_linked` flag & compare-and-swap for concurrency
- ex. Cassandra's secondary index memtable, WiredTiger's some in-memory operations

##### Compression & Disk Access

- compressed page size will not align with page boundary
- so need an indirection layer, *offset table*, which stores offsets and size of compressed pages

### Unordered LSM Storage

- *Bitcask*
  - one of the storage engine used in Riak
  - no memtable, store in log file directly, to avoid extra write
  - *keydir* as the in-memory hash table point from key to the latest record in log file
  - GC during compaction
  - not allow range scan
- *WiscKey*
  - unsorted data records in append-only *vLogs*
  - sorted key in LSM tree
  - to allow range scan
  - when scanning range, use internal SSD parallelism to prefetch blocks, to reduce random I/O

### Concurrency in LSM Trees

- Cassandra uses operation order barriers
- *Memtable switch*: after this, all writes go only to the new memtable, while the old one is still available for read
- *Flush finalization*: replace the old memtable with a flushed disk-resident table in the table view
- *Write-ahead log truncation*: discard a log segment holding records associated with a flushed memtable

## Log Stacking

- SSDs also use log-structured storage to deal with small random writes
- stacking multiple log-structured systems can run into several problems
  - write amplification
  - fragmentation
  - poor performance
- *Flash Translation Layer*
  - flash translation layer (FTL) is used by SSD
  - translate logical page addresses to their physical locations
  - keep track of pages status (live, discarded, empty)
  - garbage collection
    - relocate live pages
    - erase by block (group of pages, 64 to 512 pages)
  - *wear leveling* distributes the load evenly across the medium, to extend device lifetime
- *Filesystem Logging*
  - cause
    - redundant logging
    - different GC pattern
    - misaligned segment writes
    - interleave data records and log records due to multiple write streams

### LLAMA & Mindful Stacking

- *latch-free, log-structured, access-method aware* (LLAMA)
- allow Bw-Trees to arrange the physical delta nodes in the same chain in contiguous physical location
- more efficient GC, less fragmentation
- reduce read latency
- *Open-Channel SSDs*
  - expose internal control of wear-leveling, garbage collection, data placement, & scheduling
  - skip flash translation layer, can achieve single layer GC, minimize write amplification
  - Software Defined Flash (SDF): read in page, write in block
  - LOCS (LSM Tree-based KV Store on Open-Channel SSD), 2013
  - LightNVM, implemented in the Linux kernel, 2017
