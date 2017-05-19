-module(invariants).

% -> Monotonically increasing TX IDs 
% -> Every prepare should have a corresponding commit 
% -> Unique TX ids
% Timestamps do not necessarely increase monotonically, concurrently commiting TXs may be in different order
% Same object key can appear twice in the same TX


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


-spec inv_tx_ids(
