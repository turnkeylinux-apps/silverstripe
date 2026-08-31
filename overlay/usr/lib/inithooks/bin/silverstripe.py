#!/usr/bin/python3
"""Set Silverstripe CMS administrator password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively

"""

import getopt
import json
import subprocess
import sys

from libinithooks import inithooks_cache
from libinithooks.dialog_wrapper import Dialog


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, _args = getopt.gnu_getopt(sys.argv[1:], "h",
                                        ['help', 'pass=', 'email='])
    except getopt.GetoptError as e:
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

    subprocess.run(
        [
            'runuser', '-u', 'www-data', '--', 'php',
            '/usr/lib/inithooks/bin/silverstripe-admin.php',
        ],
        input=json.dumps({'email': email, 'password': password}),
        text=True,
        check=True,
    )
    inithooks_cache.write('APP_EMAIL', email)


if __name__ == "__main__":
    main()
