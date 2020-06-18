%%%-------------------------------------------------------------------
%% @doc erathia node
%% keeps role of node
%% votes during election
%% sends healthchecks
%% @end
%%%-------------------------------------------------------------------

-module(erathia_node).

-behaviour(gen_statem).

%% API
-export([start_link/0,
         start_link/2,
         role/1,
         message/2]).

%% gen_statem callbacks
-export([init/1,
         callback_mode/0,
         code_change/4,
         terminate/3]).

%% events

-export([folower/3,
         candidate/3,
         leader/3]).

%% types and records
-record(node_data, {node_list = [] :: list(atom()),
                    votes = [] :: list(atom())}).

-type role() :: folower | candidate | leader.
-type node_data() :: #node_data{}.
-type vote() :: {vote, From :: atom()}.
-type candidate() :: {candidate, From :: atom()}.


%% API

start_link() ->
    gen_statem:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec start_link(atom(), [atom()]) -> {ok, pid()}.
start_link(Name, NodeList) ->
    gen_statem:start_link({local, Name}, ?MODULE, [NodeList], []).

-spec role(atom()) -> role().
role(Name) ->
    {Role, _} = sys:get_state(Name),
    Role.

-spec message(atom(), term()) -> ok.
message(Name, Msg) ->
    gen_statem:cast(Name, Msg).

%% state callbacks

%% TODO:
%% Folower:
%% Folower wait election_timeout and become candidate
%% if Folower got vote_request -> it votes and restart election_timeout
%% if Folower got healthcheck or data_message -> it response and restart election_timeout
%%
%% Candidate:
%% When Candidate enter this state -> it votes for itself and send vote_request
%% if Candidate got vote it checks amount of votes
%%      in case of majority voted -> node become leader
%%      otherwise node wait
%% if Candidate got vote_request -> it votes and become Folower
%% if Candidate got healthcheck or data_message -> it response and become Folower
%%
%% Leader:
%% Leader sends healthcheck each healthcheck_interval
%% if Leader got healthcheck or data_message -> it response and become Folower
%% if Leader got vote_request -> it does nothing

-spec folower(gen_statem:event_type(), term(), node_data()) -> {keep_state, node_data()}.
folower(cast = EventType, {candidate, From} = EventContent, Data) ->
    io:format("Folower ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    vote(From, node_name()),
    {next_state, candidate, Data, random_timeout()};
folower(cast = EventType, EventContent, Data) ->
    io:format("Folower ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    {next_state, candidate, Data, random_timeout()};
folower(EventType, EventContent, Data) ->
    io:format("Folower ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    {next_state, candidate, Data, random_timeout()}.

-spec candidate(gen_statem:event_type(), term(), node_data()) -> {keep_state, node_data()}.
candidate(cast = EventType, {candidate, From} = EventContent, Data) ->
    io:format("Candidate ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    vote(From, node_name()),
    {next_state, folower, Data#node_data{votes = []}};
candidate(cast = EventType, {vote, From} = EventContent, #node_data{node_list = NodeList, votes = Votes} = Data) ->
    io:format("Candidate ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    case lists:member(From, Data#node_data.node_list) of
        true ->
            case majority(NodeList, [From | Votes]) of
                true ->
                    io:format("Candidate ~p: majority voted for me. Became leader ~n", [node_name()]),
                    {next_state, leader, Data#node_data{votes = []}};
                false ->
                {keep_state, Data#node_data{votes = [From | Votes]}}
            end;
        false ->
            {keep_state, Data#node_data{}}
    end;
candidate(EventType, EventContent, Data) ->
    candidate(node_name(), Data#node_data.node_list),
    io:format("Candidate ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    {keep_state, Data}.

-spec leader(gen_statem:event_type(), term(), node_data()) -> {keep_state, node_data()}.
leader(enter = EventType, candidate, Data) ->
    io:format("Leader ~p: majority voted for me.~n", [node_name()]),
    {keep_state, Data};
leader(cast = EventType, EventContent, Data) ->
    io:format("Leader ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    {keep_state, Data};
    % {next_state, folower, Data, random_timeout()};
leader(EventType, EventContent, Data) ->
    io:format("Leader ~p: ~p: ~p~n", [node_name(), EventType, EventContent]),
    {keep_state, Data}.

%% Mandatory callback functions

callback_mode() -> state_functions.

-spec init(term()) -> {ok, role(), node_data()}.
init([NodeList]) ->
    State = folower,
    {ok,State,#node_data{node_list = NodeList}, [{state_timeout, random_timeout(), candidate}]}.

code_change(_Vsn, State, Data, _Extra) ->
    {ok,State,Data}.

terminate(_Reason, _State, _Data) ->
    ok.

%% helpers

-spec vote(atom(), atom()) -> ok.
vote(Name, From) ->
    message(Name, {vote, From}).

-spec candidate(atom(), atom()) -> ok.
candidate(From, NodeList) ->
    [message(Node, {candidate, From}) || Node <- NodeList],
    ok.

-spec healthcheck(atom(), [atom()]) -> ok.
healthcheck(From, NodeList) ->
    [message(Node, {healthcheck, From}) || Node <- NodeList],
    ok.

-spec majority([atom()], [atom()]) -> boolean().
majority(NodeList, Votes) ->
    length(Votes) > length(NodeList) / 2.

%% TODO: 150 - 300 ms
-spec election_timeout() -> non_neg_integer().
election_timeout() ->
    floor((1.0 - rand:uniform()) * 100 ) * 100.

-spec random_timeout() -> non_neg_integer().
random_timeout() ->
    floor((1.0 - rand:uniform()) * 100 ) * 100.

-spec node_name() -> atom().
node_name() ->
    {registered_name, Name} = process_info(self(), registered_name),
    Name.
