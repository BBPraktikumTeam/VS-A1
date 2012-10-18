-module(server).
-compile(export_all).
-import(werkzeug).
-include("server.hrl").


% Client Timeouts pr�fen


loop(S= #state{message_id = Id}) ->		
	    receive
		{getmessages,Pid} ->
		  State = test_client_timeout(S),
		  NewState=getmessages(Pid,State);
		{dropmessage, {Message,Number}} ->
		  TempState=dropmessage({Message,Number},S),
		  NewState=check_for_gaps(update_queues(TempState));
		{getmsgid,Pid} ->
		  Pid ! Id, 
		  NewState=S#state{message_id=Id+1};
		_ ->
		  werkzeug:logging("NServer.log","Sorry, I don't understand~n"),
		  NewState=S
	    end,
	    loop(NewState).
update_queues(S=#state{holdback_queue =HQ}) when HQ==[]-> S;
update_queues(S=#state{delivery_queue = DQ, holdback_queue = HQ,dlqlimit=DQLimit})->
	if DQ==[] -> [{_,TempLastDeliveryID}|_] = HQ,LastDeliveryID=TempLastDeliveryID-1;
	   true ->{_,LastDeliveryID} = lists:last(DQ)
	end,
	[{_,FirstHoldbackID}|_] = HQ,
	if  FirstHoldbackID =< LastDeliveryID -> 
		FirstBlob=[],
		[_|NewHQ]=HQ;
	    LastDeliveryID + 1 == FirstHoldbackID ->
	      FirstBlob=lists:reverse(lists:foldl(fun getBlob/2,[],HQ)),
	      NewHQ=HQ;
	   true -> 
	      FirstBlob=[],
              NewHQ=HQ
	end,
	TempDQ=DQ++FirstBlob,
	NewDQ=normalize_list(TempDQ,DQLimit),
	NewHQ2=lists:sublist(NewHQ,length(FirstBlob)+1,length(NewHQ)),
	S#state{delivery_queue=NewDQ,holdback_queue=NewHQ2}.

normalize_list(List,Limit) when length(List) =< Limit -> List;
normalize_list(List,Limit) when length(List) > Limit -> lists:sublist(List,length(List)-Limit+1,length(List)).


check_for_gaps(S=#state{holdback_queue = HQ}) when HQ==[] -> S;
check_for_gaps(S=#state{delivery_queue = DQ}) when DQ==[] -> S;
check_for_gaps(S=#state{delivery_queue = DQ, holdback_queue = HQ,dlqlimit=DQLimit})->
	CriteriaMatched=is_splitting_criteria(HQ,DQLimit),
         if CriteriaMatched ->
			{_,LastDeliveryID} = lists:last(DQ),
			[{_,FirstHoldbackID}|_] = HQ,
			if 	LastDeliveryID + 1 < FirstHoldbackID ->
					ErrorMessage=lists:concat(["***Fehlertextzeile fuer die Nachrichtennummern ",LastDeliveryID + 1," bis ",FirstHoldbackID -1, " um ", werkzeug:timeMilliSecond(),"|~n"]),	
					S#state{delivery_queue=DQ++[{ErrorMessage,FirstHoldbackID-1}]};
				true -> S
			end;
		true -> S
	end.

is_splitting_criteria(List,Limit)->
    length(List)> (Limit/2).
   
test_client_timeout(S = #state{clients = Clients, clientlifetime = Clientlifetime}) ->
	NewClients = orddict:filter(fun(_,{_,Timestamp}) -> (timestamp() - Timestamp) < Clientlifetime end,Clients),
	S#state{clients = NewClients}.
 

getmessages(Pid,S=#state{delivery_queue=DQ, clients = Clients}) -> 
  MsgId=getLastMsgId(Pid,S),
  case lists:dropwhile(fun({_,X})-> X =< MsgId end,DQ) of
    [] ->
      Message="Keine neuen Nachrichten vorhanden;",
      Getall=true,
      NewMsgId=MsgId;
    [{Message,NewMsgId}] -> 
      Getall = true;
    [{Message,NewMsgId}|_] ->
      Getall = false
   end,
   Pid ! {X = appendTimeStamp(Message,"Sendezeit"),Getall},
   werkzeug:logging("NServer.log", lists:concat([X,"-getmessages",io_lib:nl()])),
   S#state{clients=orddict:store(Pid,{NewMsgId,timestamp()}, Clients)}.


appendTimeStamp(Message,Type) ->
  lists:concat([Message," ",Type,": ",werkzeug:timeMilliSecond(),"|"]).


getLastMsgId(Pid,#state{clients = Clients}) ->
    %pr�fen ob Client bereits bekannt:
  case orddict:find(Pid,Clients) of
      error ->
        orddict:store(Pid,{0,timestamp()}, Clients),
        0;
      {ok,{MsgId,_}} -> MsgId
   end.


dropmessage({Message,Number},S=#state{holdback_queue=HQ}) when HQ==[] -> 
    NewMessage=appendTimeStamp(Message, "Empfangszeit"),
    werkzeug:logging("NServer.log",lists:concat([NewMessage,"-dropmessage",io_lib:nl()])),
    S#state{holdback_queue=[{NewMessage,Number}]};
dropmessage({Message,Number},S=#state{holdback_queue=HQ}) when HQ=/=[] ->
  % hier k�nnte ein Fehler geschmissen werden, wenn schon eine Nachricht mit der ID vorhanden ist, momentan wird sie �berschrieben
  % NewMessage=Message++"Empfangszeit: "++werkzeug:timeMilliSecond(),
  NewMessage = lists:concat([Message, " Empfangszeit: ", werkzeug:timeMilliSecond(), " "]),
  %% Sorted Insert in the List
  NewHQ=lists:takewhile(fun({_,X})-> X< Number end,HQ)++[{NewMessage,Number}]++lists:dropwhile(fun({_,X})-> X<Number end,HQ),
  werkzeug:logging("NServer.log",lists:concat([NewMessage,"-dropmessage",io_lib:nl()])),
  S#state{holdback_queue = NewHQ}.
        

getBlob({Message,Id},[]) -> [{Message,Id}];
getBlob({Message,Id},[{LastMessage,LastId}|List]) when Id -LastId == 1 -> [{Message,Id}|[{LastMessage,LastId}|List]];
getBlob(_,Accu) -> Accu.


timestamp() -> 
  {Mega, Secs, _} = now(),
  Mega*1000000 + Secs.


init() -> 
	{ok, ConfigListe} = file:consult("server.cfg"),
      	{ok, Lifetime} = werkzeug:get_config_value(lifetime, ConfigListe),
	ServerPid=self(),
	spawn(fun()->timer:kill_after(Lifetime*1000,ServerPid) end),
      	{ok, Clientlifetime} = werkzeug:get_config_value(clientlifetime, ConfigListe),
      	{ok, Servername} = werkzeug:get_config_value(servername, ConfigListe),
	register(Servername,self()),
	{ok, Dlqlimit} = werkzeug:get_config_value(dlqlimit, ConfigListe),
	{ok, Difftime} = werkzeug:get_config_value(difftime, ConfigListe),
	loop(#state{clients=orddict:new(),delivery_queue=[],message_id=1,holdback_queue=[],clientlifetime=Clientlifetime,dlqlimit=Dlqlimit,difftime=Difftime}).


start() -> spawn(fun init/0).
