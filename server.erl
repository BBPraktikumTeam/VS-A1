-module(server).
-compile(export_all).
-import(werkzeug).
-record(state, {clients,message_id,delivery_queue,holdback_queue}).

%%Client -> erhaltene Nachricht
%Client -> Letze Meldung
%Zeilennummer -> Nachricht
%aktuelle Zeilennummer
%Timeout


loop(S= #state{message_id=Id,delivery_queue=DQ}) ->
	    receive
		{getmessages,Pid} ->
		  NewState=getmessages(Pid,S),
		  loop(NewState);
		{dropmessage, {Message,Number}} ->
		  NewState=dropmessage({Message,Number},S),
		  loop(NewState);
		{getmsgid,Pid} -> 
		  io:format("Send Id ~p~n",[Id]), 
		  Pid ! {Id}, 
		  loop(S#state{message_id=Id+1})
	    end.

   

getmessages(Pid,S=#state{delivery_queue=DQ, clients = Clients}) -> 
  MsgId=getLastMsgId(Pid,S),
  case lists:dropwhile(fun({_,X})-> X<=MsgId end,DQ) of
    [] ->
      Message="Keine neuen Nachrichten vorhanden;",
      Getall=true,
      NewMsgId=MsgId;
    [{Message,NewMsgId}] -> 
      Getall = true;
    [{Message,NewMsgId}|_] ->
      Getall = false
   end,
   Pid ! {appendTimeStamp(Message,"Sendezeit"),Getall},
   S#state{clients=orddict:store(Pid,{NewMsgId,timestamp()})}.


appendTimeStamp(Message,Type) ->
  Message++" "++Type++": "++werkzeug:timeMilliSecond().


getLastMsgId(Pid,S=#state{clients = Clients}) ->
    %prüfen ob Client bereits bekannt:
  case orddict:find(Pid,Clients) of
      error ->
	orddict:append(Pid,{1,timestamp()}, Clients);
	1.
      {ok,{MsgId,_}} -> MsgId.

dropmessage({Message,Number},S=#state{holdback_queue=HQ}) ->
  % hier könnte ein Fehler geschmissen werden, wenn schon eine Nachricht mit der ID vorhanden ist, momentan wird sie überschrieben
  NewMessage=Message++"Empfangszeit: "++werkzeug:timeMilliSecond(),
  %% Sorted Insert in the List
  NewHQ=lists:takewhile(fun({_,X})-> X< Number end,HQ)++[{NewMessage,Number}]++lists:dropwhile(fun({_,X})-> X<Number end,HQ),
  werkzeug:logging("NServer.log",NewMessage),
  S#state{holdback_queue=NewHQ}.
  

%update_queues(S = #state{messages=Messages,delivery_queue = DQ, holdback_queue = HQ}, {Message,Number}}) -> 
%    AllowedMessage=lists:max(DQ)+1,
%    case lists:member(AllowedMessage, HQ) of
%      true -> 
%	%% Sorted List besser, damit out funzt
%	{{value,Msg},NewHQ} = queue:out(Number),
%	NewDQ = queue:in(Msg, DQ),
%	Length = queue:len(DQ),  %% Length of the List
%	if Length > 10 ->   %% MaxLength of DQ    
%	  {{value,Msg}, Queue} = queue:out(NewDQ),
%	  S#state
%	    {holdback_queue=NewHQ,
%	     delivery_queue=Queue,
%	   );
%	true ->
%	  S#state
%	    {holdback_queue=NewHQ,
%	     delivery_queue=NewDQ,
%	   )
%      false -> 
%    end.
timestamp() -> 
  {Mega, Secs, _} = now(),
  Timestamp = Mega*1000000 + Secs.


init() -> loop(#state{clients=orddict:new(),delivery_queue=[{"Nachricht1",1},{"Nachricht2",2}],message_id=1,holdback_queue=[]}).


start() -> spawn(fun init/0).