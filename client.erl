-module(client).
-compile(export_all).
-import(werkzeug).

init() -> 
	{ok, ConfigListe} = file:consult("client.cfg"),
	{ok, ClientsNr} = werkzeug:get_config_value(clients, ConfigListe),
	{ok, Lifetime} = werkzeug:get_config_value(lifetime, ConfigListe),
	{ok, Servername} = werkzeug:get_config_value(servername, ConfigListe),
	{ok, Sendeintervall} = werkzeug:get_config_value(sendeintervall, ConfigListe),
	Hostname = net_adm:localhost(),
	loop(Servername,now(),Sendeintervall,0,0,false).


start() -> spawn(fun init/0).
%% Nachrichten senden, bis Sendcounter >=5
loop(Servername,StartTime,Sendeintervall,MessageCounter,SendCounter,GetAll) when SendCounter < 5 ->
																	erlang:send_after(seconds_to_mseconds(Sendeintervall), Servername, write_message({_,Hostname}= inet:gethostname(),MessageCounter)),
																	werkzeug:logging(("client_1.log"), werkzeug:timeMilliSecond() ),
																	io:format("Sending ~p ~p Message~n", [SendCounter,Sendeintervall]),
																	loop(Servername,StartTime,random_intervall(Sendeintervall), MessageCounter + 1, SendCounter + 1,GetAll);
%% NAchrichten empfangen bis GetAll == true
loop(Servername,StartTime,Sendeintervall,MessageCounter,SendCounter,GetAll) when SendCounter >= 5, GetAll == false  -> 
			AllReceived = getmessages(Servername),
		%%	loop(Servername,StartTime,Sendeintervall,MessageCounter,0,GetAll),
			io:format("ALL DONE~n").
																	   

 getmessages(Servername) -> 
			io:format("~s", [Servername]),
			Servername ! {getmessages, self()},
            receive {Nachrichteninhalt,Getall} -> 
				io:format("Nachricht vom Server: ~s", [Nachrichteninhalt]),
				werkzeug:logging("client_1.log", Nachrichteninhalt ++ "Empfangszeit Client: " ++ werkzeug:timeMilliSecond() ),
				Getall
				end.

 
 %% Wandelt Sekudnen in Mikrosekunden um.
 seconds_to_useconds(Seconds) -> round(Seconds * math:pow(10,6)).
  seconds_to_mseconds(Seconds) -> round(Seconds * math:pow(10,3)).
 
 %% Calculates the message to send.
 write_message(Hostname,MessageCounter) -> "testmessage".
 
 %% Randomizes the message intervall +,- min(1Sek), but not below 1Sek.
 random_intervall(Sendeintervall) -> Sendeintervall.