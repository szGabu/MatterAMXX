#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#assert "AMX Mod X versions 1.8.2 and below are not supported. Please upgrade your shit."
#endif

#include <amxmisc>
#include <fake_rcon>
#include <matteramxx>
#include <celltrie>
#include <cellarray>
#include <regex>

#define PLUGIN_NAME                     "MatterAMXX RCON"
#define PLUGIN_AUTHOR                   "szGabu"

#define MATTERAMXX_CONSOLE_OBEY_FILE    "matteramxx_rcon_accounts.ini"

#pragma semicolon 1

new g_iPluginFlags;

new g_cvarEnabled;
new g_cvarDontIgnoreObeyTo;
new g_cvarPrefix;
new g_cvarHideCvars;
new g_cvarHideIPs;
new g_cvarCodeBlock;

new g_bEnabled;
new g_bDontIgnoreObeyTo;
new g_szPrefix[PREFIX_LENGTH];
new g_bHideCvars;
new g_bHideIPs;
new g_bCodeBlock;

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
    register_plugin(PLUGIN_NAME, MATTERAMXX_PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_cvarEnabled = create_cvar("amx_matter_rcon_enable", "1", FCVAR_NONE, "Enables the sub-plugin.", true, 0.0, true, 1.0);
    g_cvarDontIgnoreObeyTo = create_cvar("amx_matter_rcon_dont_ignore_list", "1", FCVAR_PROTECTED, "Disable if you want to ignore the master user list. This is a dangerous command so ensure the channel is only accesible by people you trust.", true, 0.0, true, 1.0);
    g_cvarPrefix = create_cvar("amx_matter_rcon_prefix", "!rcon ", FCVAR_PROTECTED, "The prefix that will be read for a message to be considered console access.");
    g_cvarHideCvars = create_cvar("amx_matter_rcon_hide_cvars", "1", FCVAR_PROTECTED, "Enable if you want to hide the values of sensitive values (marked with FCVAR_PROTECTED, like passwords). Disable only if only you have access to the rcon output.", true, 0.0, true, 1.0);
    g_cvarHideIPs = create_cvar("amx_matter_rcon_hide_ips", "1", FCVAR_PROTECTED, "Enable if you want to mask users IPs (on commands like `status`). This is a basic privacy setting for your players. Disable only if only you have access to the rcon output.", true, 0.0, true, 1.0);
    g_cvarCodeBlock = create_cvar("amx_matter_rcon_code_block", "1", FCVAR_NONE, "Enable if you want to wrap the console output in a markdown codeblock. It will improve readability on protocols that support it.", true, 0.0, true, 1.0);

    AutoExecConfig();

    register_dictionary("admincmd.txt");
    register_dictionary("matteramxx.txt");
}

public OnConfigsExecuted()
{
    create_cvar("amx_matter_rcon_bridge_version", MATTERAMXX_PLUGIN_VERSION, FCVAR_SERVER);

    bind_pcvar_num(g_cvarEnabled, g_bEnabled);
    bind_pcvar_num(g_cvarDontIgnoreObeyTo, g_bDontIgnoreObeyTo);
    bind_pcvar_string(g_cvarPrefix, g_szPrefix, charsmax(g_szPrefix));
    bind_pcvar_num(g_cvarHideCvars, g_bHideCvars);
    bind_pcvar_num(g_cvarHideIPs, g_bHideIPs);
    bind_pcvar_num(g_cvarCodeBlock, g_bCodeBlock);

    if(g_bEnabled)
    {
        new iMasterPluginIndex = is_plugin_loaded("MatterAMXX");
        if(iMasterPluginIndex > -1)
        {
            g_iPluginFlags = plugin_flags();
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::OnConfigsExecuted() - Plugin is enabled.", __BINARY__);

            g_iTrieObeyTo = TrieCreate();

            new szFileName[PLATFORM_MAX_PATH];
            new sConfigDir[64];
            get_configsdir(sConfigDir, charsmax(sConfigDir));
            formatex(szFileName, charsmax(szFileName), "%s/%s", sConfigDir, MATTERAMXX_CONSOLE_OBEY_FILE);
            if(!LoadMasterFile(szFileName))
                set_fail_state("Unable to open Master Accounts file.");

            g_iProtectedCvars = ArrayCreate(64);
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::OnConfigsExecuted() - Creating array with size %d.", __BINARY__, ArraySize(g_iProtectedCvars));
            server_cmd("cvarlist log");
            server_exec();

            // some games, like ricochet, start from cvarlist01.txt instead of cvarlist00.txt, we need to retry until we get the correct file
            new x = 0;
            formatex(szFileName, charsmax(szFileName), "cvarlist0%d.txt", x);
            while(!file_exists(szFileName) && x <= CVARLIST_TRIES)
                formatex(szFileName, charsmax(szFileName), "cvarlist0%d.txt", ++x);
            ReadConVars(szFileName);
            unlink(szFileName);

            g_rPattern = regex_compile_ex(IP_REGEX);

            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::OnConfigsExecuted() - Finished OnConfigsExecuted()", __BINARY__);
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

public bool:LoadMasterFile(const szFilePath[])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::LoadMasterFile() - Trying to read file %s", __BINARY__, szFilePath);
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
                    server_print("[DEBUG] %s::LoadMasterFile() - Found master: %s (%s)", __BINARY__, szUsername, szProtocol);
                TrieSetString(g_iTrieObeyTo, szUsername, szProtocol);
                iCnt++;
            }
        }
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] %s::LoadMasterFile() - Loaded %d master accounts.", __BINARY__, iCnt);
        fclose(hFile);
        return true;
    }
    else 
    {
        log_amx("Can't open master accounts file.");
        return false;
    }
}

public bool:ReadConVars(const szFilePath[])
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::ReadConVars() - Trying to read file %s", __BINARY__, szFilePath);
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
                        server_print("[DEBUG] %s::ReadConVars() - Found a protected cvar: %s", __BINARY__, szCvar);
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
        log_amx("Can't open cvarlist file.");
        return false;
    }
}

public matteramxx_print_message(szMessage[MESSAGE_LENGTH], szUserName[MAX_NAME_LENGTH], szProtocol[MAX_NAME_LENGTH], szIdentifier[MAX_NAME_LENGTH])
{
    if(equali(szProtocol, "api"))
        return MATTER_IGNORE; //we should not catch commands coming from any game server or integration
    
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::ReadConVars() - Message arrived %s", __BINARY__, szMessage);

    trim(szMessage);

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s::ReadConVars() - Comparing if it has the prefix %s", __BINARY__, g_szPrefix);

    if(contain(szMessage, g_szPrefix) == 0)
    {
        if(g_iPluginFlags & AMX_FLAG_DEBUG)
            server_print("[DEBUG] %s::ReadConVars() - It is a valid prefix, checking if user is authorized.", __BINARY__);

        new sTrieProtocol[MAX_NAME_LENGTH];
        if(!g_bDontIgnoreObeyTo || (TrieGetString(g_iTrieObeyTo, szIdentifier, sTrieProtocol, charsmax(sTrieProtocol)) && equali(sTrieProtocol, szProtocol)))
        {
            replace_all(szMessage, charsmax(szMessage), g_szPrefix, "");
            trim(szMessage);
            
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::ReadConVars() - I'm setting the hook and executing %s on the game console.", __BINARY__, szMessage);

            if(containi(szMessage,";") != -1) //command injection
                return RejectCommand(szMessage);

            for(new i; i < sizeof g_sDangerousCommands; i++)
            {
                if(containi(szMessage, g_sDangerousCommands[i]) == 0)
                    return RejectCommand(szMessage);
            }

            g_szResponseMessage = g_bCodeBlock ? "```" : "";

            new szConsoleOutput[SERVER_RESPONSE_LENGTH];
            fake_rcon(szConsoleOutput, charsmax(szConsoleOutput), szMessage);
            add(g_szResponseMessage, charsmax(g_szResponseMessage), szConsoleOutput, charsmax(szConsoleOutput));

            if(g_bHideCvars)
                HideProtectedCvars(g_szResponseMessage, charsmax(g_szResponseMessage));

            if(g_bHideIPs)
                regex_replace(g_rPattern, g_szResponseMessage, charsmax(g_szResponseMessage), "$1XXX.XXX");

            if(g_bCodeBlock)
                add(g_szResponseMessage, charsmax(g_szResponseMessage), "```");
            else
                replace_all(g_szResponseMessage, charsmax(g_szResponseMessage), "^"", "\^"");
                
            matteramxx_send_message(g_szResponseMessage, _, _, true);
        }
        else
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[DEBUG] %s::ReadConVars() - %s (%s)'s (ID:%s) command got rejected.", __BINARY__, szUserName, szIdentifier, szProtocol);
            formatex(g_szResponseMessage, charsmax(g_szResponseMessage), "* %L", LANG_SERVER, random(101) > 99 ? "MATTERAMXX_PLUGIN_RCON_UNAUTHORIZED" : "MATTERAMXX_PLUGIN_RCON_HAL", szUserName);
            matteramxx_send_message(g_szResponseMessage, _, _, true);
        }
        return MATTER_SUPERCEDE;
    }
    return MATTER_IGNORE;
}

public RejectCommand(const szMessage[])
{
    formatex(g_szResponseMessage, charsmax(g_szResponseMessage), "* %L", LANG_SERVER, "MATTERAMXX_PLUGIN_RCON_NO_OUTPUT");
    matteramxx_send_message(g_szResponseMessage, _, _, true);
    server_cmd(szMessage);
    return MATTER_SUPERCEDE;
}

public HideProtectedCvars(szString[], iBuffer)
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
                formatex(sProtected, charsmax(sProtected), g_bCodeBlock ? "*** %L ***" : "\*\*\* %L \*\*\*", LANG_SERVER, "PROTECTED");
                replace_all(szString, iBuffer, szCvarValue, sProtected);
            }
        }
    }
}