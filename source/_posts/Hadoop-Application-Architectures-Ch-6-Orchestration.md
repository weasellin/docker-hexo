---
title: Hadoop Application Architectures Ch.6 Orchestration
date: 2019-12-16 07:23:45
tags:
- reading_note
- data_engineering
- hadoop
- hadoop_application_architectures
---

## Overview

System of,
- *workflow orchestration*
- *workflow automation*
- *business process automation*
- scheduling, coordinating, and managing workflows

Each of jobs, referred to as an *action*, could be
- scheduled
  - at a particular time
  - periodic interval
  - triggered by events or status
- coordinated
  - when a previous action finishes successfully
- managing to
  - send notification mails
  - record the time taken

Good workflow orchestration engines will
- expressed as a **DAG**
- help defining the **interfaces** between workflow components
- support metadata and data lineage tracking
- integration between various software system
- data lifecycle management
- track and report data quality
- workflow components repository
- flexible scheduling
- dependency management
- centralized status monitoring
- workflow failure recovery
- workflow rolling back
- report generation
- parameterized workflow
- arguments passing

## Orchestration Framworks

| Workflow Engine | Summary |
|---|---|
| Apache Oozie | developed by Yahoo!, in order to support its growing Hadoop clusters and the increasing number of jobs and workflows running on those clusters |
| Azkaban | developed by LinkedIn, with the goal of being a visual and easy way to manage workflows |
| Luigi | an open source Python package from Spotify, that allows you to orchestrate long-running batch jobs and has built-in support for Hadoop |
| Airflow | created by Airbnb, an open source Python workflow management system designed for authoring, scheduling, and monitoring workflows |


Considerations,
- ease of installation
- community involvement and uptake
- UI support
- testing
- logs
- workflow management
- error handling

![Oozie Architecture](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-6-Orchestration/oozie_architecture.png)

![Azkaban Architecture](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-6-Orchestration/azkaban_architecture.png)

## Workflow Patterns

![Point-to-Point Workflow](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-6-Orchestration/point_to_point_workflow.png)

![Fan-out Workflow](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-6-Orchestration/fan_out_workflow.png)

![Capture-and-Decision Workflow](https://github.com/weasellin/docker-hexo/raw/master/source/_posts/Hadoop-Application-Architectures-Ch-6-Orchestration/capture_decision_workflow.png)

## Scheduling Patterns

- Frequency Scheduling
  - Note: DST cause that a day (with Timezone info) will not always be 24 hours
- Time and Data Triggers
