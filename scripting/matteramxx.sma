// ** COMPILER OPTIONS **

// enable if you want to use HamSandwich (recommended)
// disable if you want to use DeathMsg, for example
// in games that do not have HamSandwich support
#define USE_HAMSANDWICH 1

// enable if you want to use extended string buffers, 
// most of the time you won't need it, but you may 
// enable it if you have problems with messages.
// note that this will cause this plugin to be more heavy
#define USE_EXTENDED_BUFFER 0

// ** COMPILER OPTIONS END HERE **

#if USE_EXTENDED_BUFFER > 0
    #pragma dynamic 65536
#else
    #pragma dynamic 32768
#endif

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <regex>
#include <fun>

#if USE_HAMSANDWICH > 0
    #include <hamsandwich>
#endif

#include <grip>

#if USE_EXTENDED_BUFFER > 0
    #define INCOMING_BUFFER_LENGTH 10240
    #define TARGET_URL_LENGTH 2048
    #define MESSAGE_LENGTH 1024
    #define BASE_URL_LENGTH 512
    #define JSON_PARAMETER_LENGTH 512
    #define TOKEN_LENGTH 128
#else
    #define INCOMING_BUFFER_LENGTH 5120
    #define TARGET_URL_LENGTH 1024
    #define MESSAGE_LENGTH 512
    #define BASE_URL_LENGTH 256
    #define JSON_PARAMETER_LENGTH 256
    #define TOKEN_LENGTH 64
#endif

#if AMXX_VERSION_NUM < 183
    #define MAX_PLAYERS 32
    #define MAX_NAME_LENGTH 32
#endif

#define REGEX_STEAMID_PATTERN       "^^STEAM_(0|1):(0|1):\d+$"

#define SYSMES_ID                   "0xDEADBEEF"

#define FAKEBOT_TASK_ID             3526373

#define MATTERAMXX_PLUGIN_NAME      "MatterAMXX"
#define MATTERAMXX_PLUGIN_AUTHOR    "szGabu"
#define MATTERAMXX_PLUGIN_VERSION   "1.6-dev"

#define TEAM_COLOR_PLACEHOLDER      "$%&/"

#pragma semicolon 1

new g_cvarEnabled;
new g_cvarSystemAvatarUrl;
new g_cvarAutogenAvatarUrl;
new g_cvarAvatarUrl;
new g_cvarBridgeProtocol;
new g_cvarBridgeHost;
new g_cvarBridgePort;
new g_cvarBridgeGateway;
new g_cvarToken;
new g_cvarUseFakeBot;
new g_cvarFakeBotTryHltv;
new g_cvarFakeBotName;
new g_cvarIncoming;
new g_cvarIncoming_DontColorize;
new g_cvarIncoming_IgnorePrefix;
new g_cvarIncoming_RefreshTime;
new g_cvarOutgoing;
new g_cvarOutgoing_SystemUsername;
new g_cvarOutgoing_Chat_Mode;
new g_cvarOutgoing_Chat_SpamFil;
new g_cvarOutgoing_Chat_ZeroifyAtSign;
new g_cvarOutgoing_Chat_RequirePrefix;
new g_cvarOutgoing_Chat_MuteServer;
new g_cvarOutgoing_Chat_CopyBack;
new g_cvarOutgoing_Kills;
new g_cvarOutgoing_Join;
new g_cvarOutgoing_Join_Delay;
new g_cvarOutgoing_Quit;
new g_cvarOutgoing_Quit_IgnoreIntermission;
new g_cvarOutgoing_JoinQuit_ShowCount;
new g_cvarOutgoing_StripColors;
new g_cvarOutgoing_DisplayMap;
new g_cvarRetry_Delay;
new GripRequestCancellation:g_gripIncomingHandle;
new GripRequestCancellation:g_gripOutgoingHandle;
new GripRequestOptions:g_gIncomingHeader;
new GripRequestOptions:g_gOutgoingHeader;

//deprecated cvars
new g_cvarDeprecatedBridgeUrl;

new g_sIncomingUri[BASE_URL_LENGTH];
new g_sOutgoingUri[BASE_URL_LENGTH];
new g_sBridgeUrl[BASE_URL_LENGTH];
new g_sAvatarUrl[BASE_URL_LENGTH];
new g_sAutogenAvatarUrl[BASE_URL_LENGTH];
new g_sSystemAvatarUrl[BASE_URL_LENGTH];
new g_sSystemName[MAX_NAME_LENGTH];
new g_sGateway[MAX_NAME_LENGTH];
new g_sGamename[MAX_NAME_LENGTH];
new g_sBogusUserName[MAX_NAME_LENGTH];
new g_sCopyBack[MAX_NAME_LENGTH];

new g_sLastMessages[MAX_PLAYERS+1][MESSAGE_LENGTH];
new g_bUserConnected[MAX_PLAYERS+1];

new g_bUserAuthenticated[MAX_PLAYERS+1];

new bool:g_bJoinDelayDone = false;
new bool:g_bIsIntermission = false;

new g_iPrintMessageForward; 
new g_iPluginFlags;
new g_iBogusUser;

new Float:g_fRetryDelay;
new Float:g_fQueryDelay;

new Regex:g_rAuthId_Pattern;
new Regex:g_rPrefix_Pattern;

new const sHexTable[] = "0123456789ABCDEF";

enum (*= 2)
{
    CHAT_TYPE_ALL = 1,
    CHAT_TYPE_TEAM,
//    CHAT_TYPE_ALL_SYSMSG,
//    CHAT_TYPE_TEAM_SYSMSG
}

public plugin_natives()
{
    register_library("matteramxx");
    register_native("matteramxx_send_message", "send_message_custom");
}

public plugin_init()
{
    new sServername[MAX_NAME_LENGTH];
    get_modname(g_sGamename, charsmax(g_sGamename));
    get_cvar_string("hostname", sServername, charsmax(sServername));

    register_plugin(MATTERAMXX_PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_matter_enable", "1");
    g_cvarSystemAvatarUrl = register_cvar("amx_matter_system_avatar", "", FCVAR_PROTECTED);
    g_cvarAutogenAvatarUrl = register_cvar("amx_matter_autogenerate_avatar", "", FCVAR_PROTECTED); //https://robohash.org/%s.png?set=set4
    g_cvarAvatarUrl = register_cvar("amx_matter_player_avatar", "", FCVAR_PROTECTED); //http://localhost/avatars/get_avatar.php?steamid=%s
    g_cvarBridgeProtocol = register_cvar("amx_matter_bridge_protocol", "http", FCVAR_PROTECTED);
    g_cvarBridgeHost = register_cvar("amx_matter_bridge_host", "localhost", FCVAR_PROTECTED);
    g_cvarBridgePort = register_cvar("amx_matter_bridge_port", "1337", FCVAR_PROTECTED);
    g_cvarDeprecatedBridgeUrl = register_cvar("amx_matter_bridge_url", "", FCVAR_PROTECTED);
    g_cvarBridgeGateway = register_cvar("amx_matter_bridge_gateway", g_sGamename, FCVAR_PROTECTED);
    g_cvarToken = register_cvar("amx_matter_bridge_token", "", FCVAR_PROTECTED);
    g_cvarUseFakeBot = register_cvar("amx_matter_fake_bot", "0", FCVAR_PROTECTED);
    g_cvarFakeBotTryHltv = register_cvar("amx_matter_fake_bot_hltv_first", "1", FCVAR_PROTECTED);
    g_cvarFakeBotName = register_cvar("amx_matter_fake_bot_name", "", FCVAR_PROTECTED);
    g_cvarIncoming = register_cvar("amx_matter_bridge_incoming", "1");
    g_cvarIncoming_DontColorize = register_cvar("amx_matter_bridge_incoming_dont_colorize", "0");
    g_cvarIncoming_IgnorePrefix = register_cvar("amx_matter_bridge_incoming_ignore_prefix", "!");
    g_cvarIncoming_RefreshTime = register_cvar("amx_matter_bridge_incoming_update_time", "3.0");
    g_cvarOutgoing = register_cvar("amx_matter_bridge_outgoing", "1");
    g_cvarOutgoing_SystemUsername = register_cvar("amx_matter_bridge_outgoing_system_username", sServername);
    g_cvarOutgoing_Chat_Mode = register_cvar("amx_matter_bridge_outgoing_chat_mode", "3");
    g_cvarOutgoing_Chat_SpamFil = register_cvar("amx_matter_bridge_outgoing_chat_no_repeat", "1");
    g_cvarOutgoing_Chat_ZeroifyAtSign = register_cvar("amx_matter_bridge_outgoing_chat_zwsp_at", "1");
    g_cvarOutgoing_Chat_RequirePrefix = register_cvar("amx_matter_bridge_outgoing_chat_require_prefix", "");
    g_cvarOutgoing_Chat_MuteServer = register_cvar("amx_matter_bridge_outgoing_chat_mute_server", "0");
    g_cvarOutgoing_Chat_CopyBack = register_cvar("amx_matter_bridge_outgoing_chat_copyback_prefix", "");
    g_cvarOutgoing_Kills = register_cvar("amx_matter_bridge_outgoing_kills", "1");
    g_cvarOutgoing_Join = register_cvar("amx_matter_bridge_outgoing_join", "1");
    g_cvarOutgoing_Join_Delay = register_cvar("amx_matter_bridge_outgoing_join_delay", "15.0");
    g_cvarOutgoing_Quit = register_cvar("amx_matter_bridge_outgoing_quit", "1");
    g_cvarOutgoing_Quit_IgnoreIntermission = register_cvar("amx_matter_bridge_outgoing_quit_ignore_intermission", "0");
    g_cvarOutgoing_StripColors = register_cvar("amx_matter_bridge_outgoing_strip_colors", "1");
    g_cvarOutgoing_DisplayMap = register_cvar("amx_matter_bridge_outgoing_display_map", "1");
    g_cvarOutgoing_JoinQuit_ShowCount = register_cvar("amx_matter_bridge_outgoing_joinquit_count", "1");
    g_cvarRetry_Delay = register_cvar("amx_matter_bridge_retry_delay", "3.0");

    register_dictionary("matteramxx.txt");

    //TS and SC don't support rendering % 
    if(is_running("ts") || is_running("svencoop"))
        register_dictionary("matteramxx_old.txt");

    register_cvar("amx_matter_bridge_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);
}

public plugin_cfg()
{
    if(get_pcvar_num(g_cvarEnabled))
    {
        //tag mismatch if bool:
        new const bSvencoopRunning = is_running("svencoop"); 
        new const bValveRunning = is_running("valve");
        new const bRicochetRunning = is_running("ricochet");
        new const bSpecialistsRunning = is_running("ts");
        new const bTeamFortressRunning = is_running("tfc");

        new sToken[TOKEN_LENGTH];
        get_pcvar_string(g_cvarDeprecatedBridgeUrl, g_sBridgeUrl, charsmax(g_sBridgeUrl));
        if(!empty(g_sBridgeUrl))
            server_print("[MatterAMXX Warning] amx_matter_bridge_url is deprecated. This will throw an error in future MatterBridge versions, please update your cvars.");
        else
        {
            new sBridgeProtocol[16], sBridgeHost[64], sBridgePort[16];
            get_pcvar_string(g_cvarBridgeProtocol, sBridgeProtocol, charsmax(sBridgeProtocol));
            get_pcvar_string(g_cvarBridgeHost, sBridgeHost, charsmax(sBridgeHost));
            get_pcvar_string(g_cvarBridgePort, sBridgePort, charsmax(sBridgePort));
            formatex(g_sBridgeUrl, charsmax(g_sBridgeUrl), "%s://%s", sBridgeProtocol, sBridgeHost);
            if(!empty(sBridgePort))
            {
                add(g_sBridgeUrl, charsmax(g_sBridgeUrl), ":");
                add(g_sBridgeUrl, charsmax(g_sBridgeUrl), sBridgePort);
            }
        }

        get_pcvar_string(g_cvarToken, sToken, charsmax(sToken));
        if(get_pcvar_bool(g_cvarOutgoing))
        {
            g_gOutgoingHeader = grip_create_default_options();
            grip_options_add_header(g_gOutgoingHeader, "Content-Type", "application/json");

            get_pcvar_string(g_cvarSystemAvatarUrl, g_sSystemAvatarUrl, charsmax(g_sSystemAvatarUrl));

            if(!empty(sToken))
            {
                new sTokenHeader[JSON_PARAMETER_LENGTH];
                formatex(sTokenHeader, charsmax(sTokenHeader), "Bearer %s", sToken);
                grip_options_add_header(g_gOutgoingHeader, "Authorization", sTokenHeader);
            }

            get_pcvar_string(g_cvarBridgeGateway, g_sGateway, charsmax(g_sGateway));
            get_pcvar_string(g_cvarOutgoing_SystemUsername, g_sSystemName, charsmax(g_sSystemName));
            
            formatex(g_sOutgoingUri, charsmax(g_sOutgoingUri), "%s/api/message", g_sBridgeUrl);
            
            if(get_pcvar_num(g_cvarOutgoing_Chat_Mode) > 0)
            {
                if(get_pcvar_num(g_cvarOutgoing_Chat_Mode) & CHAT_TYPE_ALL)
                    register_clcmd("say", "say_message");
                if(get_pcvar_num(g_cvarOutgoing_Chat_Mode) & CHAT_TYPE_TEAM)
                    register_clcmd("say_team", "say_message");
                    
                g_rAuthId_Pattern = regex_compile(REGEX_STEAMID_PATTERN);
                get_pcvar_string(g_cvarAvatarUrl, g_sAvatarUrl, charsmax(g_sAvatarUrl)); 
                get_pcvar_string(g_cvarAutogenAvatarUrl, g_sAutogenAvatarUrl, charsmax(g_sAutogenAvatarUrl)); 
            }

            if(get_pcvar_bool(g_cvarOutgoing_Kills))
            {
            #if USE_HAMSANDWICH > 0
                RegisterHam(bTeamFortressRunning ? Ham_TFC_Killed : Ham_Killed, "player", bTeamFortressRunning ? "player_killed_tfc" : "player_killed", true);
            #else 
                register_event("DeathMsg", "player_killed_ev", "a");
            #endif
            }
            if(get_pcvar_float(g_cvarOutgoing_Join_Delay) > 0)
                set_task(get_pcvar_float(g_cvarOutgoing_Join_Delay), "join_delay_done");
            else
            {
                if(get_pcvar_bool(g_cvarOutgoing_DisplayMap))
                {
                    new sMapName[32], sMessage[MESSAGE_LENGTH];
                    get_mapname(sMapName, charsmax(sMapName));
                    formatex(sMessage, charsmax(sMessage), "* Map changed to %s", sMapName);
                    
                    new GripJSONValue:gJson = grip_json_init_object();
                    grip_json_object_set_string(gJson, "text", sMessage);
                    grip_json_object_set_string(gJson, "username", g_sSystemName);
                    if(!empty(g_sSystemAvatarUrl))
                        grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
                    grip_json_object_set_string(gJson, "userid", SYSMES_ID);

                    send_message_rest(gJson, g_sGateway);
                }
                g_bJoinDelayDone = true;
            }

            if(!get_pcvar_bool(g_cvarOutgoing_Quit_IgnoreIntermission))
                register_message(SVC_INTERMISSION, "map_end");

            get_pcvar_string(g_cvarOutgoing_Chat_CopyBack, g_sCopyBack, charsmax(g_sCopyBack));
            replace_all(g_sCopyBack, charsmax(g_sCopyBack), "!n", "^1");
            replace_all(g_sCopyBack, charsmax(g_sCopyBack), "!r", "^3");
            replace_all(g_sCopyBack, charsmax(g_sCopyBack), "!b", "^3");
            replace_all(g_sCopyBack, charsmax(g_sCopyBack), "!g", "^4");
            replace_all(g_sCopyBack, charsmax(g_sCopyBack), "!t", TEAM_COLOR_PLACEHOLDER);
        }
        
        if(get_pcvar_bool(g_cvarIncoming))
        {
            formatex(g_sIncomingUri, charsmax(g_sIncomingUri), "%s/api/messages", g_sBridgeUrl);
       
            g_gIncomingHeader = grip_create_default_options();

            if(!empty(sToken))
            {
                new sTokenHeader[JSON_PARAMETER_LENGTH];
                formatex(sTokenHeader, charsmax(sTokenHeader), "Bearer %s", sToken);
                grip_options_add_header(g_gIncomingHeader, "Authorization", sTokenHeader);
            }

            g_fRetryDelay = get_pcvar_float(g_cvarRetry_Delay);
            g_fQueryDelay = get_pcvar_float(g_cvarIncoming_RefreshTime);

            g_iPrintMessageForward = CreateMultiForward("matteramxx_print_message", ET_STOP, FP_STRING, FP_STRING, FP_STRING, FP_STRING);

            set_task(g_fQueryDelay, "connect_api");

            new sRegexPrefix[32];
            get_pcvar_string(g_cvarIncoming_IgnorePrefix, sRegexPrefix, charsmax(sRegexPrefix));

            if(!empty(sRegexPrefix))
                g_rPrefix_Pattern = regex_compile(sRegexPrefix);

            g_rAuthId_Pattern = regex_compile(REGEX_STEAMID_PATTERN);
        }

        if(get_pcvar_bool(g_cvarUseFakeBot) && (((bValveRunning || bRicochetRunning || bTeamFortressRunning) && get_cvar_num("allow_spectators") == 1) || (!bValveRunning && !bRicochetRunning && !bTeamFortressRunning)))
        {
            if(get_pcvar_bool(g_cvarFakeBotTryHltv))
            {
                new players[32], playernum;
                get_players(players, playernum);
                for(new i = 0; i < playernum; i++)
                {
                    //this may be trying to get a real player? check if it is not bot as well
                    if(is_user_hltv_ex(players[i]) && is_user_bot(players[i]))
                    {  
                        g_iBogusUser = players[i];
                        get_user_name(g_iBogusUser, g_sBogusUserName, charsmax(g_sBogusUserName));
                        server_print("[MatterAMXX Debug] DEBUG bogus user name found: %s.", g_sBogusUserName);
                        break;
                    }
                }  
            }

            server_print("[MatterAMXX Debug] bogus user is %N", g_iBogusUser);
            
            if(!g_iBogusUser)
            {
                server_print("[MatterAMXX Debug] trying to spawn a new one");
                #if USE_HAMSANDWICH > 0
                RegisterHam(Ham_Spawn, "player", "fakebot_spawn");
                #endif
                get_pcvar_string(g_cvarFakeBotName, g_sBogusUserName, charsmax(g_sBogusUserName));
                g_iBogusUser = engfunc(EngFunc_CreateFakeClient, g_sBogusUserName);
                
                server_print("[MatterAMXX Debug] bogus client is %d %N", g_iBogusUser, g_iBogusUser);
                engfunc(EngFunc_FreeEntPrivateData, g_iBogusUser);
                //dllfunc(DLLFunc_ClientConnect, g_iBogusUser);
                new szRejectReason[32];
                dllfunc(DLLFunc_ClientConnect, g_iBogusUser, g_sBogusUserName, "127.0.0.1", szRejectReason);
                if(!is_user_connected(g_iBogusUser))
                    set_fail_state("Fake Bot connection rejected: %s", szRejectReason);

                dllfunc(DLLFunc_ClientPutInServer, g_iBogusUser);
                dllfunc(DLLFunc_Spawn, g_iBogusUser);
                set_pev(g_iBogusUser, pev_flags, pev(g_iBogusUser, pev_flags) | (FL_FAKECLIENT | FL_PROXY));

                set_user_info(g_iBogusUser, "dm", "0");
                set_user_info(g_iBogusUser, "tracker", "0");
                set_user_info(g_iBogusUser, "friends", "0");
                set_user_info(g_iBogusUser, "*bot", "1");

                new Float:fOrigin[3];
                fOrigin[0] = 99999999999.0;
                fOrigin[1] = 99999999999.0;
                fOrigin[2] = 99999999999.0;
                set_pev(g_iBogusUser, pev_origin, fOrigin);

                if(!bValveRunning)
                    user_kill(g_iBogusUser, 1);

                if(!bSvencoopRunning)
                {
                    //send bot to spectator in the next frame
                    RequestFrame("SendBogusUserToSpec", g_iBogusUser);
                }

                #if USE_HAMSANDWICH > 0
                if((bValveRunning && get_cvar_num("mp_teamplay") == 0) || !bValveRunning)
                {
                    ExecuteHam(bSvencoopRunning ? Ham_SC_AddPoints : Ham_AddPoints, g_iBogusUser, -1337, true);
                    set_user_frags(g_iBogusUser, -1337);
                }

                if(bSvencoopRunning)
                    ExecuteHam(Ham_SC_SetClassification, g_iBogusUser, 19);
                #endif
            }
            register_message(get_user_msgid("SayText"), "change_name_notif_block");
        }

        g_iPluginFlags = plugin_flags();
    }
    else
        pause("ad");
}

public SendBogusUserToSpec(iClient)
{
    engclient_cmd(g_iBogusUser, "spectate");
}

public plugin_end()
{
    if(grip_is_request_active(g_gripIncomingHandle))
        grip_cancel_request(g_gripIncomingHandle);
    if(grip_is_request_active(g_gripOutgoingHandle))
        grip_cancel_request(g_gripOutgoingHandle);

    DestroyForward(g_iPrintMessageForward);
}

public fakebot_spawn(id)
{
    if(id == g_iBogusUser)
    {
        new origin[3];
        origin[0] = 99999999999;
        origin[1] = 99999999999;
        origin[2] = 99999999999;
        set_user_origin(g_iBogusUser, origin); 
        return HAM_SUPERCEDE;
    }
    else
        return HAM_IGNORED;
}

public join_delay_done()
{
    g_bJoinDelayDone = true;
    if(get_pcvar_bool(g_cvarOutgoing_DisplayMap) && get_playersnum_ex(GetPlayers_IncludeConnecting) > 0)
    {
        new sMapName[32], sMessage[MESSAGE_LENGTH];
        get_mapname(sMapName, charsmax(sMapName));
        formatex(sMessage, charsmax(sMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_MAP_CHANGED", sMapName);

        new GripJSONValue:gJson = grip_json_init_object();
        grip_json_object_set_string(gJson, "text", sMessage);
        grip_json_object_set_string(gJson, "username", g_sSystemName);
        if(!empty(g_sSystemAvatarUrl))
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
        grip_json_object_set_string(gJson, "userid", SYSMES_ID);

        send_message_rest(gJson, g_sGateway);
    }
}

public map_end()
{
    g_bIsIntermission = true;
}

public connect_api()
{
    g_gripIncomingHandle = grip_request(g_sIncomingUri, Empty_GripBody, GripRequestTypeGet, "incoming_message", g_gIncomingHeader);
}

public retry_connection()
{
    server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_RETRYING", floatround(g_fRetryDelay));
    set_task(g_fRetryDelay, "connect_api");
}

public incoming_message()
{
    if(grip_get_response_state() != GripResponseStateSuccessful)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_CONN_FAILED");
        retry_connection();
    }

    new sIncomingMessage[INCOMING_BUFFER_LENGTH], sJsonError[MESSAGE_LENGTH], GripJSONValue:gJson;

    grip_get_response_body_string(sIncomingMessage, charsmax(sIncomingMessage));

    replace_all(sIncomingMessage, charsmax(sIncomingMessage), "^%", ""); 

    gJson = grip_json_parse_string(sIncomingMessage, sJsonError, charsmax(sJsonError));

    if(!empty(sJsonError))
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_INVALID");
        set_task(g_fQueryDelay, "connect_api");
        return;
    }

    if(grip_json_get_type(gJson) == GripJSONObject)
    {
        new sErrorMessage[INCOMING_BUFFER_LENGTH];
        grip_json_object_get_string(gJson, "message", sErrorMessage, charsmax(sErrorMessage));
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_ERROR", sErrorMessage);
        grip_destroy_json_value(gJson);
        set_fail_state(sErrorMessage);
        return;
    }

    for(new x = 0; x < grip_json_array_get_count(gJson); x++)
    {
        new sMessageGateway[MAX_NAME_LENGTH];
        new GripJSONValue:jCurrentMessage = grip_json_array_get_value(gJson, x);
        grip_json_object_get_string(jCurrentMessage, "gateway", sMessageGateway, charsmax(sMessageGateway));
        if(!equali(g_sGateway, sMessageGateway))
            continue;
        
        new sMessageBody[MESSAGE_LENGTH], sUsername[MAX_NAME_LENGTH], sProtocol[MAX_NAME_LENGTH], sUserID[MAX_NAME_LENGTH];
        grip_json_object_get_string(jCurrentMessage, "userid", sUserID, charsmax(sUserID));
        if(equal(sUserID, SYSMES_ID))
        {
            server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_SYSMSG_NOT_SENT");
            continue;
        }
        grip_json_object_get_string(jCurrentMessage, "text", sMessageBody, charsmax(sMessageBody));
        grip_json_object_get_string(jCurrentMessage, "username", sUsername, charsmax(sUsername));
        grip_json_object_get_string(jCurrentMessage, "protocol", sProtocol, charsmax(sProtocol));

        print_message(sMessageBody, sUsername, sProtocol, sUserID);

        grip_destroy_json_value(jCurrentMessage);
    }

    grip_destroy_json_value(gJson);

    set_task(g_fQueryDelay, "connect_api");
}

print_message_fakebot(const sMessage[], const sUserName[], user_id = 0)
{
    new sNewUserName[MAX_NAME_LENGTH];
    copy(sNewUserName, charsmax(sNewUserName), sUserName);

    //the following symbols are known to glitch out the chat
    replace_all(sNewUserName, charsmax(sNewUserName), "#", "¤");
    //replace_all(sNewUserName, charsmax(sNewUserName), "@", "¤"); //apparently it only causes problems in Windows clients

    if(user_id == g_iBogusUser)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] matteramxx.amxx::print_message_fakebot() - Renaming fakebot %d to %s", g_iBogusUser, sNewUserName);

        set_user_info(g_iBogusUser, "name", sNewUserName);
    }

    //in theory a race condition can happen, but it hasn't happened in my tests
    set_task(0.1, "print_message_fakebot_post", FAKEBOT_TASK_ID+user_id, sMessage, MESSAGE_LENGTH);
}

public print_message_fakebot_post(const sMessage[], taskid)
{
    //to add colors in names in games that are not CS or DOD I pretty much had to
    //rebuild the entire print message function from scratch
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] matteramxx.amxx::print_message_fakebot_post() - Fake Post Print Post: Message: %s", sMessage);

    new id = taskid - FAKEBOT_TASK_ID;

    new sUserName[MAX_NAME_LENGTH];
    get_user_name(id, sUserName, charsmax(sUserName));
    new sMessageNew[MESSAGE_LENGTH];

    if(strlen(g_sCopyBack) > 0)
        formatex(sMessageNew, charsmax(sMessageNew), get_pcvar_bool(g_cvarIncoming_DontColorize) ? "^2%s %s%s: %s" : "^0%s ^2%s%s: %s", g_sCopyBack, sUserName, cstrike_running() ? "^1" : "", sMessage);
    else
        formatex(sMessageNew, charsmax(sMessageNew), "^2%s%s: %s", sUserName, cstrike_running() ? "^1" : "", sMessage);

    //strcat(sMessageNew, "^n", charsmax(sMessageNew));

    if(get_pcvar_bool(g_cvarOutgoing_Chat_MuteServer)) //id of zero and muteserver should never happen
    {
        emessage_begin(MSG_ONE, get_user_msgid("SayText"), {0,0,0}, id);
        ewrite_byte(id);
        ewrite_string(sMessageNew);
        emessage_end();
    }
    else
    {
        new players[32], playernum;
        get_players(players, playernum);
        for(new i = 0; i < playernum; i++)
        {
            if(!is_user_bot(players[i]) && is_user_connected(players[i]))
            {  
                emessage_begin(MSG_ONE, get_user_msgid("SayText"), {0,0,0}, players[i]);
                ewrite_byte(id);
                ewrite_string(sMessageNew);
                emessage_end();
            }
        }  
    }
    
    server_print(sMessageNew);
    RequestFrame("ChangeNameBack", id);
}

public ChangeNameBack(id)
{
    if(id == g_iBogusUser)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] matteramxx.amxx::ChangeNameBack() - Renaming fakebot %d back to %s", g_iBogusUser, g_sBogusUserName);

        set_user_info(g_iBogusUser, "name", g_sBogusUserName);
    }
}

public change_name_notif_block(msgid, dest, receiver)
{
    new message[MESSAGE_LENGTH];
    get_msg_arg_string(2, message, charsmax(message));
    // new senderID = get_msg_arg_int(1);

    // replace_all(message, charsmax(message), "^0", "^^0");
    // replace_all(message, charsmax(message), "^1", "^^1");
    // replace_all(message, charsmax(message), "^2", "^^2");
    // replace_all(message, charsmax(message), "^3", "^^3");
    // replace_all(message, charsmax(message), "^4", "^^4");
    // replace_all(message, charsmax(message), "^5", "^^5");
    // replace_all(message, charsmax(message), "^6", "^^6");
    // replace_all(message, charsmax(message), "^7", "^^7");
    // replace_all(message, charsmax(message), "^8", "^^8");
    // replace_all(message, charsmax(message), "^9", "^^9");
    // replace_all(message, charsmax(message), "^n", "^^n");

    // //if(g_iPluginFlags & AMX_FLAG_DEBUG)
    // server_print("[DEBUG] matteramxx.amxx::change_name_notif_block() - Message ^"%s^" was sent by %d.", message, senderID);
    
    if(contain(message, g_sBogusUserName) != -1)
        return PLUGIN_HANDLED;
    else
        return PLUGIN_CONTINUE;
}

public print_message(const sMessage[], sUsername[MAX_NAME_LENGTH], sProtocol[MAX_NAME_LENGTH], sUserID[MAX_NAME_LENGTH])
{
    new iReturnVal = 0;
    new sMessageNew[MESSAGE_LENGTH];
    //copy(sMessageNew, MESSAGE_LENGTH, sMessage);
    ExecuteForward(g_iPrintMessageForward, iReturnVal, sMessage, sUsername, sProtocol, sUserID);
    switch(iReturnVal)
    {
        case 0:
        {
            if(prefix_matches(sMessage))
                return;

            if(empty(sUsername))
                copy(sUsername, charsmax(sUsername), g_sSystemName);
            if(empty(sProtocol))
                copy(sProtocol, charsmax(sProtocol), g_sGamename);

            // apparently the super compact code didn't work on CS
            // let's try it again

            if(cstrike_running()) 
            {
                // counter strike is running
                // todo: does DOD support color chat?

                new bool:is_red = containi(sUsername, "!b") ? false : true;

                replace_all(sUsername, charsmax(sUsername), "!n", "^1");
                replace_all(sUsername, charsmax(sUsername), "!r", "^3");
                replace_all(sUsername, charsmax(sUsername), "!b", "^3");
                replace_all(sUsername, charsmax(sUsername), "!g", "^4");
                replace_all(g_sCopyBack, charsmax(g_sCopyBack), "!t", TEAM_COLOR_PLACEHOLDER);

                //formatex(sMessageNew, charsmax(sMessageNew), get_pcvar_bool(g_cvarIncoming_DontColorize) ? "%s^1: %s" : "^4%s^1: %s", sUsername, sMessage); 

                if(strlen(g_sCopyBack) > 0)
                    formatex(sMessageNew, charsmax(sMessageNew), get_pcvar_bool(g_cvarIncoming_DontColorize) ? "%s %s^1: %s" : "^4%s %s^1: %s", g_sCopyBack, sUsername, sMessage);
                else
                    formatex(sMessageNew, charsmax(sMessageNew), "%s^1: %s", sUsername, sMessage);

                client_print_color(0, is_red ? print_team_red : print_team_blue, sMessageNew); 
            }
            else  
            {
                // counter strike is not running, so we wouldn't have colors even if we wanted them
                // 2022 Update: it's possible to get colors in games that are not CS or DOD
                // we just need an overly complicated hack
                if(get_pcvar_bool(g_cvarUseFakeBot) && g_iBogusUser)
                    print_message_fakebot(sMessage, sUsername, g_iBogusUser);
                else
                {
                    if(strlen(g_sCopyBack) > 0)
                        formatex(sMessageNew, charsmax(sMessageNew), get_pcvar_bool(g_cvarIncoming_DontColorize) ? "%s %s: %s" : "^4%s %s^1: %s", g_sCopyBack, sUsername, sMessage);
                    else
                        formatex(sMessageNew, charsmax(sMessageNew), "%s: %s", sUsername, sMessage);
                    client_print(0, print_chat, sMessageNew);
                }
            } 
        }
        case 1:
        {
            server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_API_SUPERCEDED", sMessage);
        }
    }  
}

public say_message(id)
{
    new sMessage[MESSAGE_LENGTH], sUserName[MAX_NAME_LENGTH], sSteamId[MAX_NAME_LENGTH], sRequiredPrefix[2]; //magic number?
    read_args(sMessage, charsmax(sMessage));

    remove_quotes(sMessage);
    replace_all(sMessage, charsmax(sMessage), "^"", "\^"");

    trim(sMessage);

    get_pcvar_string(g_cvarOutgoing_Chat_RequirePrefix, sRequiredPrefix, charsmax(sRequiredPrefix));

    if(!empty(sRequiredPrefix) && sMessage[0] != sRequiredPrefix[0])
        return PLUGIN_CONTINUE;
    else if(!empty(sRequiredPrefix))
        format(sMessage, charsmax(sMessage), "%s" , sMessage[strlen(sRequiredPrefix)]); 

    if(get_pcvar_bool(g_cvarOutgoing_Chat_ZeroifyAtSign))
        replace_all(sMessage, charsmax(sMessage), "@", "@​");

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] matteramxx.amxx::say_message() - Message ^"%s^" was sent.", sMessage);

    if(empty(sMessage) || (get_pcvar_bool(g_cvarOutgoing_Chat_SpamFil) && equal(sMessage, g_sLastMessages[id])))
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] matteramxx.amxx::say_message() - First condition of say_message returned false, returning.");
            server_print("[DEBUG] matteramxx.amxx::say_message() - (Message length was %i)", strlen(sMessage));
        }
        return PLUGIN_CONTINUE;
    }

    if(get_pcvar_bool(g_cvarOutgoing_Chat_SpamFil))
        g_sLastMessages[id] = sMessage;

    new GripJSONValue:gJson = grip_json_init_object();

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] matteramxx.amxx::say_message() - Preparing gJson object.");
    
    if(id)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] matteramxx.amxx::say_message() - id is %i.", id);
        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(id, sUserName, charsmax(sUserName));
        else
            get_user_name(id, sUserName, charsmax(sUserName));

        get_user_info(id, "*sid", sSteamId, charsmax(sSteamId));

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] matteramxx.amxx::say_message() - Fullname is %s.", sUserName);
            server_print("[DEBUG] matteramxx.amxx::say_message() - Steam ID is %s.", sSteamId);
        }

        if(!empty(sSteamId))
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] matteramxx.amxx::say_message() - Steam ID is from a player.");
            new sAvatarUrlFull[TARGET_URL_LENGTH];
            if(g_bUserAuthenticated[id])
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[DEBUG] matteramxx.amxx::say_message() - User is authenticated.");
                if(!empty(g_sAvatarUrl))
                    formatex(sAvatarUrlFull, charsmax(sAvatarUrlFull), g_sAvatarUrl, sSteamId);
            }
            else
            {
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[DEBUG] matteramxx.amxx::say_message() - User not is authenticated.");
                if(!empty(g_sAutogenAvatarUrl))
                {
                    new sEncodedName[MAX_NAME_LENGTH];
                    urlencode(sUserName, sEncodedName, charsmax(sEncodedName));
                    formatex(sAvatarUrlFull, charsmax(sAvatarUrlFull), g_sAutogenAvatarUrl, sEncodedName);
                }
            }

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] matteramxx.amxx::say_message() - Resulting avatar URL is %s.", sAvatarUrlFull);

            if(!empty(sAvatarUrlFull))
                grip_json_object_set_string(gJson, "avatar", sAvatarUrlFull);
        }
        else if(!empty(g_sSystemAvatarUrl))
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] matteramxx.amxx::say_message() - The server sent this message.");
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
        }
    } 

    grip_json_object_set_string(gJson, "text", sMessage);
    grip_json_object_set_string(gJson, "username", (id) ? sUserName : g_sSystemName);
    grip_json_object_set_string(gJson, "userid", (id) ? sSteamId : "GAME_CONSOLE");

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] matteramxx.amxx::say_message() - I'm going to send the message.");
    send_message_rest(gJson, g_sGateway);

    //for consistency, we need to check the if the bogus user is in the server
    //otherwise we'll just print it normally
    if(get_pcvar_bool(g_cvarUseFakeBot) && g_iBogusUser)
    {
        print_message_fakebot(sMessage, sUserName, id);
        return PLUGIN_HANDLED;
    }
    else
    {
        new sMessageNew[MESSAGE_LENGTH];
        if(strlen(g_sCopyBack) == 0)
        {
            if(get_pcvar_bool(g_cvarOutgoing_Chat_MuteServer))
            {
                formatex(sMessageNew, charsmax(sMessageNew), "(YOU) %s%s: %s", sUserName, cstrike_running() ? "^1" : "", sMessage);
                if(cstrike_running())
                    client_print_color(id, id, sMessageNew);
                else
                    client_print(id, print_chat, sMessageNew);
                return PLUGIN_HANDLED;
            }
            else
                return PLUGIN_CONTINUE;
        }
        else
        {
            if(cstrike_running())
            {
                formatex(sMessageNew, charsmax(sMessageNew), "%s %s%s%s: %s", g_sCopyBack, 0 < id && id <= MAX_PLAYERS ? "^3" : "^4", sUserName, cstrike_running() ? "^1" : "", sMessage);
                client_print_color(get_pcvar_bool(g_cvarOutgoing_Chat_MuteServer) ? id : 0, id, sMessageNew);
            }
            else
            {
                formatex(sMessageNew, charsmax(sMessageNew), "%s %s%s: %s", g_sCopyBack, sUserName, cstrike_running() ? "^1" : "", sMessage);
                client_print(get_pcvar_bool(g_cvarOutgoing_Chat_MuteServer) ? id : 0, print_chat, sMessageNew);
            }
        }

        //Matterbridge messages already come with a line end character, this ensures correct console display
        replace_all(sMessage, charsmax(sMessage), "^n", ""); 
        
        server_print("%s: %s", sUserName, sMessage);
        return PLUGIN_HANDLED;
    }
}

public player_killed_ev()
{
    new idattacker = read_data(1);
    new id = read_data(2);

    player_killed(id, idattacker);
}

public player_killed_tfc(id, idinflictor, idattacker)
{
    player_killed(id, idattacker);
}

public player_killed(id, idattacker)
{
    new sUserName[MAX_NAME_LENGTH], sAttackerName[MAX_NAME_LENGTH], sMessage[MESSAGE_LENGTH];
    
    if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
        get_colorless_name(id, sUserName, charsmax(sUserName));
    else
        get_user_name(id, sUserName, charsmax(sUserName));

    if(is_user_connected(idattacker))
    {
        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(idattacker, sAttackerName, charsmax(sAttackerName));
        else
            get_user_name(idattacker, sAttackerName, charsmax(sAttackerName));
    }
    else
        pev(idattacker, pev_classname, sAttackerName, charsmax(sAttackerName)); //todo: get the monster name in Sven Co-op

    replace_all(sUserName, charsmax(sUserName), "^"", "");
    replace_all(sAttackerName, charsmax(sAttackerName), "^"", ""); 

    formatex(sMessage, charsmax(sMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_KILLED", sUserName, sAttackerName);

    new GripJSONValue:gJson = grip_json_init_object();

    grip_json_object_set_string(gJson, "text", sMessage);
    grip_json_object_set_string(gJson, "username", g_sSystemName);
    if(!empty(g_sSystemAvatarUrl))
        grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
    grip_json_object_set_string(gJson, "userid", SYSMES_ID);

    send_message_rest(gJson, g_sGateway);
}

public send_message_custom(iPlugin, iParams)
{
    // we can manage backwards compatiblity ths way
    new sMessage[MESSAGE_LENGTH], sUsername[MAX_NAME_LENGTH], sAvatar[TARGET_URL_LENGTH], sGateway[MAX_NAME_LENGTH];
    
    get_string(1, sMessage, charsmax(sMessage));
    get_string(2, sUsername, charsmax(sUsername));
    get_string(3, sAvatar, charsmax(sAvatar));
    new is_system = get_param(4);
    get_string(5, sGateway, charsmax(sGateway));

    new GripJSONValue:gJson = grip_json_init_object();

    grip_json_object_set_string(gJson, "text", sMessage);
    grip_json_object_set_string(gJson, "username", empty(sUsername) ? g_sSystemName : sUsername);
    grip_json_object_set_string(gJson, "avatar", empty(sAvatar) ? g_sSystemAvatarUrl : sAvatar);
    grip_json_object_set_string(gJson, "userid", is_system ? SYSMES_ID : "");

    send_message_rest(gJson, empty(sGateway) ? g_sGateway : sGateway);
}

public outgoing_message()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
    {
        server_print("[DEBUG] matteramxx.amxx::say_message() - I sent the message. Response State is %d", grip_get_response_state());
        new sResponse[INCOMING_BUFFER_LENGTH];
        grip_get_response_body_string(sResponse, charsmax(sResponse));
        server_print("[DEBUG] matteramxx.amxx::say_message() - Server said: %s", sResponse);
    }

    if(grip_get_response_state() != GripResponseStateSuccessful)
    {
        server_print("[MatterAMXX] %L", LANG_SERVER, "MATTERAMXX_MSG_FAILED"); //to do: why?
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            new sIncomingMessage[MESSAGE_LENGTH];
            grip_get_response_body_string(sIncomingMessage, charsmax(sIncomingMessage));
            server_print(sIncomingMessage);
        }
    }
}

public client_authorized(id)
{
    new authid[32];
    get_user_authid(id, authid, charsmax(authid));
    if(is_valid_authid(authid))
        g_bUserAuthenticated[id] = 1;
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
    g_bUserAuthenticated[id] = 0;
    if(!g_bIsIntermission && get_pcvar_bool(g_cvarOutgoing_Quit) && !is_user_bot(id) && g_bUserConnected[id])
    {
        new sUserName[MAX_NAME_LENGTH], sMessage[MESSAGE_LENGTH];
        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(id, sUserName, charsmax(sUserName));
        else
            get_user_name(id, sUserName, charsmax(sUserName));
        replace_all(sUserName, charsmax(sUserName), "^"", "");

        if(get_pcvar_bool(g_cvarOutgoing_JoinQuit_ShowCount))
            formatex(sMessage, charsmax(sMessage), "%L [%d/%d]", LANG_SERVER, "MATTERAMXX_MESSAGE_LEFT", sUserName, get_playersnum_ex(GetPlayers_ExcludeBots)-1, get_maxplayers());
        else
            formatex(sMessage, charsmax(sMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_LEFT", sUserName);
        g_bUserConnected[id] = false;
        
        new GripJSONValue:gJson = grip_json_init_object();
        grip_json_object_set_string(gJson, "text", sMessage);
        grip_json_object_set_string(gJson, "username", g_sSystemName);
        if(!empty(g_sSystemAvatarUrl))
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
        grip_json_object_set_string(gJson, "userid", SYSMES_ID);

        send_message_rest(gJson, g_sGateway);
    }
}

public client_putinserver(id)
{
    if(g_bJoinDelayDone && get_pcvar_bool(g_cvarOutgoing_Join) && !is_user_bot(id))
    {
        new sUserName[MAX_NAME_LENGTH], sMessage[MESSAGE_LENGTH];

        if((equali(g_sGamename, "valve") || equali(g_sGamename, "ag")) && get_pcvar_bool(g_cvarOutgoing_StripColors))
            get_colorless_name(id, sUserName, charsmax(sUserName));
        else
            get_user_name(id, sUserName, charsmax(sUserName));

        replace_all(sUserName, charsmax(sUserName), "^"", "");

        if(get_pcvar_bool(g_cvarOutgoing_JoinQuit_ShowCount))
            formatex(sMessage, charsmax(sMessage), "%L [%d/%d]", LANG_SERVER, "MATTERAMXX_MESSAGE_JOINED", sUserName, get_playersnum_ex(GetPlayers_ExcludeBots), get_maxplayers());
        else
            formatex(sMessage, charsmax(sMessage), "%L", LANG_SERVER, "MATTERAMXX_MESSAGE_JOINED", sUserName);
        
        g_bUserConnected[id] = true;
        g_sLastMessages[id] = "";
        
        new GripJSONValue:gJson = grip_json_init_object();
        grip_json_object_set_string(gJson, "text", sMessage);
        grip_json_object_set_string(gJson, "username", g_sSystemName);
        if(!empty(g_sSystemAvatarUrl))
            grip_json_object_set_string(gJson, "avatar", g_sSystemAvatarUrl);
        grip_json_object_set_string(gJson, "userid", SYSMES_ID);

        send_message_rest(gJson, g_sGateway);
    }
}

stock getPlayersByScore()
{
    
}

//thanks to YaLTeR
stock get_colorless_name(id, name[], len)
{
	get_user_name(id, name, len);

	// Clear out color codes
	new i, j;
	new const hat[3] = "^^";
	while(name[i])
	{
		if(name[i] == hat[0] && name[i + 1] >= '0' && name[i + 1] <= '9')
		{
			i++;
		}
		else
		{
			if(j != i)
				name[j] = name[i];
			j++;
		}
		i++;
	}
	name[j] = 0;
}

//thanks to Th3-822
stock urlencode(const sString[], sResult[], len)
{
    new from, c, to;

    while(from < len)
    {
        c = sString[from++];
        if(c == 0)
        {
            sResult[to++] = c;
            break;
        }
        else if(c == ' ')
        {
            sResult[to++] = '_';
        }
        else if(!(0 <= c <= 255))
        { // UTF-8 Fix (Doesn't encode put .)
            sResult[to++] = '_';
        }
        else if((c < '0' && c != '-' && c != '.') ||
                (c < 'A' && c > '9') ||
                (c > 'Z' && c < 'a' && c != '_') ||
                (c > 'z'))
        {
            if((to + 3) > len)
            {
                sResult[to] = 0;
                break;
            }
            // UTF-8 Fix - Need to check real c values.
            /* if(c < 0) c = 256 + c; */
            sResult[to++] = '_';
            sResult[to++] = sHexTable[c >> 4];
            sResult[to++] = sHexTable[c & 15];
        }
        else
        {
            sResult[to++] = c;
        }
    }
}

stock send_message_rest(GripJSONValue:gJson, const gateway[])
{
    grip_json_object_set_string(gJson, "gateway", gateway);
    grip_json_object_set_string(gJson, "protocol", g_sGamename);

    new GripBody:gPayload = grip_body_from_json(gJson);

    g_gripOutgoingHandle = grip_request(g_sOutgoingUri, gPayload, GripRequestTypePost, "outgoing_message", g_gOutgoingHeader);

    grip_destroy_body(gPayload);
    grip_destroy_json_value(gJson);
}

stock is_valid_authid(authid[]) 
{
    return regex_match_c(authid, g_rAuthId_Pattern) > 0;
}

stock prefix_matches(const message[]) 
{
    return regex_match_c(message, g_rPrefix_Pattern) > 0;
}

stock empty(const string[])
{
    return !string[0];
}

stock is_user_hltv_ex(iClient)
{
    if(is_user_connected(iClient) && is_user_bot(iClient))
    {
        new szSteamId[MAX_NAME_LENGTH];
        get_user_authid(iClient, szSteamId, charsmax(szSteamId));
        return equali(szSteamId, "HLTV");
    }
    else
        return false;
}