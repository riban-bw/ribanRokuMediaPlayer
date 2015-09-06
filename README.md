# ribanRokuMediaPlayer
A media player app for the Roku which uses a simple web server to manage media assets

This project provides a html media asset manager and a client application for the roku (and NowTV box) to access the media.
The backend is based on html and php technologies. Each media file is stored in a http accessible repository.
PHP scripts, also accessible via http, provide media management including marking recordings as deleted, updating play position and deleting media from the repository.
A sqlite3 database manages the media, providing the metadata required to support the media managment. The "status" flag within the database defines whether a media is available to a client to play and whether it is marked for deletion.
The client application implements a hierarchical menu system. This provides access to media and the wastebin (marked for deletion) and application configuration. Media items may be played or marked for deletion. Playback may be fromstart or resumed from last play postion. (Only supports one play position so multiple clients share the same resume point.)

The system is designed to be simple and require low resources and few dependencies. The backend requires a web server and php. It is designed to be run on a GNU/Linux system but should work on other platforms.
