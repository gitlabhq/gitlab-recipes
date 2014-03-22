
## FreeBsd 8 / 9 Install Troubleshooting


### Charlock Holmes installation fails

Every now and then `devel/icu` (the freebsd port of `libicu-dev`) or another library charlock_holmes depends on will get updated, thus invalidating the gem currently 
installed in the gitlab directory. 

N.B. Your running server will continue normal operation in that case, but updates or things like a rake backup command will suddenly fail.

__Solution__:

Implicetely tell the installer where to look for dependencies:

```
sudo gem install charlock_holmes -- --with-icu-dir=/usr/lib --with-opt-include=/usr/local/include/
```

After this has run through, rake commands as well as the update process (repeat last failed step) should resume normal operation.



