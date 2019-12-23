---
title: Hadoop Application Architectures Ch.5 Graph Processing on Hadoop
date: 2019-12-16 06:32:23
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

Use cases:
- page ranking
- social network
- investment funds underlying equities
- route planning

*gragh querying* v.s. *graph processing*

*onion joining* v.s. *message sending*

### The Bulk Synchronous Parallel (BSP) Model

- proposed by Leslie Valiant of Harvard, a British computer scientist
- at the core of the Google graph processing solution, Pregel
- the distributed processes can send **messages** to each other, but they cannot act upon those messages until the next **superstep**

## Graph

- an open source implementation of Google's Pregel
- main stages
  - read and partition the data
  - batch-process the graph with BSP
  - write the graph back to disk

## GraphX

- contains an implementation of the Pregel API built on the Spark DAG engine
- RDD representation of EdgeRDD and VertexRDD
- could be mixed with Spark transformations
