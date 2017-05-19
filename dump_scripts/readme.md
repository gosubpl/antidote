# What's here

This repo contains tools developed for [Antidote](https://github.com/SyncFree/antidote)

## [Plotter](./plotter/)
Python scripts for plotting [Basho Bench](https://github.com/SyncFree/basho_bench) results from [this set of scripts](https://github.com/SyncFree/basho_bench/tree/ec1/script/g5k), both for *Staleness* and *Throughput*


![Example throughput plot](./plotter/images/singledc.png "Throughput example plot")
![Example staleness plot](./plotter/images/example-staleness-muli-dc-multi-round-phyx-csi.png "Staleness chart")

## [Dump scripts](./tables_dump/)
Erlang scripts for dumping *log*, and *cache/snapshot* tables into files.
A lot of useful information about log structures, log handling and schematics is present here.

## [Parser](./parser/)
This implementation has been **abandoned** and the functionalities will be directly implemented into [Antidote](https://github.com/SyncFree/antidote) replication protocols.