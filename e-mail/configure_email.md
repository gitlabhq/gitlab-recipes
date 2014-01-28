## Centos - Sendmail

    su -
    yum -y install sendmail-cf
    cd /etc/mail
    vim /etc/mail/sendmail.mc

Add a line with the smtp gateway hostname

    define(`SMART_HOST', `smtp.example.com')dnl

Then replace this line:

    EXPOSED_USER(`root')dnl

with:

    dnl EXPOSED_USER(`root')dnl

Now enable these settings with:

    make
    chkconfig sendmail on

### Forwarding all emails

Now we want all logging of the system to be forwarded to a central email address:

    su -
    echo adminlogs@example.com > /root/.forward
    chown root /root/.forward
    chmod 600 /root/.forward
    restorecon /root/.forward

    echo adminlogs@example.com > /home/git/.forward
    chown git /home/git/.forward
    chmod 600 /home/git/.forward
    restorecon /home/git/.forward