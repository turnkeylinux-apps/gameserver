#!/bin/bash -e

set -o pipefail

SOURCE_RECORD=/usr/local/share/turnkey-gameserver/source
WRAPPER_DIR=/root/gameservers
LINUXGSM_BOOTSTRAP=/usr/local/share/turnkey-gameserver/linuxgsm.sh

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
[ "$(record_value linuxgsm_version)" = v26.2.0 ] || fail "unexpected LinuxGSM version"
[ "$(record_value linuxgsm_tag_commit)" = bded3376bc44d20b89fcc6c32f23a66347fffec6 ] ||
    fail "unexpected LinuxGSM tag commit"
[ "$(record_value linuxgsm_bootstrap_sha256)" = 0a17b88b4d6a272ce8494d55fc0c2748f3187057c15b801d71991428aa8f79bd ] ||
    fail "unexpected LinuxGSM bootstrap digest"
printf '%s  %s\n' \
    0a17b88b4d6a272ce8494d55fc0c2748f3187057c15b801d71991428aa8f79bd \
    "$LINUXGSM_BOOTSTRAP" | sha256sum -c - >/dev/null
grep -qx 'version="v26.2.0"' "$LINUXGSM_BOOTSTRAP" || fail "LinuxGSM runtime version differs"

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
    'linuxgsm_candidate_commit=bded3376bc44d20b89fcc6c32f23a66347fffec6' ||
    fail "LinuxGSM candidate commit mismatch"
printf '%s\n' "$update_check" | grep -qx 'status=up-to-date' ||
    fail "updater did not report a stable installed state"
update_apply=$(turnkey-gameserver-update --apply --dry-run)
printf '%s\n' "$update_apply" | grep -qx 'apply=dry-run verified exact candidates' ||
    fail "updater apply plan was not verified"

[ ! -e /etc/gameserver/installation.done ] ||
    fail "fixture requires a fresh appliance without an installed game"
fixture_root=/run/gameserver-v19-fixture
fixture_script=/home/gameuser/gameserver/fixtureserver
cleanup() {
    systemctl stop gameserver >/dev/null 2>&1 || true
    rm -f /etc/gameserver/gameserver "$fixture_script"
    rm -rf "$fixture_root"
}
trap cleanup EXIT HUP INT TERM

install -d -o gameuser -g gameuser -m 0755 "$fixture_root"
install -d -o gameuser -g gameuser -m 0755 /home/gameuser/gameserver
cat > "$fixture_script" <<'EOF'
#!/bin/bash -e

case "$1" in
    start) touch /run/gameserver-v19-fixture/running ;;
    stop) rm -f /run/gameserver-v19-fixture/running ;;
    *) exit 2 ;;
esac
EOF
chown gameuser:gameuser "$fixture_script"
chmod 0755 "$fixture_script"
install -d -m 0755 /etc/gameserver
cat > /etc/gameserver/gameserver <<'EOF'
GAME="fixture"
GAME_LONG_NAME="Wave 2 lightweight lifecycle fixture"
EOF

systemctl daemon-reload
systemctl start gameserver
systemctl -q is-active gameserver || fail "game-server service did not become active"
[ -f "$fixture_root/running" ] || fail "game-server start action did not reach the fixture"
systemctl stop gameserver
[ ! -e "$fixture_root/running" ] || fail "game-server stop action did not reach the fixture"
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
updater_command=turnkey-gameserver-update --check; turnkey-gameserver-update --apply --dry-run
updater_result=verified exact wrapper master commit and LinuxGSM stable tag; installed sources are current
updater_channel=official wrapper master and official LinuxGSM stable tags
integrity_evidence=wrapper archive SHA256 302b859632e34715f88b6f3455b7925efe822fb0b6b4a04514af12c1143cb983; LinuxGSM bootstrap SHA256 0a17b88b4d6a272ce8494d55fc0c2748f3187057c15b801d71991428aa8f79bd
EOF
fi

echo "PASS: GameServer management, TeamSpeak install, updater, and service lifecycle"
echo "wrapper=d2017be9f56db0da2a1c45651e656f47bc7ce42a linuxgsm=v26.2.0 servers=$server_count"
