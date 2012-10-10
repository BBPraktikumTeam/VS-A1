-module(server).
-compile(export_all).
-record(state, {clients,message_id,messages,delivery_queue,holdback_queue}).

%%Client -> erhaltene Nachricht
%Client -> Letze Meldung
%Zeilennummer -> Nachricht
%aktuelle Zeilennummer
%Timeout
%kommentar


loop(S= #state{message_id=Id,delivery_queue=DQ,messages = Messages}) ->
	    receive
		{getmessages,Pid} ->
		  {{_,Msg},NQ}=queue:out(DQ),
		  Pid ! Msg,
		  loop(S#state{delivery_queue=NQ});
		{dropmessage, {Message,Number}} ->
		  New_messages = append(Number,Message,Messages),
		  NewState=dropmessage(S,{Message,Number}),
		  io:format("~p :  ~s~n",[Number,Message]),
		  loop(NewState});
		{getmsgid,Pid} -> 
		  io:format("Send Id ~p~n",[Id]), 
		  Pid ! {Id}, 
		  loop(S#state{message_id=Id+1})
	    end.

dropmessage(S = #state{messages=Messages,delivery_queue = DQ, holdback_queue = HQ}, {Message,Number}) -> 
	NewState = S#state
		    {holdback_queue=queue:in(Number,HQ),
		    messages=append(Number,Message,Messages),
	organize_queues(NewState).
      
    

update_queues(S = #state{messages=Messages,delivery_queue = DQ, holdback_queue = HQ}, {Message,Number}}) -> 
    AllowedMessage=lists:max(DQ)+1,
    case lists:member(AllowedMessage, HQ) of
      true -> 
	%% Sorted List besser, damit out funzt
	{{value,Msg},NewHQ} = queue:out(Number),
	NewDQ = queue:in(Msg, DQ),
	Length = queue:len(DQ),  %% Length of the List
	if Length > 10 ->   %% MaxLength of DQ    
	  {{value,Msg}, Queue} = queue:out(NewDQ),
	  S#state
	    {holdback_queue=NewHQ,
	     delivery_queue=Queue,
	   );
	true ->
	  S#state
	    {holdback_queue=NewHQ,
	     delivery_queue=NewDQ,
	   )
      false -> 
    end.



init() -> loop(#state{clients=orddict:new(),messages=orddict:new(),delivery_queue=queue:new(),message_id=1}).


start() -> spawn(fun init/0).