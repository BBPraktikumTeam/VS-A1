-module(server).
-compile(export_all).
-import(werkzeug).
-record(state, {clients,message_id,delivery_queue,holdback_queue,clientlifetime,dlqlimit,difftime}).


% Client Timeouts prüfen


loop(S= #state{message_id = Id}) ->
% updating clients bevore every loop!
		State = test_client_timeout(S), 			
	    receive
		{getmessages,Pid} ->
        	  io:format("getmessage~n"),
		  NewState=getmessages(Pid,State),
		  loop(test_client_timeout(NewState));
		{dropmessage, {Message,Number}} ->
		  NewState=dropmessage({Message,Number},State),
		  io:format("dropmessage~n"),
          	  loop(update_queues(NewState));
		{getmsgid,Pid} -> 
		  io:format("Send Id: ~p to:~p ~n",[Id,Pid]), 
		  Pid ! Id, 
		  loop(S#state{message_id=Id+1});
		Any ->
		  io:format("Sorry, I don't understand: ~s~n",[Any])
	    end.

update_queues(S=#state{delivery_queue = DQ, holdback_queue = HQ,dlqlimit=DQLimit})->
	{_,LastDeliveryID} = lists:last(DQ),
	{_,FirstHoldbackID} = lists:first(HQ),
	if LastDeliveryID + 1 == FirstHoldbackID ->
	      FirstBlob=lists:reverse(lists:foldl(fun getBlob/2,[],HQ));
	   true -> FirstBlob=[]
	end,
	TempDQ=DQ++FirstBlob,
	NewDQ=lists:sublist(TempDQ,length(TempDQ)-DQLimit+1,length(TempDQ)),
	NewHQ=lists:sublist(HQ,length(FirstBlob)+1,length(HQ)),
	check_for_gaps(S#state{delivery_queue=NewDQ,holdback_queue=NewHQ}).

check_for_gaps(S=#state{delivery_queue = DQ, holdback_queue = HQ,dlqlimit=DQLimit})->
	LengthHQ=lists:length(HQ),
	HalfOfDQLimit=DQLimit/2,
	if 	LengthHQ > HalfOfDQLimit ->
			{_,LastDeliveryID} = lists:last(DQ),
			{_,FirstHoldbackID} = lists:first(HQ),
			if 	LastDeliveryID + 1 < FirstHoldbackID ->
					ErrorMessage=lists:concat(["***Fehlertextzeile fuer die Nachrichtennummern ",LastDeliveryID + 1,FirstHoldbackID -1, " um ", werkzeug:timeMilliSecond(),"|~n"]),	
					S#state{delivery_queue=DQ++[{ErrorMessage,FirstHoldbackID-1}]};
				true -> S
			end;
		true -> S
	end.
  
   
test_client_timeout(S = #state{clients = Clients, clientlifetime = Clientlifetime}) ->
	NewClients = orddict:filter((fun(_,{_,T1}) -> (T1 - timestamp()) < Clientlifetime end),Clients),
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
   werkzeug:logging("NServer.log", X),
   S#state{clients=orddict:store(Pid,{NewMsgId,timestamp()}, Clients)}.


appendTimeStamp(Message,Type) ->
  Message++" "++Type++": "++werkzeug:timeMilliSecond().


getLastMsgId(Pid,#state{clients = Clients}) ->
    %prüfen ob Client bereits bekannt:
  case orddict:find(Pid,Clients) of
      error ->
        orddict:append(Pid,{0,timestamp()}, Clients),
        0;
      {ok,{MsgId,_}} -> MsgId
   end.

dropmessage({Message,Number},S=#state{holdback_queue=HQ}) ->
  % hier könnte ein Fehler geschmissen werden, wenn schon eine Nachricht mit der ID vorhanden ist, momentan wird sie überschrieben
  % NewMessage=Message++"Empfangszeit: "++werkzeug:timeMilliSecond(),
  NewMessage = lists:concat([Message, " Empfangszeit: ", werkzeug:timeMilliSecond(), " "]),
  %% Sorted Insert in the List
  NewHQ=lists:takewhile(fun({_,X})-> X< Number end,HQ)++[{NewMessage,Number}]++lists:dropwhile(fun({_,X})-> X<Number end,HQ),
  werkzeug:logging("NServer.log",NewMessage),
  loop(S#state{holdback_queue = NewHQ}).
        

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
