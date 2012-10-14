-module(client).
-compile(export_all).
-import(werkzeug).

init() -> 
	{ok, ConfigListe} = file:consult("client.cfg"),
	{ok, ClientsNr} = get_config_value(clients, ConfigListe),
	{ok, Lifetime} = get_config_value(lifetime, ConfigListe),
	{ok, Servername} = get_config_value(servername, ConfigListe),
	{ok, Sendeintervall} = get_config_value(sendeintervall, ConfigListe),
	loop(now()).


start() -> spawn(fun init/0).

loop(StartTime) -> 