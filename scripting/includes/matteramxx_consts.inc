#if defined _matteramxx_const_included
	#endinput
#endif
#define _matteramxx_const_included

#define INCOMING_BUFFER_LENGTH      10240
#define TARGET_URL_LENGTH           2048
#define MESSAGE_LENGTH              1024
#define BASE_URL_LENGTH             512
#define JSON_PARAMETER_LENGTH       512
#define TOKEN_LENGTH                128

#pragma dynamic 65536

#define MATTERAMXX_PLUGIN_VERSION   "1.6.0-25w17a"

enum {
  MATTER_IGNORE = 0,
  MATTER_SUPERCEDE,
};