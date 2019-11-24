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
| Writables | - simple, efficient, serializable | Only in Hadoop & Java |
| Thrift | - language-natrual <br> - by Facebook <br> - use IDL <br> -robust RPC | - no internal compression of records <br> - not splittable <br> - not native MapReduce support <br> (addressed by Elephant Bird) |
| Protocol Buffers | - language-natrual <br> - by Google <br> - use IDL, stub code generation | same as Thrift |
| Avro | - language-natrual <br> - optional IDL: JSON, C-like <br> - native support for MapReduce <br> - compressible: Snappy, Deflate <br> - splittable: sync marker <br> - self-decribing: schema in each file header's metadata |

Additional refer: http://blog.maxkit.com.tw/2017/10/thrift-protobuf-avro.html

### Columnar Formats

- skip I/O and decompression
- efficient columnar compression rate

Term:
- **RCFile** (Record Columnar File)
- **ORC** (Optimized Row Columnar)
- **RLE** (bit-packaging/run length encoding)

| Format | Summary | Limitation |
|---|---|---|
| RCFile | column-oriented storage within each row splits | has some deficiencies that prevent optimal performance for query times and compression <br> (what's this exactly?) |
| ORC | - lightweight, always-on compression <br> - zlib, LZO, Snappy <br> - predicate push down <br> - Hive type, including decimal, complex <br> - splittable | - only designed for Hive, not general purpose |
| Parquet | - per-column level compression <br> - support nested data structure <br> - full metadata, self-documenting <br> - fully support Avro, Thrift API <br> - efficient and extensible encoding schemas, RLE |  |

##### Avro and Parquet

- single interface: recommended if you are choosing for the single interface
- compatibility: Parquet can be read and written to with Avro APIs and Avro schemas

### Compression

- disk & network I/O
- source & intermediate data
- trade with CPU loading
- splittability for parallelism and data locality

| Format | Summary | Limitation |
|---|---|---|
| Snappy | - developed at Google <br> - high speed and reasonable compression rate | - not inherently splittable <br> - intended to be used with a container format |
| LZO | - very efficient decompression <br> - splittable | - requires additional indexing <br> - requires a separated installation from Hadoop because of license prevention |
| Gzip | - good compression rate, 2.5x to Snappy <br> - read almost as fast as Snappy | - write speed about half to Snappy <br> - not splittable <br> - fewer blocks might lead to lower parallelism => using smaller blocks |
| bzip2 | - excellent compression rate, 9% better than Gzip | - slow read / write, 10x slower than Gzip <br> - only used in archival purposes |

#### Compression Recommendation

- Enable compression of the MapReduce intermediate data
- Compress on columnar chunks
- With splittable container formats, ex. Avro or SequenceFiles, make the compression & decompression could be processed individually

![Compression Block](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-1-Data-Modeling-in-Hadoop/container_format_and_compression_block.png)

## HDFS Schema Design

Standard directory structure:

- Easier to share data sets between teams
- Allows access and quota controls
- "Stage" data during process pipeline
- Tool conventions compliant

### Location of HDFS Files

- */user/\<username\>*
- */etl*
  - ex. */etl/\<group>/\<application>/\<process>/{input,processing,output,bad}*
- */tmp*
- */data*
- */app*
  - ex. */app/\<group>/\<application>/\<version>/\<artifact directory>/\<artifact>*
- */metadata*

### Advanced HDFS Schema Design

#### PARTITIONING

> Unlike traditional data warehouses, however, HDFS doesn’t store indexes on the data. This lack of indexes plays a large role in speeding up data ingest, but it also means that every query will have to read the entire data set even when you’re processing only a small subset of the data (a pattern called full table scan).

- Main purpose: reduce the amount of I/O required
- Common pattern: *\<data set name>/\<partition_column_name=partition_column_value>/{files}*
- Understood by: HCatalog, Hive, Impala, Pig, etc.

#### BUCKETING

Not always the key is good for partitioning. ex. *physician*, may result in too many partitions and too small in file size.

*small files problem*:
> Storing a large number of small files in Hadoop can lead to excessive memory use for the NameNode, since metadata for each file stored in HDFS is held in memory. Also, many small files can lead to many processing tasks, causing excessive overhead in processing.

Bucketing is the solution,
- be able to control the size of the data subsets
- good average bucket size is a few multiples of the HDFS block size
- having an even distribution of data when hashed on the bucketing column is important because it leads to consistent bucketing
- having the number of buckets as a power of two is quite common

*joining* with bucketing

- reduce-side join
  - if for two data sets, both are bucketed on the join key
  - and the number of buckets is factor and multiple
  - could be done by bucket individually join, to save reduce-side join complexity
- map-side join
  - if the bucket size can be fit into memory, map-side join can further improve performance
- merge join
  - if the data in the buckets is sorted, it is also possible to use a merge join
  - requires less memory

Based on common query patterns,
- decide partitioning and bucketing
- for multiple patterns, consider to have multiple store
- trade space to query speed

#### DENORMALIZING

In relational databases, data is often stored in *third normal form*. In Hadoop, however, joins are often the slowest operations and consume the most resources from the cluster.

- prejoined, preaggregated
- consolidates many of the small dimension tables into a few larger dimensions
- data preprocessing, like aggregation or data type conversion, *Materialized Views*

## HBase Schema Design

Distributed key-value store which could operate,

- put
- get
- iterate
- value increment
- delete

### Row Key

##### RECORD RETRIEVAL

- unlimited columns
- single key
  - may need to combine multiple pieces of information in a single key
- `get` single record is the fastest
  - put most common uses of the data into a single `get`
  - denormalized
  - very "wide" table

##### DISTRIBUTION

Row key determines scattering throughout various regions.
So, it’s usually best to choose row keys so the load on the cluster is fairly distributed.

- Anti-pattern: *use a timestamp for row keys*
  - easy to hit into single region and defeats the parallelism

##### BLOCK CACHE

HBase block in chunks of default 64 KB with least recently used (LRU) cache.

- Anti-pattern: *row key by hash of some attribute*
  - records in the same block could be "un-relevance", and to reduce the cache hit rate

##### ABILITY TO SCAN

A wise selection of row key can be used to co-locate related records in the same region.
- HBase scan rates are about eight times slower than HDFS scan rates.

##### SIZE

Trade-off:
- shorter row keys: lower storage overhead and faster read/write performance
- longer row keys: better `get`/`scan` properties

##### READABILITY

Recommend to use readable prefix.

- easier to identify and debug issues
- easier to use the HBase console

##### UNIQUENESS

Require to be unique key.

### Timestamp

timestamp's important purposes:

- determines newer record `put`
- determines the order when multiple versions are requested
- determines to remove while time-to-live (TTL)

### Hops

*Hops*: the number of synchronized `get` requests required to retrieve the requested info

- best to avoid them through better schema design. ex, by leveraging denormalization.
- every hop is a round-trip to HBase that incurs a significant performance overhead

### Tables and Regions

![Region Table Topology](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-1-Data-Modeling-in-Hadoop/region_table_topology.png)

- one region server per node
- multiple regions pre region server
- for a region, it's pinned to a region server at a time
- tables are split into regions and scattered across region servers

The number of regions for a table is a trade-off between **put performance** and **compaction time**.

##### Put performance

*memstore*:
- cache structure present on every HBase region server
- wrtie => cahce => sort => flush
- more regions in a region server => less memstore space pre region => smaller flush & HFiles => less performant
- ideal flush size: 100 MB

##### Compaction time

region size limit: 20GB (default) - 120GB

region assignment:
- auto splitting
  - forever-growing data set, only update most recent data, with periodic TTL-based compaction, no need to compact the ole regions
- assign the region number
  - recommended in most of cases
  - set the region size to a high enough value (e.g., 100 GB per region) to avoid autosplitting
  - split policy selected, `ConstantSizeRegionSplitPolicy` or `DisabledRegionSplitPolicy`

### Using Columns

Two different schema structures:

- Physical Columns
|RowKey |TimeStamp  |Column  |Value |
|-------|-----------|--------|------|
|101    |1395531114 |F       |A1    |
|101    |1395531114 |B       |B1    |

- Combined Logical Columns
|RowKey |TimeStamp  |Column  |Value |
|-------|-----------|--------|------|
|101    |1395531114 |X       |A1\|B1|


Considerations:

- dependency on read, write, TTL
- number of records can fit in the block cache
- amount of data can fit through the WAL
- number of records can fit into the memstore
- compaction time

### Using Column Families

*column families*: a column family is essentially a container for columns, each column family has its own set of HFiles and gets compacted independently of other column families in the same table.

Use case: the `get`/`put` rate of the subset of columns are significant different, separate them to different culomn families would be beneficial of
- lower compaction cost (by `put`)
- better use of block cache (by `get`)

### Time-to-Live

*TTL*: built-in feature of HBase that ages out data based on its timestamp

- ignore outdated records during the major compaction
- the HFile record timestamp will be used
- if TTL not used, but delete records manually, it'd require full scan and insert the "delete records" (could be TBs), and also need the major compaction eventually

## Managing Metadata

### What Is Metadata?

In general, refers to data about the data.

- about logical data sets, usually stored in a separate metadata repository
  - location
    - dir path in HDFS
    - table name in HBase
  - schema
  - partitioning and sorting properties
  - format
- about files on HDFS, usually stored and managed by Hadoop NameNode
  - permissions and ownership
  - location of various blocks of that file on data nodes
- about tables in HBase, stored and managed by HBase itself
  - table names
  - associated namespace
  - associated attributes (e.g., MAX_FILESIZE, READONLY, etc.)
  - names of column families
- about data ingest and transformations
  - which user generated a given data set
  - where the data set came from
  - how long it took to generate it
  - how many records there are
  - the size of the data loaded
- about data set statistics, useful for various tools that can leverage it for optimizing their execution plans but also for data analysts, who can do quick analysis based on it
  - the number of rows in a data set
  - the number of unique values in each column
  - a histogram of the distribution of data
  - maximum and minimum values

### Why Care About Metadata?

It allows to,

- interact with higher-level logical abstraction
- supply information that can then be leveraged by various tools
- data management tools to “hook” into this metadata and allow you to perform data discovery and lineage analysis

### Where to Store Metadata?

- Hive metastore (database & service)
  - deployed mode
    - embedded metastore
    - local metastore
    - remote metastore
      - MySQL (most common), PostgreSQL, Derby, and Oracle
  - could be used by Hive, Impala seamless
- HCatalog
  - WebHCat REST API
    - could be used for MapReduce, Pig, and standalone applications
  - Java API
    - could be used for MapReduce, Spark, or Cascading
  - CLI

### Limitations of the Hive Metastore and HCatalog

- High availability
  - HA for metastore database
  - HA for metastore service
    - concurrency issue unresolved, HIVE-4759
- Fixed schema
  - only for tabular abstraction data sets
  - ex. not for image or video data sets
- Additional dependency
  - the metastore database itself is just another dependent component

### Other Ways of Storing Metadata

- Embedded in HDFS paths
  - partitioned data sets
  - *\<data set name>/\<partition_column_name=partition_column_value>/{files}*
- Store in HDFS
  - maintain & manage by your own
  ```
  /data/event_log
  /data/event_log/file1.avro
  /data/event_log/.metadata
  ```
  - Kite SDK
    - supports multiple metadata providers
    - allows easily transform metadata from one source (say HCatalog) to another (say the *.metadata* directory in HDFS)
