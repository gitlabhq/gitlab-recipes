# FreeBsd 8 / 9 Install Troubleshooting

## Naughty Gems


- [charlock_holmes](#charlock-holmes-gem-install-fails-or-breaks-after-pkg-upgrade)

- [rugged](#rugged-gem-install-fails-wo-gmake)

### Charlock Holmes-Gem install fails or breaks after `pkg upgrade`

Every now and then `devel/icu` - or other dependencies of charlock_holmes - will get updated, sometimes invalidating the gem installation in the gitlab directory.  

N.B. Your running server will continue normal operation in that case, but updates and/or rake commands in general may suddenly fail.

__Cure__ ([Kudos to herrBeesch](https://github.com/brianmario/charlock_holmes/issues/9#issuecomment-10370071))

On FreeBSD we need to tell the gem install routine where to look for certain dependencies:

```
sudo gem install charlock_holmes -- --with-icu-dir=/usr/lib --with-opt-include=/usr/local/include/
```

This process _should_ now succeed, provided _that_ it does, let's store those values in the build configuration for gitlab:

```
sudo -u git -H bundle config build.charlock_holmes --with-opt-include=/usr/local/include/ --with-opt-lib=/usr/local/lib/
```

Now you should be able to pickup where you were when you bumped into this :)



### Rugged-Gem install fails w/o gmake

```
checking for gmake... no
checking for make... yes
 -- /usr/bin/make -f Makefile.embed
*** extconf.rb failed ***
Could not create Makefile due to some reason, probably lack of necessary
libraries and/or headers.  Check the mkmf.log file for more details.  You may
need configuration options.
```
__Remedy__:

Make gmake available `sudo pkg install gmake` (or whatever freebsd install routine you prefer) and retry.

