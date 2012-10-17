-module(server_tests).
-include_lib("eunit/include/eunit.hrl").
-include("server.hrl").
-import_record_info({server,state}).

normalize_test_() ->
    [?_assertEqual([1,2,3],server:normalize_list([1,2,3],4)),
     ?_assertEqual([2,3,4],server:normalize_list([1,2,3,4],3)),
     ?_assertEqual([1,2,3,4],server:normalize_list([1,2,3,4],4)),
      ?_assertEqual([],server:normalize_list([],3))].
check_for_gaps_test()->
    HQ1=[{hallo,1},{hallo,2}],
    DQ1=[],
    S1=#state{holdback_queue=HQ1,delivery_queue=DQ1},
    [?_assertEqual(S1,server:check_for_gaps(S1))].
