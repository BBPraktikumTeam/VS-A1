-module(server).
-compile(export_all).
-import(werkzeug).
-record(state, {clients,message_id,delivery_queue,holdback_queue,time_of_death,clientlifetime,dlqlimit,difftime}).

%%Client -> erhaltene Nachricht
%Client -> Letze Meldung
%Zeilennummer -> Nachricht
%aktuelle Zeilennummer
%Timeout
%kommentar


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
		  loop(S#state{message_id=Id+1});
		Any ->
		  io:format("Sorry, I don't understand: ~s~n",[Any])
	    end.

   

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


getLastMsgId(Pid,S=#state{clients = Clients}) ->
    %prüfen ob Client bereits bekannt:
  case orddict:find(Pid,Clients) of
      error ->
        orddict:append(Pid,{0,timestamp()}, Clients),
        0;
      {ok,{MsgId,_}} -> MsgId
   end.

dropmessage({Message,Number},S=#state{holdback_queue=HQ}) ->
  % hier könnte ein Fehler geschmissen werden, wenn schon eine Nachricht mit der ID vorhanden ist, momentan wird sie überschrieben
  NewMessage=Message++"Empfangszeit: "++werkzeug:timeMilliSecond(),
  %% Sorted Insert in the List
  NewHQ=lists:takewhile(fun({_,X})-> X< Number end,HQ)++[{NewMessage,Number}]++lists:dropwhile(fun({_,X})-> X<Number end,HQ),
  werkzeug:logging("NServer.log",NewMessage).
%%  update_queues(S#state{holdback_queue=NewHQ}).
  
  

%% update_queues(S = #state{messages=Messages,delivery_queue = DQ, holdback_queue = HQ}, {Message,Number}}) -> 
%%    {_,LastDeliveryID} = lists:last(DQ),
%%    {_,FirstHoldbackID} = lists:first(HQ),
%%    if LastDeliverID + 1 = FirstHoldbackID ->
%%            FirstBlob=lists:reverse(lists:foldl(fun getBlob/2,[],HQ));
%%        true -> FirstBlob=[]
%%    end,
%%    NewDQ=DQ++FirstBlob,
%%   lists:sublist(List,length(List)-3+1,length(List)).
    %% IN WORK!!!%%
        

getBlob({Message,Id},[]) -> [{Message,Id}];
getBlob({Message,Id},[{LastMessage,LastId}|List]) when Id -LastId == 1 -> [{Message,Id}|[{LastMessage,LastId}|List]];
getBlob(_,Accu) -> Accu.


timestamp() -> 
  {Mega, Secs, _} = now(),
  Timestamp = Mega*1000000 + Secs.


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
	loop(#state{clients=orddict:new(),delivery_queue=[{"Nachricht1",1},{"Nachricht2",2}],message_id=1,holdback_queue=[],time_of_death=timestamp()+Lifetime,clientlifetime=Clientlifetime,dlqlimit=Dlqlimit,difftime=Difftime}).


start() -> spawn(fun init/0).
