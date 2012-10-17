-module(client).
-compile(export_all).
-import(werkzeug).

-record(state, {clientnr,servername,startTime,sendeintervall,sendCounter,getAll}).

init(Number,ConfigListe,Node) -> 
	{ok, Lifetime} = werkzeug:get_config_value(lifetime, ConfigListe),
	ClientPid=self(),
	spawn(fun()->timer:kill_after(Lifetime*1000,ClientPid) end),
	{ok, Servername} = werkzeug:get_config_value(servername, ConfigListe),
	{ok, Sendeintervall} = werkzeug:get_config_value(sendeintervall, ConfigListe),
	loop_redakteur(#state{clientnr=Number,servername={Servername,Node},sendeintervall=Sendeintervall,sendCounter=1,getAll=false}).



start() ->
	{ok, ConfigListe} = file:consult("client.cfg"),
	{ok, ClientsNr} = werkzeug:get_config_value(clients, ConfigListe),
	startX(ClientsNr).

startX(Nr) -> 
	{ok, ConfigListe} = file:consult("client.cfg"),
	lists:map(fun(X)->spawn(fun()->init(X,ConfigListe,node()) end) end,lists:seq(1,Nr)).

start(Node) ->
	{ok, ConfigListe} = file:consult("client.cfg"),
	{ok, ClientsNr} = werkzeug:get_config_value(clients, ConfigListe),
	startX(ClientsNr,Node).

startX(Nr,Node) -> 
	{ok, ConfigListe} = file:consult("client.cfg"),
	lists:map(fun(X)->spawn(fun()->init(X,ConfigListe,Node) end) end,lists:seq(1,Nr)).
    
loop_leser(S= #state{getAll=GetAll}) ->
            
            if  GetAll==true ->
                    loop_redakteur(S#state{getAll=false});
                true ->
                    loop_leser(get_message(S))
            end.
			
loop_redakteur(S= #state{sendeintervall=Sendeintervall,sendCounter=SendCounter})->            
            if SendCounter > 5 ->
                    loop_leser(S#state{sendCounter=1,sendeintervall=random_intervall(Sendeintervall)});
                true ->
                    send_message(S),
                    loop_redakteur(S#state{sendCounter=SendCounter+1})
            end.
            
send_message(#state{clientnr=ClientNr,sendeintervall= Sendeintervall, servername = Servername}) -> 
            Id = getMsgId(Servername),
            Message = lists:concat([net_adm:localhost(),":1-10: ",Id,"te Nachricht Sendezeit: ", werkzeug:timeMilliSecond(),"|"]),
            Servername ! {dropmessage,{Message,Id}},
            timer:sleep(seconds_to_mseconds(Sendeintervall)),
            werkzeug:logging( log_file_name(ClientNr), lists:concat([Message,io_lib:nl()])).
            
            
 getMsgId(Servername) -> 
    Servername ! {getmsgid,self()},
    receive Id -> Id
    end.
                                                                       
 get_message(S=#state{clientnr=ClientNr,servername=Servername}) -> 
			Servername ! {getmessages, self()},
            receive {Nachrichteninhalt,GetAll} -> 
				werkzeug:logging(log_file_name(ClientNr), lists:concat([Nachrichteninhalt,"Empfangszeit Client: ",werkzeug:timeMilliSecond(),io_lib:nl()] )),
				S#state{getAll=GetAll}
            end.

 log_file_name(ClientNr) -> lists:concat(["client_",ClientNr,net_adm:localhost(),".log"]).
 
 
 %% Wandelt Sekudnen in Millisekunden um.
  seconds_to_mseconds(Seconds) -> round(Seconds * math:pow(10,3)).

 %% Randomizes the message intervall +,- min(1Sek), but not below 1Sek.
 random_intervall(Sendeintervall) -> 
    Intervall = Sendeintervall + new_delta(Sendeintervall),
    if Intervall < 1 -> 1;
        true -> Intervall
    end.

new_delta(Sendeintervall) ->
    Delta = (random:uniform() - 0.5) * Sendeintervall,
    if (Delta < 0) and (Delta > -1) -> -1;
       (Delta >= 0) and (Delta < 1) -> 1;
       true -> Delta
    end.
 
