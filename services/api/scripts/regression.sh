#!/usr/bin/env bash
# PulangAman API regression harness (dev-auth mode).
# Requires: curl, python. Usage: BASE=https://... bash regression.sh
set -u

BASE="${BASE:-https://pulangaman-api.onrender.com}"

# Emulator coordinates provided by tester.
PARENT_LAT=1.300494;  PARENT_LNG=103.910760
CHILD_LAT=1.310750;   CHILD_LNG=103.926097   # "Sekolah Indonesia"

STAMP=$(date +%s)
P_PHONE="+62812${STAMP: -7}1"
C_PHONE="+62812${STAMP: -7}2"
G_PHONE="+62812${STAMP: -7}3"
S_PHONE="+62812${STAMP: -7}4"
P_TOK="dev:parent_${P_PHONE//[^0-9]/}"
C_TOK="dev:child_${C_PHONE//[^0-9]/}"
G_TOK="dev:guardian_${G_PHONE//[^0-9]/}"
S_TOK="dev:parent_${S_PHONE//[^0-9]/}"  # school admin logs in as generic user

PASS=0; FAIL=0
jq() { python -c "import sys,json;d=json.load(sys.stdin);print(d$1)" 2>/dev/null; }

# check NAME EXPECTED_HTTP METHOD PATH TOKEN [BODY]
run() {
  local name="$1" exp="$2" method="$3" path="$4" tok="$5" body="${6:-}"
  local args=(-sS -o /tmp/pa_body -w "%{http_code}" -X "$method" "$BASE$path" -H "Authorization: Bearer $tok")
  if [ -n "$body" ]; then args+=(-H "Content-Type: application/json" -d "$body"); fi
  local code; code=$(curl "${args[@]}")
  RESP=$(cat /tmp/pa_body)
  if [ "$code" = "$exp" ]; then
    PASS=$((PASS+1)); printf "PASS | %-38s | %s %s\n" "$name" "$method" "$code"
  else
    FAIL=$((FAIL+1)); printf "FAIL | %-38s | %s exp=%s got=%s | %s\n" "$name" "$method" "$exp" "$code" "${RESP:0:160}"
  fi
}

echo "===== PulangAman API regression  base=$BASE ====="
echo "----- Health -----"
run "health"                 200 GET  /health           "$P_TOK"
run "ready"                  200 GET  /ready            "$P_TOK"
run "auth missing token"     401 GET  /api/v1/children  "nope-no-bearer" || true
curl -sS -o /tmp/pa_body -w "%{http_code}" "$BASE/api/v1/children" > /tmp/pa_code
[ "$(cat /tmp/pa_code)" = "401" ] && { PASS=$((PASS+1)); echo "PASS | no-bearer rejected                   | GET 401"; } || { FAIL=$((FAIL+1)); echo "FAIL | no-bearer rejected"; }

echo "----- Auth / sessions -----"
P=$(curl -sS -X POST "$BASE/api/v1/auth/session" -H "Authorization: Bearer $P_TOK" -H "Content-Type: application/json" -d "{\"name\":\"Ibu Sari\",\"phone\":\"$P_PHONE\",\"role\":\"parent\"}")
PARENT_ID=$(echo "$P" | jq "['userId']"); echo "parent=$PARENT_ID"
[ -n "$PARENT_ID" ] && PASS=$((PASS+1)) && echo "PASS | parent session" || { FAIL=$((FAIL+1)); echo "FAIL | parent session | $P"; }
G=$(curl -sS -X POST "$BASE/api/v1/auth/session" -H "Authorization: Bearer $G_TOK" -H "Content-Type: application/json" -d "{\"name\":\"Pak Budi\",\"phone\":\"$G_PHONE\",\"role\":\"guardian\"}")
GUARD_ID=$(echo "$G" | jq "['userId']"); echo "guardian=$GUARD_ID"
[ -n "$GUARD_ID" ] && PASS=$((PASS+1)) && echo "PASS | guardian session" || { FAIL=$((FAIL+1)); echo "FAIL | guardian session | $G"; }
S=$(curl -sS -X POST "$BASE/api/v1/auth/session" -H "Authorization: Bearer $S_TOK" -H "Content-Type: application/json" -d "{\"name\":\"Admin Sekolah\",\"phone\":\"$S_PHONE\",\"role\":\"parent\"}")
SADMIN_ID=$(echo "$S" | jq "['userId']")

echo "----- Children -----"
CR=$(curl -sS -X POST "$BASE/api/v1/children" -H "Authorization: Bearer $P_TOK" -H "Content-Type: application/json" -d "{\"name\":\"Andi\",\"phone\":\"$C_PHONE\",\"grade\":5}")
CHILD_ID=$(echo "$CR" | jq "['id']"); echo "child=$CHILD_ID"
[ -n "$CHILD_ID" ] && PASS=$((PASS+1)) && echo "PASS | create child" || { FAIL=$((FAIL+1)); echo "FAIL | create child | $CR"; }
run "list children"          200 GET  /api/v1/children  "$P_TOK"
# child logs in (binds to created child via phone)
CS=$(curl -sS -X POST "$BASE/api/v1/auth/session" -H "Authorization: Bearer $C_TOK" -H "Content-Type: application/json" -d "{\"name\":\"Andi\",\"phone\":\"$C_PHONE\",\"role\":\"child\"}")
CHILD_LOGIN_ID=$(echo "$CS" | jq "['userId']")
[ "$CHILD_LOGIN_ID" = "$CHILD_ID" ] && PASS=$((PASS+1)) && echo "PASS | child login binds to created id" || { FAIL=$((FAIL+1)); echo "FAIL | child login binds ($CHILD_LOGIN_ID vs $CHILD_ID)"; }
run "add emergency contact"  201 POST /api/v1/children/$CHILD_ID/emergency-contacts "$P_TOK" "{\"name\":\"Nenek\",\"phone\":\"$G_PHONE\",\"priority\":1}"
run "list emergency contacts" 200 GET /api/v1/children/$CHILD_ID/emergency-contacts "$P_TOK"

echo "----- Devices -----"
run "register device (parent)" 201 POST /api/v1/devices "$P_TOK" "{\"fcmToken\":\"tok-parent-$STAMP\",\"platform\":\"android\"}"
run "register device (child)"  201 POST /api/v1/devices "$C_TOK" "{\"fcmToken\":\"tok-child-$STAMP\",\"platform\":\"android\"}"

echo "----- Zones -----"
run "create home zone"   201 POST /api/v1/zones "$P_TOK" "{\"childId\":\"$CHILD_ID\",\"type\":\"home\",\"lat\":$PARENT_LAT,\"lng\":$PARENT_LNG,\"radiusM\":150,\"name\":\"Rumah\"}"
run "create school zone" 201 POST /api/v1/zones "$P_TOK" "{\"childId\":\"$CHILD_ID\",\"type\":\"school\",\"lat\":$CHILD_LAT,\"lng\":$CHILD_LNG,\"radiusM\":150,\"name\":\"Sekolah\"}"
run "list zones"         200 GET  "/api/v1/zones?childId=$CHILD_ID" "$P_TOK"

echo "----- Location -----"
run "child post location"    202 POST /api/v1/location "$C_TOK" "{\"lat\":$CHILD_LAT,\"lng\":$CHILD_LNG,\"accuracyM\":10}"
# location returns 201? check actual; treat 200/201/202 as ok via custom
LC=$(curl -sS -o /tmp/pa_body -w "%{http_code}" -X POST "$BASE/api/v1/location" -H "Authorization: Bearer $C_TOK" -H "Content-Type: application/json" -d "{\"lat\":$CHILD_LAT,\"lng\":$CHILD_LNG,\"accuracyM\":10}")
echo "  (location raw code=$LC body=$(cat /tmp/pa_body))"
run "parent read child loc"  200 GET  /api/v1/children/$CHILD_ID/location "$P_TOK"

echo "----- Guardians -----"
run "invite guardian"    201 POST /api/v1/guardians/invite "$P_TOK" "{\"childId\":\"$CHILD_ID\",\"guardianPhone\":\"$G_PHONE\",\"guardianName\":\"Pak Budi\"}"
run "guardian invites list" 200 GET /api/v1/guardians/invites "$G_TOK"
run "guardian accept"    200 POST /api/v1/guardians/accept "$G_TOK" "{\"childId\":\"$CHILD_ID\"}"
run "list guardians"     200 GET  "/api/v1/guardians?childId=$CHILD_ID" "$P_TOK"
run "guardian presence"  200 POST /api/v1/guardians/presence "$G_TOK" "{\"status\":\"ONLINE\",\"lat\":$PARENT_LAT,\"lng\":$PARENT_LNG}"

echo "----- Panic cascade -----"
PA=$(curl -sS -X POST "$BASE/api/v1/panic/trigger" -H "Authorization: Bearer $C_TOK" -H "Content-Type: application/json" -d "{\"lat\":$CHILD_LAT,\"lng\":$CHILD_LNG}")
ALERT_ID=$(echo "$PA" | jq "['alertId']"); echo "alert=$ALERT_ID"
[ -n "$ALERT_ID" ] && PASS=$((PASS+1)) && echo "PASS | panic trigger" || { FAIL=$((FAIL+1)); echo "FAIL | panic trigger | $PA"; }
run "guardian share location" 200 POST /api/v1/guardians/share-location "$G_TOK" "{\"alertId\":\"$ALERT_ID\",\"lat\":$PARENT_LAT,\"lng\":$PARENT_LNG}"
run "parent ack panic"   200 POST /api/v1/panic/$ALERT_ID/ack "$P_TOK" "{}"
run "parent resolve panic" 200 POST /api/v1/panic/$ALERT_ID/resolve "$P_TOK" "{\"notes\":\"aman\"}"
run "revoke guardian"    200 POST /api/v1/guardians/revoke "$P_TOK" "{\"childId\":\"$CHILD_ID\",\"guardianId\":\"$GUARD_ID\"}"

echo "----- Schools -----"
SC=$(curl -sS -X POST "$BASE/api/v1/schools" -H "Authorization: Bearer $S_TOK" -H "Content-Type: application/json" -d "{\"name\":\"Sekolah Indonesia\",\"lat\":$CHILD_LAT,\"lng\":$CHILD_LNG,\"radiusM\":150,\"panicContactPhone\":\"$P_PHONE\",\"panicContactName\":\"TU\"}")
SCHOOL_ID=$(echo "$SC" | jq "['id']"); echo "school=$SCHOOL_ID"
[ -n "$SCHOOL_ID" ] && PASS=$((PASS+1)) && echo "PASS | create school" || { FAIL=$((FAIL+1)); echo "FAIL | create school | $SC"; }
run "list schools"       200 GET  /api/v1/schools "$S_TOK"
run "add roster"         201 POST /api/v1/schools/$SCHOOL_ID/roster "$S_TOK" "{\"childId\":\"$CHILD_ID\",\"grade\":5}"
run "get roster"         200 GET  /api/v1/schools/$SCHOOL_ID/roster "$S_TOK"
run "patch panic contact" 200 PATCH /api/v1/schools/$SCHOOL_ID/panic-contact "$S_TOK" "{\"panicContactPhone\":\"$P_PHONE\",\"panicContactName\":\"TU Sekolah\"}"
run "notify school panic" 200 POST /api/v1/schools/$SCHOOL_ID/notify-panic "$S_TOK" "{\"childId\":\"$CHILD_ID\",\"message\":\"tes\"}"

echo "----- Community reports -----"
RP=$(curl -sS -X POST "$BASE/api/v1/reports" -H "Authorization: Bearer $P_TOK" -H "Content-Type: application/json" -d "{\"category\":\"hazard\",\"note\":\"jalan rusak\",\"lat\":$PARENT_LAT,\"lng\":$PARENT_LNG}")
REPORT_ID=$(echo "$RP" | jq "['id']")
[ -n "$REPORT_ID" ] && PASS=$((PASS+1)) && echo "PASS | create report" || { FAIL=$((FAIL+1)); echo "FAIL | create report | $RP"; }
run "list reports"       200 GET  "/api/v1/reports?lat=$PARENT_LAT&lng=$PARENT_LNG&radiusM=5000" "$P_TOK"
run "verify report"      200 POST /api/v1/reports/$REPORT_ID/verify "$P_TOK" "{}"

echo "----- Safe route -----"
run "safe route"         200 POST /api/v1/routes/safe "$P_TOK" "{\"originLat\":$PARENT_LAT,\"originLng\":$PARENT_LNG,\"destLat\":$CHILD_LAT,\"destLng\":$CHILD_LNG,\"mode\":\"walking\"}"

echo "----- Attendance -----"
run "manual attendance"  201 POST /api/v1/attendance/manual "$P_TOK" "{\"childId\":\"$CHILD_ID\",\"schoolId\":\"$SCHOOL_ID\",\"event\":\"check_in\"}"
run "get attendance"     200 GET  "/api/v1/attendance?childId=$CHILD_ID" "$P_TOK"

echo "----- Rewards -----"
run "get rewards"        200 GET  /api/v1/rewards/$CHILD_ID "$P_TOK"
run "parent adjust reward" 201 POST /api/v1/rewards/$CHILD_ID/adjust "$P_TOK" "{\"delta\":15,\"reason\":\"rajin\"}"

echo "----- Screen time policies -----"
INSTALL="install-$STAMP-abcdef"
run "child register device policy" 201 POST /api/v1/policies/device "$C_TOK" "{\"installationId\":\"$INSTALL\",\"deviceName\":\"Emu Child\",\"appVersion\":\"0.2.0\",\"usageAccessGranted\":true,\"accessibilityEnabled\":true}"
PP=$(curl -sS -X POST "$BASE/api/v1/policies/$CHILD_ID" -H "Authorization: Bearer $P_TOK" -H "Content-Type: application/json" -d "{\"enabled\":true,\"dailyLimitMinutes\":120,\"blockedPackages\":[\"com.instagram.android\"],\"emergencyAllowlist\":[],\"schedules\":[]}" -X PUT)
POLICY_ID=$(echo "$PP" | jq "['id']"); POLICY_VER=$(echo "$PP" | jq "['version']")
[ -n "$POLICY_ID" ] && PASS=$((PASS+1)) && echo "PASS | parent publish policy (v$POLICY_VER)" || { FAIL=$((FAIL+1)); echo "FAIL | parent publish policy | $PP"; }
run "child get current policy" 200 GET /api/v1/policies/current/me "$C_TOK"
run "parent get child policy"  200 GET /api/v1/policies/$CHILD_ID "$P_TOK"
run "child ack policy"   201 POST /api/v1/policies/ack "$C_TOK" "{\"installationId\":\"$INSTALL\",\"policyId\":\"$POLICY_ID\",\"version\":$POLICY_VER}"

echo "----- Telemetry -----"
run "child telemetry batch" 202 POST /api/v1/telemetry/batch "$C_TOK" "{\"installationId\":\"$INSTALL\",\"events\":[{\"clientEventId\":\"ev-$STAMP-0001\",\"kind\":\"usage\",\"packageName\":\"com.instagram.android\",\"durationSeconds\":600,\"recordedAt\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\"}]}"
run "parent telemetry summary" 200 GET /api/v1/telemetry/$CHILD_ID/summary "$P_TOK"

echo ""
echo "===== RESULT: PASS=$PASS FAIL=$FAIL ====="
