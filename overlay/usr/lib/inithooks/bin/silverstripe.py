#!/usr/bin/python
"""Set SilverStripe admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively

"""

import os
import sys
import getopt
import inithooks_cache
import bcrypt

from dialog_wrapper import Dialog
from mysqlconf import MySQL

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "SilverStripe Password",
            "Enter new password for the SilverStripe 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "SilverStripe Email",
            "Enter email address for the SilverStripe 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

    salt = bcrypt.gensalt(10)
    hash = bcrypt.hashpw(password, salt)

    # munge the salt and hash, argh!
    _salt = salt[4:]
    _hash = "$2y$" + hash[4:]

    m = MySQL()
    m.execute('UPDATE silverstripe.Member SET Salt=\"%s\" WHERE ID=1;' % _salt)
    m.execute('UPDATE silverstripe.Member SET Password=\"%s\" WHERE ID=1;' % _hash)
    m.execute('UPDATE silverstripe.Member SET Email=\"%s\" WHERE ID=1;' % email)

    m.execute('UPDATE silverstripe.MemberPassword SET Salt=\"%s\" WHERE ID=1;' % _salt)
    m.execute('UPDATE silverstripe.MemberPassword SET Password=\"%s\" WHERE ID=1;' % _hash)


if __name__ == "__main__":
    main()

