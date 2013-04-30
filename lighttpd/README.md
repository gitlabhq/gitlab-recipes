Gitlab with lighttpd webserver
==============================

* Maintainer: @tvn87
* App Version: 5.1

This config access gitlab via TCP port instead of sockets because of the
mod_proxy module which seems to be unable to connect via sockets.

Because the _gitlab_ default config is set for listening to UNIX sockets you
need to change that default configuration in *gitlab/config/puma.rb*:

	bind "tcp://127.0.0.1:8080"
