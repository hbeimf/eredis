-module(eredis_sub_tests).

-include_lib("eunit/include/eunit.hrl").
-include("eredis.hrl").
-include("eredis_sub.hrl").

-import(eredis, [create_multibulk/1]).

c() ->
    Res = eredis:start_link(),
    ?assertMatch({ok, _}, Res),
    {ok, C} = Res,
    C.

s(Channels) ->
    Res = eredis_sub:start_link("127.0.0.1", 6379, "", Channels),
    ?assertMatch({ok, _}, Res),
    {ok, C} = Res,
    C.


%% pubsub_test() ->
%%     Pub = c(),
%%     Sub = s([<<"chan1">>, <<"chan2">>]),
%%     ok = eredis_sub:controlling_process(Sub),
%%     ?assertEqual({ok, <<"1">>}, eredis:q(Pub, ["PUBLISH", chan1, msg])),
%%     receive
%%         {message, _, _, _} = M ->
%%             ?assertEqual({message, <<"chan1">>, <<"msg">>, Sub}, M)
%%     after 10 ->
%%             throw(timeout)
%%     end,

%%     receive
%%         Msg ->
%%             throw({unexpected_message, Msg})
%%     after 5 ->
%%             ok
%%     end.

%% Push size so high, the queue will be used
pubsub2_test() ->
    Pub = c(),
    Sub = s([<<"chan">>]),
    ok = eredis_sub:controlling_process(Sub),
    lists:foreach(
      fun(_) ->
              Msg = binary:copy(<<"0">>, 2048),
              ?assertEqual({ok, <<"1">>}, eredis:q(Pub, ["PUBLISH", chan, Msg]))
      end, lists:seq(1, 500)),
    %%Msgs = recv_all(Sub),
    %%?assertEqual(5, length(Msgs)).
    ok.


recv_all(Sub) ->
    recv_all(Sub, []).

recv_all(Sub, Acc) ->
    receive
        {message, _, _, _} = InMsg ->
            eredis_sub:ack_message(Sub),
            recv_all(Sub, [InMsg | Acc])
    after 5 ->
              lists:reverse(Acc)
    end.


%% pubsub_manage_subscribers_test() ->
%%     Pub = c(),
%%     Sub = s([<<"chan">>]),
%%     unlink(Sub),

%%     error_logger:info_msg("~p~n", [get_state(Sub)]),

%%     ?assertMatch(#state{controlling_process=undefined}, get_state(Sub)),
%%     S1 = subscriber(Sub),
%%     ok = eredis:controlling_process(Sub, S1),
%%     #state{controlling_process={_, S1}} = get_state(Sub),
%%     S2 = subscriber(Sub),
%%     ok = eredis:controlling_process(Sub, S2),
%%     #state{controlling_process={_, S2}} = get_state(Sub),
%%     eredis:q(Pub, ["PUBLISH", chan, msg1]),
%%     S1 ! stop,
%%     ok = wait_for_stop(S1),
%%     eredis:q(Pub, ["PUBLISH", chan, msg2]),
%%     M2 = wait_for_msg(S2),
%%     ?assertEqual(M2, {message, <<"chan">>, <<"msg1">>, Sub}),
%%     M3 = wait_for_msg(S2),
%%     ?assertEqual(M3, {message, <<"chan">>, <<"msg2">>, Sub}),
%%     S2 ! stop,
%%     ok = wait_for_stop(S2),
%%     Ref = erlang:monitor(process, Sub),
%%     receive {'DOWN', Ref, process, Sub, _} -> ok end.


%% pubsub_connect_disconnect_messages_test() ->
%%     Pub = c(),
%%     Sub = s([<<"chan">>]),
%%     S = subscriber(Sub),
%%     ok = eredis:controlling_process(Sub, S),
%%     eredis:q(Pub, ["PUBLISH", chan, msg]),
%%     wait_for_msg(S),
%%     #state{socket=Sock} = get_state(Sub),
%%     gen_tcp:close(Sock),
%%     Sub ! {tcp_closed, Sock},
%%     M1 = wait_for_msg(S),
%%     ?assertEqual({eredis_disconnected, Sub}, M1),
%%     M2 = wait_for_msg(S),
%%     ?assertEqual({eredis_connected, Sub}, M2).


subscriber(Client) ->
    Test = self(),
    Pid = spawn(fun () -> subscriber(Client, Test) end),
    spawn(fun() ->
                  Ref = erlang:monitor(process, Pid),
                  receive
                      {'DOWN', Ref, _, _, _} ->
                          Test ! {stopped, Pid}
                  end
          end),
    Pid.

subscriber(Client, Test) ->
    receive
        stop ->
            ok;
        Msg ->
            Test ! {got_message, self(), Msg},
            eredis:ack_message(Client),
            subscriber(Client, Test)
    end.

wait_for_msg(Subscriber) ->
    receive
        {got_message, Subscriber, Msg} ->
            Msg
    end.

wait_for_stop(Subscriber) ->
    receive
        {stopped, Subscriber} ->
            ok
    end.

get_state(Pid)
  when is_pid(Pid) ->
    {status, _, _, [_, _, _, _, State]} = sys:get_status(Pid),
    get_state(State);
get_state([{data, [{"State", State}]} | _]) ->
    State;
get_state([_|Rest]) ->
    get_state(Rest).
