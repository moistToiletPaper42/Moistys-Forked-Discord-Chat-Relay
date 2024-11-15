# Moisty's Fork of Infra's Simple Discord Chat Relay for SourceMod

Simple SourceMod plugin that logs chats (as well as server connections/disconnects) to Discord via webhooks. Not everything needs to be complicated! The original was tested in CS:GO and TF2. This fork was tested in L4D2.

## Types of messages sent:

- "Server has started!" - the first time OnConfigsExecuted is called after plugin load
- "Map ___ has loaded..." - same as above as well as anytime OnMapStart() is called (usually as soon as a map switch ends)
- "Map ___ is unloading..." - anytime OnMapEnd() is called (usually as soon as a map switch starts)
- "Player connected (`<country>`): `<username>` (`<steam-id>`)" - anytime a player connects and loads into the game
- "Player disconnected (`<country>`): `<username>` (`<steam-id>`)" - anytime a player disconnects from the game
- "Server is empty!" - Whenever the last player disconnects from the server
- "`<username>` (`<steam-id>`): `<message>`" - whenever a message is sent in in-game chat (can also send chat triggers and gagged messages, if you set `dcr_triggers_gagged` to `1`)

Currently, there is no server shutdown message. This mod has been catered to Endelei's Super Coop mod for L4D2, which sends a `crash` command and auto-restarts the server whenver the server is empty (to save resources)

## Server Commands:

`discord`:
- **Syntax:** `discord <message> [webhook*]`
- **Description:** Sends a message to Discord using the specified webhook. If no webhook is specified, the default webhook will be used. \*`webhook` is an optional argument and should be wrapped in quotes as Source Mod parses ":" as an individual argument.

## Webhook Styles:

The plugin features two webhook styles, one super simple style suited for logging and the other looking slighly prettier. Styles can be configured in `cfg/sourcemod/Simple-DiscordChat.cfg` using the `dcr_pretty` variable.

Pretty Style (`dcr_pretty "1"`):

![Pretty Style](https://infra.s-ul.eu/prjXi6Df)

Simple Style (`dcr_pretty "0"`):

![Simple Style](https://infra.s-ul.eu/75UIvxUK)

If you are looking to use this plugin purely to log chats, I recommend using the simple style. While it may not be as pretty as the other option, it makes searching SteamIDs in Discord possible.

## How to Install:

- Install SteamWorks: https://users.alliedmods.net/~kyles/builds/SteamWorks/
- The following mods are already included in the repository. If they don't work or need to be updated they can be found here:
  - `plugins/discord_api.smx`: https://github.com/Cruze03/sourcemod-discord/tree/master
  - `extensions/smjansson.ext.dll` and `extensions/smjansson.ext.so`: https://github.com/davenonymous/SMJansson/tree/master/bin
  - `scripting/include/smjansson.inc`: https://github.com/davenonymous/SMJansson/tree/master/pawn/scripting/include
- Clone the repository (or download it as a .zip) by hitting the big green code button at the top.
- Extract the ZIP file to your game-directory folder (Eg: csgo/) on your server.

## How to Configure:

All configuration is done in `cfg/sourcemod/Simple-DiscordChat.cfg`. 

### Setting up `dcr_webhook_url`:
The plugin needs a WebHook URL from Discord to be able to send chat messages to. Follow the steps below if you are unsure how this can be done:

* ***Step 1:*** Edit a channel > enter the Webhooks section inside the Integrations sub-menu > Make a new webhook.
* ***Step 2:*** Customize your new webhook! I recommend naming it according to the server you're going to use the webhook for, and adding an avatar related to your servers. (Making separate webhooks, accordingly named, for each server you host is a great way to identify what server a chat message was sent in!)
* ***Step 3:*** Copy your webhook URL, go back to `Simple-DiscordChat.cfg`, and send `dcr_webhook_url` to your webhook URL.

![Webhook Setup](https://infra.s-ul.eu/PGIRZY4W)

### Setting up `dcr_steamAPI_key`:
The plugin uses a SteamAPI key to access the Steam Web API to get player's profile pictures. This is an optional ConVar, disabling it will default the plugin to the simple webhook style since it can't pull profile pictures.

You can get your SteamAPI key here: https://steamcommunity.com/dev/apikey (**DO NOT SHARE THIS KEY WITH ANYONE.**)

## Building

How you build this is entirely up to you. However, the build script is setup to work with the gitignored `linking/` and `tools/` directories.

To setup tools, get a build of SourceMod and extract it to `tools/`.
- builds are here: https://www.sourcemod.net/downloads.php
  - For Windows, click the latest Blue (not Pink) Windows icon, so you don't have to build SourceMod yourself.

The build script will automatically copy the necessary files from the project and `tools/` to the `linking/` directory prior to compiling. The compiled .smx files will be automatically placed in the `addons/sourcemod/plugins` directory. If you feel like contributing your build, please be sure to include the compiled .smx files in `addons/sourcemod/plugins` in your pull request.

To run the build script, run build.ps1 from the git-root
