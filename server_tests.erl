-module(server_tests).
-include_lib("eunit/include/eunit.hrl").
-rr(server).

normalize_test_() ->
    [?_assertEqual([1,2,3],server:normalize_list([1,2,3],4)),
     ?_assertEqual([2,3,4],server:normalize_list([1,2,3,4],3)),
     ?_assertEqual([1,2,3,4],server:normalize_list([1,2,3,4],4)),
      ?_assertEqual([],server:normalize_list([],3))].
