#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#assert "AMX Mod X versions 1.8.2 and below are not supported. Please upgrade your shit."
#endif

#include <fake_rcon>
#include <matteramxx>
#include <regex>

#define PLUGIN_NAME        "MatterAMXX Lag Checker"
#define PLUGIN_AUTHOR      "szGabu"

#define REGEX_STATUS       "LB\s*(\d*\.\d*)\s*\d*\.\d*\s*\d*\.\d*\s*\d*\s*\d*\s*(\d*\.\d*)"

#pragma semicolon 1

static g_cvarEnabled;
static g_cvarComputeThreshold;
static g_cvarFramesThreshold;
static g_cvarSendAllStatus;
static g_cvarToPing;

static bool:g_bEnabled;
static g_iComputeThreshold;
static g_iFramesThreshold;
static bool:g_bSendAllStatus;
static g_szToPing[MAX_NAME_LENGTH];

static g_iPluginFlags;

new g_bRestartScheduled = false;

new Regex:g_hStatusPattern;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_clcmd("say", "ClientCommand_Say");
    register_clcmd("say_team", "ClientCommand_Say");

    g_cvarEnabled = create_cvar("amx_matter_lagchecker_enabled", "1", FCVAR_NONE, "Enable the sub-plugin.", true, 0.0, true, 1.0);
    g_cvarToPing = create_cvar("amx_matter_lagchecker_ping_this_person", "", FCVAR_PROTECTED, "You can add a ping format for any protocol, for example, to ping you when the server is lagging. For Discord you can use seomthing like <@youruniqueid>, other protocols may use other formats.");
    g_cvarSendAllStatus = create_cvar("amx_matter_lagchecker_send_all_status", "0", FCVAR_NONE, "Enable if you want to send a message every time a player complains about lag, even if the server is lagging or not.", true, 0.0, true, 1.0);
    g_cvarComputeThreshold = create_cvar("amx_matter_lagchecker_cpu_threshold", "75", FCVAR_NONE, "If CPU percent is above this, send an alert.", true, 0.0, true, 100.0);
    g_cvarFramesThreshold = create_cvar("amx_matter_lagchecker_fps_threshold", "30", FCVAR_NONE, "If FPS percent (based on sys_ticrate) is below this, send an alert.", true, 0.0, true, 100.0);
    AutoExecConfig();

    register_dictionary("matteramxx.txt");
}

public plugin_end()
{
    if(g_hStatusPattern)
        regex_free(g_hStatusPattern);
}

public OnConfigsExecuted()
{
    create_cvar("amx_matter_lagchecker_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);

    bind_pcvar_num(g_cvarEnabled, g_bEnabled);
    bind_pcvar_string(g_cvarToPing, g_szToPing, charsmax(g_szToPing));
    bind_pcvar_num(g_cvarSendAllStatus, g_bSendAllStatus);
    bind_pcvar_num(g_cvarComputeThreshold, g_iComputeThreshold);
    bind_pcvar_num(g_cvarFramesThreshold, g_iFramesThreshold);

    if(g_bEnabled)
    {
        new iMasterPluginIndex = is_plugin_loaded("MatterAMXX");
        if(iMasterPluginIndex > -1)
        {
            g_iPluginFlags = plugin_flags();
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
            {
                server_print("[DEBUG] %s::plugin_cfg() - Plugin is enabled.", __BINARY__);
                server_print("[DEBUG] %s::plugin_cfg() - Finished plugin_cfg()", __BINARY__);
            }

            g_hStatusPattern = regex_compile_ex(REGEX_STATUS);
        }
        else
            set_fail_state("This plugin requires MatterAMXX to be loaded.");
    }
    else
        pause("ad");
}

public ClientCommand_Say(iClient)
{
    new sMessage[MESSAGE_LENGTH];
    read_args(sMessage, charsmax(sMessage));

    if (empty(sMessage))
        return PLUGIN_CONTINUE;

    if(iClient)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] %s::ClientCommand_Say() - Message is: %s", __BINARY__, sMessage);

        if(containi(sMessage, "lag") != -1)
        {
            if(g_bRestartScheduled)
                client_print(0, print_chat, "* %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_RESTART_SCHEDULE");
            else
                set_task(2.0, "Task_ExecuteLagCheck"); //fixes SZ_GetSpace: tried to write to an uninitialized sizebuf_t: ???
        }
    }

    return PLUGIN_CONTINUE;
}

public Task_ExecuteLagCheck()
{
    new szStats[MESSAGE_LENGTH];
    
    fake_rcon(szStats, sizeof(szStats), "stats");

    replace_all(szStats, charsmax(szStats), "^n", "LB");

    new szComputeField[16], szFramesField[16];
    new Regex:hHandle = Regex:regex_match_c(szStats, g_hStatusPattern);
    if(hHandle > REGEX_NO_MATCH)
    {
        regex_substr(g_hStatusPattern, 1, szComputeField, charsmax(szComputeField));
        regex_substr(g_hStatusPattern, 2, szFramesField, charsmax(szFramesField));

        new Float:fCpuPercent = str_to_float(szComputeField);
        new Float:iFpsValue = str_to_float(szFramesField);

        //my source is that I made it the fuck out
        new Float:fIdealTicrate = get_cvar_num("sys_ticrate")*0.90;
        new iComparedFpsValue = floatround((iFpsValue/fIdealTicrate)*100);

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[DEBUG] %s::Task_ExecuteLagCheck() - Ideal desired FPS is: %d", __BINARY__, floatround(fIdealTicrate));
            server_print("[DEBUG] %s::Task_ExecuteLagCheck() - Server is running at an ideal %d%% of the desired FPS", __BINARY__, iComparedFpsValue);
        }

        new szMatterMessage[MESSAGE_LENGTH];

        if(floatround(fCpuPercent) > g_iComputeThreshold || iComparedFpsValue < g_iFramesThreshold)
        {
            client_print(0, print_chat, "* %L %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(fCpuPercent), floatround(iFpsValue), LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_RESTART_SCHEDULE");
            formatex(szMatterMessage, charsmax(szMatterMessage), "%s %L %L", g_szToPing, LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(fCpuPercent), floatround(iFpsValue), LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_NOTIF");
            matteramxx_send_message(szMatterMessage, _, _, true);
            register_message(SVC_INTERMISSION, "Event_Intermission");
            g_bRestartScheduled = true;
        }
        else
        {
            if(g_bSendAllStatus)
            {
                formatex(szMatterMessage, charsmax(szMatterMessage), "* %L", LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(fCpuPercent), floatround(iFpsValue));
                matteramxx_send_message(szMatterMessage, _, _, true);
            }
            client_print(0, print_chat, "* %L %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(fCpuPercent), floatround(iFpsValue), LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STFU");
        }
    }
    else
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] %s:: - Failure to check regex match", __BINARY__);
    }
}

public Event_Intermission()
{
    server_cmd("quit");
    server_exec();
}

stock empty(const string[])
{
    return !string[0];
}