---
title: Database-Internals-Ch-4-Implementing-B-Trees
date: 2020-05-18 21:37:55
tags:
- reading_note
- data_engineering
- database_internals
---

## Page Header

- PostgreSQL: page size, layout version
- MySQL InnoDB: number of heap records, level, implementation-specific values
- SQLite: number of cells, a rightmost pointer

### Magic Numbers

- multibyte block, ex. `(50 41 47 45)`
- validation & sanity check
- identify version

### Sibling Links

- forward / backward links
- help to locate neighboring nodes without ascending back to parent / root
- add complexity to split and merge
  - may required additional locking for the updating sibling node
  - could be useful in *Blink-Trees* (discussed later)

### Rightmost Pointers

- each cell has 1 separator key and 1 child pointer
- the rightmost pointer is stored in header
- used by SQLite

### Node High Keys

- *high key*, represents the highest possible key of the subtree
- used by PostgreSQL, called B^link-Trees
- pros:
  - pairwise store separator keys and child pointers
  - less edge case handling
  - more explicit search space

### Overflow Pages

- *primary page*, followed by multiple linked *overflow pages*
  - page ID of the *next* page could be stored in the page header
- most of implementation
  - using fixed size of payload (`max_payload_size`) in the primary page
  - spill out to overflow page for the rest of payload
  - `max_payload_size` calculated by page size / fanout
- require extra bookkeeping for defragmentation
- keys reside in the primary page for frequent comparison
- data records may need to traverse to locate in several overflow pages for the parts

## Operation

### Propagating Splits and Merges

- *breadcrumbs*
  - be used to maintain the track of traversal path
  - PostgreSQL implements with BTStask
  - equivalent as parent pointers, since the child nodes are always referred from the root and parent(s)
  - build and maintained in memory
- *deadlocks* may happen when using *sibling pointers*
  - WiredTiger uses parent pointers for leaf traversal

### Rebalancing

- Operation Cost
  - to postpone split & merge operations
  - to amortize the cost of split & merge by *rebalancing*
- Occupancy
  - to improve the occupancy
    - B*-Trees keep distributing between the neighboring nodes until both are full
    - then split the two nodes into three nodes
  - lower the tree height
    - fewer pages traversal
- SQLite implements as the *balance-siblings* algorithm

### Right-Only Appends

- An optimization for auto-incremented monotonically increasing primary index
- *fastpath* in PostgreSQL
  - cache the rightmost leaf, to skip the whole read path from the root
- *quickbalance* in SQLite
  - when rightmost page being full, "creating" a new empty page instead of "splitting" to form a half full page
- *bulk loading*
  - bulk loading presorted data or rebuild the tree
  - compose bottom up, avoid splits & merges
    - fill the leaf level pages
    - propagate the first keys of each leaf node up to its parent node
- Immutable B-Trees or auto-incremented primary index
  - can fill up nodes with out leaving any space for future middle insertion

### Compression

- Compression Level
  - entire index file
    - impractical
  - page-wise
    - may not align with the disk blocks
  - row-wise
  - filed-wise
- Compression Evaluation, ex. Squash Compression Benchmark
  - memory overhead
  - compression performance
  - decompression performance
  - compression ratio

### Vacuum & Maintenance

- Rewrite the page with the lived cell data
- Similar terminologies:
  - *defragmentation*
  - *garbage collection*
  - *compaction*
  - *vacuum*
  - *maintenance*
