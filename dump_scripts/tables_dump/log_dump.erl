#! /usr/bin/env escript 
%% -*- erlang -*-
%%! -smp enable -name log_dumper@127.0.0.1 -cookie antidote

-module(log_dump).
-mode(compile).

-define(dbug, io:format("dbug ~p ~p...~n", [?FUNCTION_NAME, ?LINE])).
%% -----------------------------------------------------------------------------
%% Helper tool for dumping the logs to storage.
%% Usage: 
%% $ log_dump.erl <Node>, <Directory>
%% ex: $ log_dump.erl 'antidote@127.0.0.1' "./log_dump/"
%% Attention: The trailing slash in directory name is essential. 
%%            "./log_dump" will simply not work. The directory is created
%%            at node's root dir: "antidote/log_dump/"
%% -----------------------------------------------------------------------------

%% Node is of form antidote@127.0.0.1
%% Dir is of form /log_dump/
main([Node1, Dir]) ->
    Node = list_to_atom(Node1),
    {ok, connected} = antidote_connect(Node),
    {ok, created} = create_dir(Dir, Node),
    {ok, {LocalLog, _DistributedLog}} = retrieve_all(Node),
    {ok, File} = prep_filename(Dir),
    {ok, processed} = process_m2o(Node, LocalLog, File),
    {ok, done}.

%% Connects
-spec antidote_connect(atom()) -> ok | {error, node_offline}.
antidote_connect(Node) ->
    case net_kernel:start([Node, longnames]) of
        {ok, _} -> 
	    ok;
	{error, {already_started,_}} -> 
	    ok;
        {error, {{already_started, _},_}} -> 
	    ok;
	{error, R} -> 
	    io:format("Error connecting ~p~n", [R]),
	    halt(1)
    end,
    %% Hardcoded for simplicity sake
    erlang:set_cookie(Node, antidote),
    %% Redundant connection verification
    case net_adm:ping(Node) of
	pong -> %% We're good
	    io:format("Connected: ~p~n", [Node]),
	    {ok, connected};
	Other -> %% Offline
	    io:format("Can't connect to node ~p (return: ~p)! Aborting.~n", 
		      [Node, Other]),
	    {error, node_offline},
		halt(1)
    end.

%% Ensures the dir for dump is present, creates it otherwise
-spec create_dir(string(), atom()) -> ok | {error, dir_create}.
create_dir(DumpDir, Node) ->
    case rpc:call(Node, filelib, ensure_dir, [list_to_atom(DumpDir)]) of
	ok ->
	    io:format("Dir created: ~s~n", [DumpDir]),
	    {ok, created};
	{error, R} ->
	    io:format("Bad rpc: ~p~n", [R]),
	    {error, R}
    end.

%% Retrieves the logs available at the node
%% Returns a tuple of two lists  : {[LocalLog], [DistributedLog]}
-spec retrieve_all(atom()) -> tuple().
retrieve_all(Node) ->
    case rpc:call(Node, disk_log, accessible_logs, []) of 
	{badrpc, R} ->
	    {error, R};
	{Local, Distributed} ->
	    io:format("Retrieved ~p local and ~p distributed logs~n", 
		      [length(Local), length(Distributed)]),
	    {ok, {Local, Distributed}}
    end.

%% Prepares the filename, appending the date and time and prefixing it with 
%% the desired directory
%% Log files are named 'log_dump-year_month_day-hour_minute_second.txt'
-spec prep_filename(string()) -> string().
prep_filename(Dir) ->
    File = string:concat(Dir, "log_dump-"),
    {Yr, Dy} = calendar:now_to_local_time(erlang:timestamp()),
    A = tuple_to_list(Yr),
    B = tuple_to_list(Dy),
    Year = lists:nth(1, A),
    Month = lists:nth(2, A),
    Day = lists:nth(3, A),
    Hour = lists:nth(1, B),
    Min= lists:nth(2, B),
    Sec= lists:nth(3, B),
    {ok, lists:concat([File, Year, "_", Month, "_", Day, "-",
		       Hour, "_", Min, "_", Sec, ".txt"])}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                          Log file handling methods                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Handles a log file, saves it to file as plaintext
-spec log_to_file(string(), disk_log:log(), start  | disk_log:continuation(),
		  file:io_device()) -> ok | {error, _}.
log_to_file(Node, Log, Continuation, File) ->
    case Continuation of
	start -> % First open
	    {Cont, Items} = rpc:call(Node, disk_log, chunk, [Log, start]),
	    Contents=io_lib:fwrite("~p", [Items]),
	    ok = rpc:call(Node, file, write, [File, Contents]),
	    log_to_file(Node, Log, Cont, File);
	eof -> % EOF
	    {ok, eof};
	{error, R}  ->
	    io:format("Error: ~p~n", [R]),
	    {error, R};
	_ -> % Grindin teh dataz
	    case rpc:call(Node, disk_log, bchunk, [Log, Continuation]) of 
		eof -> 
		    log_to_file(Node, Log, eof, File);
		{error, R} ->
		    io:format("R: ~p~n", [R]),
		    halt(1);
		{NextChunk, Items} ->
		    Contents=io_lib:fwrite("~p", [Items]),
		    rpc:call(Node, file, write, [File, Contents]),
		    log_to_file(Node, Log, NextChunk, File)
	    end
    end.

%% Intermediary function handling disk_log opening and closing
-spec process_log_file(string(), disk_log:log(), file:filename()) -> 
			 {ok, processed} | {error, term()}.
process_log_file(Node, Log, File) ->
    {ok, LogFile} = rpc:call(Node, disk_log, open, [[{name, Log}]]),
    {ok, eof} = log_to_file(Node, LogFile, start, File),
    io:format("-"),
    {ok, processed}. %Done, bye

%% Process whole list of logs using process_log_file
%% m2o - many-to-one, i.e. several log files -> one dump file
-spec process_m2o(atom(), lists:list(), file:filename()) -> ok | {error, _}.
process_m2o(Node, List, File) ->
    io:format("Processing logs from ~p to ~p~n", 
	      [Node, File]),
    {ok, IO} = rpc:block_call(Node, file, open, [File, [append]]),
    lists:foreach(fun(Log) -> process_log_file(Node, Log, IO) end, List),
    io:format(" ok~n"),
    {ok, processed}.

