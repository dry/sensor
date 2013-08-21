-module(sensor_scanner).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {left_fan_speed,
                right_fan_speed,
                temp}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    {ok, #state{}, 0}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({temp, Temp}, State) ->
    NewState = State#state{temp = Temp},
    {noreply, NewState};

handle_cast({left_fan_speed, Speed}, State) ->
    NewState = State#state{left_fan_speed = Speed},
    {noreply, NewState};

handle_cast({right_fan_speed, Speed}, State) ->
    NewState = State#state{right_fan_speed = Speed},
    check(NewState),
    {noreply, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(timeout, State) ->
    timer:send_interval(5000, ?MODULE, scan),
    {noreply, State};

handle_info(scan, State) ->
    scan(),
    {noreply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
scan() ->
    parse(os:cmd("sensors")).

parse(Sensors) ->
    [parse_line(list_to_binary(Line))
     || Line <- string:tokens(Sensors, "\n")].

parse_line(<<"temp1:        +", Temp:4/binary, _R/binary>>) ->
    gen_server:cast(?SERVER, {temp, Temp});
parse_line(<<"Left side  : ", LSpeed:4/binary, _R/binary>>) ->
    gen_server:cast(?SERVER, {left_fan_speed, LSpeed});
parse_line(<<"Right side : ", RSpeed:4/binary, _R/binary>>) ->
    gen_server:cast(?SERVER, {right_fan_speed, RSpeed});
parse_line(_) ->
    ok.

check(State) ->
    Temp = binary_to_float(State#state.temp),
    if
        Temp > 75.0 ->
            Vars = io_lib:format("Temp: ~p Left Fan: ~p Right Fan: ~p",
                                 [binary_to_list(State#state.temp),
                                  binary_to_list(State#state.left_fan_speed),
                                  binary_to_list(State#state.right_fan_speed)]),
            os:cmd("notify-send 'CPU Temperature Warning' '" ++ Vars ++ "'");
        true ->
            ok
    end.
