#if defined _matteramxx_const_included
	#endinput
#endif
#define _matteramxx_const_included

#define INCOMING_BUFFER_LENGTH      10240
#define SERVER_RESPONSE_LENGTH      5120
#define TARGET_URL_LENGTH           2048
#define MESSAGE_LENGTH              1024
#define BASE_URL_LENGTH             512
#define JSON_PARAMETER_LENGTH       512
#define TOKEN_LENGTH                128
#define CVARLIST_TRIES              6 //cannot be more than 6, inclusive, starts from 0
#define IP_REGEX                    "((?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){2})((?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9]))"
#define CVARQUERY_FORMAT            "^"%s^" is ^"%s^"^n"
#define STATS_FORMAT                "CPU   In    Out   Uptime  Users   FPS    Players^n%s^n"

#pragma dynamic 65536

#define MATTERAMXX_PLUGIN_VERSION   "1.6.0-25w17a"

enum {
  MATTER_IGNORE = 0,
  MATTER_SUPERCEDE,
};