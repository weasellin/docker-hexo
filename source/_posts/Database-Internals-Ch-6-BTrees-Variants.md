---
title: Database-Internals-Ch-6-BTrees-Variants
date: 2020-06-14 23:19:13
tags:
- reading_note
- data_engineering
- database_internals
---

- Abstracting Node Updates, allow to have different life cycles
  - on-disk pages
  - in-memory raw binary cached versions
  - in-memory language-native representations (materialized)
- Three problems for in-place update B-Tree implementation
  - *write amplification*
    - updating a disk-resident page copy on every update
  - *space amplification*
    - preserve some unused buffer space for future insertion and update, and included in transferring
  - *complexity of concurrency*
    - solving concurrency and dealing with latches


## Copy-on-Write B-Trees

- content updating
  - make a copy on the modified nodes
  - on completion, switch the topmost pointer
- pros
  - tree is immutable
  - readers require no sync, no lock
  - inherent structure of MVCC (multiversioned)
- cons
  - requires extra page copying
  - requires more space (but not too much since the shallow tree depth)\
- ex. *Lightning Memory-Mapped Database* (LMDB)
  - k-v store used by the OpenLDAP
  - single-level data store
  - direct memory map, no application-level cache, no materialization

## Lazy B-Trees

- buffer updates and propagate them with a delay

### WiredTiger

- default MongoDB's storage engine
- data structures:
  - for a node, *clean* page consists of just index, initially constructed from the on-disk page image
  - for a node, *update buffer*, implemented using *skiplists*, complexity similar to search trees, better concurrency profile
- operations
  - when content updating, save into the *update buffer* list
  - when reading, the update buffers are merge with the on-disk page content
  - when flushing, the update buffers contents are *reconciled* and persisted on disk
    - split or merge according to the reconciled page size
- pros
  - page updates and structural modifications are performed by the background thread

### Lazy-Adaptive Tree

- *update buffers* attach to subtrees
- when buffer full, it's propagating to lower tree levels' buffer
- when the propagation reaching the leaf level and the buffer full, if flush to disk and change tree structure at once.

## FD-Trees

- small mutable *head tree* & multiple immutable sorted *runs*
  - limit the surface area, where random write I/O in the *head tree*
  - *head tree* is a small B-Tree buffering the updates
  - once *head tree* get full, contents are transferred to the immutable *run*
  - propagating records from upper level run to lower level
- *Fractional Cascading*
  - helps to reduce the cost of locating an item in the lower cascading levels
  - *bridges* between neighboring-level
  - pull every N-th item from the lower level
- *Logarithmic Runs*
  - increasing by factor k to previous level
  - propagating from up to down when *run* get full


## Bw-Trees

- *Buzzword-Tree*, try to resolve the *three problems* at once
- *Update Chains*
  - each logical node for B-Tree consist of a linked list head from latest update: *delta* -> *delta* -> ... -> *base*
  - *base node*: cache of the disk copy page contents
  - *delta node*: all the modifications, can represents inserts, updates, or deletes
  - logical rather than physical
    - node sizes are unlikely to be page aligned
    - no need to pre-allocate space
- *Concurrency*
  - each logical node for B-Tree has a *logical identifier*
  - maintained with an in-memory *mapping table*
  - the mapping table contains virtual links to the *update chain*'s head (latest delta node)
  - updated with *Compare-and-Swap* (lock-free)
- *Structural Modification Operations*
  - SMO
  - Split
    - append a special *split delta* node to the splitting node
    - *split delta* node with the midpoint separator key & the pointer to the new logical sibling node
    - similar to *B_link-Tree*'s *half-split*
    - update the parent with the new child node
  - Merge
    - append a special *remove delta* node to the *right* sibling, indicating the start of merge SMO
    - append a special *merge delta* node to the *left* sibling to point to the right sibling so to logical merge the contents
    - update the parent to remove the link to the right sibling
  - Prevent concurrent SMO
    - an *abort delta* node is installed on the parent, like a write lock
    - remove when SMO completes
- *Consolidation & GC*
  - once the delta chain length reaches a threshold, consolidate the chain into a new node
  - then write to disk and update the mapping table
  - but need to wait for all reader complete to reclaim the memory, *epoch-based reclaimation*
- ex. *Sled*, *OpenBw-Tree* (by CMU Database Group)

## Cache-Oblivious B-Trees

- automatically optimize the parameters, ex. block size, page size, cache line size for arbitrary adjacent two levels of memory hierarchy
- *van Emde Boas Layout*
  - split the B-tree from the middle level, recursive for the subtree
  - result in the `sqrt(N)` size subtrees
  - any recursive subtree is stored in a contiguous block of memory
  - *packed array* with parameter *density threshold* to allow gaps for insertion or update
  - array grow or shrink when become too dense or sparse
