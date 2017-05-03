---
title: Quick Start Guide
last_updated: May 2, 2017
tags: [quick_start]
sidebar: mydoc_sidebar
permalink: quick_start.html
toc: true
---

This guide will walk you through the core features of AntidoteDB. We will use Docker to run AntidoteDB nodes. Please refer to the [complete installation guide](http://syncfree.github.io/antidote/setup.html) if you wish to build the nodes from source.

In this guide, you will accomplish the following steps:

 * Start two AntidoteDB nodes and connect them to each other;
 * Start and commit a transaction;
 * Use the Bounded Counter data type.

## Dependencies
 * Install the latest version of Docker ([Installation Guide](https://docs.docker.com/engine/installation/)).

## Fetch AntidoteDB docker image

Simply type:

```sh
docker pull balegas/antidotedb
```

## Create a cluster

Create a virtual network interface:

```sh
docker network create --driver bridge default_ntwk
```

Start two AntidoteDB node instances which will be called 'antidote1' and 'antidote2':

```sh
docker run -i -t -d --name antidote1 --network default_ntwk -e NODE_NAME=antidote1 -e INSTANCE_NAME=antidote balegas/antidotedb

docker run -i -t -d --name antidote2 --network default_ntwk -e NODE_NAME=antidote2 -e INSTANCE_NAME=antidote balegas/antidotedb
```

To simplify the addressing of the Antidote nodes, we get the host names of both nodes:

```sh
docker inspect --format '{{ "{{.Config.Hostname "}}}}' antidote1
# output: 1ea3a5843daf

docker inspect --format '{{ "{{.Config.Hostname "}}}}' antidote2
# output: 7d8a69ce1faf
```

Connect to the console of each node using separate terminals:

```sh
docker exec -it antidote1 /opt/antidote/bin/antidote attach

docker exec -it antidote2 /opt/antidote/bin/antidote attach
```

In one of the consoles, enter the command to connect the two nodes together:

```erlang
    cluster_mgr:connect_cluster(['antidote1@1ea3a5843daf','antidote2@7d8a69ce1faf']).
    # output: [ok,ok]
```

Our cluster is now ready!

## Interacting with AntidoteDB

First start a new transaction and increment the value of a bounded counter. By default, if the counter does not exist, one is created automatically.

```erlang
{ok, TxId} = antidote:start_transaction(ignore, []).
antidote:update_objects([{ {counter_key, antidote_crdt_bcounter, test_bucket}, increment, {10, client1}}], TxId).
antidote:commit_transaction(TxId).
# output: {ok, ...}
```

The counter can be decremented in the replica where it was created:

```erlang
{ok, TxId1} = antidote:start_transaction(ignore, []).
antidote:update_objects([{ {counter_key, antidote_crdt_bcounter, test_bucket}, decrement, {1, client1}}], TxId1).
antidote:commit_transaction(TxId1).
# output: {ok, ...}
```

And the value of the counter can be read on the other replica (use the other terminal):

```erlang
{ok, TxId} = antidote:start_transaction(ignore, []).
{ok, [Obj]} = antidote:read_objects([{counter_key, antidote_crdt_bcounter, test_bucket}], TxId).
antidote_crdt_bcounter:permissions(Obj).
# output: 9
```

But cannot be decremented:

```erlang
{error, _} = antidote:update_objects([{ {counter_key, antidote_crdt_bcounter, test_bucket}, decrement, {1, client2}}], TxId).
# output: {error,{aborted, ...}}
```

At this point, the transaction aborts and the system will automatically fetch permissions from another replica.
After the resources are transfered between nodes, it is possible to decrement the counter.

```erlang
{ok, TxId1} = antidote:start_transaction(ignore, []).
antidote:update_objects([{ {counter_key, antidote_crdt_bcounter, test_bucket}, decrement, {1, client2}}], TxId1).
antidote:commit_transaction(TxId1).
# output: {ok, ...}
```

Look at the [documentation](http://syncfree.github.io/antidote/rawapi.html) to see more examples of AntidoteDB in action.
We are working on new features for AntidoteDB, contact us at [info@antidotedb.com](mailto:info@antidotedb.com) if you want to know more.
