# pimatic-spotify

A pimatic plugin to connect to and control Spotify Connect players on your network. 
This plugin was developed against Apple and Denon devices. Similar hardware should work equally well.

## Status of Implementation

Since the first release the following features have been implemented:
* Autodiscovery of Spotify Connect devices and Playlists
* Pimatic devices for the above, respectively extending from AVPlayer and Presence Sensor devices
* Rule Actions to play a playlist on a device, and set the volume. 
* The presence predicate can be used to detect if a playlist is being played

Roadmap:
* Creating a login device, for aesthetic purposes.

## Requirements

* Spotify Premium account
* Spotify App created via https://developer.spotify.com/dashboard/applications
* Redirect URI correctly set in the Spotify app (usually http://<Pimatic Server IP>:8888/callback)
* Client ID and secret obtained from the Spotify app

## Contributions / Credits

The project depends on the Node integration with the Spotify API through spotify-web-api-node by Michael Thelin (https://github.com/thelinmichael/spotify-web-api-node)


## Configuration

* Add the plugin to your config.json, or via the GUI (Do not forget to activate)
* The authentication server listens on port 8888  by default, you can change this in the Plugin Config
* Restart Pimatic
* Browse to http://<pimatic IP>:8888/login, to allow Pimatic to access Spotify via OAuth2. You are logging in at Spotify, so your Spotify user credentials are not saved or obtained locally 
* Run device autodiscovery and add your devices
* Create rules to Play playlists on devices of your choice, e.g.
  * ```when Bathroom Light is turned on then play Songs to Sing in the Shower on Bathroom Speaker and set volume of Bathroom Speaker to 30%```

### Plugin Configuration
```json
{
  "plugin": "spotify",
  "debug": false,
  "clientID": "<Spotify app Client ID>",
  "secret": "<Spotify App Secret",
  "auth_port": 8888
}
```

The plugin has the following configuration properties:

| Property          | Default  | Type    | Description                                     |
|:------------------|:---------|:--------|:------------------------------------------------|
| debug             | false    | Boolean | Debug messages to pimatic log, if set to true   |
| clientID          | none     | String  | Client ID obtained in Spotify API app           |
| secret            | none     | String  | Secret obtained in Spotify API app              |
| auth_port         | 8888     | Number  | TCP port for the authentication server          |


### Device Configuration
Default settings through autodiscovery should work fine.

#### SpotifyPlayer

```json
{
  "class": "SpotifyPlayer",
  "name": "Bathroom Speaker",
  "id": "spotify-player-bathroom-speaker",
  "spotify_id": "3b859.....",
  "spotify_type": "Speaker"
}
```
The device has the following configuration properties:

| Property            | Default   | Type    | Description                                             |
|:--------------------|:----------|:--------|:--------------------------------------------------------|
| spotify_id          | ''        | String  | Spotify device ID (Autodiscovery)                       |
| spotify_type        | 'Speaker' | Enum    | Spotify device ID (Autodiscovery)                       |


#### SpotifyPlaylist

```json
{
  "class": "SpotifyPlaylist",
  "name": "Songs to Sing in the Shower",
  "id": "spotify-playlist-songs-to-sing-in-the-shower",
  "spotify_id": "37i9dQZF1DWSqmBTGDYngZ",
  "spotify_type": "playlist",
  "spotify_uri": "spotify:playlist:37i9dQZF1DWSqmBTGDYngZ"
}
```

| Property            | Default    | Type    | Description                                      |
|:--------------------|:-----------|:--------|:-------------------------------------------------|
| spotify_id          | ''         | String  | Spotify ID of the playlist (Autodiscovery)       |
| spotify_type        | 'playlist' | String  | Spotify type (Always playlist for now            |
| spotify_uri      	  | ''         | String  | Spotify URI for Playlist (Autodiscovery)         |

## Predicates and Actions

The following predicates are supported:
* {device} is present|absent (For Playlist devices)

The following actions are supported:
* play <Playlist> on <Device> (For Player devices)
* set volume of <Device> to 50% (For Player devices, variables are supported)

## License 

Copyright (c) 2022, Danny Wigmans and contributors. All rights reserved.

[GPL-3.0](https://github.com/SenTzu01/pimatic-woox/blob/main/LICENSE)
