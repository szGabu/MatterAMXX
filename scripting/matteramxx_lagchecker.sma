#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#assert "AMX Mod X versions 1.8.2 and below are not supported. Please upgrade your shit."
#endif

#include <fake_rcon>
#include <matteramxx>
#include <regex>

#define MATTERAMXX_PLUGIN_PLUGIN        "MatterAMXX Lag Checker"
#define MATTERAMXX_PLUGIN_AUTHOR        "szGabu"
#define MATTERAMXX_PLUGIN_VERSION       "1.6-dev"

#define REGEX_STATUS                    "LB\s*(\d*\.\d*)\s*\d*\.\d*\s*\d*\.\d*\s*\d*\s*\d*\s*(\d*\.\d*)"

#pragma semicolon 1

new g_cvarEnabled;
new g_cvarCpuThreshold;
new g_cvarFpsThreshold;
new g_cvarSendAllStatus;
new g_cvarToPing;
new g_szStats[MESSAGE_LENGTH];

new g_iPluginFlags;
new g_bRestartScheduled = false;

new Regex:g_rPattern;

public plugin_init()
{
    register_plugin(MATTERAMXX_PLUGIN_PLUGIN, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    register_clcmd("say", "say_message");
    register_clcmd("say_team", "say_message");

    g_cvarEnabled = register_cvar("amx_matter_lagchecker_enabled", "1");
    g_cvarToPing = register_cvar("amx_matter_lagchecker_ping_this_person", "");
    g_cvarSendAllStatus = register_cvar("amx_matter_lagchecker_send_all_status", "0");
    g_cvarCpuThreshold = register_cvar("amx_matter_lagchecker_cpu_threshold", "75");
    g_cvarFpsThreshold = register_cvar("amx_matter_lagchecker_fps_threshold", "30");

    register_dictionary("matteramxx.txt");
}

public plugin_cfg()
{
    if(get_pcvar_num(g_cvarEnabled))
    {
        new iMasterPluginIndex = is_plugin_loaded("MatterAMXX");
        if(iMasterPluginIndex > -1)
        {
            g_iPluginFlags = plugin_flags();
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
            {
                server_print("[MatterAMXX Lag Checker Debug] Plugin is enabled.");
                server_print("[MatterAMXX Lag Checker Debug] Finished plugin_cfg()");
            }

            g_rPattern = regex_compile_ex(REGEX_STATUS);
        }
        else
            set_fail_state("This plugin requires MatterAMXX to be loaded.");
    }
    else
        pause("ad");
}

public say_message(iClient)
{
    new sMessage[MESSAGE_LENGTH];
    read_args(sMessage, charsmax(sMessage));

    if (empty(sMessage))
        return PLUGIN_CONTINUE;

    if(iClient)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX Lag Checker Debug] Message is: %s", sMessage);

        if(containi(sMessage, "lag") != -1)
        {
            if(g_bRestartScheduled)
                client_print(0, print_chat, "* %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_RESTART_SCHEDULE");
            else
                set_task(2.0, "execute_lag"); //fixes SZ_GetSpace: tried to write to an uninitialized sizebuf_t: ???
        }
    }

    return PLUGIN_CONTINUE;
}

public execute_lag()
{
    g_szStats = "";
    
    fake_rcon(g_szStats, sizeof(g_szStats), "stats");

    replace_all(g_szStats, charsmax(g_szStats), "^n", "LB");

    new szCpuField[16], szFpsField[16];
    if(regex_match_c(g_szStats, g_rPattern))
    {
        regex_substr(g_rPattern, 1, szCpuField, charsmax(szCpuField));
        regex_substr(g_rPattern, 2, szFpsField, charsmax(szFpsField));

        new Float:fCpuPercent = str_to_float(szCpuField);
        new Float:iFpsValue = str_to_float(szFpsField);

        new Float:fIdealTicrate = get_cvar_num("sys_ticrate")*0.90;
        new iComparedFpsValue = floatround((iFpsValue/fIdealTicrate)*100);

        if(g_iPluginFlags & AMX_FLAG_DEBUG)
        {
            server_print("[MatterAMXX Lag Checker Debug] Ideal ticrate is: %d", floatround(fIdealTicrate));
            server_print("[MatterAMXX Lag Checker Debug] Server is running at an ideal %d%% of the desired FPS", iComparedFpsValue);
        }

        new szMatterMessage[MESSAGE_LENGTH];

        if(floatround(fCpuPercent) > get_pcvar_num(g_cvarCpuThreshold) || iComparedFpsValue < get_pcvar_num(g_cvarFpsThreshold))
        {
            client_print(0, print_chat, "* %L %L", LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(fCpuPercent), floatround(iFpsValue), LANG_PLAYER, "MATTERAMXX_PLUGIN_LAG_RESTART_SCHEDULE");
            new szWhoToPing[MAX_NAME_LENGTH];
            get_pcvar_string(g_cvarToPing, szWhoToPing, charsmax(szWhoToPing));
            formatex(szMatterMessage, charsmax(szMatterMessage), "%s %L %L", szWhoToPing, LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_STATS", floatround(fCpuPercent), floatround(iFpsValue), LANG_SERVER, "MATTERAMXX_PLUGIN_LAG_NOTIF");
            matteramxx_send_message(szMatterMessage, _, _, true);
            register_message(SVC_INTERMISSION, "Event_Intermission");
            g_bRestartScheduled = true;
        }
        else
        {
            if(get_pcvar_bool(g_cvarSendAllStatus))
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
            server_print("[MatterAMXX Lag Checker Debug] Failure to check regex match");
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