---
title: Database-Internals-Ch-2-B-Tree-Basics
date: 2020-05-04 22:00:03
tags:
- reading_note
- data_engineering
- database_internals
---

## Binary Search Trees

- BST (Binary Search Trees)
- Tree balancing, *pathological* tree
- rebalancing, *pivot*, *rotate*

Considerations (impractical) on trees for disk-based storage:

- *locality*: node child pointers may span across several disk pages
- *tree height*: hight number of disk seek to located the searched element

## Disk-Based Structures

- HDD (Hard Disk Drives)
  - read/write *head movements* (seek for random access): most expensive
  - *sequential operations*: relatively cheap
  - smallest transfer unit: *sector* (512Bytes - 4 KB)
- SSD (Solid State Drives)
  - no disk spin or head movements
    - the diff between random versus sequential I/O is not as large as HDD
  - is built of
    - *memory cells*
    - *strings* (32 - 64 cells per string)
    - *arrays*
    - *pages* (2 - 16 KB)
    - *blocks* (64 - 512 pages per blocks)
    - *planes*
    - *dies*
  - smallest unit for read/write: page (write to empty cells only)
  - smallest unit for erase: block
  - FTL (Flash Translation Layer), responsible for
    - mapping page ID to physical locations
    - tracking empty, written, discarded pages
    - *garbage collection*, relocate live pages, erase unused blocks

### On-Disk Structures

- *Block Device* abstration
  - hide the internal disk structures provided by HDD & SSD for OS
  - even though garbage collection usually done in background, it may impact write performance in case of random and unaligned workloads
  - writing *full block*, combining subsequent writes to the same block
    - buffering, immutability
- *Pointer* for disk structures
  - on disk, the data layout is managed manually
  - offset are
    - precomputed: if the pointer is written before the referring part
    - or cached in memory
  - preferred
    - to keep number of pointers and spans to minimum
    - rather to have a long dependency chain
- Fewer disk access by reduce "out-of-page"pointers
  - Paged Binary Trees
    - group nodes into pages to improve locality
    - but still need to update out-of-page pointers during balancing
  - B-Trees
    - increase node fanout
    - reduce tree height
    - reduce the node pointers
    - reduce the frequency of balancing operations

## Ubiquitous B-Trees

Using B-Tree, could query both *point* and *range*.

### B-Tree Hierarchy

- *node*: holds up to N keys and N + 1 pointers
- *key* in the node: *index entries*, *separator keys*, *divider cells*
- *root node*, *internal nodes*, *leaf nodes*
- *page* as *node*
- *occupancy*
  - balancing operations are triggered when full or nearly empty
- *B+-Trees*: only holds value on the leaf nodes
- some variants also have *sibling node pointers*, to simplify range scan

### B-Tree Lookup

- Complexity
  - block transfers: `log_k(M)`
  - comparisons: `log_2(M)` (binary search within each node)
- Lookup objective
  - exact match: point queries, updates, deletions
  - predecessor: range scan, inserts

### B-Tree Node Splits & Merges

| Splits | Merges |
|---|---|
| insert | delete |
| when *overflow* the capacity | when *underflow* the capacity |
| leaf nodes: N k-v pairs | (occupancy under a threshold) |
| internal nodes: N + 1 pointers | merge, otherwise rebalance |
| *promote* the *split point* (midpoint) to the parent node | *demote* / *delete* the separator key for internal / leaf node |
