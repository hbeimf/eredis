-module(eredis_test).

-export([start/0]).


-include("log.hrl").

start() ->

	?LOG("start"),
	ok.