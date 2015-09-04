SilverStripe - CMS and framework
================================

`SilverStripe`_ is an award-winning open source web content management
system and application framework used by governments, businesses, and
non-profit organisations around the world. It is a power tool for
professional web development teams, and web content authors rave about
how easy it is to use.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- SilverStripe configurations:
   
   - Installed from upstream source code to /var/www/silverstripe

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL, Adminer: username **root**
-  SilverStripe: username is email set on first boot


.. _SilverStripe: http://www.silverstripe.org
.. _TurnKey Core: http://www.turnkeylinux.org/core
.. _Adminer: http://www.adminer.org/
