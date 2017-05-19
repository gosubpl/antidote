%% Building blocks for tx_id record
-type timestamp() :: non_neg_integer().
-type serv_id() :: { atom() | pid() }.


%% Needed for prepare->commit invariant
-type op_type() :: { update | read | prepare | commit }.

%% Needed for unique tx ids invariant
-record(tx_id_struct, {
	  server :: serv_id(), 
	  time :: timestamp()}).

-type tx_id() :: #tx_id_struct{}.

%% log record abstract structure
%% txid for monotonically increasing invariant 
%% op type for prepare->commit invariant
-record(log_record, {
		    txid :: tx_id(),
		    type :: op_type()}).


