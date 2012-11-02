# CentOS daemon scripts for gitlab service

## Related (kudos @4sak3n0ne):

* https://github.com/gitlabhq/gitlabhq/issues/1049#issuecomment-8386882

* https://gist.github.com/3062860

## Notes

Add the service to chkconfig with:

    chkconfig --add gitlab

Related services (redis, mysql, nginx) should also be added to chkconfig.

Check chkconfig state with 

    chkconfig -l

And if any of the services are not set properly, run:

    chkconfig --levels 2345 [name] on

