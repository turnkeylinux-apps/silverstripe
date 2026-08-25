#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
base=https://localhost
email=admin@example.invalid
webroot=/var/www/silverstripe
cookie=/tmp/tkl-silverstripe-cookie.$$
page=/tmp/tkl-silverstripe-page.$$
headers=/tmp/tkl-silverstripe-headers.$$
created=/tmp/tkl-silverstripe-created.$$
asset=/tmp/tkl-silverstripe-asset.$$
update=/tmp/tkl-silverstripe-update.$$
policy=/tmp/tkl-silverstripe-policy.$$

cleanup() {
    rm -f -- "$cookie" "$page" "$headers" "$created" "$asset" \
        "$update" "$policy"
}
trap cleanup EXIT

composer_version() {
    APP_ROOT="$webroot" turnkey-composer show "$1" --format=json |
        php -r '$data = json_decode(stream_get_contents(STDIN), true, flags: JSON_THROW_ON_ERROR); echo $data["versions"][0];'
}

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    cron.service multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service \
    cron.service
apache2ctl -t
apache2ctl -M 2>/dev/null | grep -q ' rewrite_module '
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-silverstripe-19\.0' /etc/turnkey_version

# shellcheck disable=SC1091
. /usr/local/share/silverstripe-release
test "$SILVERSTRIPE_VERSION" = 6.2.0
test "$SILVERSTRIPE_TAG_OBJECT" = \
    64ee1f94e92fed3dd20c205c70d42d3857628451
test "$SILVERSTRIPE_COMMIT" = d37c47c527ebb11c747cb60bde1a2c6c9be0f8c4
test "$SILVERSTRIPE_SOURCE" = \
    https://github.com/silverstripe/silverstripe-installer.git
test "$(git -c safe.directory="$webroot" -C "$webroot" rev-parse HEAD)" = \
    "$SILVERSTRIPE_COMMIT"
test "$(git -c safe.directory="$webroot" -C "$webroot" \
    rev-parse "$SILVERSTRIPE_VERSION^{tag}")" = "$SILVERSTRIPE_TAG_OBJECT"
test "$(git -c safe.directory="$webroot" -C "$webroot" \
    rev-parse "$SILVERSTRIPE_VERSION^{commit}")" = "$SILVERSTRIPE_COMMIT"

recipe_version=$(composer_version silverstripe/recipe-cms)
cms_version=$(composer_version silverstripe/cms)
test "$recipe_version" = 6.2.0
[[ $cms_version == 6.2.* ]]
php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
test "$php_version" = 8.4
for module in curl dom gd intl mbstring mysqli pdo_mysql simplexml tokenizer \
    xml zip; do
    php -m | grep -Fxiq "$module"
done
APP_ROOT="$webroot" turnkey-composer check-platform-reqs --no-dev >/dev/null
APP_ROOT="$webroot" turnkey-composer validate --no-check-publish \
    --no-interaction >/dev/null
stat -c '%U:%G %a' "$webroot/.env" | grep -Fxq 'www-data:www-data 640'
stat -c '%U:%G' "$webroot/public/assets" | grep -Fxq 'www-data:www-data'
! grep -q '^SS_DEFAULT_ADMIN_' "$webroot/.env"
grep -Fxq 'SS_ENVIRONMENT_TYPE="live"' "$webroot/.env"

curl --insecure --fail --silent --show-error --location \
    --cookie-jar "$cookie" "$base/admin/" >"$page"
token=$(sed -n 's/.*name="SecurityID" value="\([^"]*\)".*/\1/p' \
    "$page" | head -n 1)
test -n "$token"
curl --insecure --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode 'AuthenticationMethod=SilverStripe\Security\MemberAuthenticator\MemberAuthenticator' \
    --data-urlencode "Email=$email" \
    --data-urlencode "Password=$app_password" \
    --data-urlencode 'BackURL=/admin/pages' \
    --data-urlencode "SecurityID=$token" \
    --data-urlencode 'action_doLogin=Log in' \
    --dump-header "$headers" --output "$page" \
    "$base/Security/login/default/LoginForm"
grep -q '^HTTP/.* 302' "$headers"
grep -Eqi '^location: .*/admin/pages\r$' "$headers"
curl --insecure --fail --silent --show-error --location \
    --cookie "$cookie" "$base/admin/pages" >"$page"
grep -qi 'Pages' "$page"
grep -qi 'Security/logout' "$page"

suffix="$$-$RANDOM"
page_title="TurnKey v19 acceptance page $suffix"
page_segment="turnkey-v19-acceptance-$suffix"
page_content="Silverstripe page content round trip $suffix"
asset_title="TurnKey v19 acceptance asset $suffix"
asset_target="turnkey-v19/acceptance-$suffix.txt"
asset_content="Silverstripe asset content round trip $suffix"
printf '%s\n' "$asset_content" >"$asset"
chown www-data:www-data "$asset"
runuser -u www-data -- php \
    /run/tkl-v19-tests/tests/fixtures/create-content.php \
    --page-title "$page_title" --page-segment "$page_segment" \
    --page-content "$page_content" --asset-title "$asset_title" \
    --asset-target "$asset_target" --asset-source "$asset" >"$created"
page_id=$(sed -n 's/^page_id=//p' "$created")
page_url=$(sed -n 's/^page_url=//p' "$created")
asset_id=$(sed -n 's/^asset_id=//p' "$created")
asset_url=$(sed -n 's/^asset_url=//p' "$created")
test "$page_id" -gt 0
test "$asset_id" -gt 0
[[ $page_url == "/$page_segment"* ]]
[[ $asset_url == /assets/* ]]
curl --insecure --fail --silent --show-error "$base$page_url" >"$page"
grep -Fq "$page_title" "$page"
grep -Fq "$page_content" "$page"
curl --insecure --fail --silent --show-error "$base$asset_url" |
    grep -Fxq "$asset_content"

MYSQL_PWD=$db_password mariadb --user=root --batch --skip-column-names \
    silverstripe --execute \
    "SELECT CONCAT(ID, '|', Title, '|', URLSegment) FROM SiteTree_Live WHERE ID=$page_id" |
    grep -Fxq "$page_id|$page_title|$page_segment"
MYSQL_PWD=$db_password mariadb --user=root --batch --skip-column-names \
    silverstripe --execute \
    "SELECT CONCAT(ID, '|', Title, '|', FileFilename) FROM File_Live WHERE ID=$asset_id" |
    grep -Fxq "$asset_id|$asset_title|$asset_target"
MYSQL_PWD=$db_password mariadb --user=root --batch --skip-column-names \
    silverstripe --execute "SELECT Email FROM Member WHERE ID=1" |
    grep -Fxq "$email"
systemctl restart mariadb.service
curl --insecure --fail --silent --show-error "$base$page_url" |
    grep -Fq "$page_content"

dpkg-query -W adminer webmin-apache webmin-mysql webmin-phpini postfix \
    >/dev/null
curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12322/ | grep -qi Adminer
curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12321/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

before_app=$(sha256sum "$webroot/composer.json" "$webroot/composer.lock")
silverstripe-update --check >"$update" 2>&1
after_app=$(sha256sum "$webroot/composer.json" "$webroot/composer.lock")
test "$after_app" = "$before_app"
grep -Eq 'Nothing to (modify|install)|Package operations:' "$update"

composer_package=$(dpkg-query -W -f='${Version}' composer)
mariadb_package=$(dpkg-query -W -f='${Version}' mariadb-server)
apache_package=$(dpkg-query -W -f='${Version}' apache2)
before_debian="$composer_package|$mariadb_package|$apache_package"
apt-get update >/dev/null
for package in php-cli composer mariadb-server apache2 git; do
    apt-cache policy "$package" >"$policy"
    candidate=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate"
    test "$candidate" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after_debian="$(dpkg-query -W -f='${Version}' composer)|$(dpkg-query -W -f='${Version}' mariadb-server)|$(dpkg-query -W -f='${Version}' apache2)"
test "$after_debian" = "$before_debian"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Official immutable Silverstripe installer tag $SILVERSTRIPE_VERSION, tag object $SILVERSTRIPE_TAG_OBJECT and commit $SILVERSTRIPE_COMMIT; CMS patch packages from the official Composer channel; PHP, MariaDB, Apache and Composer from Debian Trixie
installed_version=Silverstripe recipe $recipe_version and CMS $cms_version; PHP $php_version; composer $composer_package; mariadb-server $mariadb_package; apache2 $apache_package
runtime_checks=normal init; Apache, MariaDB, Postfix and cron health; firstboot administrator HTTPS login; published page and asset create-read round trips; direct MariaDB persistence and database restart; Adminer and Webmin HTTPS endpoints
updater_command=silverstripe-update --check
updater_result=Composer resolved the supported 6.2 patch channel without changing composer.json, composer.lock or installed Debian packages
updater_channel=https://repo.packagist.org metadata for the official silverstripe/recipe-cms ~6.2.0 stable dependency channel
integrity_evidence=Official GitHub release tag object and commit matched the installed Git checkout; Composer lock references and platform requirements validated; APT accepted signed Trixie metadata; no Bookworm source remained
EOF
