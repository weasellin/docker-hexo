---
title: Hadoop Application Architectures Ch.2 Data Movement
date: 2019-11-24 23:55:50
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

- Ingestion
- Extraction

## Data Ingestion Considerations

Common data sources:
- data management system such as relational databases
- logs, event data
- files from existing storage system

Considerations:
- Timeliness of data ingestion and accessibility
- Incremental updates
- Data access and processing
- Source system and data structure
- Partitioning and splitting of data
- Storage format
- Data transformation

### Timeliness of Data Ingestion

Timeliness classification:
- Macro batch (15 mins -)
- Microbatch (2 mins -)
- Near-Real-Time Decision Support (2 secs -)
- Near-Real-Time Event Processing (100 msecs -)
- Real Time

System complexity, cost, disk or memory.

### Incremental Updates

- `append`
  - notice the *small files problem*, may require periodic process to merge small files
  - write to
- `update`
  - HDFS
    - *delta file* and *compaction job*
    - only work for multi-minute timeliness intervals
  - HBase
    - milliseconds timeliness
    - 8 - 10 times slower scan (compare to HDFS)

### Access Patterns

- scan: HDFS (supports memory cache from Hadoop 2.3.0)
- random access: HBase
- search: Solr

| Tool | Use cases | Storage device |
| --- | --- | --- |
| MapReduce | Large batch processes | HDFS preferred |
| Hive | Batch processing with SQL-like language | HDFS preferred |
| Pig | Batch processing with a data flow language | HDFS preferred |
| Spark | Fast interactive processing | HDFS preferred |
| Giraph | Batch graph processing | HDFS preferred |
| Impala | MPP style SQL | HDFS is preferred for most cases |
| HBase API | Atomic puts, gets, and deletes on record-level data | HBase |

### Original Source System and Data Structure

##### READ SPEED OF THE DEVICES ON SOURCE SYSTEMS

> Disk I/O: often a major bottleneck in any processing pipeline.
Generally, with Hadoop we’ll see read speeds of anywhere from 20 MBps to 100 MBps, and there are limitations on the motherboard or controller for reading from all the disks on the system.
To maximize read speeds, make sure to take advantage of as many disks as possible on the source system.
On a typical drive three threads is normally required to maximize throughput, although this number will vary.

- to use as many as multiple disks
- multi-threads

##### ORIGINAL FILE TYPE

##### COMPRESSION

##### RELATIONAL DATABASE MANAGEMENT SYSTEMS

Apache Sqoop: a very rich tool with lots of options, but at the same time it is simple and easy to learn

- batch process: slow timeliness
  - Sqoop
- data pipeline split: one to RDBMS, one to HDFS
  - Flume or Kafka
- network limited: edge node
  - RDBMS file dump

##### STREAMING DATA

##### LOGFILES

- anti-pattern: read the logfiles from disk as they are written
  - because this is almost impossible to implement without losing data
- recommend: Flume or Kafka

### Transformations

Options:
- Transformation
- Partitioning
- Splitting

For timeliness,
- batch transformation
  - Hive, Pig, MapReduce, Spark
  - checkpoint for failure
  - all-or-nothing
- streaming ingestion
  - Flume
    - interceptors
      - notice the performance issue, external call, GC, etc.
    - selectors
      - decide which of the roads of event data will go down

### Network Bottlenecks

- increase bandwidth
- compress data

### Network Security

- encrypt with OpenSSL

### Push or Pull

requirements:
- Keeping track of what has been sent
- Handling retries or failover options in case of failure
- Being respectful of the source system that data is being ingested from
- Access and security

##### SQOOP

a pull solution, requires
- connection information for the source database
- one or more tables to extract
- ensure at a defined extraction rate
- scheduled to not interfere with the source system’s peak load time

##### FLUME

- Log4J appender
  - pushing events through a pipeline
- spooling directory source or the JMS source
  - events are being pulled

### Failure Handling

> Failure scenarios need to be documented, including failure delay expectations and how data loss will be handled.

- File transfer
  - using directories for different stages
    - *ToLoad*
    - *InProgress*
    - *Failure*
    - *Successful*
- Streaming ingestion
  - areas for failure
    - publisher failure
    - broker failure
    - consumer failure
  - deduplication
    - is a heavy performance cost
    - some other works
      - https://segment.com/blog/exactly-once-delivery/
      - http://eng.tapjoy.com/blog-list/real-time-deduping-at-scale

### Level of Complexity

ease of use, ex. HDFS CLI, FUSE, or NFS

## Data Ingestion Options

In here,
- File transfer
- Sqoop
- Flume
- Kafka

### File Transfers

Hadoop client's `hadoop fs -put` and `hadoop fs -get`

- simplest
- all-or-nothing batch processing
- single-threaded
- no transformations
- any file types

##### HDFS CLIENT COMMANDS

- configurable replicas, common default 3
- checksum file accompanies each block
- *double-hop* from a edge node due to some network policy

##### MOUNTABLE HDFS

- allow to use common filesystem commands
- not full POSIX semantic
- not support random write
- potential misuse: small files problem
  - mitigated by Solr for indexing, HBase, container format as Avro

implementations example
- Fuse-DFS
  - no need to modify the Linux kernel
  - multiple hops, poor consistency model
  - not yet production ready
- NFSv3
  - scaling by Hadoop NFS Gateway nodes
  - recommended to use only in small, manual data transfers

#### Considerations

- single sink or multiple sinks
- reliability or not
- transformation or not

### Sqoop: Batch Transfer Between Hadoop and Relational Databases

> When used for importing data into Hadoop, Sqoop generates map-only MapReduce jobs where each mapper connects to the database using a Java database connectivity (JDBC) driver, selects a portion of the table to be imported, and writes the data to HDFS.

##### CHOOSING A SPLIT-BY COLUMN

- `split-by`
- `num-mappers`

##### USING DATABASE-SPECIFIC CONNECTORS WHENEVER AVAILABLE

##### USING THE GOLDILOCKS METHOD OF SQOOP PERFORMANCE TUNING

- start with a very low number of mappers
- gradually increase it to achieve a balance

##### LOADING MANY TABLES IN PARALLEL WITH FAIR SCHEDULER THROTTLING

- Load the tables sequentially
![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-2-Data-Movement/load_sequencially.png)

- Load the tables in parallel (Fair Scheduler)
![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-2-Data-Movement/load_parallel.png)

##### DIAGNOSING BOTTLENECKS

- Network bandwidth
  - likely to be either 1 GbE or 10 GbE (120 MBps or 1.2 GBps)
- RDBMS
  - review the query generated by the mappers
  - in Sqoop incremental mode
    - make sure using index
  - ingest entire table
    - full table scans are typically preferred
  - monitor the database
  - schedule the execution time
- Data skew
  - default splitting range evenly with min to max of split_by column values
  - choose `--split-by`
  - define `--boundary-query`
- Connector
  - RDBMS-specific connector is preferred
- Hadoop
  - check disk I/O, CPU utilization, and swapping on the DataNodes where the mappers are running
- Inefficient access path
  - incredibly important the split column is either the **partition key** or has an **index**
  - if no such column, then use only one mapper

##### KEEPING HADOOP UPDATED

- small table
  - just overwrite it
- large table
  - delta
    - Incremental Sequence ID
    - Timestamp
  - write to a new directory
    - check `{output_dir}/_SUCCESS`
  - compaction with `sqoop-merge`
    - sorted and partitioned data set could be optimized in merge, map-only job

### Flume: Event-Based Data Collection and Processing

##### FLUME ARCHITECTURE

[Flume Components]

Main components inside of the Flume agent JVM:
- Sources
  - consume events from external sources and forward to channels
  - including AvroSource, SpoolDirectorySource, HTTPSource, and JMSSource
- Interceptors
  - allow events to be intercepted and modified in flight
  - anything that can be implemented in a Java class
  - formatting, partitioning, filtering, splitting, validating, or applying metadata to events
- Selectors
  - routing for events
  - fork to multiple channels, or send to a specific channel based on the event
- Channels
  - store events until they’re consumed by a sink
  - memory channel, file channel, balancing performance with durability
- Sinks
  - remove events from a channel and deliver to a destination

##### FLUME PATTERNS

###### Fan-in

Agents on Hadoop edge nodes.

![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-2-Data-Movement/flume_ingest_fan_in.png)


###### Splitting data on ingest

Backup HDFS cluster for disaster recovery (DR).

![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-2-Data-Movement/flume_ingest_split.png)

###### Partitioning data on ingest

Ex. partition events by timestamp.

![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-2-Data-Movement/flume_ingest_partition.png)

###### Splitting events for streaming analytics

Send to streaming such as Storm or Spark Streaming. (point a Flume Avro sink to Spark Streaming’s Flume Stream)

##### FILE FORMATS

- Text files
  - with container format SequenceFiles or Avro
  - Avro is preferred because
    - it stores schema as part of the file,
    - and also compresses more efficiently.
    - providing better failure handling.
- Columnar formats
  - RCFile, ORC, or Parquet are also **not** well suited for Flume
  - more data lose risk due to batch processing
- Customized *event serializers*
  - override the EventSerializer interface to apply your own logic and create a custom output format

##### RECOMMENDATIONS

###### Flume sources

- Batch size
  - notice of the network latency for sending acknowledge
  - start from 1,000
- Threads
  - pushing source: add more clients or client threads
  - pulling source: configure more sources in the agent

###### Flume sinks

- Number of sinks
  - channel to sink, is one-to-many
  - sink is single thread
  - limitation with more sinks should be the network or the CPU
- Batch Sizes
  - overhead of an *fsync* system call
  - only big downside to large batches with a sink is an increased risk of duplicate events
  - balance between throughput and potential duplicates

###### Flume interceptors

- capability to take an event or group of events and modify them, filter them, or split them
- custom code comes with risk of issues like memory leaks or consuming excessive CPU

###### Flume memory channels

- if performance is your primary consideration, and data loss is not an issue
- better for streaming analytics sink

###### Flume file channels

- it’s more durable than the memory channel
- to use multiple disks
- if using multiple file channels, use distinct directories, and preferably separate disks, for each channel
- use dual checkpoint directories
- better for persistent sink

###### JDBC channels

- persists events to any JDBC-compliant data store
- most durable channel, but also the least performant

###### Sizing Channels

- Memory channels
  - can be fed by multiple sources
  - can be fetched from by multiple sinks
  - so for a pipeline, one channel in a node usually is enough
- Channel size
  - large memory channel could have **garbage collection** activity that could slow down the whole agent

##### FINDING FLUME BOTTLENECKS

- Latency between nodes
  - batch size or more threads
- Throughput between nodes
  - data compression
- Number of threads
- Number of sinks
- Channel
- Garbage collection issues

### Kafka

- *producers*, *brokers*, *consumers*
- *topic*, *partition*, *offset*

Large number of partitions:
- Each partition can be consumed by at most one consumer from the same group
- Therefore, we recommend at least as many partitions per node as there are servers in the cluster, possibly planning for a few years of growth.
- There are no real downsides to having a few hundred partitions per topic.

##### KAFKA FAULT TOLERANCE

- *replica*
- *leader*, *followers*

Producer acknowledge:
- all synchronized replicas
- leader only
- asynchronized

Consumer only read *committed* (all synchronized) messages.

Supported semantics,
- *at least once*
  - consumer advances the offset **after** processing the messages
- *at most once*
  - consumer advances the offset **before** processing the messages
- *exactly once*
  - consumer advances the offset, and processes the messages **at the same time** with two-phase commits

Multiple data centers deployment.

##### KAFKA AND HADOOP

| | Kafka | Flume |
|-|-------|-------|
| Hadoop ingest solution | less | more |
| Required code writing | yes | no |
| Fault tolerant | higher | lower |
| Performance | higher | lower |

###### Flume with Kafka

- Kafka source
  - consumer, reads data from Kafka and sends it to the Flume channel
  - adding multiple sources with the same *groupId* for load balancing and high availability
  - batch size tuning
- Kafka sink
  - producer, sends data from a Flume channel to Kafka
  - batch size tuning
- Kafka channel
  - combines a producer and a consumer
  - each batch will be sent to a separate Kafka partition, so the writes will be load-balanced

###### Camus

- ingesting data from Kafka to HDFS
- automatic discovery of Kafka topics from ZooKeeper
- conversion of messages to Avro and Avro schema management
- automatic partitioning
- all-or-nothing batch processing
- need to write decoder to convert Kafka messages to Avro

![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-2-Data-Movement/camus.png)

## Data Extraction

- Moving data from Hadoop to an RDBMS or data warehouse
  - In most cases, Sqoop will be the appropriate choice for ingesting the transformed data into the target database.
- Moving data between Hadoop clusters
  - DistCp uses MapReduce to perform parallel transfers of large volumes of data.
  - DistCp is also suitable when either the source or target is a non-HDFS filesystem—for example, an increasingly common need is to move data into a cloud-based system, such as Amazon’s Simple Storage System (S3).
