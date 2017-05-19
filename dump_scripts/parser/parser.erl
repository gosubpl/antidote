#! /usr/bin/env escript 

% Parser veryfing sets of invariants.
% Log dump from <log_dump.erl> is parsed, records are reconstructed into 
% the abstract log_record defined in <parser.hrl>.
% Invariants verification logic is then executed on the beforementioned 
% records. 
-module(parser).
-include("parser.hrl").
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% File stuff %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pretty self explanatory ennit
open_file(Fname) ->
    {ok, Dev} = file:open(Fname, read),
    Dev.

% Pretty self explanatory ennit
close_file(Fname) ->		
    ok = file:close(Fname).

% Checks if file is present 
check_file(Fname) ->
    case filelib:is_file(Fname) of 
	true ->
	    ok;
	false ->
	    io:format("File ~p not found~n", [Fname]),
	    halt(1)
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Strings and regexs %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Counts the # of occurrences of Char in String
count_chr(String, Chr) ->
    F = fun(X, N) when X =:= Chr -> N + 1;
           (_, N)                -> N
        end,
    lists:foldl(F, 0, String).

count_brackets(Line) ->
    Left = count_chr(Line, ${),
    Right = count_chr(Line, $}),
    {Left, Right}.

% Parses the recovered record and returns the 
% {tx_id,1493300303013265,<9656.3473.0>} tuple
% Fucking doesn't work for whatever reason.
% Some lines match properly, others go to hell.
get_tx_id(Record) ->
    Regexp = ".*(tx_id.*\}).*",
    case re:run(Record, Regexp, [{capture, first, list}]) of
	{match, Match} ->
	    [{St, End} | R] = Match,
	    io:format("Match: ~p~n", [Match]),
	    Ret = string:sub_string(Record, St+1, St+End),
	    io:format("Ret: ~p~n", [Ret]),
	    Ret;
	nomatch ->
	    io:format("TX no match~n")
    end.

% Works ok
get_node_name(Record) ->
    Regexp = ".*\'(.*@.*)\'.*",
    case re:run(Record, Regexp, [{capture, [1]}]) of
	{match, Match} ->
	    [{St, End} | R] = Match,
	    Ret = string:sub_string(Record, St+1, St+End),
	    Ret;
	nomatch ->
	    io:format("TX no match~n")
    end.

% Used while regexping
strip_whitespace(S) ->
    re:replace(S, "\\s+", "", [global,{return,list}]).

%% Todo: Complete this rewrite of do_stuff
%% Abstract record type defined as follows: 
%% #log_record{
%%             txid{
%%                  serv_id{
%%                          atom, pid}
%%                  timestamp}
%%             op_type { update | read | prepare | commit }
%%             }
%% TODO: Recover following fields: 
%% - TX ID:
%%   - Server ID: 
%%     - server name : antidote@127.0.0.1
%%     - pid : <9656,3477.0>
%%   - timestamp : 1493300303013624
%% - op_type: 
%%   - update | read | prepare | commit << atoms, once grabbed, 
%%     don't forget to cast to atom
get_records(File, TLeft, TRight, Acc, Records) ->
    case file:read_line(File) of
	{ok, Line} ->
	    {Left, Right} = count_brackets(Line),
	    NextLeft  = Left + TLeft,
	    NextRight = Right + TRight,
	    NextAcc   = string:concat(Acc, Line),
	    %% Test and record recovery here
	    if
		% Continue parsing, line without brackets
		% There's a lot, especially in prepare records
		Left == 0, Right == 0, TLeft /= TRight ->
		    get_records(File, NextLeft, NextRight, NextAcc, Records);
		% Complete record, store, recursive
		NextLeft == NextRight ->
		    %% Record complete so concat to list 
		    %% and recurse with empty Acc and reset bracket counts
		    get_records(File, 0, 0, "", [NextAcc|Records]);
		true ->
		    %io:format("Case3~n"),
		    %% Record uncomplete, continue parsing
		    get_records(File, NextLeft, NextRight, NextAcc, Records)
	    end;
	eof ->
	    Records;
	{error, R} ->
	    % Should never get here, file error or something
	    io:format("That went to shit - ~p~n", [R]),
	    halt(1)
    end.

make_structures([], Acc) -> 
    Acc;
make_structures([R | Records], Acc) ->
    Current = strip_whitespace(R),
    TX = get_tx_id(Current),
    Node = get_node_name(Current),
    io:format("TX ~p~n", [TX]),
    io:format("Node ~p~n", [Node]),
    %io:format("~nParsing ~p, Acc: ~p ~n", [Current, length(Acc)]),
    %% Recursive call
    make_structures(Records, []).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main
main(Logfile) ->
    [ F | _ ] = Logfile,
    check_file(F),
    Fio = open_file(F),
    io:format("Parsing log file, please wait... "),
    Records=get_records(Fio, 0, 0, "", []),
    io:format("done. Recovered ~p records~n", [length(Records)]),
    Structures = make_structures(Records, []),
    %io:format("Recovered shit: ~s~n", [Records]),
    io:format("Closing file~n"),
    close_file(Fio),
    ok.
