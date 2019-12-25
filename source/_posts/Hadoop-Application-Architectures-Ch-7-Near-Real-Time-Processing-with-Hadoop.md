---
title: Hadoop Application Architectures Ch.7 Near-Real-Time Processing with Hadoop
date: 2019-12-23 00:46:04
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

Straming processing tools
- *Apache Storm*
- *Apache Spark Streaming*
- *Apache Samza*
- *Apache Flume* via Flume interceptors
- *Apache Flink*

Not include
- *Kafka*
  - is only a message bus, not processing streaming data
- *Impala, Apache Drill, or Presto*
  - are the low-latency, massively parallel processing (MPP) query engines

NRT, near-real-time, processing

## Stream Processing


Common functions,
- Aggregation
- Windowing averages
- Record level enrichment
- Record level alerting / validation
- Persistence of transient data (storing state)
- Support for Lambda Architectures
- Higher-level functions (sorting, grouping, partitioning, joining)
- Integration with HDFS / HBase

##### THE LAMBDA ARCHITECTURE

> The Lambda Architecture, as defined by Nathan Marz and James Warren and described more thoroughly in their book Big Data (Manning), is a general framework for scalable and fault-tolerant processing of large volumes of data.

- Batch layer
  - immutable copy of the master data
  - precomputes the *batch views*
- Serving layer
  - indexes the batch views, loads them, and makes them available for low-latency querying
- Speed layer
  - is essentially the real-time layer in the architecture
  - creates views on data as it arrives in the system

Processing Flow,
- new data will be sent to the **batch** and **speed** layers
  - in the batch layer, appended to the master data set
  - in the speed layer, used to do incremental updates of the real-time views
- at query time
  - data from both layers will be combined
  - when the data is available in the **batch** and **serving** layers, it can be discarded from the **speed** layer

Advantage,
- fault tolerant
- low latency
- error correction

##### MICROBATCHING VERSUS STREAMING

- processing logic simplification
- message processing overhead (batch *puts*)
- exactly-once
- Storm, pure streaming tool

## Apache Storm

### Storm High-Level Architecture

![Storm Architecture](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-7-Near-Real-Time-Processing-with-Hadoop/storm_architecture.png)

### Storm Topologies

![Storm Topology](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-7-Near-Real-Time-Processing-with-Hadoop/storm_topology.png)

- In Storm you are building a topology that is solving a problem.
- In Trident and Spark Streaming you are expressing how to solve a problem, and the topology is constructed for you behind the scenes.

### Tuples and Streams

A stream is an unbounded sequence of tuples between any two nodes in a topology.

### Spouts and Bolts

- Spouts
  - provide the source of streams in a topology
  - read data from some external source, and emit one or more streams
- Bolts
  - consume streams in a topology
  - do some processing on the tuples in the stream
  - then emit zero or more tuples to downstream bolts or external system as a data persistence layer

### Stream Groupings

An important feature of Storm, over Flume.

Groupings,
- Shuffle grouping
  - evenly and randomly distributing tuples to each downstream bolts
- Fields grouping
  - based on the specified field(s) in the tuples, send to the same bolt
  - like partitioning by hash key
- All grouping
  - fan-out
  - replicates stream to all bolts
- Global grouping
  - fan-in, collecting
  - sends an entire stream to a single bolt

### Reliability of Storm Applications

The ability to guarantee message processing relies on having a reliable message source, ex. *Kafka*.

- At-most-once processing
- At-least-once processing
- Exactly-once processing
  - leverage an additional abstraction over core Storm, like Trident

### Storm Example: Simple Moving Average

- Linked list for the windowing buffer
- `suffleGrouping` and `fieldGrouping(new Field("ticker"))` in `buildTopology()`

### Evaluating Storm

##### SUPPORT FOR AGGREGATION AND WINDOWING

- easy to implement
- state, counters not fault-tolerant, since it uses local storage
  - if using external storage, like HBase or Memcached, notice the sync overhead, and progress loss trade-off

##### ENRICHMENT AND ALERTING

##### LAMDBA ARCHITECTURE

- batch processes implemented with ex. MapReduce or Spark

## Trident

- a higher-level abstraction over Storm
- wrap Storm in order to provide support for transactions over Storm
- follows a declarative programming model similar to SQL
- use *operations* for processing, such as filters, splits, merges, joins, and groupings
- follows a microbatching model
  - providing a model where exactly-once semantics can be more easily supported
  - provides the ability to replay tuples in the event of failure
  - provides management of batches to ensure that tuples are processed exactly once

### Evaluating Trident

##### SUPPORT FOR AGGREGATION AND WINDOWING

- now can persist to external storage systems to maintain state with higher throughput

##### ENRICHMENT AND ALERTING

- the batches are merely wrappers, nothing more than a marker at the end of a group of tuples

##### LAMDBA ARCHITECTURE

- still need to implement the batch process in something like MapReduce or Spark

## Spark Streaming

- Reliable persistence of intermediate data for your counting and rolling averages.
- Supported integration with external storage systems like HBase.
- Reusable code between streaming and batch processing.
- The Spark Streaming microbatch model allows for processing patterns that help to mitigate the risk of duplicate events.

Concept:
- normal *RDD*: a reference to a distributed immutable collection
- *DStream*: a reference to a distributed immutable collection in relation to a batch window, chunk

![Spark Streaming simple count example](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-7-Near-Real-Time-Processing-with-Hadoop/spark_stream_simple_count.png)

![Spark Streaming multiple stream](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-7-Near-Real-Time-Processing-with-Hadoop/spark_stream_multiple.png)

![Maintaining state in Spark Streaming](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-7-Near-Real-Time-Processing-with-Hadoop/spark_stream_stateful.png)

- `updateStateByKey()`
- *checkpoint*

##### DSTREAMS PROVIDES FAULT TOLERANCE

- saved state to *checkpoint* directory every *N* microbatch
- recreate from cache in memory or disk

##### SPARK STREAMING FAULT TOLERANCE

- WAL for driver process failure recovery
- resilient RDD, configurable

### Evaluating Spark Streaming

##### SUPPORT FOR AGGREGATION AND WINDOWING

- counting, windowing, and rolling averages are straightforward in Spark Streaming

##### ENRICHMENT AND ALERTING

- have performance throughput advantages if it requires lookup from external systems like HBase to execute the enrichment and/or alerting
- major downside here is the latency, seconds level microbatching

##### LAMDBA ARCHITECTURE

- code reuse for Spark & Spark Streaming
