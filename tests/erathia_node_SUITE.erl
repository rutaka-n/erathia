-module(erathia_node_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile(export_all).

all() ->
    [election].

election(_Config) ->
    Nodes = [n1, n2, n3],
    _Pids = [erathia_node:start_link(Node, Nodes -- [Node]) || Node <- Nodes],

    ct:sleep(1000),
    ?debugFmt("~n~p~n", [[erathia_node:role(Node) || Node <- Nodes]]),
    ct:sleep(3000),
    ?debugFmt("~n~p~n", [[erathia_node:role(Node) || Node <- Nodes]]),
    ok.
