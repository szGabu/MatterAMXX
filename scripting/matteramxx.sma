#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#assert "AMX Mod X versions 1.8.2 and below are not supported."
#endif

// ** COMPILER OPTIONS **
// Adjust as needed

// Enable if you want to use HamSandwich (recommended)
// Disable if you want to use DeathMsg, for example in games that do not have HamSandwich support like Ricochet
// Useful in: Ricochet and games with no virtual table data
#define USE_HAMSANDWICH 0

// Enable if you want to use the deprecated `client_disconnect()` forward instead of the newer `client_disconnected()`
// Useful in engines where there are no signature for the newer forward yet
// This WILL cause a warning on compilation, but can be safely ignored
// Useful in: Bleeding edge versions of Svengine
#define USE_DEPRECATED_DISCONNECT_FORWARD 0
// Did you know pawn supports a warning disable pragma but it was removed from AMX?
// Yet they use the warning disable pragma in C when they compile AMXX bins?
// Crazy right?

// ** COMPILER OPTIONS END HERE **

#define TEAM_0_SYMBOL       "🟧" // Invalid or not Teamplay
#define TEAM_1_SYMBOL       "🟦" // Team 1 in Half-Life, CTs in Counter-Strike, BLUE in Team Fortress
#define TEAM_2_SYMBOL       "🟥" // Team 2 in Half-Life, Terrorists in Counter-Strike, RED in Team Fortress
#define TEAM_3_SYMBOL       "🟨" // Team 3 in Half-Life, YELLOW in Team Fortress
#define TEAM_4_SYMBOL       "🟩" // Team 4 in Half-Life, GREEN in Team Fortress
#define TEAM_5_SYMBOL       "⬛️" // Team 5 in Half-Life, then he loops back to 1 to repeat the colors
#define SPECTATOR_SYMBOL    "⬜️" // Spectator team
#define DEAD_SYMBOL         "☠️" // Dead (Ghost), spectating but currently on a team

#include <amxmisc>
#include <fakemeta>
#include <regex>
#include <fun>
#tryinclude <hlstocks>

#if USE_HAMSANDWICH > 0
    #include <hamsandwich>
#endif

#include <matteramxx_consts>
#include <easy_http>

#pragma semicolon 1

enum
{
	RENDER_MODE = 0,
	RENDER_AMT,
	RENDER_FX,
	MAX_RENDER
}

new g_cvarEnabled;
new g_cvarSystemAvatarUrl;
new g_cvarAutogenAvatarUrl;
new g_cvarAvatarUrl;
new g_cvarBridgeProtocol;
new g_cvarBridgeHost;
new g_cvarBridgePort;
new g_cvarBridgeGateway;
new g_cvarToken;
new g_cvarUseRelayUser;
new g_cvarIncoming;
new g_cvarIncoming_DontColorize;
new g_cvarIncoming_IgnorePrefix;
new g_cvarIncoming_RefreshTime;
new g_cvarOutgoing;
new g_cvarOutgoing_SystemUsername;
new g_cvarOutgoing_Chat_Mode;
new g_cvarOutgoing_Chat_Passthrough;
new g_cvarOutgoing_Chat_SpamFil;
new g_cvarOutgoing_Chat_ZeroifyAtSign;
new g_cvarOutgoing_Chat_RequirePrefix;
new g_cvarOutgoing_Chat_MuteServer;
new g_cvarOutgoing_Chat_PrefixTeam;
new g_cvarOutgoing_Chat_PrefixDeadStatus;
new g_cvarOutgoing_Chat_IgnoreBots;
new g_cvarOutgoing_Chat_IgnoreHLTV;
new g_cvarForcePrefix;
new g_cvarOutgoing_Kills;
new g_cvarOutgoing_Join;
new g_cvarOutgoing_Join_Wait;
new g_cvarOutgoing_Join_Delay;
new g_cvarOutgoing_Quit;
new g_cvarOutgoing_Quit_IgnoreIntermission;
new g_cvarOutgoing_JoinQuit_ShowCount;
new g_cvarOutgoing_StripColors;
new g_cvarOutgoing_DisplayMap;
new g_cvarRetry_Delay;

new bool:g_bEnabled;

new g_szAvatarUrl[BASE_URL_LENGTH];
new g_szAutogenAvatarUrl[BASE_URL_LENGTH];
new g_szSystemAvatarUrl[BASE_URL_LENGTH];

new g_szBridgeProtocol[SHORT_LENGTH];
new g_szBridgeHost[MAX_NAME_LENGTH];
new g_szBridgePort[SHORT_LENGTH];
new g_szBridgeToken[BASE_URL_LENGTH];

new bool:g_bIncomingMessages = false;
new bool:g_bIncomingDontColorize = false;
new g_szIncomingIgnorePrefix[SHORT_LENGTH];
new Float:g_fIncomingUpdateTime = 0.0;
new bool:g_bIncomingRelayMessagesOnUser = false;

new bool:g_bOutgoingMessages = false;
new g_szOutgoingSystemUsername[MAX_NAME_LENGTH];
new g_iOutgoingChatMode = 0;
new bool:g_bOutgoingPassthrough = false;
new bool:g_bOutgoingNoRepeat = false;
new bool:g_bOutgoingZwspAt = false;
new g_szOutgoingRequirePrefix[SHORT_LENGTH];
new bool:g_bOutgoingMuteServer = false;
new g_iOutgoingPrefixTeam = 0;
new g_iOutgoingPrefixDeadStatus = 0;
new bool:g_bOutgoingIgnoreBots = false;
new bool:g_bOutgoingIgnoreHLTV = false;
new g_szForcePrefix[MAX_NAME_LENGTH];
new bool:g_bOutgoingKills = false;
new bool:g_bOutgoingJoin = false;
new Float:g_fOutgoingJoinWait = 0.0;
new Float:g_fOutgoingJoinDelay = 0.0;
new bool:g_bOutgoingLeave = false;
new bool:g_bOutgoingLeaveIgnoreIntermission = false;
new bool:g_bOutgoingStripColors = false;
new bool:g_bOutgoingDisplayMap = false;
new bool:g_bOutgoingJoinQuitPlayerCount = false;
new Float:g_fRetryDelay = 0.0;

new g_szIncomingUri[BASE_URL_LENGTH];
new g_szOutgoingUri[BASE_URL_LENGTH];
new g_szBridgeUrl[BASE_URL_LENGTH];
new g_szGateway[MAX_NAME_LENGTH];
new g_szGamename[MAX_NAME_LENGTH];

new g_szLastMessages[MAX_PLAYERS+1][MESSAGE_LENGTH];
new g_bUserConnected[MAX_PLAYERS+1];

new bool:g_bTeamPlay = false;

new g_bUserAuthenticated[MAX_PLAYERS+1];

new bool:g_bJoinDelayDone = false;
new bool:g_bIsIntermission = false;

new g_hPrintMessageForward; 
new g_iPluginFlags;

new g_hSayTextUserMessage;

new Regex:g_hAuthId_Pattern;
new Regex:g_hPrefix_Pattern;

new const sHexTable[] = "0123456789ABCDEF";

enum (*= 2)
{
    CHAT_TYPE_ALL = 1,
    CHAT_TYPE_TEAM,
}

enum aCurrentGame
{
	GAME_UNKNOWN = 0,
	GAME_VALVE,
	GAME_CSTRIKE,
	GAME_CZERO,
    GAME_DOD,
    GAME_RICOCHET,
    GAME_SPECIALISTS,
    GAME_TEAMFORTRESS,
    GAME_SVENCOOP,
    GAME_ADRENALINE_GAMER,
    GAME_OPFOR,
    GAME_DMC,
}

enum _: aMessageQueueStruct
{
    szMessageQueueName[MAX_NAME_LENGTH],
    szMessageQueueMessage[MESSAGE_LENGTH],
    iMessageQueueClient
}

/**
 * Holds the currently running game
 */
new aCurrentGame:g_hCurrentGame = GAME_UNKNOWN;

public plugin_natives()
{
    register_library("matteramxx");
    register_native("matteramxx_send_message", "send_message_custom");
}

public plugin_init()
{
    //always compile regex on map init to avoid errors
    g_hAuthId_Pattern = regex_compile(REGEX_STEAMID_PATTERN);
    
    register_plugin(MATTERAMXX_PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    new szServerName[MAX_NAME_LENGTH];
    get_modname(g_szGamename, charsmax(g_szGamename));

    if(equali(g_szGamename, "valve"))
        g_hCurrentGame = GAME_VALVE;
    else if(equali(g_szGamename, "cstrike"))
        g_hCurrentGame = GAME_CSTRIKE;
    else if(equali(g_szGamename, "czero"))
        g_hCurrentGame = GAME_CZERO;
    else if(equali(g_szGamename, "dod"))
        g_hCurrentGame = GAME_DOD;
    else if(equali(g_szGamename, "ricochet"))
        g_hCurrentGame = GAME_RICOCHET;
    else if(equali(g_szGamename, "ts"))
        g_hCurrentGame = GAME_SPECIALISTS;
    else if(equali(g_szGamename, "tfc"))
        g_hCurrentGame = GAME_TEAMFORTRESS;
    else if(equali(g_szGamename, "svencoop"))
        g_hCurrentGame = GAME_SVENCOOP;
    else if(equali(g_szGamename, "ag"))
        g_hCurrentGame = GAME_ADRENALINE_GAMER;
    else if(equali(g_szGamename, "gearbox"))
        g_hCurrentGame = GAME_OPFOR;
    else if(equali(g_szGamename, "dmc"))
        g_hCurrentGame = GAME_DMC;

    get_cvar_string("hostname", szServerName, charsmax(szServerName));

    g_cvarEnabled = create_cvar(                            "amx_matter_enable",                                    "1",                                                  FCVAR_NONE,       "Determines if MatterAMXX should be enabled.");
    g_cvarSystemAvatarUrl = create_cvar(                    "amx_matter_system_avatar",                             "",                                                   FCVAR_PROTECTED,  "URL pointing to a picture that will be used as avatar image in system messages (In protocols that support it).");
    g_cvarAutogenAvatarUrl = create_cvar(                   "amx_matter_autogenerate_avatar",                       "",                                                   FCVAR_PROTECTED,  "URL pointing to a picture that will be used as avatar image in unauthenticated player messages (In protocols that support it). Use %s to pass the name as a parameter.");
    g_cvarAvatarUrl = create_cvar(                          "amx_matter_player_avatar",                             "",                                                   FCVAR_PROTECTED,  "URL pointing to a picture that will be used as avatar image in player messages (In protocols that support it), note that this is dynamic based on the user's Steam ID64, if it can't be retrieved the message will use unauthenticated avatars. Use %s to pass the SID64 as a parameter.");
    g_cvarBridgeProtocol = create_cvar(                     "amx_matter_bridge_protocol",                           "http",                                               FCVAR_PROTECTED,  "Protocol of where the bridge is located.");
    g_cvarBridgeHost = create_cvar(                         "amx_matter_bridge_host",                               "localhost",                                          FCVAR_PROTECTED,  "Host of where the bridge is located.");
    g_cvarBridgePort = create_cvar(                         "amx_matter_bridge_port",                               "1337",                                               FCVAR_PROTECTED,  "Port of where the bridge is located.");
    g_cvarBridgeGateway = create_cvar(                      "amx_matter_bridge_gateway",                            g_szGamename,                                         FCVAR_PROTECTED,  "Gateway name to connect.");
    g_cvarToken = create_cvar(                              "amx_matter_bridge_token",                              "",                                                   FCVAR_PROTECTED,  "String token to authenticate, it's recommended that you set it up, but it will accept any connection by default.");
    g_cvarIncoming = create_cvar(                           "amx_matter_bridge_incoming",                           "1",                                                  FCVAR_NONE,       "Enables incoming messages (protocols to server).");
    g_cvarIncoming_DontColorize = create_cvar(              "amx_matter_bridge_incoming_dont_colorize",             "0",                                                  FCVAR_NONE,       "For incoming messages and games like Counter-Strike and Day of Defeat only. By default it will colorize any message with a simple format (green username) but if set to 1 it will not colorize anything, leaving the admin to handle any colorization in the matterbridge.toml file.");
    g_cvarIncoming_IgnorePrefix = create_cvar(              "amx_matter_bridge_incoming_ignore_prefix",             "!",                                                  FCVAR_NONE,       "For incoming messages. Messages matching this in the beggining of the message will be ignored by the plugin");
    g_cvarIncoming_RefreshTime = create_cvar(               "amx_matter_bridge_incoming_update_time",               "3.0",                                                FCVAR_NONE,       "For incoming messages. Specifies how many seconds it has to wait before querying new incoming messages. Performance wise is tricky, lower values mean the messages will be queried instantly, while higher values will wait and bring all messages at once, both cases may cause overhead. Experiment and see what's ideal for your server.");
    g_cvarUseRelayUser = create_cvar(                       "amx_matter_bridge_incoming_relay_user",                "0",                                                  FCVAR_NONE,       "For incoming messages. Determines if incoming messages should use an active player as a relay. It will make usernames to display as color in games like Half-Life Deathmatch and The Specialists. This value is ignored in games like Counter-Strike and Day of Defeat.");
    g_cvarOutgoing = create_cvar(                           "amx_matter_bridge_outgoing",                           "1",                                                  FCVAR_NONE,       "Enables outgoing messages (server to protocols).");
    g_cvarOutgoing_SystemUsername = create_cvar(            "amx_matter_bridge_outgoing_system_username",           szServerName,                                         FCVAR_NONE,       "For outgoing messages. Name of the 'user' when relying system messages.");
    g_cvarOutgoing_Chat_Mode = create_cvar(                 "amx_matter_bridge_outgoing_chat_mode",                 "3",                                                  FCVAR_NONE,       "For outgoing messages. Select which chat messages you want to send. (1=All chat 2=Team chat) You must sum the values you want to send. For example, if you want to send everything the value must be 3.");
    g_cvarOutgoing_Chat_Passthrough = create_cvar(          "amx_matter_bridge_outgoing_chat_passthrough",          "0",                                                  FCVAR_NONE,       "For outgoing messages. Whenever a message is sent to the bridge, it will pass through and reprinted by the plugin.");
    g_cvarOutgoing_Chat_SpamFil = create_cvar(              "amx_matter_bridge_outgoing_chat_no_repeat",            "1",                                                  FCVAR_NONE,       "For outgoing messages. Implement basic anti-spam filter. Useful for preventing taunt binds from sending multiple times.");
    g_cvarOutgoing_Chat_ZeroifyAtSign = create_cvar(        "amx_matter_bridge_outgoing_chat_zwsp_at",              "1",                                                  FCVAR_NONE,       "For outgoing messages. This controls if the plugin should add a ZWSP character after the at symbol (@) to prevent unintentional or malicious pinging.");
    g_cvarOutgoing_Chat_RequirePrefix = create_cvar(        "amx_matter_bridge_outgoing_chat_require_prefix",       "",                                                   FCVAR_NONE,       "For outgoing messages. Messages need this prefix to be able to be sent. Regex compatible.");
    g_cvarOutgoing_Chat_MuteServer = create_cvar(           "amx_matter_bridge_outgoing_chat_mute_server",          "0",                                                  FCVAR_NONE,       "For outgoing messages. When an user talks (and the message goes through the bridge) it will not be sent to other players. Works better with 'amx_matter_bridge_outgoing_chat_require_prefix' enabled.");
    g_cvarOutgoing_Chat_PrefixTeam = create_cvar(           "amx_matter_bridge_outgoing_chat_prefix_team",          "2",                                                  FCVAR_NONE,       "For outgoing messages. When an user talks (and the message goes through the bridge) the message will contain a prefix representing their team if they speak though a respective channel. (1=All chat 2=Team chat) You must sum the values you want to send. 0 to disable.");
    g_cvarOutgoing_Chat_PrefixDeadStatus = create_cvar(     "amx_matter_bridge_outgoing_chat_prefix_dead_status",   "2",                                                  FCVAR_NONE,       "For outgoing messages. When an user talks (and the message goes through the bridge) the message will contain a prefix representing if they're dead if they speak though a respective channel. (1=All chat 2=Team chat) You must sum the values you want to send. 0 to disable.");
    g_cvarOutgoing_Chat_IgnoreBots = create_cvar(           "amx_matter_bridge_outgoing_ignore_bots",               "1",                                                  FCVAR_NONE,       "For outgoing messages. For messages and events, anything coming from bots will be ignored. (Kills made by bots will be suppressed, but users killing bots will not).");
    g_cvarOutgoing_Chat_IgnoreHLTV = create_cvar(           "amx_matter_bridge_outgoing_ignore_hltv",               "1",                                                  FCVAR_NONE,       "For outgoing messages. For messages and events, anything coming from a HLTV proxy will be ignored.");
    g_cvarOutgoing_Kills = create_cvar(                     "amx_matter_bridge_outgoing_kills",                     "1",                                                  FCVAR_NONE,       "For outgoing messages. Transmit kill feed. It's recommended that you to turn it off on heavy activity servers (Like CSDM/Half-Life servers with tons of players).");
    g_cvarOutgoing_Join = create_cvar(                      "amx_matter_bridge_outgoing_join",                      "1",                                                  FCVAR_NONE,       "For outgoing messages. Transmit when people join the server.");
    g_cvarOutgoing_Join_Wait = create_cvar(                 "amx_matter_bridge_outgoing_join_wait",                 "3.0",                                                FCVAR_NONE,       "For outgoing messages. Amount of time to wait for every individual player before sending their join message. Useful if you have a plugin blocking improper names and you want to show the message when their name is validated.");
    g_cvarOutgoing_Join_Delay = create_cvar(                "amx_matter_bridge_outgoing_join_delay",                "15",                                                 FCVAR_NONE,       "For outgoing messages. Specify how many seconds the server has to wait before sending Join messages.");
    g_cvarOutgoing_Quit = create_cvar(                      "amx_matter_bridge_outgoing_quit",                      "1",                                                  FCVAR_NONE,       "For outgoing messages. Transmit when people leave the server.");
    g_cvarOutgoing_Quit_IgnoreIntermission = create_cvar(   "amx_matter_bridge_outgoing_quit_ignore_intermission",  "0",                                                  FCVAR_NONE,       "For outgoing messages. Specify if the server shouldn't send quit messages if the server reached the intermission state (End of the Map).");
    g_cvarOutgoing_StripColors = create_cvar(               "amx_matter_bridge_outgoing_strip_colors",              "1",                                                  FCVAR_NONE,       "For outgoing messages. Strip color codes from player names. It will only affect Half-Life and Adrenaline Gamer. No effect in other games.");
    g_cvarOutgoing_DisplayMap = create_cvar(                "amx_matter_bridge_outgoing_display_map",               "1",                                                  FCVAR_NONE,       "For outgoing messages. Display the current map at the start of every session.");
    g_cvarOutgoing_JoinQuit_ShowCount = create_cvar(        "amx_matter_bridge_outgoing_joinquit_count",            "1",                                                  FCVAR_NONE,       "For outgoing messages. Display playercount on each Join/Quit message. No effect if both amx_matter_bridge_outgoing_quit and amx_matter_bridge_outgoing_join are 0.");
    g_cvarForcePrefix = create_cvar(                        "amx_matter_bridge_force_prefix",                       "",                                                   FCVAR_NONE,       "For messages displayed in the in-game chat, the value of this cvar will be always prefixed before the username.");
    g_cvarRetry_Delay = create_cvar(                        "amx_matter_bridge_retry_delay",                        "3.0",                                                FCVAR_NONE,       "In seconds, how long the server has wait before retrying a connection when it was interrupted.");

    AutoExecConfig();

    register_dictionary("matteramxx.txt");

    g_hSayTextUserMessage = get_user_msgid("SayText");

    //TS and SC don't support rendering % 
    if(g_hCurrentGame == GAME_SPECIALISTS || g_hCurrentGame == GAME_SVENCOOP)
        register_dictionary("matteramxx_old.txt");
}

public OnConfigsExecuted()
{
    create_cvar("amx_matter_bridge_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);

    bind_pcvar_num(g_cvarEnabled, g_bEnabled);
    bind_pcvar_string(g_cvarSystemAvatarUrl, g_szSystemAvatarUrl, charsmax(g_szSystemAvatarUrl));
    bind_pcvar_string(g_cvarAutogenAvatarUrl, g_szAutogenAvatarUrl, charsmax(g_szAutogenAvatarUrl));
    bind_pcvar_string(g_cvarAvatarUrl, g_szAvatarUrl, charsmax(g_szAvatarUrl));
    bind_pcvar_string(g_cvarBridgeProtocol, g_szBridgeProtocol, charsmax(g_szBridgeProtocol));
    bind_pcvar_string(g_cvarBridgeHost, g_szBridgeHost, charsmax(g_szBridgeHost));
    bind_pcvar_string(g_cvarBridgePort, g_szBridgePort, charsmax(g_szBridgePort));
    bind_pcvar_string(g_cvarBridgeGateway, g_szGateway, charsmax(g_szGateway));
    bind_pcvar_string(g_cvarToken, g_szBridgeToken, charsmax(g_szBridgeToken));
    bind_pcvar_num(g_cvarIncoming, g_bIncomingMessages);
    bind_pcvar_num(g_cvarIncoming_DontColorize, g_bIncomingDontColorize);
    bind_pcvar_string(g_cvarIncoming_IgnorePrefix, g_szIncomingIgnorePrefix, charsmax(g_szIncomingIgnorePrefix));
    bind_pcvar_float(g_cvarIncoming_RefreshTime, g_fIncomingUpdateTime);
    bind_pcvar_num(g_cvarUseRelayUser, g_bIncomingRelayMessagesOnUser),
    bind_pcvar_num(g_cvarOutgoing, g_bOutgoingMessages);
    bind_pcvar_string(g_cvarOutgoing_SystemUsername, g_szOutgoingSystemUsername, charsmax(g_szOutgoingSystemUsername));
    bind_pcvar_num(g_cvarOutgoing_Chat_Mode, g_iOutgoingChatMode);
    bind_pcvar_num(g_cvarOutgoing_Chat_Passthrough, g_bOutgoingPassthrough);
    bind_pcvar_num(g_cvarOutgoing_Chat_SpamFil, g_bOutgoingNoRepeat);
    bind_pcvar_num(g_cvarOutgoing_Chat_ZeroifyAtSign, g_bOutgoingZwspAt);
    bind_pcvar_string(g_cvarOutgoing_Chat_RequirePrefix, g_szOutgoingRequirePrefix, charsmax(g_szOutgoingRequirePrefix));
    bind_pcvar_num(g_cvarOutgoing_Chat_MuteServer, g_bOutgoingMuteServer);
    bind_pcvar_num(g_cvarOutgoing_Chat_PrefixTeam, g_iOutgoingPrefixTeam);
    bind_pcvar_num(g_cvarOutgoing_Chat_PrefixDeadStatus, g_iOutgoingPrefixDeadStatus);
    bind_pcvar_num(g_cvarOutgoing_Chat_IgnoreBots, g_bOutgoingIgnoreBots);
    bind_pcvar_num(g_cvarOutgoing_Chat_IgnoreHLTV, g_bOutgoingIgnoreHLTV);
    bind_pcvar_num(g_cvarOutgoing_Kills, g_bOutgoingKills);
    bind_pcvar_num(g_cvarOutgoing_Join, g_bOutgoingJoin);
    bind_pcvar_float(g_cvarOutgoing_Join_Wait, g_fOutgoingJoinWait);
    bind_pcvar_float(g_cvarOutgoing_Join_Delay, g_fOutgoingJoinDelay);
    bind_pcvar_num(g_cvarOutgoing_Quit, g_bOutgoingLeave);
    bind_pcvar_num(g_cvarOutgoing_Quit_IgnoreIntermission, g_bOutgoingLeaveIgnoreIntermission);
    bind_pcvar_num(g_cvarOutgoing_StripColors, g_bOutgoingStripColors);
    bind_pcvar_num(g_cvarOutgoing_DisplayMap, g_bOutgoingDisplayMap);
    bind_pcvar_num(g_cvarOutgoing_JoinQuit_ShowCount, g_bOutgoingJoinQuitPlayerCount);
    bind_pcvar_string(g_cvarForcePrefix, g_szForcePrefix, charsmax(g_szForcePrefix));
    bind_pcvar_float(g_cvarRetry_Delay, g_fRetryDelay);
    
    new hCvarTeamPlay = get_cvar_pointer("mp_teamplay");

    if(hCvarTeamPlay)
        bind_pcvar_num(hCvarTeamPlay, g_bTeamPlay);

    if(g_bEnabled)
    {
        PrepareBridgeUrl();

        if(g_bOutgoingMessages)
        {  
            formatex(g_szOutgoingUri, charsmax(g_szOutgoingUri), "%s/api/message", g_szBridgeUrl);
            
            if(g_iOutgoingChatMode > 0)
            {
                register_clcmd("say", "Event_SayMessage_All");
                register_clcmd("say_team", "Event_SayMessage_Team");
            }

            if(g_bOutgoingKills)
            {
            #if USE_HAMSANDWICH > 0
                RegisterHam(g_hCurrentGame == GAME_TEAMFORTRESS ? Ham_TFC_Killed : Ham_Killed, "player", g_hCurrentGame == GAME_TEAMFORTRESS ? "Event_PlayerKilledTFC" : "Event_PlayerKilled", true);
            #else 
                register_event("DeathMsg", "Event_PlayerKilledEV", "a");
            #endif
            }

            if(g_fOutgoingJoinDelay > 0.0)
                set_task(g_fOutgoingJoinDelay, "Task_JoinDelayDone");
            else
                Task_JoinDelayDone();

            if(!g_bOutgoingLeaveIgnoreIntermission)
                register_message(SVC_INTERMISSION, "Event_Intermission");

            replace_all(g_szForcePrefix, charsmax(g_szForcePrefix), "!n", "^1");
            replace_all(g_szForcePrefix, charsmax(g_szForcePrefix), "!r", "^3");
            replace_all(g_szForcePrefix, charsmax(g_szForcePrefix), "!b", "^3");
            replace_all(g_szForcePrefix, charsmax(g_szForcePrefix), "!g", "^4");
            replace_all(g_szForcePrefix, charsmax(g_szForcePrefix), "!t", TEAM_COLOR_PLACEHOLDER);
        }
        
        if(g_bIncomingMessages)
        {
            formatex(g_szIncomingUri, charsmax(g_szIncomingUri), "%s/api/messages", g_szBridgeUrl);

            g_hPrintMessageForward = CreateMultiForward("matteramxx_print_message", ET_STOP, FP_STRING, FP_STRING, FP_STRING, FP_STRING);

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::plugin_cfg() - g_fIncomingUpdateTime is %f", __BINARY__, g_fIncomingUpdateTime);

            set_task(g_fIncomingUpdateTime, "MatterConnectAPI");

            if(!empty(g_szIncomingIgnorePrefix))
                g_hPrefix_Pattern = regex_compile(g_szIncomingIgnorePrefix);
        }

        g_iPluginFlags = plugin_flags();
    }
    else
        pause("ad");
}

public PrepareBridgeUrl()
{
    formatex(g_szBridgeUrl, charsmax(g_szBridgeUrl), "%s://%s", g_szBridgeProtocol, g_szBridgeHost);
    if(!empty(g_szBridgePort))
    {
        add(g_szBridgeUrl, charsmax(g_szBridgeUrl), ":");
        add(g_szBridgeUrl, charsmax(g_szBridgeUrl), g_szBridgePort);
    }
}

public plugin_end()
{
    DestroyForward(g_hPrintMessageForward);
}

public Task_JoinDelayDone()
{
    g_bJoinDelayDone = true;
    if(g_bOutgoingDisplayMap && get_playersnum_ex(GetPlayers_IncludeConnecting | (g_bOutgoingIgnoreBots ? GetPlayers_ExcludeBots : GetPlayers_None) | (g_bOutgoingIgnoreHLTV ? GetPlayers_ExcludeHLTV : GetPlayers_None)) > 0)
    {
        new sMapName[32], szMessage[MESSAGE_LENGTH];
        get_mapname(sMapName, charsmax(sMapName));
        formatex(szMessage, charsmax(szMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_MAP_CHANGED", sMapName);

        new EzJSON:hJson = ezjson_init_object();
        ezjson_object_set_string(hJson, "text", szMessage);
        ezjson_object_set_string(hJson, "username", g_szOutgoingSystemUsername);
        if(!empty(g_szSystemAvatarUrl))
            ezjson_object_set_string(hJson, "avatar", g_szSystemAvatarUrl);
        ezjson_object_set_string(hJson, "userid", SYSMES_ID);

        send_message_rest(hJson, g_szGateway);
    }
}

public Event_Intermission()
{
    g_bIsIntermission = true;
}

public MatterConnectAPI()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::MatterConnectAPI() - Called", __BINARY__);

    new EzHttpOptions:ezIncomingHeader = ezhttp_create_options();

    if(!empty(g_szBridgeToken))
    {
        new szTokenHeader[JSON_PARAMETER_LENGTH];
        formatex(szTokenHeader, charsmax(szTokenHeader), "Bearer %s", g_szBridgeToken);
        ezhttp_option_set_header(ezIncomingHeader, "Authorization", szTokenHeader);
    }
    
    ezhttp_get(g_szIncomingUri, "MatterIncomingMessage", ezIncomingHeader);
}

public MatterRetryConnection()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::MatterRetryConnection() - Called", __BINARY__);

    server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_RETRYING", floatround(g_fRetryDelay));
    set_task(g_fRetryDelay, "MatterConnectAPI");
}

public MatterIncomingMessage(EzHttpRequest:request)
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::MatterIncomingMessage() - Called", __BINARY__);

    if(ezhttp_get_error_code(request) != EZH_OK)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_CONN_FAILED");
        MatterRetryConnection();
        return;
    }

    new szIncomingMessage[INCOMING_BUFFER_LENGTH], EzJSON:hJson;

    new EzJSON:hRequestHandle = ezhttp_parse_json_response(request);

    if(hRequestHandle == EzInvalid_JSON)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] %s::MatterIncomingMessage() - Json Error", __BINARY__);

        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_INVALID");
        set_task(g_fRetryDelay, "MatterConnectAPI");
        return;
    }
    
    ezjson_serial_to_string(hRequestHandle, szIncomingMessage, charsmax(szIncomingMessage));

    replace_all(szIncomingMessage, charsmax(szIncomingMessage), "^%", "");

    hJson = ezjson_parse(szIncomingMessage);

    if(ezjson_get_type(hJson) == EzJSONObject)
    {
        new sErrorMessage[INCOMING_BUFFER_LENGTH];
        ezjson_object_get_string(hJson, "message", sErrorMessage, charsmax(sErrorMessage));
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_ERROR", sErrorMessage);
        ezjson_free(hJson);
        set_fail_state(sErrorMessage);
        return;
    }

    for(new x = 0; x < ezjson_array_get_count(hJson); x++)
    {
        new szMessageGateway[MAX_NAME_LENGTH];
        new EzJSON:hCurrentMessage = ezjson_array_get_value(hJson, x);
        ezjson_object_get_string(hCurrentMessage, "gateway", szMessageGateway, charsmax(szMessageGateway));
        if(!equali(g_szGateway, szMessageGateway))
            continue;
        
        new szMessageBody[MESSAGE_LENGTH], szUserName[MAX_NAME_LENGTH], szProtocol[MAX_NAME_LENGTH], szUserIdentifier[MAX_NAME_LENGTH];
        ezjson_object_get_string(hCurrentMessage, "userid", szUserIdentifier, charsmax(szUserIdentifier));
        if(equal(szUserIdentifier, SYSMES_ID))
        {
            server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_SYSMSG_NOT_SENT");
            continue;
        }
        ezjson_object_get_string(hCurrentMessage, "text", szMessageBody, charsmax(szMessageBody));
        ezjson_object_get_string(hCurrentMessage, "username", szUserName, charsmax(szUserName));
        ezjson_object_get_string(hCurrentMessage, "protocol", szProtocol, charsmax(szProtocol));

        MatterPrintMessage(szMessageBody, szUserName, szProtocol, szUserIdentifier);

        ezjson_free(hCurrentMessage);
    }

    ezjson_free(hJson);

    set_task(g_fIncomingUpdateTime, "MatterConnectAPI");
}

public MatterPrintMessage(const szMessage[], szUserName[MAX_NAME_LENGTH], szProtocol[MAX_NAME_LENGTH], szUserIdentifier[MAX_NAME_LENGTH])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
    {
        server_print("[DEBUG] %s::MatterPrintMessage() - Called", __BINARY__);
        server_print("[DEBUG] %s::MatterPrintMessage() - szMessage is %s", __BINARY__, szMessage);
        server_print("[DEBUG] %s::MatterPrintMessage() - szUserName is %s", __BINARY__, szUserName);
        server_print("[DEBUG] %s::MatterPrintMessage() - szProtocol is %s", __BINARY__, szProtocol);
        server_print("[DEBUG] %s::MatterPrintMessage() - szUserIdentifier is %s", __BINARY__, szUserIdentifier);
    }

    new iReturnVal = 0;
    new szMessageNew[MESSAGE_LENGTH];
    ExecuteForward(g_hPrintMessageForward, iReturnVal, szMessage, szUserName, szProtocol, szUserIdentifier);

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::MatterPrintMessage() - iReturnVal is %d", __BINARY__, iReturnVal);

    switch(iReturnVal)
    {
        case 0:
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::MatterPrintMessage() - Check prefix value", __BINARY__);

            if(prefix_matches(szMessage))
                return;

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::MatterPrintMessage() - Not returning", __BINARY__);

            if(empty(szUserName))
                copy(szUserName, charsmax(szUserName), g_szOutgoingSystemUsername);
            if(empty(szProtocol))
                copy(szProtocol, charsmax(szProtocol), g_szGamename);

            if(g_hCurrentGame == GAME_CSTRIKE || g_hCurrentGame == GAME_CZERO || g_hCurrentGame == GAME_DOD) 
            {
                new bool:bIsRed = containi(szUserName, "!b") ? false : true;

                replace_all(szUserName, charsmax(szUserName), "!n", "^1");
                replace_all(szUserName, charsmax(szUserName), "!r", "^3");
                replace_all(szUserName, charsmax(szUserName), "!b", "^3");
                replace_all(szUserName, charsmax(szUserName), "!g", "^4");
                replace_all(g_szForcePrefix, charsmax(g_szForcePrefix), "!t", TEAM_COLOR_PLACEHOLDER);

                if(strlen(g_szForcePrefix) > 0)
                    formatex(szMessageNew, charsmax(szMessageNew), g_bIncomingDontColorize ? "%s %s^1: %s" : "^4%s %s^1: %s", g_szForcePrefix, szUserName, szMessage);
                else
                    formatex(szMessageNew, charsmax(szMessageNew), g_bIncomingDontColorize ? "%s^1: %s" : "^4%s^1: %s", szUserName, szMessage);

                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[DEBUG] %s::MatterPrintMessage() - szMessageNew %s", __BINARY__, szMessageNew);

                client_print_color(0, bIsRed ? print_team_red : print_team_blue, szMessageNew); 
            }
            else  
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[DEBUG] %s::MatterPrintMessage() - Not Counter-Strike", __BINARY__);

                if(g_bIncomingRelayMessagesOnUser)
                {
                    if(g_iPluginFlags & AMX_FLAG_DEBUG)
                        server_print("[DEBUG] %s::MatterPrintMessage() - g_bIncomingRelayMessagesOnUser", __BINARY__);

                    PrintRelayUser(szMessage, szUserName);
                }
                else
                {
                    //so far all goldsrc games have the init string control character at the start
                    if(strlen(g_szForcePrefix) > 0)
                        formatex(szMessageNew, charsmax(szMessageNew), "%s %s: %s", g_szForcePrefix, szUserName, szMessage);
                    else
                        formatex(szMessageNew, charsmax(szMessageNew), "%s: %s", szUserName, szMessage);
                    
                    client_print(0, print_chat, szMessageNew);
                }
            } 
        }
        case 1:
        {
            server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_API_SUPERCEDED", szMessage);
        }
    }  
}

PrintRelayUser(const szMessage[], const szUserName[], iClient = 0)
{
    new szFixedUserName[MAX_NAME_LENGTH];
    copy(szFixedUserName, charsmax(szFixedUserName), szUserName);

    // the following symbols are known to glitch out the chat
    replace_all(szFixedUserName, charsmax(szFixedUserName), "#", "¤");
    // replace_all(szFixedUserName, charsmax(szFixedUserName), "@", "¤"); // apparently it only causes problems in Windows clients

    new szTemporaryNameBuffer[MAX_NAME_LENGTH], szUserInfoBuffer[256];
    new bool:bShouldRevertName = false;
    if(iClient == 0)
    {
        // we need to use a player as a relay to preserve correct text rendering
        iClient = get_suitable_target();
        if(iClient > 0)
        {
            bShouldRevertName = true;
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::PrintRelayUser() - Renaming client %d to %s", __BINARY__, iClient, szFixedUserName);

            get_user_name(iClient, szTemporaryNameBuffer, charsmax(szTemporaryNameBuffer));
            set_user_info(iClient, "name", szFixedUserName);
            copy_infokey_buffer(engfunc(EngFunc_GetInfoKeyBuffer, iClient), szUserInfoBuffer, charsmax(szUserInfoBuffer));
            message_begin(MSG_ALL, SVC_UPDATEUSERINFO);
            write_byte(iClient - 1);
            write_long(get_user_userid(iClient));
            write_string(szUserInfoBuffer);
            write_long(0);
            write_long(0);
            write_long(0);
            write_long(0);
            message_end();
        }
    }

    new szFormattedMessage[MESSAGE_LENGTH];

    if(strlen(g_szForcePrefix) > 0)
        formatex(szFormattedMessage, charsmax(szFormattedMessage), "^2%s %s: %s ^n", g_szForcePrefix, szFixedUserName, szMessage);
    else
        formatex(szFormattedMessage, charsmax(szFormattedMessage), "^2%s: %s ^n", szFixedUserName, szMessage);

    if(g_bOutgoingMuteServer) 
    {
        if(iClient != 0)
        {
            //id of zero and muteserver should never happen, this is for added security
            message_begin(MSG_ONE, g_hSayTextUserMessage, _, iClient);
            write_byte(iClient);
            write_string(szFormattedMessage);
            message_end();
        }
    }
    else
    {
        message_begin(MSG_ALL, g_hSayTextUserMessage);
        write_byte(iClient);
        write_string(szFormattedMessage);
        message_end();
    }

    replace_all(szFormattedMessage, charsmax(szFormattedMessage), "^n", "");

    server_print(szFormattedMessage);

    if(bShouldRevertName)
    {
        set_user_info(iClient, "name", szTemporaryNameBuffer);
        copy_infokey_buffer(engfunc(EngFunc_GetInfoKeyBuffer, iClient), szUserInfoBuffer, charsmax(szUserInfoBuffer));
        message_begin(MSG_ALL, SVC_UPDATEUSERINFO);
        write_byte(iClient - 1);
        write_long(get_user_userid(iClient));
        write_string(szUserInfoBuffer);
        write_long(0);
        write_long(0);
        write_long(0);
        write_long(0);
        message_end();
    }
}


public Event_SayMessage_All(iClient)
{
    if(g_iOutgoingChatMode & CHAT_TYPE_ALL)
        return SayMessage_Process(iClient, CHAT_TYPE_ALL);

    return PLUGIN_CONTINUE;
}

public Event_SayMessage_Team(iClient)
{
    
    if(g_iOutgoingChatMode & CHAT_TYPE_TEAM)
        return SayMessage_Process(iClient, CHAT_TYPE_TEAM);

    return PLUGIN_CONTINUE;
}

SayMessage_Process(iClient, iMessageSource)
{
    if(is_user_bot(iClient) && g_bOutgoingIgnoreBots)
        return PLUGIN_CONTINUE;

    if(is_user_hltv(iClient) && g_bOutgoingIgnoreHLTV)
        return PLUGIN_CONTINUE;

    new szMessage[MESSAGE_LENGTH], szUserName[MAX_NAME_LENGTH], szSteamId[MAX_NAME_LENGTH];
    read_args(szMessage, charsmax(szMessage));

    remove_quotes(szMessage);
    replace_all(szMessage, charsmax(szMessage), "^"", "\^"");

    if((g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER) && g_bOutgoingStripColors)
        strip_colors_from_string(szMessage);

    trim(szMessage);

    if(strlen(szMessage) == 0)
        return PLUGIN_CONTINUE;

    new bIsSpectator = false;

    if(g_iOutgoingPrefixTeam & iMessageSource)
    {
        if(g_hCurrentGame == GAME_SVENCOOP || g_hCurrentGame == GAME_RICOCHET || ((g_hCurrentGame == GAME_SPECIALISTS || g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER || g_hCurrentGame == GAME_OPFOR || g_hCurrentGame == GAME_DMC) && !g_bTeamPlay))
            format(szMessage, charsmax(szMessage), "%s %s", TEAM_0_SYMBOL, szMessage);
        else
        {
            new iTeam = get_user_team(iClient);
            new szTeamSymbol[8];

            if(g_hCurrentGame == GAME_CSTRIKE || g_hCurrentGame == GAME_CZERO)
            {
                switch (iTeam)
                {
                    case 1: 
                        copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_2_SYMBOL); //terrorists
                    case 2: 
                        copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_1_SYMBOL); //counter-terrorists
                    default: 
                    {
                        bIsSpectator = true;
                        copy(szTeamSymbol, charsmax(szTeamSymbol), SPECTATOR_SYMBOL); 
                    }
                }
            }
            else
            {
                if(pev(iClient, pev_iuser1) != 0)
                {
                    bIsSpectator = true;
                    copy(szTeamSymbol, charsmax(szTeamSymbol), SPECTATOR_SYMBOL); 
                }
                else
                {
                    #if defined _hlstocks_included
                    if(g_hCurrentGame == GAME_SPECIALISTS || g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER || g_hCurrentGame == GAME_OPFOR || g_hCurrentGame == GAME_DMC)
                        iTeam = __get_user_team(iClient);
                    #endif

                    new iLoopedTeam = ((iTeam - 1) % 5) + 1;

                    switch (iLoopedTeam)
                    {
                        case 1: copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_1_SYMBOL);
                        case 2: copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_2_SYMBOL);
                        case 3: copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_3_SYMBOL);
                        case 4: copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_4_SYMBOL);
                        case 5: copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_5_SYMBOL);
                        default: copy(szTeamSymbol, charsmax(szTeamSymbol), TEAM_0_SYMBOL);
                    }
                }
            }

            format(szMessage, charsmax(szMessage), "%s %s", szTeamSymbol, szMessage);
        }
    }

    if(g_iOutgoingPrefixDeadStatus & iMessageSource && !is_user_alive(iClient) && !bIsSpectator)
        format(szMessage, charsmax(szMessage), "%s %s", DEAD_SYMBOL, szMessage);

    if(!empty(g_szOutgoingRequirePrefix) && szMessage[0] != g_szOutgoingRequirePrefix[0])
        return PLUGIN_CONTINUE;
    else if(!empty(g_szOutgoingRequirePrefix))
        format(szMessage, charsmax(szMessage), "%s" , szMessage[strlen(g_szOutgoingRequirePrefix)]); 

    if(g_bOutgoingZwspAt)
        replace_all(szMessage, charsmax(szMessage), "@", "@​");

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::Event_SayMessage() - Message ^"%s^" was sent.", __BINARY__, szMessage);

    if(empty(szMessage) || (g_bOutgoingNoRepeat && equal(szMessage, g_szLastMessages[iClient])))
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] %s::Event_SayMessage() - First condition returned false, returning.", __BINARY__);
            server_print("[DEBUG] %s::Event_SayMessage() - (Message length was %i)", __BINARY__, strlen(szMessage));
        }
        return PLUGIN_CONTINUE;
    }

    if(g_bOutgoingNoRepeat)
        g_szLastMessages[iClient] = szMessage;

    new EzJSON:hJson = ezjson_init_object();

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::Event_SayMessage() - Preparing json object.", __BINARY__);
    
    if(iClient)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] %s::Event_SayMessage() - iClient is %i.", __BINARY__, iClient);
        if((g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER) && g_bOutgoingStripColors)
            get_colorless_name(iClient, szUserName, charsmax(szUserName));
        else
            get_user_name(iClient, szUserName, charsmax(szUserName));

        get_user_info(iClient, "*sid", szSteamId, charsmax(szSteamId));

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] %s::Event_SayMessage() - Fullname is %s.", __BINARY__, szUserName);
            server_print("[DEBUG] %s::Event_SayMessage() - Steam ID is %s.", __BINARY__, szSteamId);
        }

        if(!empty(szSteamId))
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::Event_SayMessage() - Steam ID is from a player.", __BINARY__);
            new sAvatarUrlFull[TARGET_URL_LENGTH];
            if(g_bUserAuthenticated[iClient])
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[DEBUG] %s::Event_SayMessage() - User is authenticated.", __BINARY__);
                if(!empty(g_szAvatarUrl))
                    formatex(sAvatarUrlFull, charsmax(sAvatarUrlFull), g_szAvatarUrl, szSteamId);
            }
            else
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[DEBUG] %s::Event_SayMessage() - User not is authenticated.", __BINARY__);
                if(!empty(g_szAutogenAvatarUrl))
                {
                    new sEncodedName[MAX_NAME_LENGTH];
                    url_encode(szUserName, sEncodedName, charsmax(sEncodedName));
                    formatex(sAvatarUrlFull, charsmax(sAvatarUrlFull), g_szAutogenAvatarUrl, sEncodedName);
                }
            }

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::Event_SayMessage() - Resulting avatar URL is %s.", __BINARY__, sAvatarUrlFull);

            if(!empty(sAvatarUrlFull))
                ezjson_object_set_string(hJson, "avatar", sAvatarUrlFull);
        }
        else if(!empty(g_szSystemAvatarUrl))
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::Event_SayMessage() - The server sent this message.", __BINARY__);
            ezjson_object_set_string(hJson, "avatar", g_szSystemAvatarUrl);
        }
    } 

    ezjson_object_set_string(hJson, "text", szMessage);
    ezjson_object_set_string(hJson, "username", (iClient) ? szUserName : g_szOutgoingSystemUsername);
    ezjson_object_set_string(hJson, "userid", (iClient) ? szSteamId : "GAME_CONSOLE");

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::Event_SayMessage() - I'm going to send the message.", __BINARY__);
    send_message_rest(hJson, g_szGateway);

    if(g_bOutgoingPassthrough)
    {
        if(g_bIncomingRelayMessagesOnUser)
        {
            PrintRelayUser(szMessage, szUserName, iClient);
            return PLUGIN_HANDLED;
        }
        else
        {
            new szMessageNew[MESSAGE_LENGTH];
            if(strlen(g_szForcePrefix) == 0)
            {
                if(g_bOutgoingMuteServer)
                {
                    formatex(szMessageNew, charsmax(szMessageNew), "(YOU) %s%s: %s", szUserName, cstrike_running() ? "^1" : "", szMessage);
                    if(cstrike_running())
                        client_print_color(iClient, iClient, szMessageNew);
                    else
                        client_print(iClient, print_chat, szMessageNew);
                    return PLUGIN_HANDLED;
                }
                else
                    return PLUGIN_CONTINUE;
            }
            else
            {
                if(cstrike_running())
                {
                    formatex(szMessageNew, charsmax(szMessageNew), "%s %s%s%s: %s", g_szForcePrefix, 0 < iClient && iClient <= MAX_PLAYERS ? "^3" : "^4", szUserName, cstrike_running() ? "^1" : "", szMessage);
                    client_print_color(g_bOutgoingMuteServer ? iClient : 0, iClient, szMessageNew);
                }
                else
                {
                    formatex(szMessageNew, charsmax(szMessageNew), "%s %s%s: %s", g_szForcePrefix, szUserName, cstrike_running() ? "^1" : "", szMessage);
                    client_print(g_bOutgoingMuteServer ? iClient : 0, print_chat, szMessageNew);
                }
            }

            //Matterbridge messages already come with a line end character, this ensures correct console display
            replace_all(szMessage, charsmax(szMessage), "^n", ""); 
            
            server_print("%s: %s", szUserName, szMessage);
            return PLUGIN_HANDLED;
        }
    }
    else
        return PLUGIN_CONTINUE;
}

public Event_PlayerKilledEV()
{
    new iAttacker = read_data(1);
    new iClient = read_data(2);

    Event_PlayerKilled(iClient, iAttacker);
}

public Event_PlayerKilledTFC(iClient, iInflictor, iAttacker)
{
    Event_PlayerKilled(iClient, iAttacker);
}

public Event_PlayerKilled(iClient, iAttacker)
{
    new szUserName[MAX_NAME_LENGTH], szAttackerName[MAX_NAME_LENGTH], szMessage[MESSAGE_LENGTH];
    
    if((g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER) && g_bOutgoingStripColors)
        get_colorless_name(iClient, szUserName, charsmax(szUserName));
    else
        get_user_name(iClient, szUserName, charsmax(szUserName));

    if(is_user_connected(iAttacker))
    {
        if(is_user_bot(iAttacker) && g_bOutgoingIgnoreBots)
            return;

        if(is_user_hltv(iAttacker) && g_bOutgoingIgnoreHLTV)
            return;
            
        if((g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER) && g_bOutgoingStripColors)
            get_colorless_name(iAttacker, szAttackerName, charsmax(szAttackerName));
        else
            get_user_name(iAttacker, szAttackerName, charsmax(szAttackerName));
    }
    else
        pev(iAttacker, pev_classname, szAttackerName, charsmax(szAttackerName)); //todo: get the monster name in Sven Co-op

    replace_all(szUserName, charsmax(szUserName), "^"", "");
    replace_all(szAttackerName, charsmax(szAttackerName), "^"", ""); 

    formatex(szMessage, charsmax(szMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_KILLED", szUserName, szAttackerName);

    new EzJSON:hJson = ezjson_init_object();

    ezjson_object_set_string(hJson, "text", szMessage);
    ezjson_object_set_string(hJson, "username", g_szOutgoingSystemUsername);
    if(!empty(g_szSystemAvatarUrl))
        ezjson_object_set_string(hJson, "avatar", g_szSystemAvatarUrl);
    ezjson_object_set_string(hJson, "userid", SYSMES_ID);

    send_message_rest(hJson, g_szGateway);
}

public send_message_custom(iPlugin, iParams)
{
    // we can manage backwards compatiblity ths way
    new szMessage[MESSAGE_LENGTH], szUsername[MAX_NAME_LENGTH], szAvatar[TARGET_URL_LENGTH], sGateway[MAX_NAME_LENGTH];
    
    get_string(1, szMessage, charsmax(szMessage));
    get_string(2, szUsername, charsmax(szUsername));
    get_string(3, szAvatar, charsmax(szAvatar));
    new bool:bSystem = get_param(4) == 1;
    get_string(5, sGateway, charsmax(sGateway));

    new EzJSON:hJson = ezjson_init_object();

    ezjson_object_set_string(hJson, "text", szMessage);
    ezjson_object_set_string(hJson, "username", empty(szUsername) ? g_szOutgoingSystemUsername : szUsername);
    ezjson_object_set_string(hJson, "avatar", empty(szAvatar) ? g_szSystemAvatarUrl : szAvatar);
    ezjson_object_set_string(hJson, "userid", bSystem ? SYSMES_ID : "");

    send_message_rest(hJson, empty(sGateway) ? g_szGateway : sGateway);
}

public outgoing_message(EzHttpRequest:hRequest)
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
    {
        server_print("[DEBUG] %s::Event_SayMessage() - I sent the message. Response State is %d", __BINARY__, ezhttp_get_error_code(hRequest));
        new sResponse[INCOMING_BUFFER_LENGTH];
        new EzJSON:hRequestHandle = ezhttp_parse_json_response(hRequest);

        if (hRequestHandle == EzInvalid_JSON)
        {
            server_print("[DEBUG] %s::Event_SayMessage() - Json Error", __BINARY__);
            return;
        }
        else
        {
            ezjson_serial_to_string(hRequestHandle, sResponse, charsmax(sResponse));
            server_print("[DEBUG] %s::Event_SayMessage() - Server said: %s", __BINARY__, sResponse);
        }
        
    }

    if(ezhttp_get_error_code(hRequest) != EZH_OK)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_MSG_FAILED"); //to do: why?
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            new szIncomingMessage[MESSAGE_LENGTH];
            new EzJSON:hRequestHandle = ezhttp_parse_json_response(hRequest);
            ezjson_serial_to_string(hRequestHandle, szIncomingMessage, charsmax(szIncomingMessage));
            server_print(szIncomingMessage);
        }
    }
}

public client_authorized(iClient)
{
    new szAuthId[MAX_AUTHID_LENGTH];
    get_user_authid(iClient, szAuthId, charsmax(szAuthId));
    if(is_valid_authid(szAuthId))
        g_bUserAuthenticated[iClient] = 1;
}

#if USE_DEPRECATED_DISCONNECT_FORWARD
public client_disconnect(iClient)
{
    if(g_hCurrentGame == GAME_SVENCOOP)
    {
        //ditto plugin_init()
        HandleDisconnectEvent(iClient);
    }
}
#endif

public client_disconnected(iClient)
{
    if(g_hCurrentGame != GAME_SVENCOOP)
    {
        //ditto plugin_init()
        HandleDisconnectEvent(iClient);
    }
}

HandleDisconnectEvent(iClient)
{
    g_bUserAuthenticated[iClient] = 0;
    if(!g_bIsIntermission && g_bOutgoingLeave && !is_user_bot(iClient) && g_bUserConnected[iClient])
    {
        if(is_user_bot(iClient) && g_bOutgoingIgnoreBots)
            return;

        if(is_user_hltv(iClient) && g_bOutgoingIgnoreHLTV)
            return;
            
        new szUserName[MAX_NAME_LENGTH], szMessage[MESSAGE_LENGTH];
        if((g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER) && g_bOutgoingStripColors)
            get_colorless_name(iClient, szUserName, charsmax(szUserName));
        else
            get_user_name(iClient, szUserName, charsmax(szUserName));
        replace_all(szUserName, charsmax(szUserName), "^"", "");

        if(g_bOutgoingJoinQuitPlayerCount)
            formatex(szMessage, charsmax(szMessage), "%L [%d/%d]", LANG_SERVER, "MATTERAMXX_MESSAGE_LEFT", szUserName, get_playersnum_ex((g_bOutgoingIgnoreBots ? GetPlayers_ExcludeBots : GetPlayers_None) | (g_bOutgoingIgnoreHLTV ? GetPlayers_ExcludeHLTV : GetPlayers_None))-1, get_maxplayers());
        else
            formatex(szMessage, charsmax(szMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_LEFT", szUserName);
        g_bUserConnected[iClient] = false;
        
        new EzJSON:hJson = ezjson_init_object();
        ezjson_object_set_string(hJson, "text", szMessage);
        ezjson_object_set_string(hJson, "username", g_szOutgoingSystemUsername);
        if(!empty(g_szSystemAvatarUrl))
            ezjson_object_set_string(hJson, "avatar", g_szSystemAvatarUrl);
        ezjson_object_set_string(hJson, "userid", SYSMES_ID);

        send_message_rest(hJson, g_szGateway);
    }
}

public client_putinserver(iClient)
{
    if(g_bOutgoingJoin && g_bJoinDelayDone)
    {
        if(g_fOutgoingJoinWait > 0.0)
            set_task(g_fOutgoingJoinWait, "client_putinserver_delayed", get_user_userid(iClient));
        else
            ShowJoinMessage(iClient);
    }
}

public client_putinserver_delayed(iUserId)
{
    new iClient = find_player_ex(FindPlayer_MatchUserId, iUserId);
    if(iClient)
        ShowJoinMessage(iClient);
}

ShowJoinMessage(iClient)
{
    if(is_user_bot(iClient) && g_bOutgoingIgnoreBots)
        return;

    if(is_user_hltv(iClient) && g_bOutgoingIgnoreHLTV)
        return;

    new szUserName[MAX_NAME_LENGTH], szMessage[MESSAGE_LENGTH];

    if((g_hCurrentGame == GAME_VALVE || g_hCurrentGame == GAME_ADRENALINE_GAMER) && g_bOutgoingStripColors)
        get_colorless_name(iClient, szUserName, charsmax(szUserName));
    else
        get_user_name(iClient, szUserName, charsmax(szUserName));

    replace_all(szUserName, charsmax(szUserName), "^"", "");

    if(g_bOutgoingJoinQuitPlayerCount)
        formatex(szMessage, charsmax(szMessage), "%L [%d/%d]", LANG_SERVER, "MATTERAMXX_MESSAGE_JOINED", szUserName, get_playersnum_ex((g_bOutgoingIgnoreBots ? GetPlayers_ExcludeBots : GetPlayers_None) | (g_bOutgoingIgnoreHLTV ? GetPlayers_ExcludeHLTV : GetPlayers_None)), get_maxplayers());
    else
        formatex(szMessage, charsmax(szMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_JOINED", szUserName);
    
    g_bUserConnected[iClient] = true;
    g_szLastMessages[iClient] = "";
    
    new EzJSON:hJson = ezjson_init_object();
    ezjson_object_set_string(hJson, "text", szMessage);
    ezjson_object_set_string(hJson, "username", g_szOutgoingSystemUsername);
    if(!empty(g_szSystemAvatarUrl))
        ezjson_object_set_string(hJson, "avatar", g_szSystemAvatarUrl);
    ezjson_object_set_string(hJson, "userid", SYSMES_ID);

    send_message_rest(hJson, g_szGateway);
}

stock get_suitable_target()
{
    // First try to find HLTV proxy
    for (new iClient = 1; iClient <= MaxClients; iClient++) 
    {
        if (is_user_connected(iClient) && is_user_hltv(iClient))
            return iClient;
    }
    
    // Next try to find a bot
    for (new iClient = 1; iClient <= MaxClients; iClient++) 
    {
        if (is_user_connected(iClient) && is_user_bot(iClient))
            return iClient;
    }
    
    // Next try to find a regular player
    for (new iClient = 1; iClient <= MaxClients; iClient++) 
    {
        if (is_user_connected(iClient) && !is_user_bot(iClient) && !is_user_hltv(iClient))
            return iClient;
    }
    
    // If nothing found, return zero
    return 0;
}

stock empty(const szString[])
{
    return !szString[0];
}

//thanks to YaLTeR
stock get_colorless_name(iClient, szName[], iLen)
{
    get_user_name(iClient, szName, iLen);
    strip_colors_from_string(szName);
}

stock strip_colors_from_string(szMessage[])
{
	// Clear out color codes
	new i, j;
	new const hat[3] = "^^";
	while(szMessage[i])
	{
		if(szMessage[i] == hat[0] && szMessage[i + 1] >= '0' && szMessage[i + 1] <= '9')
		{
			i++;
		}
		else
		{
			if(j != i)
				szMessage[j] = szMessage[i];
			j++;
		}
		i++;
	}
	szMessage[j] = 0;
}

//thanks to Th3-822
stock url_encode(const szString[], szResult[], iLen)
{
    new from, c, to;

    while(from < iLen)
    {
        c = szString[from++];
        if(c == 0)
        {
            szResult[to++] = c;
            break;
        }
        else if(c == ' ')
        {
            szResult[to++] = '_';
        }
        else if(!(0 <= c <= 255))
        { // UTF-8 Fix (Doesn't encode put .)
            szResult[to++] = '_';
        }
        else if((c < '0' && c != '-' && c != '.') ||
                (c < 'A' && c > '9') ||
                (c > 'Z' && c < 'a' && c != '_') ||
                (c > 'z'))
        {
            if((to + 3) > iLen)
            {
                szResult[to] = 0;
                break;
            }
            // UTF-8 Fix - Need to check real c values.
            /* if(c < 0) c = 256 + c; */
            szResult[to++] = '_';
            szResult[to++] = sHexTable[c >> 4];
            szResult[to++] = sHexTable[c & 15];
        }
        else
        {
            szResult[to++] = c;
        }
    }
}

stock send_message_rest(EzJSON:hJson, const szGateway[])
{
    ezjson_object_set_string(hJson, "gateway", szGateway);
    ezjson_object_set_string(hJson, "protocol", g_szGamename);

    new szPayload[MESSAGE_LENGTH];
    ezjson_serial_to_string(hJson, szPayload, charsmax(szPayload));

    new EzHttpOptions:ezOutgoingHeader = ezhttp_create_options();

    ezhttp_option_set_header(ezOutgoingHeader, "Content-Type", "application/json");

    if(!empty(g_szBridgeToken))
    {
        new szTokenHeader[JSON_PARAMETER_LENGTH];
        formatex(szTokenHeader, charsmax(szTokenHeader), "Bearer %s", g_szBridgeToken);
        ezhttp_option_set_header(ezOutgoingHeader, "Authorization", szTokenHeader);
    }

    ezhttp_option_set_body(ezOutgoingHeader, szPayload);
    ezhttp_post(g_szOutgoingUri, "outgoing_message", ezOutgoingHeader);

    ezjson_free(hJson);
}

stock is_valid_authid(szAuthId[]) 
{
    return regex_match_c(szAuthId, g_hAuthId_Pattern) > 0;
}

stock prefix_matches(const szMessage[]) 
{
    return regex_match_c(szMessage, g_hPrefix_Pattern) > 0;
}