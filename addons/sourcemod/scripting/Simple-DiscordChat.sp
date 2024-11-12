#include <sourcemod>
#include <geoip>
#include <discord>
#include <basecomm>
#include <ripext>

#include "dcr/utils.sp"

ConVar g_cvChatWebhook;
ConVar g_cvChatRelayEnabled;
ConVar g_cvPrettyMode;
ConVar g_cvSteamAPIKey;
ConVar g_cvDebug;
ConVar g_cvGaggedAndTriggers;
HTTPClient httpClient;
char g_szSteamAvatar[MAXPLAYERS + 1][256];
int started = 0;

public Plugin myinfo = 
{
	name = "Moisty's Forked Simple Discord Chat Relay",
	author = "Infra (forked by moistToiletPaper42)",
	description = "Simple plugin to relay in-game text chat to a webhook!", 
	version = "1.0.0", 
	url = "https://github.com/1zc"
};

public void OnPluginStart()
{   
    g_cvChatRelayEnabled = CreateConVar("dcr_enable", "0", "Toggle whether the plugin is enabled. 1 = Enabled, 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_cvPrettyMode = CreateConVar("dcr_pretty", "0", "Toggle pretty chat webook mode. 1 = Pretty, 0 = Simple.", _, true, 0.0, true, 1.0);
    g_cvDebug = CreateConVar("dcr_debug", "0", "Toggle debug mode. 1 = Enabled, 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_cvGaggedAndTriggers = CreateConVar("dcr_triggers_gagged", "0", "Toggle whether chat triggers and gagged messages are sent to Discord. 1 = Enabled, 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_cvChatWebhook = CreateConVar("dcr_webhook_url", "", "Webhook URL to relay chats to.", FCVAR_PROTECTED);
    g_cvSteamAPIKey = CreateConVar("dcr_steamAPI_key", "", "Steam Web API key.", FCVAR_PROTECTED);

    RegServerCmd("discord", Command_Discord, "Send a message to a Discord webhook.")

    AutoExecConfig(true, "Simple-DiscordChat");
}

bool RealPlayerExist(int iExclude = 0)
{
	for( int client = 1; client <= MaxClients; client++ )
	{
		if( client != iExclude && IsClientConnected(client) )
		{
			if( !IsFakeClient(client) )
			{
				return true;
			}
		}
	}
	return false;
}

public void OnConfigsExecuted()
{
    if (httpClient != null)
    	delete httpClient;
    
    httpClient = new HTTPClient("https://api.steampowered.com");

    if (started == 0){
        started = 1;

        char message[512] = "## _Server has started!_";
        sendDefaultWebhook(message);

        char map[PLATFORM_MAX_PATH];
        GetCurrentMap(map, sizeof(map));
        GetMapDisplayName(map, map, sizeof(map));
        Format(message, sizeof(message), "_**Map `%s` has loaded...**_", map);
        sendDefaultWebhook(message);
    }
}

public void OnClientPostAdminCheck(int client)
{
    GetProfilePic(client);
}

public void OnClientPutInServer(int client)
{
    if (IsClientConnected(client) && IsClientInGame(client))
    {
        char steamId[32];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId), true);

        if(strncmp(steamId, "BOT", 3) == 0){
            return;
        }

        char webhook[1024];
        GetConVarString(g_cvChatWebhook, webhook, sizeof(webhook));    
        if (StrEqual(webhook, ""))
        {
            LogError("[Simple-DCR] WebhookURL was not configured, aborting.");
            return;
        }

        char name[MAX_NAME_LENGTH];
        GetClientName(client, name, sizeof(name));

        char ip[64];
        GetClientIP(client, ip, sizeof(ip), true);

        char ccode[4];
        GeoipCode3(ip, ccode);

        if(strlen(ccode) == 0){
            ccode = "???";
        }

        char message[512];
        Format(message, sizeof(message), "**Player connected (`%s`):** %s (`%s`)", ccode, name, steamId);

        sendSpecifiedWebhook(webhook, message);
    }
}

public void OnClientDisconnect(int client){
    if (IsClientConnected(client))
    {

        char steamId[32];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId), true);

        if(strncmp(steamId, "BOT", 3) == 0){
            return;
        }
        char webhook[1024];
        GetConVarString(g_cvChatWebhook, webhook, sizeof(webhook));
        if (StrEqual(webhook, ""))
        {
            LogError("[Simple-DCR] WebhookURL was not configured, aborting.");
            return;
        }

        char name[MAX_NAME_LENGTH];
        GetClientName(client, name, sizeof(name));

        char ip[64];
        GetClientIP(client, ip, sizeof(ip), true);

        char ccode[4];
        GeoipCode3(ip, ccode);
        
        if(strlen(ccode) == 0){
            ccode = "???";
        }

        char message[512];
        Format(message, sizeof(message), "**Player disconnected (`%s`):** %s (`%s`)", ccode, name, steamId);

        sendSpecifiedWebhook(webhook, message);

        if(!RealPlayerExist( client )){
            message = "_**Server is empty!**_";

            sendDefaultWebhook(message);
        }
    }
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] argText)
{
    if (!g_cvChatRelayEnabled.BoolValue)
    {
        if (g_cvDebug.BoolValue)
        {
            PrintToConsole(0, "[Simple-DCR] DEBUG: Plugin not enabled in config, aborting. (dcr_enable = 0)");
        }
        return;
    }

    if (client > 0) // Check if client is NOT console.
    {
        if (BaseComm_IsClientGagged(client) || IsChatTrigger()) // Check if client is gagged. || Check if text was a recognized command/trigger.
        {
            if (g_cvDebug.BoolValue)
            {
                PrintToConsole(0, "[Simple-DCR] DEBUG: Client %i is gagged or used a chat trigger, aborting.", client);
            }
            if (!g_cvGaggedAndTriggers.BoolValue){
                return;
            }
        }
    }
    
    // Prep the message before processing.
    char messageTxt[256];
    Format(messageTxt, sizeof(messageTxt), argText);
    StripQuotes(messageTxt);
    TrimString(messageTxt);
    // Time to sanitise.
    SanitiseText(messageTxt);

    // Is the resultant string blank?
    if (StrEqual(messageTxt, "") || StrEqual(messageTxt, " "))
    {
        if (g_cvDebug.BoolValue)
        {
            PrintToConsole(0, "[Simple-DCR] DEBUG: Client %i sent a blank message, aborting.", client);
        }
        return;
    }

    // Away it goes!
    if (g_cvPrettyMode.BoolValue)
        sendPrettyChatWebhook(client, messageTxt);
    else
        sendSimpleChatWebhook(client, messageTxt);
}

public void OnMapEnd() {
    char message[512], map[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    GetMapDisplayName(map, map, sizeof(map));
    Format(message, sizeof(message), "_**Map `%s` is unloading...**_", map);
    sendDefaultWebhook(message);
}

public void OnMapStart() {
    char message[512], map[PLATFORM_MAX_PATH]
    GetCurrentMap(map, sizeof(map));
    GetMapDisplayName(map, map, sizeof(map));
    Format(message, sizeof(message), "_**Map `%s` has loaded...**_", map);
    sendDefaultWebhook(message);
}

public Action Command_Discord(int args)
{
    // discord command accepts 2 arguments, the webhook (optional - check for "http" prefix) and the message (can contain spaces!)
    if (args < 1)
    {
        PrintToConsole(0, "[Simple-DCR] Usage: discord <message> [webhook*]. *if webhook is to be specified, wrap it in quotes, otherwise it will be treated as a comment.");
        return Plugin_Handled;
    }

    char webhook[1024], messageTxt[512], lastArg[1024], fullargs[2048];
    GetCmdArg(args, lastArg, sizeof(lastArg));
    GetCmdArgString(fullargs, sizeof(fullargs));

    if(strncmp(lastArg, ":", 1) == 0){
        PrintToConsole(0, "[Simple-DCR] You may have forgotten to wrap the webhook in quotes! This may not work as intended.");
    }

    if(strncmp(lastArg, "http", 4) == 0)
    {
        webhook = lastArg;
        int webhookLen = strlen(webhook);
        int fullArgsLen = strlen(fullargs);
        strcopy(messageTxt, fullArgsLen - webhookLen - 2, fullargs) //-2 to account for quotes and space
    } else {
        GetConVarString(g_cvChatWebhook, webhook, sizeof(webhook));
        if (StrEqual(webhook, ""))
        {
            LogError("[Simple-DCR] WebhookURL was not configured, aborting.");
            return Plugin_Handled;
        }
        strcopy(messageTxt, sizeof(messageTxt), fullargs);
    }

    if (StrEqual(webhook, ""))
    {
        PrintToConsole(0, "[Simple-DCR] WebhookURL was not specified or configured, aborting.");
        return Plugin_Handled;
    }

    if (StrEqual(messageTxt, "") || StrEqual(messageTxt, " "))
    {
        PrintToConsole(0, "[Simple-DCR] Message was blank, aborting.");
        return Plugin_Handled;
    }

    sendSpecifiedWebhook(webhook, messageTxt);
    return Plugin_Handled;
}

void sendPrettyChatWebhook(int client, char[] text)
{
    char webhook[1024], finalText[512], clientName[128], steamID[64];
    GetConVarString(g_cvChatWebhook, webhook, sizeof(webhook));
    if (StrEqual(webhook, ""))
	{
        LogError("[Simple-DCR] WebhookURL was not configured, aborting.");
        return;
	}

    if (client == 0)
    {
        Format(clientName, sizeof(clientName), "CONSOLE")
        Format(steamID, sizeof(steamID), "-");
    }

    else
    {
        GetClientName(client, clientName, sizeof(clientName));
        GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID), true);
        Format(clientName, sizeof(clientName), "%s (%s)", clientName, steamID);
    }

    ReplaceString(clientName, 32, "@", "", false);
    ReplaceString(clientName, 32, "\\", "", false);
    ReplaceString(clientName, 32, "`", "", false);

    Format(finalText, sizeof(finalText), "`%s`", text);

    DiscordWebHook hook = new DiscordWebHook(webhook);
    hook.SlackMode = true;
    hook.SetContent(finalText);
    hook.SetUsername(clientName);
    if (!StrEqual(g_szSteamAvatar[client], "NULL", false)) //&& !StrEqual(g_szSteamAvatar[client], "", false))
    {
        if (g_cvDebug.BoolValue)
        {
            PrintToConsole(0, "[Simple-DCR] DEBUG: Client %i has an avatar, using it! URL: %s", client, g_szSteamAvatar[client]);
        }
        hook.SetAvatar(g_szSteamAvatar[client]);
    }
    hook.Send();
    delete hook;
}

void sendDefaultWebhook(char[] text)
{
    char webhook[1024];
    GetConVarString(g_cvChatWebhook, webhook, sizeof(webhook));
    if (StrEqual(webhook, ""))
    {
        LogError("[Simple-DCR] WebhookURL was not configured. Aborting.");
        return;
    }

    DiscordWebHook hook = new DiscordWebHook(webhook);
    hook.SlackMode = true;
    hook.SetContent(text);
    hook.Send();

    delete hook;
}

void sendSpecifiedWebhook(char[] webhook, char[] text)
{

    DiscordWebHook hook = new DiscordWebHook(webhook);
    hook.SlackMode = true;
    hook.SetContent(text);
    hook.Send();

    delete hook;
}

void sendSimpleChatWebhook(int client, char[] text)
{
    char webhook[1024], finalText[512], clientName[32], steamID[64];
    GetConVarString(g_cvChatWebhook, webhook, sizeof(webhook));
    if (StrEqual(webhook, ""))
	{
        LogError("[Simple-DCR] WebhookURL was not configured. Aborting.");
        return;
	}

    if (client == 0)
    {
        Format(clientName, sizeof(clientName), "CONSOLE")
        Format(steamID, sizeof(steamID), "-");
    }

    else
    {
        GetClientName(client, clientName, sizeof(clientName));
        GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID), true);
    }

    ReplaceString(clientName, 32, "@", "", false);
    ReplaceString(clientName, 32, "\\", "", false);
    ReplaceString(clientName, 32, "`", "", false);

    Format(finalText, sizeof(finalText), "> %s (`%s`): `%s`", clientName, steamID, text);

    sendSpecifiedWebhook(webhook, finalText);
}

void GetProfilePic(int client)
{
    char szRequestBuffer[1024], szSteamID[64], szAPIKey[256];

    GetClientAuthId(client, AuthId_SteamID64, szSteamID, sizeof(szSteamID), true);
    GetConVarString(g_cvSteamAPIKey, szAPIKey, sizeof(szAPIKey));
    if(!g_cvPrettyMode.BoolValue){ // performance optimization
        return;
    }

    if (StrEqual(szAPIKey, "", false))
    {
        PrintToConsole(0, "[Simple-DCR] ERROR: Steam API Key not configured. Falling back to DCR Simple Mode.");
        g_cvPrettyMode.BoolValue = false;
        return;
    }

    Format(szRequestBuffer, sizeof szRequestBuffer, "ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s&format=json", szAPIKey, szSteamID);
    httpClient.Get(szRequestBuffer, GetProfilePicCallback, client);
}

public void GetProfilePicCallback(HTTPResponse response, any client)
{
    if (response.Status != HTTPStatus_OK) 
    {
        FormatEx(g_szSteamAvatar[client], sizeof(g_szSteamAvatar[]), "NULL");
        PrintToConsole(0, "[Simple-DCR] ERROR: Failed to reach SteamAPI. Status: %i", response.Status);
        return;
    }

    JSONObject objects = view_as<JSONObject>(response.Data);
    JSONObject Response = view_as<JSONObject>(objects.Get("response"));
    JSONArray players = view_as<JSONArray>(Response.Get("players"));
    int playerlen = players.Length;
    if (g_cvDebug.BoolValue)
    {
        PrintToConsole(0, "[Simple-DCR] DEBUG: Client %i SteamAPI Response Length: %i", client, playerlen);
    }

    JSONObject player;
    for (int i = 0; i < playerlen; i++)
    {
        player = view_as<JSONObject>(players.Get(i));
        player.GetString("avatarfull", g_szSteamAvatar[client], sizeof(g_szSteamAvatar[]));
        if (g_cvDebug.BoolValue)
        {
            PrintToConsole(0, "[Simple-DCR] DEBUG: Client %i has Avatar URL: %s", client, g_szSteamAvatar[client]);
        }
        delete player;
    }
}
