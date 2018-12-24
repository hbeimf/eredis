-module(eredis_test).

-compile(export_all).

-include("log.hrl").

start() ->

	?LOG("start"),

	{ok, C} = eredis:start_link(),
	SetReply = eredis:q(C, ["SET", "foo", "bar"]),
	GetReply = eredis:q(C, ["GET", "foo"]),

	?LOG({reply, SetReply, GetReply}),
	ok.

