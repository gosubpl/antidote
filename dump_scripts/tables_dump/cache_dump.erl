#! /usr/bin/env escript 
%% -*- erlang -*-
%%! -smp enable -name log_dumper@127.0.0.1 -cookie antidote

-module(cache_dump).
-mode(compile).

-define(dbug, io:format("dbug ~p ~p...~n", [?FUNCTION_NAME, ?LINE])).
%% -----------------------------------------------------------------------------
%% Helper tool for dumping all the caches from a node to storage.
%% Usage: 
%% $ cache_dump.erl <Node>, <Directory>
%% ex: $ cache_dump.erl 'antidote@127.0.0.1', "./dump/"
%% Attention: The trailing slash in directory name is essential. 
%%            "./dump" will simply not work. The directory is created
%%            at node's root dir: "antidote/dump/"
%% -----------------------------------------------------------------------------

%% Node is of form antidote@127.0.0.1
%% Dir is of form /dump/
main([Node, Dir]) ->
    Node1 = list_to_atom(Node),
    antidote_connect(Node1),
    %% Ensure directories
    create_dir(Dir, Node1),
    %% Recover tabs from node
    AllTabs = retrieve_all(Node1),
    io:format("Retrieved ~w tables ", [length(AllTabs)]),
    %% Filter tabs
    {OpsTab, SnapTab} = filter_tabs(AllTabs, {[], []}),
    io:format("with ~p opstabs and ~p snaptabs~n", [length(OpsTab), length(SnapTab)]),
    %% Save to disk
    to_file(Dir, Node1, OpsTab),
    to_file(Dir, Node1, SnapTab),
    %% Disconnect
    net_kernel:stop().


%% Connects
-spec antidote_connect(atom()) -> ok | {error, node_offline}.
antidote_connect(Node) ->
    case net_kernel:start([Node, longnames]) of
        {ok, _} -> ok;
        {error, {already_started,_}} -> io:format("~p running, proceeding... ~n", [Node]), ok;
        {error, {{already_started, _},_}} -> io:format("~p running, proceeding... ~n", [Node]), ok;
	{error, R} -> io:format("Error connecting ~p~n", [R])
    end,
    erlang:set_cookie(Node, antidote),
    %% Redundant connection verification
    case net_adm:ping(Node) of
	pong -> %% We're good
	    io:format("Connected to ~p!~n", [Node]),
	    ok;
	_ -> %% Offline
	    io:format("Can't connect to node ~p! Aborting.~n", [Node]),
	    halt(1)
    end.

%% Ensures the dirs for dump are present
-spec create_dir(string(), atom()) -> ok | {error, dir_create}.
create_dir(DumpDir, Node) ->
    case rpc:call(Node, filelib, ensure_dir, [list_to_atom(DumpDir)]) of 
	ok ->
	    io:format("Dir created: ~s~n", [DumpDir]),
	    ok;
	{error, R} ->
	    io:format("Bad rpc: ~p~n", [R]),
	    halt(1)
    end.

%% Retrieves all the tables present at Node
-spec retrieve_all(atom()) -> list().
retrieve_all(Node) ->
    Tab = rpc:call(Node, ets, all, []),
    Tab.

%% Creates a tuple containing
%% operations cache and snapshot
%% cache tables names. Used on table dump.
-spec filter_tabs(list(), {list(), list()}) -> {list(), list()}.
filter_tabs([], {Ops, Snap}) ->
    {Ops, Snap};
filter_tabs([H|T], {Ops, Snap}) ->
    case is_atom(H) of
	true ->
	    case string:sub_string(atom_to_list(H), 1, 3) of
		"ops" ->
		    filter_tabs(T, {[H | Ops], Snap});
		"sna" ->
		    filter_tabs(T, {Ops, [H | Snap]});
		_ ->
		    %io:format("Skipping table ~p~n", [H]),
		    filter_tabs(T, {Ops, Snap})
	    end;
	_ ->
	    %io:format("Skipping table ~p~n", [H]),
	    filter_tabs(T, {Ops, Snap})
    end.

%% Iterate over table and execute tab2file on it.
%% Tables are saved as blobs, and can be opened with ets:file2tab/1,2
-spec to_file(string(), atom(), list()) -> ok | {error, {saving_failed, _}}.
to_file(Dir, Node, []) ->
    ok;
to_file(Dir, Node, [H | T]) ->
    TabName = rpc:call(Node, ets, info, [H, name]),
    TName = string:concat(Dir, atom_to_list(TabName)),
    Name = string:concat(TName, ".ets"),
    io:format("Saving  ~p~n", [Name]),
    case rpc:call(Node, ets, tab2file, [TabName, Name]) of 
	ok ->     
	    to_file(Node, T);
	{badrpc, R} -> 
	    {error, {saving_failed, R}},
	    halt(1)
    end.
