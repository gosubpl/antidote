# Parser [Abandonned]
This implementation has been **abandoned** due to conceptual error in architecture of the tool, and the functionalities will be directly implemented into [Antidote](https://github.com/SyncFree/antidote) replication protocols.

### Propositions
- Regexp parser that will recognise the log_record
	- Pros
		- As soon as I find any, pinky promise I'll put it here
	- Cons
		- Tricky, tricky, regexps
		- If log format changes, regexp will probably have to change
- Parsing the file line by line, counting the number of curly brackets to reconstruct the record and then treat it
	- Pros
		- Complete control while parsing the file
		- Somewhat independent of log implementation, brackets are brackets
	- Cons
		- I dunno man
		- Freaking annoying string management in Erlang
- sed-ing the dump file, removing the chevrons before passing it to BIFs, maintaining original conception
	- Pros
		- Original conception maintained
		- Could maybe use the Erlang BIF `file:consult/1` to reconstruct the records afterwards automatically
		- No changes to `log_dump.erl` script
		- sed should be relatively easy to do
	- Cons
		- Don't know if it works
		- Would have to be dev'd just to check
The chosen way:
	- Parse the log file by line counting the curly brackets
	- Regexp to get the required fields
	- Fill the abstract log record
Invariants verification

### Parsing
Because the `file:consult/1` does not work with the syntax Antidote uses to store log records (`{tx_id,1493300303013265,<9656.3473.0>}`}, is being recognised as syntax error, the chevron should not be there for the function to work, we need solutions.
When referring to log record hereafter, here's what we mean:

```erlang
{log_record,0,
      {op_number,
          {'antidote@127.0.0.1',{'antidote@127.0.0.1',{1493,300295,153320}}},
          1,1},
      {op_number,
          {'antidote@127.0.0.1',{'antidote@127.0.0.1',{1493,300295,153320}}},
          1,1},
      {log_operation,
          {tx_id,1493300303013265,<9656.3473.0>},
          update,
          {update_log_payload,
              {<<"71268">>,<<"antidote_bench_bucket">>},
              undefined,antidote_crdt_counter,1}}}}
```

### Infos from the structure
Data available in the log structure:

- Key hash
- Operation type (always `log_record`)
- Version
- Op_number
- Transaction id
	- Node - "antidote@127.0.0.1"
	- Node PID - <0.7102.0>
- Timestamps
	- Prepare time
	- Commit time
	- Clock time
Snapshot time

### Invariants
[WIP]

| Invariant | Log field |
|---|---|
| Monotonically increasing TX ids | `tx_id` |
| Prepare->Commit (2PC correctness) | `op_type`, `tx_id` |
| Unique transaction ids | `tx_id` |
| Syntactic coretness | Erlang `isRecord()` BIF |
