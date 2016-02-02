# Apache 2 version

The configuration files in this directory are known to work  with GitLab 8.3
and newer versions.

Fir versions of GitLab 8.2, check the `8-2-stable` branch.
For versions of GitLab 8.0 and 8.1, check the `8-1-stable` branch.
For versions of GitLab older than 8.0, check the `apache-old` branch.

## Installations from source

If you are using Apache version 2.4 or above, please use files
[gitlab-apache24.conf](gitlab-apache24.conf) or [gitlab-ssl-apache24.conf](gitlab-ssl-apache24.conf)
for the HTTP and HTTPS versions of the vhost repectively.

If you are using Apache version 2.2, please use files
[gitlab-apache22.conf](gitlab-apache22.conf) or [gitlab-ssl-apache22.conf](gitlab-ssl-apache22.conf)
for the HTTP and HTTPS versions of the vhost repectively.

To allow `gitlab-workhorse` to listen on port 8181, edit or create
`/etc/default/gitlab` and change or add the following:

```
gitlab_workhorse_options="-listenUmask 0 -listenNetwork tcp -listenAddr 127.0.0.1:8181 -authBackend http://127.0.0.1:8080"
```

## Installations unsing the Omnibus packages

[Omnibus packages][] use their own bundled Nginx server. If you want to use your
own external Apache server, follow the steps to [configure GitLab][omnibuswebext].

In the last step you will need to download the config from this repository.

# RHEL6/CentOS6 recommendations

Most of the settings below were tested on CentOS 6, but are probably applicable
to other distributions as well.

## Puma or unicorn?

### unicorn

By default, Unicorn (i.e. `unicorn.rb`) is configured to listen on port `8080`
in GitLab's documentation. Therefore, the Apache configuration files do that
by default.

### puma

Info taken from [PR #87](https://github.com/gitlabhq/gitlab-recipes/pull/87).

As apache's mod_proxy [doesn't support][sock] sockets, the proxy URL must be
configured to use tcp instead of unix sockets. `/home/git/gitlab/config/puma.rb`
should exist and be configured.  Two changes must then be made:

1. In the Apache conf replace `http://127.0.0.1:8080 ` with `http://0.0.0.0:9292`.
   Also replace `ProxyPassreverse http://gitlab.example.com:9292`
2. Edit `puma.rb`: comment out `bind 'tcp://0.0.0.0:9292'` and comment
   `bind "unix://#{application_path}/tmp/sockets/gitlab.socket"`

## Assumptions

It is assumed GitLab will be running in a secure production environment.
This Apache `httpd` configuration is hardened for that purpose. By default this
configuration only allows strong SSL and HTTP is redirected to HTTPS. If self
signed certificates are preferred then see below in this document on managing
SSL certificates. Also see additional security recommendations located at the
bottom of this document for `httpd`. Managing GitLab with plain text HTTP only
is not recommended however the config files have been provided for that purpose.

### Encryption assumptions

Only security ciphers TLSv1.0+ and SSLv3+ are used in Apache ssl configs.
Only strong ciphers 128-bit or higher. Ciphers with known weaknesses
(i.e. MD5 hashed and RC4 based ciphers) have been purposefully excluded.

### Run GitLab insecure with HTTP only

Utilize the configs without ssl in their names to run GitLab without https.
Running a production GitLab instance over plain text HTTP is NOT recommended.

## Customize gitlab-ssl-*.conf

There are a few places where the Apache configs need to be customized for the
GitLab installation.

1. `ServerName` is defined in two VirtualHosts. `ServerName` should be set to
   host name of the GitLab installation.
2. `SSLCertificateFile`, `SSLCertificateKeyFile`, and `SSLCACertificateFile`
   should be customized for signed certificates.
3. `ProxyPassReverse http://gitlab.example.com:8080` should be customized for
   public host name of the GitLab installation.
4. At the bottom of `gitlab-ssl.conf` log file names contain `gitlab.example.com`.
   The log file names should reflect the GitLab installation host name.

A quicker method is to use `sed` to modify the file.

```bash
sed -i 's/gitlab.example.com/yourhost.com/g' gitlab-ssl-*.conf
```

Even with the quicker method `SSLCertificateFile`, `SSLCertificateKeyFile`, and
`SSLCACertificateFile` should still be modified.

## SELinux modifications

In a RHEL6 production environment it is assumed [SELinux is enabled](http://stopdisablingselinux.com/).
SELinux must be configured with the following:

```bash
setsebool -P httpd_can_network_connect on
setsebool -P httpd_can_network_relay on
setsebool -P httpd_read_user_content on
semanage -i - <<EOF
fcontext -a -t user_home_dir_t '/home/git(/.*)?'
fcontext -a -t ssh_home_t '/home/git/.ssh(/.*)?'
fcontext -a -t httpd_sys_content_t '/home/git/gitlab/public(/.*)?'
fcontext -a -t httpd_sys_content_t '/home/git/repositories(/.*)?'
EOF
restorecon -R /home/git
```

**Note:** `semanage` is part of the `policycoreutils-python` package.

## Other httpd security considerations

In `/etc/httpd/conf/httpd.conf` it is recommended to add/modify the following
values. For more information see [ServerTokens][servertokens], [ServerSignature][serversignature]
and [TraceEnable][traceenable].

```bash
ServerTokens Prod
ServerSignature Off
TraceEnable Off
```

`ServerTokens` and `ServerSignature` prevent the Apache httpd version being
broadcast in HTTP RESPONSE headers. `TraceEnable` disables HTTP tracing which
is a HTTP debugging feature and is commonly used in cross-site scripting (XSS)
attacks.

There is a vulnerability in compression over SSL and the exploit is called
[CRIME][crimepatch]. To mitigate this vulnerability it is recommended to
disable compression in `httpd`. In RHEL Apache httpd 2.2.15 (official release),
`mod_ssl` enables compression over SSL by default. The only way to mitigate
that is by implementing an [RHN solution][rhnfix].  Basically add the following
line to `/etc/sysconfig/httpd`.

```bash
export OPENSSL_NO_DEFAULT_ZLIB=1
```

For Apache httpd 2.2.24 and greater there has been a fix implemented in `mod_ssl`.
Now there's a [SSLCompression][sslcompression] option available to disable
compression over SSL.  Add the following line to `httpd.conf`.

```bash
SSLCompression Off
```

Certain modules should be disabled.  Comment out the following modules from `httpd.conf`.

```bash
#LoadModule deflate_module modules/mod_deflate.so
#LoadModule suexec_module modules/mod_suexec.so
```

`mod_deflate` is potentially used by HTTP. If VirtualHosts are configured to
use `mod_deflate` then the [CRIME][crimepatch] exploit vulnerability will be a
concern.  `mod_suexec` is dangerous if apache directories' permissions are
improperly configured. `mod_suexec` can be exploited to write to the document
root which gives a remote attacker the ability to possibly execute a local
exploit to escalate privileges. GitLab does not require `mod_suexec` so it is
better to remain disabled.

## How to self manage a Certificate Authority to sign SSL certificates

Using self signed certificates is always a bad idea. It's far more secure to
self manage a certificate authority than it is to use self signed certificates.
Running a certificate authority is easy. There are three recommended options
for managing a certificate authority for signing certificates.

1. The [xca project][xca] provides a graphical front end to certificate
   authority management in openssl.  It is available for Windows, Linux, and Mac OS.
2. The OpenVPN project provides a nice [set of scripts][ovpn_scripts] for
   managing a certificate authority as well. Eventually the GitLab project may
   include these scripts for their own purpose but for now SSL certificate
   management is outside of their scope.
3. [Be your own CA][yourca_tut] tutorial provides a more manual method of
   certificate authority management outside of scripts or UI. It provides
   openssl commands for certificate authority management.

Once a certificate authority is self managed simply add the CA certificate to
all browsers and mobile devices. Enjoy secure and validated certificates everywhere.
If a GitLab service is designated for public access then self managing a
certificate authority may not be the best option. Signed certificates should
still be the preferred method  to secure GitLab. The [StartCom SSL Certificate Authority][startcom_ssl]
provides a free service to sign Class 1 SSL certificates.

---

# Ubuntu notes

In Ubuntu httpd is called Apache2 and apache logs are located under
`/var/log/apache2`. Log path names in the GitLab Apache configuration file
should reflect this. Ubuntu runs [AppArmor][apparmor] instead of SELinux and by
default doesn't affect GitLab operation.

# General notes

## mod_pagespeed

There have been [reports][] regarding `mod_pagespeed`  on Apache.
If you ever encounter such an issue, try disabling it.
In `/etc/apache2/mods-available/pagespeed.conf` place the following:

```bash
ModPagespeed off
```

If you don't want to disable it completely, read [this article][digiocean]
to better understand it.

[startcom_ssl]: http://cert.startcom.org/
[xca]: http://sourceforge.net/projects/xca/
[ovpn_scripts]: http://openvpn.net/index.php/open-source/documentation/howto.html#pki
[yourca_tut]: http://www.g-loaded.eu/2005/11/10/be-your-own-ca/
[crimepatch]: https://issues.apache.org/bugzilla/show_bug.cgi?id=53219
[sslcompression]: http://httpd.apache.org/docs/2.2/mod/mod_ssl.html#sslcompression
[rhnfix]: https://access.redhat.com/site/solutions/255473
[servertokens]: http://httpd.apache.org/docs/2.2/mod/core.html#servertokens
[traceenable]: http://httpd.apache.org/docs/2.2/mod/core.html#traceenable
[serversignature]: http://httpd.apache.org/docs/2.2/mod/core.html#serversignature
[apparmor]: https://wiki.ubuntu.com/AppArmor
[sock]: http://httpd.apache.org/docs/2.2/mod/mod_proxy.html
[reports]: https://github.com/gitlabhq/gitlabhq/issues/5139
[digiocean]: https://www.digitalocean.com/community/tutorials/how-to-get-started-with-mod_pagespeed-with-apache-on-an-ubuntu-and-debian-cloud-server
[Omnibus packages]: https://about.gitlab.com/downloads/
[omnibuswebext]: http://doc.gitlab.com/omnibus/settings/nginx.html#using-a-non-bundled-web-server
