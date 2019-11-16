---
title: Hadoop Application Architectures Ch.1 Data Modeling in Hadoop
date: 2019-11-11 11:15:43
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

The power of context in Hadoop: "Schema-on-Read", compares to "Schema-on-Write":
- the structure imposed at processing time based on the requirements
- shorter cycles of analysis, data modeling, ETL, testing, etc. before data can be processed
- agility on schema revolutions

Considerations perspectives of storing:
- Data storage formats
- Multitenancy
- Schema Design
- Metadata Management

Beyond the scope:
- [Hadoop Security](http://bit.ly/hadoop-security)

## Data Storage Options

- File format
- Compression
- Data storage system

### Standard File Formats

#### Text data

- ex. server logs, emails, CSV files
- with "splittable" compression, for parallel processing
  - container format: SequenceFiles, Avro

#### Structured text data

- ex. XML, JSON
- challenging to make XML or JSON splittable
  - using container format such as Avro
  - `XMLLoader` in `PiggyBank` library
  - `LzoJaonInputFormat` in `Elephant Bird` project

#### Binary data

- ex. images
- in most of cases, container format is preferred
- in the cases the binary data is larger than a certain size, ex. 64MB, consider not using container format.

### Hadoop File Types

Important characteristics:
- Splittable Compression
  - parallel processing
  - data locality
- Agnostic Compression
  - codec in header metadata

#### File-based data structures

- ex. SequenceFiles, MapFiles, SetFiles, ArrayFiles, and BloomMapFiles
- MapReduce specific
- SequenceFiles
  - most common
  - binary key-value pair
  - formats:
    - uncompressed
    - record-compressed (single record)
    - block-compressed (batch, "not" HDFS block)
  - sync maker
    - to allow for seeking

### Serialization Formats

byte stream <=> data structures

Term:
- **IDL** (Interface Definition Language)
- **RPC** (Remote Procedure Calls)

| Format | Summary | Limitation |
|---|---|---|
| Writables |  | Only in Hadoop & Java |
| Thrift | - language-natrual <br> - by Facebook <br> - use IDL <br> -robust RPC | - no internal compression of records <br> - not splittable <br> - not native MapReduce support <br> (addressed by Elephant Bird) |
| Protocol Buffers | - language-natrual <br> - by Google <br> - use IDL, stub code generation | same as Thrift |
| Avro | - language-natrual <br> - optional IDL: JSON, C-like <br> - native support for MapReduce <br> - compressible: Snappy, Deflate <br> - splittable: sync marker <br> - self-decribing: schema in each file header's metadata |

Additional refer: http://blog.maxkit.com.tw/2017/10/thrift-protobuf-avro.html
