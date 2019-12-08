---
title: Hadoop Application Architectures Ch.3 Processing Data in Hadoop
date: 2019-12-04 12:01:29
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

- MapReduce
- Spark
- Hive, Pig, Crunch, Cascading

*Shared Nothing Architectures*
- scalability
- fault-tolerant

## MapReduce

### Overview

- introduced by *Jeffrey Dean* and *Sanjay Ghemawat* from *Google* with [paper]()
- map phase / sort & shuffle phase / reduce phase
- input / output of each phase are *key-value* pairs
- output of mapper and reducer is written to disk
  - *syncronization barrier* (inefficient for iterative processing)
- mapper processes a single pair at a time
- mapper pass key-value pairs as output to reducers
- mapper can't pass information to other mappers

### Mapper

- `InputFormat` class
  - `getSplits()`
    - determines the number of map processes
    - determines the cluster nodes on which they will execute
    - commonly used `TextInputFormat` generates an input split per block
  - `getReader()`
    - provides a reader to map tasks
    - could be overridden
- `RecordReader` class
  - reads the data blocks, returns key-value records
  - implementations: text delimited, SequenceFile, Avro, Parquet, etc.
- `Mapper.setup()`
  - `Configuration` object
- `Mapper.map()`
  - inputs: `key`, `value`, and a `context`
  - output data would be buffered and sorted, `io.sort.mb`
- `Partitioner`
  - default, key hashed
  - custom partitioner
    - ex. secondary sort
      - key as `ticker-time` for sorted, partitioner on `ticker symbol`
- `Mapper.cleanup()`
  - flies closing, logging message, etc.
- `Combiner.combine()`
  - aggregate locally
  - output has to be identical format with `map()`
  - could assumes the input is sorted

### Reducer

- `Shuffle`
  - copy the output of the mappers from the map nodes to the reduce nodes
- `Reducer.setup()`
  - initialize variables and file handles
- `Reducer.reduce()`
  - sorted key
  - input with `values`
  - a key and all its values will never be split across more than one reducer
    - skewness, review partitioning
  - output to `outputFileFormat`
- `Reducer.cleanup()`
  - flies closing, logging message, etc.
- `OutputFormat`
  - a single reducer will always write a single file
    - ex. `part-r-00000`

### Join

Reference: https://www.edureka.co/blog/mapreduce-example-reduce-side-join/

##### Map-side Join

> The join operation is performed in the map phase itself. Therefore, in the map side join, the mapper performs the join and it is mandatory that the input to each map is partitioned and sorted according to the keys.

##### Reduce-side Join


> - Mapper reads the input data which are to be combined based on common column or join key.
- The mapper processes the input and adds a tag to the input to distinguish the input belonging from different sources or data sets or databases.
- The mapper outputs the intermediate key-value pair where the key is nothing but the join key.
- After the sorting and shuffling phase, a key and the list of values is generated for the reducer.
- Now, the reducer joins the values present in the list with the key to give the final aggregated output.

### When to Use MapReduce

- is a very low-level framework
- for experienced Java developers who are comfortable with the MapReduce programming paradigm
- where detailed control of the execution has significant advantages

## Spark

### Overview

- In 2009 *Matei Zaharia* and his team at *UC Berkeley’s AMPLab* researched possible improvements to the MapReduce framework.
- Improves on
  - iterative machine learning
  - interactive data analysis
  - reusing a data set cached in memory for multiple processing tasks
  - DAG model (directed acyclic graphs)
    - ex. Oozie for MapReduce
- reference books
  - [Learning Spark](http://bit.ly/learning-spark)
  - [Advanced Analytics with Spark](http://bit.ly/advanced-spark)

### Spark Components

- *Driver*
  - *main* function to define the RDD (*resilient distributed datasets*) and their transformations / actions
- *Dag Scheduler*
  - optimize the code and arrive an efficient DAG
- *Task Scheduler*
  - cluster manager: YARN, Mesos, etc. has info
    - workers
    - assigned threads
    - location of data blocks
    - assigning tasks to workers
- *Worker*
  - receives work and data
  - executes task without knowledge of the entire DAG

### Basic Spark Concepts

##### RDD (RESILIENT DISTRIBUTED DATASETS)

- RDDs are collections of serializable elements, and such a collection may be partitioned, in which case it is stored on multiple nodes
- Spark determines the number of partitions by the input format
- RDDs store their **lineage** — the set of transformations that was used to create the current state, starting from the first input format that was used to create the RDD
- If the data is lost, Spark will **replay** the lineage to rebuild the lost RDDs so the job can continue
- Spark would replay the “Good Replay” boxes and the “Lost Block” boxes to get the data needed to execute the final step

##### SHARED VARIABLES

- *broadcast* variables
- *accumulator* variables

##### SPARKCONTEXT

- represents the connection to a Spark cluster
- used to create RDDs, broadcast data, and initialize accumulators

##### TRANSFORMATIONS

- transformations take one RDD and return another RDD
- RDDs are **immutable**
- transformations in Spark are always **lazy**
- calling a transformation function only creates a new RDD with this specific **lineage**
- transformations is only executed when an **action** is called
  - allows optimize the execution graph

Some core transformations:
- `map()`
- `filter()`
- `keyBy()`
- `join()`
- `groupByKey()`
- `sort()`

##### ACTION

- take an RDD, perform a computation, and return the result to the driver application
- result of the computation can be *a collection*, *values printed to the screen*, *values saved to file*, or similar
- an action will never return an RDD

### Benefits of Using Spark

##### SIMPLICITY

- simpler than those of MapReduce

##### VERSATILITY

- extensible, general-purpose parallel processing framework
- support a stream-processing framework called Spark Streaming
- a graph processing engine called GraphX

##### REDUCED DISK I/O

- Spark’s RDDs can be stored in memory and processed in multiple steps or iterations without additional I/O

##### STORAGE

- the developer controls the persistence

##### MULTILANGUAGE

- Spark APIs are implemented for Java, Scala, and Python

##### RESOURCE MANAGER INDEPENDENCE

- Spark supports YARN, Mesos, & Kubernetes

##### INTERACTIVE SHELL

- REPL (read-eval-print loop)

##### APACHE TEZ: AN ADDITIONAL DAG-BASED PROCESSING FRAMEWORK

- Tez is a framework that allows for expressing complex DAGs for processing data
- the architecture of Tez is intended to provide performance improvements and better resource management than MapReduce


## Abstraction

- ETL Model: Pig, Crunch, and Cascading
- Query Model: Hive

### Apache Pig

- developed at *Yahoo*, and released to Apache in 2007
- Pig-specific workflow language, *Pig Latin*
- compiled into a logical plan and then into a physical plan
- Data container
  - *relations*, *bag*, *tuples*
- Transformation functions
  - no execution is done until the STORE command is called - nothing is done until the saveToTextFile is called
- `DESCRIBE` and `EXPLAIN`
- support UDFs
- CLI to access HDFS

### Apache Crunch

- based on Google’s *FlumeJava*
- in Java
- full access to all MapReduce functionality
- separation of business logic from integration logic
- `Pipeline` object
- actual execution of a Crunch pipeline occurs with a call to the `done()` method
- `MRPipeline`, `SparkPipeline`, `PCollection`, `PTable`

### Cascading

- in Java
- like Crunch, full access to all MapReduce functionality
- like Crunch, separation of business logic from integration logic

## Hive

### Overview

- SQL on Hadoop
- cornerstone of newer SQL implementations
  - Impala, Presto, Spark SQL, Apache Drill
- biggest drawback, **performance**, due to MapReduce execution engine
  - addressed by
    - `Hive-on-Tez`, from 0.13.0
    - `Hive-on-Spark`, [HIVE-7292](https://issues.apache.org/jira/browse/HIVE-7292)
    - *Vectorized query execution*, from 0.13.0, supports on ORC and Parquet
- Hive Metastore, becomes the standard for metadata management and sharing among different systems

![Hive Architecture](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-3-Processing-Data-in-Hadoop/hive_architecture.png)

- In `CREATE TABLE`
  - *external table*, underlying data remains intact while table deletion
  - storage format declarartion
- `ANALYZE STATISTICS`
  - `ANALYZE TABLE foo COMPUTE STATISTICS;`
  - `hive.stats.autogater`, default `true`, but only triggered by `INSERT`
  - import or moving still need explicit `ANALYZE` command
- optimized `join`
  - available in newer version only
  - `hive.auto.convert.join`
    - *map join*
    - *bucketed join*
    - *sorted bucketed merge join*
    - *regular join*
- SQL is great for query, but not for
  - machine learning, text processing, graph algorithms
- should always reviewing under the hood, ex. by `EXPLAIN`

### When to Use Hive

- Hive Metastore
- SQL
- Pluggable
  - custom data format, serialization / deserialization
  - execution engine, MapReduce, Tez, Spark
- Batch processing
- Fault-tolerant
- Feature-rich
  - nested types

## Impala

- 2012, Google had published [F1](https://ai.google/research/pubs/pub38125) and [Dremel](https://ai.google/research/pubs/pub36632)
- Impala was inspired by Dremel
- massively parallel processing (MPP) data warehouses
  - such as Netezza, Greenplum, and Teradata
- delivers query latency and concurrency
  - significantly lower than that of Hive running on MapReduce
- uses Hive SQL dialect and Hive Metastore
- supports both HDFS and HBase as data sources, like Hive
- supports the popular data formats
  - delimited text, SequenceFiles, Avro, and Parquet

### Overview

- shared nothing architecture
- Impala daemons, *impalad*
  - running on each nodes, identical and interchangeable
  - responsible for
    - query planner
    - query coordinator
    - query execution engine
- focus on the core functionality, **executing queries as fast as possible**
  - off-loaded data store to HDFS and HBase
  - off-loaded database and table management to Hive Metastore
- distributed join strategies
  - *broadcast hash joins*
  - *partitioned hash joins*
- query profiles
  - table scan rates
  - actual data sizes
  - amount of memory used
  - execution times

![Impala Architecture](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-3-Processing-Data-in-Hadoop/impala_architecture.png)

### Speed-Oriented Design

- in-memory processing
  - could spill to disk from 2.0 and later
  - minimum of 128GB to 256GB of RAM
  - not fault-tolerant, node lose will cause query failed
- long running daemons
  - no startup cost
  - high concurrency
  - colocate for data locality
  - could be managed by YARN or Linux CGroups
- efficient execution engine
  - implemented in C++
    - better advantage of vectorization, CPU instructions for text parsing, CRC32 computation, etc.
    - no JVM overhead
    - no Java GC latency
- use of LLVM
  - Low Level Virtual Machine
  - compile the query to optimized machine code
  - machine code improves the efficiency of the code execution in the CPU by getting rid of the polymorphism
  - machine code generated uses optimizations available in modern CPUs (such as Sandy Bridge) to improve its I/O efficiency
  - the entire query and its functions are compiled into a single context of execution, Impala doesn’t have the same overhead of context switching because all function calls are inlined and there are no branches in the instruction pipeline, which makes execution even faster

### When to Use Impala

- much faster than Hive
- compare to Hive
  - not fault-tolerant
  - not supports nested data types
  - not supports custom data format

## Other Tools

- RHadoop
  - for R
- Apache Mahout
  - machine learning tasks
- Oryx
  - machine learning application
  - Lambda architecture
- Python
  - [A Guide to Python Frameworks for Hadoop](https://www.slideshare.net/InfoQ/a-guide-to-python-frameworks-for-hadoop)
