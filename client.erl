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
	loop(Servername,now(),Sendeintervall,0,0).


start() -> spawn(fun init/0).

loop(Servername,StartTime,Sendeintervall,MessageCounter,SendCounter) when SendCounter < 5 ->
																	erlang:send_after(seconds_to_mseconds(Sendeintervall), Servername, get_message()),
																	werkzeug:logging("client_1.log", werkzeug:timeMilliSecond() ),
																	io:format("Sending ~p ~p Message~n", [SendCounter,Sendeintervall]),
																	loop(Servername,StartTime,random_intervall(Sendeintervall), MessageCounter + 1, SendCounter + 1);
loop(Servername,StartTime,Sendeintervall,MessageCounter,SendCounter) when SendCounter >= 5 -> io:format("ALL DONE~n").
														   

 
 
 %% Wandelt Sekudnen in Mikrosekunden um.
 seconds_to_useconds(Seconds) -> round(Seconds * math:pow(10,6)).
  seconds_to_mseconds(Seconds) -> round(Seconds * math:pow(10,3)).
 
 %% Calculates the message to send.
 get_message() -> "hallo welt".
 
 %% Randomizes the message intervall +,- min(1Sek), but not below 1Sek.
 random_intervall(Sendeintervall) -> Sendeintervall.