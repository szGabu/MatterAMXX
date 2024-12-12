#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#assert "AMX Mod X versions 1.8.2 and below are not supported. Please upgrade your shit."
#endif

// ** COMPILER OPTIONS **
// Adjust as needed

// Enable if you want to use experimental extended string buffers, most of the time you won't need it
// You may enable this if you have problems with messages (Messages cutting themselves short) to see if it works better
// Note that this will cause the plugin to use more memory
#define USE_EXTENDED_BUFFER 0

// ** COMPILER OPTIONS END HERE **

#if USE_EXTENDED_BUFFER > 0
    #pragma dynamic 65536
#else
    #pragma dynamic 32768
#endif

#include <amxmisc>
#include <fake_rcon>
#include <matteramxx>
#include <celltrie>
#include <cellarray>
#include <regex>

#define MATTERAMXX_CONSOLE_OBEY_FILE    "matteramxx_rcon_accounts.ini"
#define SERVER_RESPONSE_LENGTH          5120
#define CVARLIST_TRIES                  6 //cannot be more than 6, inclusive, starts from 0
#define IP_REGEX                        "((?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){2})((?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]))"
#define CVARQUERY_FORMAT                "^"%s^" is ^"%s^"^n"
#define STATS_FORMAT                    "CPU   In    Out   Uptime  Users   FPS    Players^n%s^n"
#define MATTERAMXX_PLUGIN_NAME          "MatterAMXX RCON"
#define MATTERAMXX_PLUGIN_AUTHOR        "szGabu"
#define MATTERAMXX_PLUGIN_VERSION       "1.6-RC1"

#pragma semicolon 1

new g_iPluginFlags;

new g_cvarEnabled;
new g_cvarDontIgnoreObeyTo;
new g_cvarPrefix;
new g_cvarHideCvars;
new g_cvarHideIPs;
new g_cvarCodeBlock;

new g_szResponseMessage[SERVER_RESPONSE_LENGTH];
new g_iProtectedArraySize = 0;

new Trie:g_iTrieObeyTo;
new Array:g_iProtectedCvars;

new Regex:g_rPattern;

new const g_sDangerousCommands[][] = { 
        "cmdlist",      //server crashes
        "cvarlist",     //server crashes
        "amxx cvars",   //string truncates, plugin crashes
        "amxx cmds",    //string truncates, plugin crashes
        "amxx list",    //string may truncate, plugin crashes
        "meta cvars",   //string truncates, plugin crashes
        "meta cmds",    //string truncates, plugin crashes
        "meta list",    //string may truncate, plugin crashes
        "changelevel",  //server crashes
        "restart",      //server crashes
        "quit",         //server crashes
        "map",          //server crashes
        "listip",        //server crashes
        "listid"        //server crashes
    };

public plugin_init()
{
    register_plugin(MATTERAMXX_PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, MATTERAMXX_PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_matter_rcon_enable", "1");
    g_cvarDontIgnoreObeyTo = register_cvar("amx_matter_rcon_dont_ignore_list", "1"); //DANGEROUS!!
    g_cvarPrefix = register_cvar("amx_matter_rcon_prefix", "!rcon ");
    g_cvarHideCvars = register_cvar("amx_matter_rcon_hide_cvars", "1");
    g_cvarHideIPs = register_cvar("amx_matter_rcon_hide_ips", "1");
    g_cvarCodeBlock = register_cvar("amx_matter_rcon_code_block", "1");

    register_dictionary("admincmd.txt");
    register_dictionary("matteramxx.txt");

    register_cvar("amx_matter_rcon_bridge_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);
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
                server_print("[MatterAMXX RCON Debug] Plugin is enabled.");

            if(get_pcvar_bool(g_cvarDontIgnoreObeyTo))
            {
                g_iTrieObeyTo = TrieCreate();

                new szFileName[128];
                new sConfigDir[64];
                get_configsdir(sConfigDir, charsmax(sConfigDir));
                formatex(szFileName, charsmax(szFileName), "%s/%s", sConfigDir, MATTERAMXX_CONSOLE_OBEY_FILE);
                if(!load_masters(szFileName))
                    set_fail_state("Unable to open Master Accounts file.");
            }

            if(get_pcvar_bool(g_cvarHideCvars))
            {
                g_iProtectedCvars = ArrayCreate(64);
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[MatterAMXX RCON Debug] Creating array with size %d.", ArraySize(g_iProtectedCvars));
                server_cmd("cvarlist log");
                server_exec();

                // some games, like ricochet, start from cvarlist01.txt instead of cvarlist00.txt, we need to retry until we get the correct file
                new szFileName[16];
                new x = 0;
                formatex(szFileName, charsmax(szFileName), "cvarlist0%d.txt", x);
                while(!file_exists(szFileName) && x <= CVARLIST_TRIES)
                    formatex(szFileName, charsmax(szFileName), "cvarlist0%d.txt", ++x);
                read_cvars(szFileName);
                unlink(szFileName);
            }

            if(get_pcvar_bool(g_cvarHideIPs))
                g_rPattern = regex_compile_ex(IP_REGEX);

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX RCON Debug] Finished plugin_cfg()");
        }
        else
            set_fail_state("This plugin requires MatterAMXX to be loaded.");
    }
    else
        pause("ad");
}

public plugin_end()
{
    TrieDestroy(g_iTrieObeyTo);
    ArrayDestroy(g_iProtectedCvars);
}

public bool:load_masters(const szFilePath[])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Trying to read file %s", szFilePath);
    static hFile, szUsername[32], szProtocol[32], szLine[100], iCnt;
    if((hFile = fopen(szFilePath, "r")))
    {
        iCnt = 0;
        while (!feof(hFile))
        {
            fgets(hFile, szLine, charsmax(szLine));
            trim(szLine);

            if (szLine[0] && szLine[0] != ';')
            {
                split(szLine, szUsername, charsmax(szUsername), szProtocol, charsmax(szProtocol), "§");
                if(g_iPluginFlags & AMX_FLAG_DEBUG)
                    server_print("[MatterAMXX RCON Debug] Found master: %s (%s)", szUsername, szProtocol);
                TrieSetString(g_iTrieObeyTo, szUsername, szProtocol);
                iCnt++;
            }
        }
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX RCON Debug] Loaded %d master accounts.", iCnt);
        fclose(hFile);
        return true;
    }
    else 
    {
        log_amx("[MatterAMXX RCON] Can't open master accounts file.");
        return false;
    }
}

public bool:read_cvars(const szFilePath[])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Trying to read file %s", szFilePath);
    static hFile, szLine[100];
    if((hFile = fopen(szFilePath, "r")))
    {
        while (!feof(hFile))
        {
            fgets(hFile, szLine, charsmax(szLine));
            trim(szLine);

            if(szLine[0])
            {
                new szCvar[64];
                split_string(szLine, " ", szCvar, charsmax(szCvar));
                new iCvarPointer = get_cvar_pointer(szCvar);
                if(iCvarPointer != 0 && get_pcvar_flags(iCvarPointer) & FCVAR_PROTECTED)
                {
                    if(g_iPluginFlags & AMX_FLAG_DEBUG)
                        server_print("[MatterAMXX RCON Debug] Found a protected cvar: %s", szCvar);
                    ArrayPushString(g_iProtectedCvars, szCvar);
                }
            }
        }

        g_iProtectedArraySize = ArraySize(g_iProtectedCvars);
        fclose(hFile);
        return true;
    }
    else 
    {
        log_amx("[MatterAMXX RCON] Can't open cvarlist file.");
        return false;
    }
}

public matteramxx_print_message(szMessage[MESSAGE_LENGTH], szUserName[MAX_NAME_LENGTH], szProtocol[MAX_NAME_LENGTH], szIdentifier[MAX_NAME_LENGTH])
{
    if(equali(szProtocol, "api"))
        return MATTER_IGNORE; //we should not catch commands coming from any game server or integration
    
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Message arrived %s", szMessage);

    trim(szMessage);

    new szPrefix[32];
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[MatterAMXX RCON Debug] Comparing if it has the prefix %s", szPrefix);

    if(equal(szMessage, szPrefix, get_pcvar_string(g_cvarPrefix, szPrefix, charsmax(szPrefix))))
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[MatterAMXX RCON Debug] It is a valid prefix, checking if user is authorized.");

        new sTrieProtocol[MAX_NAME_LENGTH];
        if(!get_pcvar_bool(g_cvarDontIgnoreObeyTo) || (TrieGetString(g_iTrieObeyTo, szIdentifier, sTrieProtocol, charsmax(sTrieProtocol)) && equali(sTrieProtocol, szProtocol)))
        {
            replace_all(szMessage, charsmax(szMessage), szPrefix, "");
            trim(szMessage);
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX RCON Debug] I'm setting the hook and executing %s on the game console.", szMessage);

            if(containi(szMessage,";") != -1) //command injection
                return reject_command(szMessage);

            for(new i; i < sizeof g_sDangerousCommands; i++)
            {
                if(containi(szMessage, g_sDangerousCommands[i]) == 0)
                    return reject_command(szMessage);
            }

            g_szResponseMessage = get_pcvar_bool(g_cvarCodeBlock) ? "```" : "";

            new szConsoleOutput[SERVER_RESPONSE_LENGTH];
            fake_rcon(szConsoleOutput, charsmax(szConsoleOutput), szMessage);
            add(g_szResponseMessage, charsmax(g_szResponseMessage), szConsoleOutput, charsmax(szConsoleOutput));

            if(get_pcvar_bool(g_cvarHideCvars))
                hide_protected(g_szResponseMessage, charsmax(g_szResponseMessage));

            if(get_pcvar_bool(g_cvarHideIPs))
                regex_replace(g_rPattern, g_szResponseMessage, charsmax(g_szResponseMessage), "$1XXX.XXX");

            if(get_pcvar_bool(g_cvarCodeBlock))
                add(g_szResponseMessage, charsmax(g_szResponseMessage), "```");
            else
                replace_all(g_szResponseMessage, charsmax(g_szResponseMessage), "^"", "\^"");
                
            matteramxx_send_message(g_szResponseMessage, _, _, true);
        }
        else
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[MatterAMXX RCON Debug] %s (%s)'s (ID:%s) command got rejected.", szUserName, szIdentifier, szProtocol);
            formatex(g_szResponseMessage, charsmax(g_szResponseMessage), "* %L", LANG_SERVER, random(101) > 99 ? "MATTERAMXX_PLUGIN_RCON_UNAUTHORIZED" : "MATTERAMXX_PLUGIN_RCON_HAL", szUserName);
            matteramxx_send_message(g_szResponseMessage, _, _, true);
        }
        return MATTER_SUPERCEDE;
    }
    return MATTER_IGNORE;
}

public reject_command(const szMessage[])
{
    formatex(g_szResponseMessage, charsmax(g_szResponseMessage), "* %L", LANG_SERVER, "MATTERAMXX_PLUGIN_RCON_NO_OUTPUT");
    matteramxx_send_message(g_szResponseMessage, _, _, true);
    server_cmd(szMessage);
    return MATTER_SUPERCEDE;
}

public hide_protected(szString[], iBuffer)
{
    for(new x=0; x < g_iProtectedArraySize;x++)
    {
        new szCvar[64];
        ArrayGetString(g_iProtectedCvars, x, szCvar, charsmax(szCvar));
        if(containi(szString, szCvar) > -1)
        {
            // cvar found, that means the value should (not always) be output
            new szCvarValue[128]; 
            if(get_pcvar_string(get_cvar_pointer(szCvar), szCvarValue, charsmax(szCvarValue)) > 0)
            {
                new sProtected[32];
                formatex(sProtected, charsmax(sProtected), get_pcvar_bool(g_cvarCodeBlock) ? "*** %L ***" : "\*\*\* %L \*\*\*", LANG_SERVER, "PROTECTED");
                replace_all(szString, iBuffer, szCvarValue, sProtected);
            }
        }
    }
}