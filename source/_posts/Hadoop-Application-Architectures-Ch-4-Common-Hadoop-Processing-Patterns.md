---
title: Hadoop Application Architectures Ch.4 Common Hadoop Processing Patterns
date: 2019-12-10 09:13:22
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

Examples:
- Removing Duplicate Records by Primary Key (Compaction)
- Using Windowing Analysis
- Updating Time Series Data

## Removing Duplicate Records by Primary Key

- Spark
  - `map()` to `keyedRDD`, `reduceByKey()` to compaction
- SQL
  - `GROUP BY` primary key, `SELECT` `MAX(TIME_STAMP)`
  - `JOIN` back to filter on the original table

## Windowing Analysis

Find the *valley* and *peak*.

- Spark
  - partition by primary key's hash, sorted by timestamp
  - `mapPartitions`
    - iterate the sorted partition to address `peak` and `valley`
- SQL
  - `SELECT` `LEAD()` and `LAG()` `OVER (PARTITION BY PRIMARY_KEY ORDER BY POSITION)`
  - `SELECT` `CASE`
    - `WHEN VALUE > LEAD` and `LAG`, `THEN 'PEAK'`
    - `WHEN VALUE < LEAD` and `LAG`, `THEN 'VALLEY'`
  - Note: multiple windowing operations with SQL will increase the disk I/O overhead and lead to performance decrease

## Time Series Modifications

![](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-4-Common-Hadoop-Processing-Patterns/time_series.png)

- HBase and Versioning
  - advantage:
    - modifications are very fast, simply update
  - disadvantage:
    - penalty in getting historical versions
    - performing large scans or block cache reads
- HBase with a RowKey of RecordKey and StartTime
  - `get` existing record
  - `put` back with update stop time
  - `put` the new current record
  - advantage:
    - faster version retrieve
  - disadvantage:
    - slower update, requires 1 `get` and 2 `put`s
    - still has the large scan and block cache problems
- Partitions on HDFS for Current and Historical Records
  - partitioning into
    - most current records partition
    - historic records partition
  - batch update
    - for updated "current" records, update the stop time and append to historic records partition
    - add new update into most current records partition
