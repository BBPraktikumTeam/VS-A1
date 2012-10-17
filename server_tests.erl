-module(server_tests).
-include_lib("eunit/include/eunit.hrl").
-include("server.hrl").
-import_record_info({server,state}).

normalize_test_() ->
    [?_assertEqual([1,2,3],server:normalize_list([1,2,3],4)),
     ?_assertEqual([2,3,4],server:normalize_list([1,2,3,4],3)),
     ?_assertEqual([1,2,3,4],server:normalize_list([1,2,3,4],4)),
      ?_assertEqual([],server:normalize_list([],3))].
check_for_gaps_test_()->
    HQ1=[{hallo,2},{hallo,3}],
    DQ1=[{hallo,1}],
    S1=#state{holdback_queue=HQ1,delivery_queue=DQ1,dlqlimit=2},
    S2=#state{holdback_queue=[],delivery_queue=[],dlqlimit=2},
    S3=#state{holdback_queue=[{hallo,5},{hallo,6},{hallo,7}],delivery_queue=HQ1,dlqlimit=2},
    S4=#state{holdback_queue=HQ1,delivery_queue=[],dlqlimit=2},
    [test_queue_equality(S1,server:check_for_gaps(S1)),
     test_queue_equality(S2,server:check_for_gaps(S2)),
     test_queue_length(3,3,server:check_for_gaps(S3)),
     test_queue_equality(S4,server:check_for_gaps(S4))].

update_queues_test_()->
    [empty_hq_full_dq(),
     empty_dq_hq_with_blob(),
     no_conseq_blob(),
     with_blob()].

empty_hq_full_dq()->
    HQ=[],
    DQ=[{hallo,1}],
    S=#state{holdback_queue=HQ,delivery_queue=DQ},
    test_queue_equality(S,server:update_queues(S)).

empty_dq_hq_with_blob()->
    HQ=[{hallo,2},{hallo,3},{hallo,5}],
    DQ=[],
    NewHQ1=[{hallo,5}],
    NewDQ1=[{hallo,3}],
    NewHQ2=NewHQ1,
    NewDQ2=[{hallo,2},{hallo,3}],
    DQLimit1=1,
    DQLimit2=3,
    S1=#state{delivery_queue=DQ,holdback_queue=HQ,dlqlimit=DQLimit1},
    S2=S1#state{dlqlimit=DQLimit2},
    NewS1=S1#state{holdback_queue=NewHQ1,delivery_queue=NewDQ1},
    NewS2=S2#state{holdback_queue=NewHQ2,delivery_queue=NewDQ2},
    [?_assertEqual(NewS1,server:update_queues(S1)),?_assertEqual(NewS2,server:update_queues(S2))].

no_conseq_blob()->
    S=#state{delivery_queue=[{hallo,1}],holdback_queue=[{hallo,3}],dlqlimit=5},
    ?_assertEqual(S,server:update_queues(S)).

with_blob()->
    HQ=[{hallo,2},{hallo,3},{hallo,5}],
    NewHQ=[{hallo,5}],
    DQ=[{hallo1,1}],
    NewDQ=[{hallo1,1},{hallo,2},{hallo,3}],
    DQLimit=3,
    S=#state{delivery_queue=DQ,holdback_queue=HQ,dlqlimit=DQLimit},
    NewS=S#state{delivery_queue=NewDQ,holdback_queue=NewHQ},
    ?_assertEqual(NewS,server:update_queues(S)).
    

is_splitting_criteria_test_()->
    [?_assert(server:is_splitting_criteria([1,2,3],2)),
     ?_assert(not(server:is_splitting_criteria([1],3)))].

test_queue_equality(#state{holdback_queue=HQ1,delivery_queue=DQ1},#state{holdback_queue=HQ2,delivery_queue=DQ2})->
    [?_assertEqual(HQ1,HQ2),?_assertEqual(DQ1,DQ2)].

test_queue_length(DQLength,HQLength,#state{holdback_queue=HQ,delivery_queue=DQ})->
    [?_assertEqual(DQLength,length(DQ)),?_assertEqual(HQLength,length(HQ))].
