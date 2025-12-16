#if defined _matteramxx_const_included
	#endinput
#endif
#define _matteramxx_const_included

#define INCOMING_BUFFER_LENGTH      10240
#define SERVER_RESPONSE_LENGTH      5120
#define TARGET_URL_LENGTH           2048
#define BASE_URL_LENGTH             2048
#define MESSAGE_LENGTH              1024
#define JSON_PARAMETER_LENGTH       512
#define TOKEN_LENGTH                128
#define SHORT_LENGTH                16
#define PREFIX_LENGTH               8
#define CVARLIST_TRIES              6 //cannot be more than 6, inclusive, starts from 0
#define IP_REGEX                    "((?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){2})((?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]))"
#define CVARQUERY_FORMAT            "^"%s^" is ^"%s^"^n"
#define STATS_FORMAT                "CPU   In    Out   Uptime  Users   FPS    Players^n%s^n"
#define REGEX_STEAMID_PATTERN       "^^STEAM_(0|1):(0|1):\d+$"
#define SYSMES_ID                   "0xDEADBEEF"
#define TEAM_COLOR_PLACEHOLDER      "$%&/"
#define TEAM_0_SYMBOL               "🟧" // Invalid or not Teamplay
#define TEAM_1_SYMBOL               "🟦" // Team 1 in Half-Life, CTs in Counter-Strike, BLUE in Team Fortress
#define TEAM_2_SYMBOL               "🟥" // Team 2 in Half-Life, Terrorists in Counter-Strike, RED in Team Fortress
#define TEAM_3_SYMBOL               "🟨" // Team 3 in Half-Life, YELLOW in Team Fortress
#define TEAM_4_SYMBOL               "🟩" // Team 4 in Half-Life, GREEN in Team Fortress
#define TEAM_5_SYMBOL               "⬛️" // Team 5 in Half-Life, then he loops back to 1 to repeat the colors
#define SPECTATOR_SYMBOL            "⬜️" // Spectator team
#define DEAD_SYMBOL                 "☠️" // Dead (Ghost), spectating but currently on a team

#pragma dynamic 65536

#define MATTERAMXX_PLUGIN_NAME      "MatterAMXX"
#define MATTERAMXX_PLUGIN_AUTHOR    "szGabu"
#define MATTERAMXX_PLUGIN_VERSION   "1.6.0-25w17a"

enum {
  MATTER_IGNORE = 0,
  MATTER_SUPERCEDE,
};