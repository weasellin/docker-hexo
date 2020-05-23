---
title: Database-Internals-Ch-3-File-Formats
date: 2020-05-11 22:27:02
tags:
- reading_note
- data_engineering
- database_internals
---

## Motivation

For on-disk layout structures, we have to deal with:

- fixed-size primitives structures & variable size structures
- garbage collection & fragmentation
- serialization & deserialization
- tracking and management of the segments usage

## Binary Encoding

- numeric (fixed-size)
  - *Big-endian*: most-significant byte (MSB)
  - *Little-endian*: least-significant byte (LSB)
  - IEEE 754: 32-bit `float` for single-precision value
    - bit 31: sign
    - bit 30-23: exponent
    - bit 22-1: fraction
- `string` (variable-size)
  - `(size|data)`: *UCSD String* or *Pascal String*
    - could get length in constant time without iterating through
    - could slice copy from memory
  - `(data/null)`: *null-terminated string*
- bit-packed data
  - booleans
  - enum
  - flags, bitmasks

## Structures & Layouts

### File Organization

`| header | page | page | page | ... | tailer |`

### Page Organization for Fixed-size Records

Page for a B-Tree node:

`| P0 | k1 | v1 | P1 | k2 | v2 | ... | kn | vn | Pn | unused |`

Downside:
- key insertion requires relocating elements
- not allow managing or accessing variable-size records efficiently

### Slotted Pages

`| header | offset0 | offset1 | offset2 | ... | unused | ... | cell2 | cell1 | cell0 |`

Allow:

- storing variable-size of records with a minimal overhead
- reclaiming space occupied by the removed records
- dynamic layout to hide the exact location internally

### Cells

- *separator key* cells

`| [int] key_size | [int] child_page_id | [bytes] key |`

- *key-value* cells

`| [int] key_size | [int] value_size | [bytes] key | [bytes] data_record |`

### Management of Cells in Slotted Pages

- Keep *offsets* sorted by keys
  - no need to relocate *cells*
- Maintain an *Availability List* for inserting a new cell
  - holds the list of offsets of freed segments and their sizes
  - *first fit strategy*
    - larger overhead, effectively wasted
  - *best fir strategy*
    - find a segment leaves smallest remainder
  - if cannot find in availability list
    - and if there are enough *fragmented bytes* available
      - => defragmentation
    - if there are not enough available
      - => create an overflow page

## Versioning

Could be done in several ways:

- identified by filename prefix (ex. Cassandra)
- separated file (ex. *PG_VERSION* in PostgreSQL)
- stored in index file header
- file format using magic number

## Checksumming

Usually put the *page cheksum* in the page header.

Distinct between:
- *checksum*
  - weakest form of guarantee and aren't able to detect corruptiob in multiple bits
- *cyclic redundancy check* (CRC)
  - make sure there were no unintended and accidental changes in data
  - not designed to resist attacks and intentional changes in data
- *cryptographic hash function*
  - for security
