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
   
   - Silverstripe CMS 6 is installed from its pinned official upstream release
     tag in ``/var/www/silverstripe``.

    **Security note**: Silverstripe updates require supervision and are not
    installed automatically. Run ``silverstripe-update --check`` to inspect
    the supported Composer patch channel. Back up the site, review the
    upstream release notes, then run ``silverstripe-update --apply`` in a
    maintenance window.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  SilverStripe: username is email set on first boot


.. _SilverStripe: https://www.silverstripe.org
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _SilverStripe documentation: https://docs.silverstripe.org/en/6/upgrading/
.. _Adminer: https://www.adminer.org/
