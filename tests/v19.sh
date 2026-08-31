#!/bin/bash -e

set -o pipefail

SOURCE_RECORD=/usr/local/share/turnkey-gameserver/source
WRAPPER_DIR=/root/gameservers
LINUXGSM_BOOTSTRAP=/usr/local/share/turnkey-gameserver/linuxgsm.sh
LINUXGSM_REPO=https://github.com/GameServerManagers/LinuxGSM.git
LINUXGSM_PREVIOUS_VERSION=v26.1.0
LINUXGSM_PREVIOUS_TAG_OBJECT=ff4226b41fe9e95637e51c67dd818b7f01a478f0
LINUXGSM_PREVIOUS_SHA256=097aecc80a2932773a25ae72798a837a70b88dd243bbd9c327b57f6f3cc51e1b
LINUXGSM_CURRENT_VERSION=v26.2.0
LINUXGSM_CURRENT_TAG_OBJECT=bded3376bc44d20b89fcc6c32f23a66347fffec6
LINUXGSM_CURRENT_SHA256=0a17b88b4d6a272ce8494d55fc0c2748f3187057c15b801d71991428aa8f79bd
FIXTURE_ROOT=/run/gameserver-v19-fixture
FIXTURE_SCRIPT=/home/gameuser/gameserver/fixtureserver

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

record_value() {
    key=$1
    value=$(sed -n "s/^${key}=//p" "$SOURCE_RECORD")
    [ -n "$value" ] || fail "missing source record key: $key"
    printf '%s\n' "$value"
}

[ -f "$SOURCE_RECORD" ] || fail "missing source record"
[ "$(record_value wrapper_commit)" = d2017be9f56db0da2a1c45651e656f47bc7ce42a ] ||
    fail "unexpected wrapper commit"
[ "$(record_value wrapper_archive_sha256)" = 302b859632e34715f88b6f3455b7925efe822fb0b6b4a04514af12c1143cb983 ] ||
    fail "unexpected wrapper archive digest"
[ "$(record_value linuxgsm_version)" = "$LINUXGSM_CURRENT_VERSION" ] ||
    fail "unexpected LinuxGSM version"
[ "$(record_value linuxgsm_tag_commit)" = "$LINUXGSM_CURRENT_TAG_OBJECT" ] ||
    fail "unexpected LinuxGSM tag commit"
[ "$(record_value linuxgsm_bootstrap_sha256)" = "$LINUXGSM_CURRENT_SHA256" ] ||
    fail "unexpected LinuxGSM bootstrap digest"
printf '%s  %s\n' \
    "$LINUXGSM_CURRENT_SHA256" \
    "$LINUXGSM_BOOTSTRAP" | sha256sum -c - >/dev/null
grep -qx "version=\"$LINUXGSM_CURRENT_VERSION\"" "$LINUXGSM_BOOTSTRAP" ||
    fail "LinuxGSM runtime version differs"

server_list=$(cd "$WRAPPER_DIR" && ./auto_install.sh --list)
server_count=$(printf '%s\n' "$server_list" | grep -Ec '^\| [a-z0-9_-]+[[:space:]]+\|')
[ "$server_count" -ge 100 ] || fail "supported server catalog is unexpectedly small"
printf '%s\n' "$server_list" | grep -Eq '^\| ts3[[:space:]]+\| Teamspeak 3' ||
    fail "lightweight TeamSpeak server definition is missing"
if printf '%s\n' "$server_list" | grep -Eq '^\| mumble[[:space:]]+\|'; then
    fail "catalog offers the LinuxGSM-unsupported Mumble server"
fi

nginx -t >/dev/null 2>&1
http_redirect=$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' http://127.0.0.1/)
[ "$http_redirect" = '307 https://127.0.0.1/' ] ||
    fail "HTTP did not redirect to the HTTPS management page"
landing_page=$(curl -kfsS https://127.0.0.1/)
grep -q '<h1>TurnKey GameServer</h1>' <<<"$landing_page" ||
    fail "game-server management landing page did not render"
grep -q 'Webmin' <<<"$landing_page" || fail "management link is missing"
[ -x /usr/local/bin/gameserver-init ] || fail "game-server selector is missing"
[ -f /usr/lib/confconsole/plugins.d/Game_Server/update_list.py ] ||
    fail "catalog update action is missing from Configuration Console"

update_check=$(turnkey-gameserver-update --check)
printf '%s\n' "$update_check" | grep -qx \
    'wrapper_candidate_commit=d2017be9f56db0da2a1c45651e656f47bc7ce42a' ||
    fail "wrapper update candidate is not the verified commit"
printf '%s\n' "$update_check" | grep -qx 'linuxgsm_candidate=v26.2.0' ||
    fail "LinuxGSM update candidate is not the verified release"
printf '%s\n' "$update_check" | grep -qx \
    "linuxgsm_candidate_commit=$LINUXGSM_CURRENT_TAG_OBJECT" ||
    fail "LinuxGSM candidate commit mismatch"
printf '%s\n' "$update_check" | grep -qx 'status=up-to-date' ||
    fail "updater did not report a stable installed state"

[ ! -e /etc/gameserver/installation.done ] ||
    fail "fixture requires a fresh appliance without an installed game"
cleanup() {
    systemctl stop gameserver >/dev/null 2>&1 || true
    rm -f /etc/gameserver/gameserver "$FIXTURE_SCRIPT"
    if [ -f "$FIXTURE_ROOT/source.original" ]; then
        install -m 0644 "$FIXTURE_ROOT/source.original" "$SOURCE_RECORD"
    fi
    if [ -f "$FIXTURE_ROOT/linuxgsm.original" ]; then
        install -m 0755 "$FIXTURE_ROOT/linuxgsm.original" "$LINUXGSM_BOOTSTRAP"
    fi
    rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT HUP INT TERM

install -d -o gameuser -g gameuser -m 0755 "$FIXTURE_ROOT"
install -d -o gameuser -g gameuser -m 0755 /home/gameuser/gameserver
install -m 0644 "$SOURCE_RECORD" "$FIXTURE_ROOT/source.original"
install -m 0755 "$LINUXGSM_BOOTSTRAP" "$FIXTURE_ROOT/linuxgsm.original"

# Recreate the immediately preceding compatible official release, then take it
# through the production apply path. This verifies more than a current-state
# check or dry run while keeping vendor game downloads outside the fixture.
previous_tag_object=$(git ls-remote --refs --tags "$LINUXGSM_REPO" \
    "refs/tags/$LINUXGSM_PREVIOUS_VERSION" | awk 'NR == 1 {print $1}')
[ "$previous_tag_object" = "$LINUXGSM_PREVIOUS_TAG_OBJECT" ] ||
    fail "official previous LinuxGSM tag changed"
curl -LfsS \
    "https://raw.githubusercontent.com/GameServerManagers/LinuxGSM/$LINUXGSM_PREVIOUS_VERSION/linuxgsm.sh" \
    -o "$FIXTURE_ROOT/linuxgsm.previous"
printf '%s  %s\n' "$LINUXGSM_PREVIOUS_SHA256" "$FIXTURE_ROOT/linuxgsm.previous" |
    sha256sum -c - >/dev/null
grep -qx "version=\"$LINUXGSM_PREVIOUS_VERSION\"" \
    "$FIXTURE_ROOT/linuxgsm.previous" || fail "previous LinuxGSM bootstrap version differs"

install -m 0755 "$FIXTURE_ROOT/linuxgsm.previous" "$LINUXGSM_BOOTSTRAP"
cat > "$SOURCE_RECORD" <<EOF
wrapper_channel=official jesinmat/linux-gameservers master
wrapper_commit=d2017be9f56db0da2a1c45651e656f47bc7ce42a
wrapper_archive_sha256=302b859632e34715f88b6f3455b7925efe822fb0b6b4a04514af12c1143cb983
linuxgsm_channel=official stable tags
linuxgsm_version=$LINUXGSM_PREVIOUS_VERSION
linuxgsm_tag_commit=$LINUXGSM_PREVIOUS_TAG_OBJECT
linuxgsm_bootstrap_sha256=$LINUXGSM_PREVIOUS_SHA256
EOF

update_apply=$(turnkey-gameserver-update --apply)
printf '%s\n' "$update_apply" | grep -qx \
    "linuxgsm_installed=$LINUXGSM_PREVIOUS_VERSION" ||
    fail "real updater fixture did not start from the previous release"
printf '%s\n' "$update_apply" | grep -qx \
    "linuxgsm_candidate=$LINUXGSM_CURRENT_VERSION" ||
    fail "real updater fixture did not resolve the current release"
printf '%s\n' "$update_apply" | grep -qx 'status=update-available' ||
    fail "real updater fixture did not detect an update"
printf '%s\n' "$update_apply" | grep -qx 'apply=complete' ||
    fail "real updater fixture did not complete"
[ "$(record_value wrapper_commit)" = d2017be9f56db0da2a1c45651e656f47bc7ce42a ] ||
    fail "real updater wrote the wrong wrapper commit"
[ "$(record_value wrapper_channel)" = "official jesinmat/linux-gameservers master" ] ||
    fail "real updater wrote the wrong wrapper channel"
[ "$(record_value wrapper_archive_sha256)" = 302b859632e34715f88b6f3455b7925efe822fb0b6b4a04514af12c1143cb983 ] ||
    fail "real updater wrote the wrong wrapper digest"
[ "$(record_value linuxgsm_channel)" = "official stable tags" ] ||
    fail "real updater wrote the wrong LinuxGSM channel"
[ "$(record_value linuxgsm_version)" = "$LINUXGSM_CURRENT_VERSION" ] ||
    fail "real updater wrote the wrong LinuxGSM version"
[ "$(record_value linuxgsm_tag_commit)" = "$LINUXGSM_CURRENT_TAG_OBJECT" ] ||
    fail "real updater wrote the wrong LinuxGSM tag object"
[ "$(record_value linuxgsm_bootstrap_sha256)" = "$LINUXGSM_CURRENT_SHA256" ] ||
    fail "real updater wrote the wrong LinuxGSM digest"
[ "$(wc -l < "$SOURCE_RECORD")" -eq 7 ] ||
    fail "real updater wrote an unexpected source record shape"
printf '%s  %s\n' "$LINUXGSM_CURRENT_SHA256" "$LINUXGSM_BOOTSTRAP" |
    sha256sum -c - >/dev/null
grep -qx "version=\"$LINUXGSM_CURRENT_VERSION\"" "$LINUXGSM_BOOTSTRAP" ||
    fail "real updater installed the wrong LinuxGSM bootstrap"

# Both selection modes terminate at this verified catalog. Parse it through
# the interactive selector and verify the automatic selector's copy boundary;
# installing a vendor game binary is intentionally deferred.
grep -Fq 'select_game_auto ||' /usr/local/bin/gameserver-init ||
    fail "automatic selector boundary is missing"
grep -Fq 'select_game_interactive ||' /usr/local/bin/gameserver-init ||
    fail "interactive selector boundary is missing"
server_list=$(cd "$WRAPPER_DIR" && ./auto_install.sh --list)
server_count=$(printf '%s\n' "$server_list" | grep -Ec '^\| [a-z0-9_-]+[[:space:]]+\|')
[ "$server_count" -ge 100 ] || fail "supported server catalog is unexpectedly small"
if printf '%s\n' "$server_list" | grep -Eq '^\| mumble[[:space:]]+\|'; then
    fail "updated catalog restored the LinuxGSM-unsupported Mumble server"
fi
interactive_count=$(PYTHONDONTWRITEBYTECODE=1 python3 - "$WRAPPER_DIR" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location(
    "gameserver_menu", "/usr/local/bin/gameserver-menu.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
games = module.parse_games_from_directory(sys.argv[1] + "/games")
assert ("ts3", "Teamspeak 3") in games
print(len(games))
PY
)
[ "$interactive_count" = "$server_count" ] ||
    fail "interactive selector parsed a different catalog"
grep -qx 'GAME="ts3"' "$WRAPPER_DIR/games/ts3/game_properties.sh" ||
    fail "automatic selector input is invalid"

nginx -t >/dev/null 2>&1
landing_page=$(curl --insecure --fail --silent --show-error --location \
    http://127.0.0.1/)
printf '%s' "$landing_page" | grep -q '<h1>TurnKey GameServer</h1>' ||
    fail "game-server management landing page did not render after update"
printf '%s' "$landing_page" | grep -q 'Webmin' || fail "management link is missing"

cat > "$FIXTURE_SCRIPT" <<'EOF'
#!/bin/bash -e

case "$1" in
    start) touch /run/gameserver-v19-fixture/running ;;
    stop) rm -f /run/gameserver-v19-fixture/running ;;
    *) exit 2 ;;
esac
EOF
chown gameuser:gameuser "$FIXTURE_SCRIPT"
chmod 0755 "$FIXTURE_SCRIPT"
install -d -m 0755 /etc/gameserver
cat > /etc/gameserver/gameserver <<'EOF'
GAME="fixture"
GAME_LONG_NAME="Wave 2 lightweight lifecycle fixture"
EOF

systemctl daemon-reload
systemctl start gameserver
systemctl -q is-active gameserver || fail "game-server service did not become active"
[ -f "$FIXTURE_ROOT/running" ] || fail "game-server start action did not reach the fixture"
systemctl stop gameserver
[ ! -e "$FIXTURE_ROOT/running" ] || fail "game-server stop action did not reach the fixture"
cleanup
trap - EXIT HUP INT TERM

GAME=ts3 /usr/local/bin/gameserver-init
[ -e /etc/gameserver/installation.done ] ||
    fail "TeamSpeak catalog installation did not complete"
grep -qx 'GAME="ts3"' /etc/gameserver/gameserver ||
    fail "TeamSpeak catalog selection was not retained"
[ -x /home/gameuser/gameserver/ts3server ] ||
    fail "LinuxGSM TeamSpeak entry point was not installed"
systemctl -q is-active gameserver || fail "installed TeamSpeak server is not active"
runuser -l gameuser -c '~/gameserver/ts3server monitor' >/dev/null ||
    fail "LinuxGSM did not report the installed TeamSpeak server running"

if [ -n "${TKL_TEST_RESULT:-}" ]; then
    cat > "$TKL_TEST_RESULT" <<EOF
package_source=official jesinmat wrapper commit d2017be9f56db0da2a1c45651e656f47bc7ce42a and LinuxGSM v26.2.0 tag
installed_version=linux-gameservers d2017be9 with LinuxGSM v26.2.0
runtime_checks=management landing page, reconciled 100-plus server catalog, real TeamSpeak catalog installation, LinuxGSM monitor, update check, and service lifecycle passed
updater_command=turnkey-gameserver-update --check; disposable LinuxGSM v26.1.0 state; turnkey-gameserver-update --apply
updater_result=real apply path upgraded the official v26.1.0 bootstrap to v26.2.0 and wrote the verified final source record
updater_channel=official wrapper master and official LinuxGSM stable tags
integrity_evidence=wrapper archive SHA256 302b859632e34715f88b6f3455b7925efe822fb0b6b4a04514af12c1143cb983; LinuxGSM bootstrap SHA256 0a17b88b4d6a272ce8494d55fc0c2748f3187057c15b801d71991428aa8f79bd
EOF
fi

echo "PASS: GameServer management, TeamSpeak install, updater, and service lifecycle"
echo "wrapper=d2017be9f56db0da2a1c45651e656f47bc7ce42a linuxgsm=v26.2.0 servers=$server_count"
