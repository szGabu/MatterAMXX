![](https://github.com/user-attachments/assets/0377e68c-8930-4912-9de8-b92b7b711f5a)

# MatterAMXX
Powered by Matterbridge, MatterAMXX is a plugin for AMXX that allows simple bridging between your game servers, Mattermost, IRC, XMPP, Gitter, Slack, Discord, Telegram, and more.  

![](https://github.com/user-attachments/assets/ff38f893-f722-48ff-bb06-63ae15649168)

## Description
  
Using Matterbridge API, this plugin allows you to bridge your game server with a Matterbridge installation, relaying messages from/to a growing number of protocols.  
  
You can also bridge multiple servers together so the players can chat between each one.  
  
  
## Protocols natively supported in Matterbridge

- Mattermost
- IRC
- XMPP
- Slack
- Discord
- Telegram
- Rocket.chat
- Matrix
- Steam ([Bugged](https://github.com/42wim/matterbridge/issues/457) [for](https://github.com/Philipp15b/go-steam/issues/94) [now](https://github.com/SteamRE/SteamKit/issues/561))
- Twitch
- Ssh-chat
- WhatsApp
- Zulip
- Keybase

  
### Tested Protocols

- Discord
- Matrix
- Telegram

  
## Dependencies
  
This plugin requires the following to work:

- **[AmxxEasyHttp](https://github.com/Next21Team/AmxxEasyHttp)**
- **[A working Matterbridge installation](https://github.com/42wim/matterbridge/wiki/How-to-create-your-config)**
- **[Fake RCON](https://forums.alliedmods.net/showthread.php?t=326556)** (Optional, required by the MatterAMXX Lag Checker and MatterAMXX Console sub-plugins)


## Supported Games
This plugin is supposed to be mod agnostic. All official games should work out of the box

- Half-Life
- Counter-Strike
- Condition Zero
- Opposing Force
- Ricochet
- Day of Defeat
- Team Fortress Classic
- Deathmatch Classic
- The Specialists
- Sven Co-op
  
### Tested Games

- Half-Life
- Ricochet
- Sven Co-op
- The Specialists

  
## Build Instructions

- Download all requirements, plus the .sma file.
- Place include files in the /scripting/includes directory.
- Compile the plugin and install the newly generated .amxx file. (Remember to install the latest version of AmxxEasyHttp in your server)

  
## Setting up MatterAMXX
  
This quickstart guide assumes you already have a working Matterbridge installation.  
  
Open your `matterbridge.toml` file and add the following lines:  

```
[api.myserver]
BindAddress="0.0.0.0:1337"
Token="verysecrettoken"
Buffer=1000
RemoteNickFormat="{NICK}"
```

Where "myserver" is goes the name of the relay, you can put anything, same with the port and Token, this is where the plugin will be listening.
  
After that, find or create a gateway where you want to relay the messages. The following is an example of where you will bridge the HLDS server (using the API created below) and a Discord server. It is assumed the Discord entry already exists in the file.

```
[[gateway]]  
name="cstrike"  
enable=true  
  
[[gateway.inout]]  
account="discord.mydiscord"  
channel="general"  
  
[[gateway.inout]]  
account="api.myserver"  
channel="api"
```

Where `cstrike` is goes the gateway name. By default is the mod's gamedir (`cstrike` for Counter-Strike, `valve` for Half-Life, etc) but you can change it using cvars, you can add more `gateway.inout` entries depending on how many protocols do you want to relay messages.  
  
  
## Avatar Spoofing
  
It's possible to set up avatars for each user on protocols that support it. Unfortunately, due to limitations of AMXX and the GRIP module, user info from the Steam API can't be retrieved because it gets truncated.  
  
However, you can host the included PHP script to query for avatars to be used in this plugin, you just need a Steam API Key that you can obtain from the [Steam Web API website](https://steamcommunity.com/dev).  
  
This will also cache each avatar and they will be deleted after a while.  
  
Remember to create the `/avatars` folder! The script won't do it for you.  
  
## API
  
The API allows other plugins to use MatterAMXX features. Just include the `matteramxx.inc` file in your plugin and it should work immediately.  
  
Remember that the plugin requires the latest version of MatterAMXX to be running in the server.  
  
## Console Variables 

moved to the wiki
  
# Credits

- 42wim  
    _Main developer of Matterbridge._
- Michael Wieland  
    _His MatterBukkit plugin for Minecraft inspired me to create this._
- Th3-822  
    _Helped me finding some bugs. Created the wonderful Fake RCON API_
- 7mochi  
    _[Ported MatterAMXX to AmxxEasyHttp](https://github.com/szGabu/MatterAMXX/commit/2d048eb8d66c5545890240c33e7aa2085745d598)_


![Alt](https://repobeats.axiom.co/api/embed/b5aa0a7891e68aee6ad9160b5602be5566496350.svg "Repobeats analytics image")
