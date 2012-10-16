-module(client).
-compile(export_all).
-import(werkzeug).

-record(state, {clientnr,servername,startTime,sendeintervall,sendCounter,getAll}).

init(Number,ConfigListe) -> 

	{ok, Lifetime} = werkzeug:get_config_value(lifetime, ConfigListe),
	ClientPid=self(),
	spawn(fun()->timer:kill_after(Lifetime*1000,ClientPid) end),
	{ok, Servername} = werkzeug:get_config_value(servername, ConfigListe),
	{ok, Sendeintervall} = werkzeug:get_config_value(sendeintervall, ConfigListe),
	Hostname = net_adm:localhost(),
	loop_redakteur(#state{clientnr=Number,servername=Servername,sendeintervall=Sendeintervall,sendCounter=1,getAll=false}).



start() ->
	{ok, ConfigListe} = file:consult("client.cfg"),
	{ok, ClientsNr} = werkzeug:get_config_value(clients, ConfigListe),
	lists:map(fun(X)->spawn(fun()->init(X,ConfigListe) end) end,lists:seq(1,ClientsNr)).

startOne() -> 
	{ok, ConfigListe} = file:consult("client.cfg"),
	spawn(fun()-> init(1,ConfigListe) end).

loop_leser(S= #state{servername=Servername,sendeintervall=Sendeintervall,sendCounter=SendCounter,getAll=GetAll}) ->
            io:format("Client is now reader"),
            if  GetAll==true ->
                    loop_redakteur(S#state{getAll=false});
                true ->
                    loop_leser(get_message(S))
            end.
			
loop_redakteur(S= #state{servername=Servername,sendeintervall=Sendeintervall,sendCounter=SendCounter,getAll=GetAll})->            
            if SendCounter >= 5 ->
                    loop_leser(S#state{sendCounter=1,sendeintervall=random_intervall(Sendeintervall)});
                true ->
                    send_message(S),
                    loop_redakteur(S#state{sendCounter=SendCounter+1})
            end.
            
send_message(S= #state{sendeintervall= Sendeintervall, servername = Servername}) -> 
            Id = getMsgId(Servername),
            Message = lists:concat([Id,"te Nachricht Sendezeit: ", werkzeug:timeMilliSecond(),"~n"]),
            Servername ! {dropmessage,{Message,Id}},
            timer:sleep(seconds_to_mseconds(Sendeintervall)),
            werkzeug:logging("client_1.log", Message).
            
            
 getMsgId(Servername) -> 
    Servername ! {getmsgid,self()},
    receive Id -> Id,
        io:format("Received ID: ~p~n" , [Id]),
        Id
    end.
                                                                       
 get_message(S=#state{servername=Servername}) -> 
			io:format("~s", [Servername]),
			Servername ! {getmessages, self()},
            receive {Nachrichteninhalt,GetAll} -> 
				werkzeug:logging("client_1.log", Nachrichteninhalt ++ "Empfangszeit Client: " ++ werkzeug:timeMilliSecond() ++ "~n" ),
				S#state{getAll=GetAll}
            end.

 
 %% Wandelt Sekudnen in Mikrosekunden um.
 seconds_to_useconds(Seconds) -> round(Seconds * math:pow(10,6)).
  seconds_to_mseconds(Seconds) -> round(Seconds * math:pow(10,3)).
 
 %% Calculates the message to send.
 write_message(Hostname,MessageCounter) -> "testmessage".
 
 %% Randomizes the message intervall +,- min(1Sek), but not below 1Sek.
 random_intervall(Sendeintervall) -> Sendeintervall.
