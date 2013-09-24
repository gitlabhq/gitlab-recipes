# RHEL6/CentOS6 recommendations

The up-to-date recommended `gitlab.conf` was configured on RHEL 6.4.

## Puma or unicorn?

### unicorn

By default, Unicorn (i.e. `unicorn.rb`) is configured to listen on port `8080` in the gitlabhq documentation.  Therefore, [gitlab.conf](gitlab.conf) does that by default.

### puma

Info taken from [PR #87](https://github.com/gitlabhq/gitlab-recipes/pull/87).

As apache's mod_proxy [doesn't support][sock] sockets, we have to configure the 
proxy URL to use tcp instead of unix sockets. First make sure that `/home/git/gitlab/config/puma.rb` exists.
Then you have to make 2 changes:

1. In `gitlab.conf` replace `http://127.0.0.1:8080/ ` with `http://0.0.0.0:9292/`
2. Edit `puma.rb`: comment out `bind 'tcp://0.0.0.0:9292'` and comment `bind "unix://#{application_path}/tmp/sockets/gitlab.socket"`

## Assumptions

Since it is assumed your GitLab will be running in a secure production system, this Apache `httpd` configuration is hardened for that purpose.  By default this configuration only allows strong SSL and HTTP is redirected to HTTPS.  If you wish to manage your own self signed certificates then see below on managing your own SSL certificates.  Also see additional security recommendations located at the bottom of this document for `httpd`.  If you wish to run with plain text HTTP only (not recommended) then the [gitlab.conf](gitlab.conf) can be easily modified.

### Encryption assumptions

For the hardened security ciphers I decided to go with TLSv1.0+ and SSLv3+.  Only strong ciphers 128-bit or higher.  Ciphers with known weaknesses (i.e. MD5 hashed and RC4 based ciphers) have been purposefully excluded.

### Run GitLab insecure with HTTP only

Simply remove the following lines:

      SSLEngine on
      #strong encryption ciphers only
      #see ciphers(1) http://www.openssl.org/docs/apps/ciphers.html
      SSLCipherSuite SSLv3:TLSv1:+HIGH:!SSLv2:!MD5:!MEDIUM:!LOW:!EXP:!ADH:!eNULL:!aNULL
      SSLCertificateFile /etc/httpd/ssl.crt/gitlab.example.com.crt
      SSLCertificateKeyFile /etc/httpd/ssl.key/gitlab.example.com.key
      SSLCACertificateFile /etc/httpd/ssl.crt/your-ca.crt

Remove this entire block.

    <VirtualHost *:80>
      ServerName gitlab.example.com
      ServerSignature Off 
    
      RewriteEngine on
      RewriteCond %{HTTPS} !=on
      RewriteRule ^(.*) https://%{SERVER_NAME}$1 [R,L]
    </VirtualHost>

And change `<VirtualHost *:443>` to `<VirtualHost *:80>`.

## Customize gitlab.conf

There are a few places in [gitlab.conf](gitlab.conf) where you'll need to modify for your own configuration.

1. `ServerName` is defined in two VirtualHosts.  You'll need to set `ServerName` to your own host value.
2. `SSLCertificateFile`, `SSLCertificateKeyFile`, and `SSLCACertificateFile` should be customized for your setup using your own signed certificates.
3. `ProxyPassReverse http://gitlab.example.com:8080` should be customized for your public host name of GitLab.
4. At the bottom of `gitlab.conf` I have the log file names defined with `gitlab.example.com`.  You should change that so it includes your hostname instead.

## SELinux modifications

In your production environment it is assumed you'll be running SELinux enabled.  Therefore you should make the following SELinux changes.

    setsebool -P httpd_can_network_connect on
    setsebool -P httpd_can_network_relay on
    setsebool -P httpd_enable_homedirs on
    setsebool -P httpd_read_user_content on
    semanage fcontext -a -t user_home_dir_t '/home/git(/.*)?'
    semanage fcontext -a -t ssh_home_t '/home/git/.ssh(/.*)?'
    semanage fcontext -a -t httpd_sys_content_t '/home/git/gitlab/public(/.*)?'
    semanage fcontext -a -t httpd_sys_content_t '/home/git/repositories(/.*)?'
    restorecon -R /home/git

## Other httpd security considerations

In `/etc/httpd/conf/httpd.conf` it is recommended you add/modify the following values.  For more information see [ServerTokens][servertokens], [ServerSignature][serversignature], and [TraceEnable][traceenable].

    ServerTokens Prod
    ServerSignature Off
    TraceEnable Off

`ServerTokens` and `ServerSignature` prevent your Apache httpd version being broadcast in HTTP RESPONSE headers.  `TraceEnable` disables HTTP tracing which is a HTTP debugging feature and is commonly used in cross-site scripting (XSS) attacks.

There is a vulnerability in compression over SSL and the exploit is called [CRIME][crimepatch].  To mitigate this vulnerability it is recommended to disable compression in `httpd`.  In RHEL Apache httpd 2.2.15 (official release) `mod_ssl` enables compression over SSL by default.  The only way to mitigate that is by implementing an [RHN solution][rhnfix].  Basically add the following line to `/etc/sysconfig/httpd`.

    export OPENSSL_NO_DEFAULT_ZLIB=1

For Apache httpd 2.2.24 and greater there has been a fix implemented in `mod_ssl`.  Now there's a [SSLCompression][sslcompression] option available to disable compression in SSL.  Add the following line to your `httpd.conf`.

    SSLCompression Off

You should comment out the following modules from your `httpd.conf`.

    #LoadModule deflate_module modules/mod_deflate.so
    #LoadModule suexec_module modules/mod_suexec.so

`mod_deflate` is potentially used by HTTP.  If you set up HTTP to use it then you'll still be vulnerable to the [CRIME][crimepatch] exploit.  `mod_suexec` is dangerous if apache directories' permissions are improperly configured.  `mod_suexec` can be exploited to write to the document root which gives a remote attacker the ability to possible execute a local exploit to escalate privileges.  There's not reason to `mod_suexec` enabled for GitLab.

## Manage your own SSL Certificates

Using self signed certificates is always a bad idea.  It's far more secure to run and manage your own certificate authority than it is to use self signed certificates.   Running your own certificate authority is easy.  There are 3 ways you can manage your own certificate authority for signing certificates.

1. The [xca project][xca] provides a graphical front end to certificate authority management in openssl.  It is available for Windows, Linux, and Mac OS.
2. The OpenVPN project provides a nice [set of scripts][ovpn_scripts] for managing a certificate authority as well.  I'd like the GitLab project to include these scripts for their own purpose but for now SSL certificate management is outside of their scope.
3. [Be your own CA][yourca_tut] tutorial which is a personal favorite and much lighter weight than the previous two options.

For your own certificate authority you just add your CA certificate to all of your browsers and mobile devices. Then you have secure and validated certificates everywhere.  If you would like your server to be more public and open you should still use SSL to secure your service because of password authentication.  You may utilize the free [StartCom SSL Certificate Authority][startcom_ssl] to sign your public certificates for free.

---
# Ubuntu 12.04 notes

In Ubuntu httpd is called Apache2 and apache logs are located under `/var/log/apache2`.  You may wish to change this in the [gitlab.conf](gitlab.conf) configuration.  Ubuntu runs [AppArmor][apparmor] instead of SELinux and by default doesn't affect GitLab operation.

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

