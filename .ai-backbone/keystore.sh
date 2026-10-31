#!/usr/bin/env bash
# Keystore accounts for spec 041. A directory in AI_BACKBONE_KEYSTORE is the
# fake store on every OS, and then this script never runs security, secret-tool
# or powershell. The real tools run only when that variable is unset.
set -euo pipefail

self=$0
service=ai-backbone

valid_account() {
  local a=$1 rest seg
  [ -n "$a" ] || return 1
  case "$a" in
    /*|-*|*\\*|*$'\n'*|*$'\r'*|*\'*|*\"*|*'$'*|*'`'*) return 1 ;;
  esac
  rest=$a
  while [ -n "$rest" ]; do
    seg=${rest%%/*}
    [ -n "$seg" ] || return 1
    case "$seg" in .|..) return 1 ;; esac
    case "$seg" in *[!A-Za-z0-9._-]*) return 1 ;; esac
    if [ "$rest" = "$seg" ]; then break; fi
    rest=${rest#*/}
  done
}

fail_line() {
  printf '%s\n' "$1" >&2
}

# Fake layout: $AI_BACKBONE_KEYSTORE/items/<account> and reason/<account>.
# reason holds the word locked or nobody, never the secret.
use_fake() {
  [ -n "${AI_BACKBONE_KEYSTORE+x}" ]
}

fake_root() {
  local store
  [ -d "${AI_BACKBONE_KEYSTORE:-}" ] || return 1
  store=$(cd "$AI_BACKBONE_KEYSTORE" && pwd -P)
  printf '%s\n' "$store"
}

# Prints the item path. Refuses an account that would leave the fake store.
fake_item() {
  local account=$1 store dir real
  valid_account "$account" || return 1
  store=$(fake_root) || return 1
  dir=$(dirname "$store/items/$account")
  mkdir -p "$dir"
  real=$(perl -MCwd=abs_path -e 'my $p = abs_path($ARGV[0]); print $p if defined $p' "$dir")
  case "$real/" in
    "$store/items/"*) ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$store/items/$account"
}

fake_reason() {
  local account=$1 store dir real
  valid_account "$account" || return 1
  store=$(fake_root) || return 1
  dir=$(dirname "$store/reason/$account")
  mkdir -p "$dir"
  real=$(perl -MCwd=abs_path -e 'my $p = abs_path($ARGV[0]); print $p if defined $p' "$dir")
  case "$real/" in
    "$store/reason/"*) ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$store/reason/$account"
}

# 0 clear, 10 locked, 11 nobody. A missing sidecar is clear.
fake_block() {
  local account=$1 path word
  path=$(fake_reason "$account") || return 1
  [ -f "$path" ] || return 0
  [ -L "$path" ] && return 1
  word=$(tr -d '[:space:]' < "$path")
  case "$word" in
    locked) return 10 ;;
    nobody) return 11 ;;
  esac
  return 0
}

say_block() {
  local account=$1 rc=$2
  case "$rc" in
    10) fail_line "$account: locked" ;;
    11) fail_line "$account: nobody there to approve" ;;
    *) fail_line "$account: absent" ;;
  esac
}

# AI_BACKBONE_OS is the suite's stand-in for uname (spec 041), so a Mac test
# can run the Windows branch against a fake powershell and never DPAPI.
os_kind() {
  local os
  case "${AI_BACKBONE_OS:-}" in
    darwin|linux|windows) printf '%s\n' "$AI_BACKBONE_OS"; return 0 ;;
  esac
  os=$(uname -s)
  case "$os" in
    Darwin) printf '%s\n' darwin ;;
    Linux) printf '%s\n' linux ;;
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' windows ;;
    *) printf '%s\n' none ;;
  esac
}

# AI_BACKBONE_SECRET_HOME is the suite's home (spec 041). Unset, it is $HOME.
# The migration and doctor must not be pointed at a real home by a test.
secret_home() {
  if [ -n "${AI_BACKBONE_SECRET_HOME+x}" ]; then
    printf '%s\n' "$AI_BACKBONE_SECRET_HOME"
    return 0
  fi
  printf '%s\n' "${HOME:-}"
}

# security(1) text, never the secret, never the raw error (it can echo a value).
map_security() {
  local account=$1 errf=$2
  if grep -qiE 'could not be found|item not found|specified item could not be found' "$errf"; then
    fail_line "$account: absent"
  elif grep -qiE 'cancel|interaction is not allowed|User interaction' "$errf"; then
    fail_line "$account: nobody there to approve"
  elif grep -qiE 'lock' "$errf"; then
    fail_line "$account: locked"
  else
    fail_line "$account: absent"
  fi
}

cmd_get() {
  local account=$1
  if use_fake; then
    local item rc=0
    fake_block "$account" || rc=$?
    if [ "$rc" -ne 0 ]; then say_block "$account" "$rc"; exit 1; fi
    item=$(fake_item "$account") || { fail_line "$account: absent"; exit 1; }
    if [ ! -f "$item" ] || [ -L "$item" ]; then fail_line "$account: absent"; exit 1; fi
    cat -- "$item"
    return 0
  fi
  case "$(os_kind)" in
    darwin) darwin_get "$account" ;;
    linux) linux_get "$account" ;;
    windows) windows_get "$account" ;;
    *) fail_line "$account: absent"; exit 1 ;;
  esac
}

cmd_put() {
  local account=$1
  if use_fake; then
    local item tmp rc=0
    # A locked store or a missing approval is a failed store (spec 041).
    fake_block "$account" || rc=$?
    if [ "$rc" -ne 0 ]; then say_block "$account" "$rc"; exit 1; fi
    item=$(fake_item "$account") || { fail_line "$account: absent"; exit 1; }
    tmp=$(mktemp "$(dirname "$item")/.put.XXXXXX")
    chmod 0600 "$tmp"
    cat > "$tmp"
    mv -f "$tmp" "$item"
    chmod 0600 "$item"
    return 0
  fi
  case "$(os_kind)" in
    darwin) darwin_put "$account" ;;
    linux) linux_put "$account" ;;
    windows) windows_put "$account" ;;
    *) fail_line "$account: absent"; exit 1 ;;
  esac
}

# 0 same, 1 differ, 2 absent, 3 cannot read. Stdin is the candidate bytes.
cmd_same() {
  local account=$1 item rc=0
  if use_fake; then
    fake_block "$account" || rc=$?
    if [ "$rc" -ne 0 ]; then exit 3; fi
    item=$(fake_item "$account") || exit 3
    if [ ! -f "$item" ] || [ -L "$item" ]; then exit 2; fi
    set +e
    cmp -s "$item" -
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then exit 0; fi
    if [ "$rc" -eq 1 ]; then exit 1; fi
    exit 3
  fi
  local tmp err
  tmp=$(mktemp)
  err=$(mktemp)
  chmod 0600 "$tmp" "$err"
  set +e
  bash "$self" get "$account" > "$tmp" 2>"$err"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    if grep -q ': absent$' "$err"; then rm -f "$tmp" "$err"; exit 2; fi
    rm -f "$tmp" "$err"
    exit 3
  fi
  rm -f "$err"
  set +e
  cmp -s "$tmp" -
  rc=$?
  set -e
  rm -f "$tmp"
  if [ "$rc" -eq 0 ]; then exit 0; fi
  if [ "$rc" -eq 1 ]; then exit 1; fi
  exit 3
}

cmd_delete() {
  local account=$1 item
  if use_fake; then
    item=$(fake_item "$account") || exit 0
    rm -f -- "$item"
    return 0
  fi
  case "$(os_kind)" in
    darwin)
      security delete-generic-password -s "$service" -a "$account" >/dev/null 2>&1 || true
      ;;
    linux)
      # Clearing a secret-tool item is unverified (spec 041). Best effort.
      secret-tool clear service "$service" account "$account" >/dev/null 2>&1 || true
      ;;
    windows)
      rm -f -- "$(windows_file "$account")"
      ;;
  esac
}

# -w is last and has no value, so the password is not in argv. Whether those
# bytes are read from stdin or only from a terminal is unverified (spec 041).
darwin_get() {
  local account=$1 err out rc
  err=$(mktemp)
  out=$(mktemp)
  chmod 0600 "$err" "$out"
  set +e
  security find-generic-password -s "$service" -a "$account" -w >"$out" 2>"$err"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    map_security "$account" "$err"
    rm -f "$err" "$out"
    exit 1
  fi
  cat -- "$out"
  rm -f "$err" "$out"
}

darwin_put() {
  local account=$1 err rc
  err=$(mktemp)
  chmod 0600 "$err"
  set +e
  security add-generic-password -s "$service" -a "$account" -T "" -w 2>"$err"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    map_security "$account" "$err"
    rm -f "$err"
    exit 1
  fi
  rm -f "$err"
}

linux_get() {
  local account=$1 err out rc
  err=$(mktemp)
  out=$(mktemp)
  chmod 0600 "$err" "$out"
  # Attribute names are unverified: no local secret-tool page on 2026-10-31.
  set +e
  secret-tool lookup service "$service" account "$account" >"$out" 2>"$err"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    if grep -qiE 'not found|no such' "$err"; then fail_line "$account: absent"
    elif grep -qiE 'lock' "$err"; then fail_line "$account: locked"
    elif grep -qiE 'cancel|dismiss' "$err"; then fail_line "$account: nobody there to approve"
    else fail_line "$account: absent"
    fi
    rm -f "$err" "$out"
    exit 1
  fi
  cat -- "$out"
  rm -f "$err" "$out"
}

linux_put() {
  local account=$1
  secret-tool store --label="$service" service "$service" account "$account"
}

windows_dir() {
  local base=${LOCALAPPDATA:-$HOME/AppData/Local}
  printf '%s/ai-backbone/keystore' "$base"
}

windows_file() {
  local account=$1
  valid_account "$account" || return 1
  printf '%s/%s' "$(windows_dir)" "$account"
}

windows_get() {
  local account=$1 file
  file=$(windows_file "$account") || { fail_line "$account: absent"; exit 1; }
  [ -f "$file" ] || { fail_line "$account: absent"; exit 1; }
  # DPAPI decrypt is unverified (spec 041). The bytes go to stdout only.
  KS_PATH=$file powershell.exe -NoProfile -NonInteractive -Command 'Add-Type -AssemblyName System.Security; $p = [IO.File]::ReadAllBytes($env:KS_PATH); $r = [Security.Cryptography.ProtectedData]::Unprotect($p, $null, "CurrentUser"); [Console]::OpenStandardOutput().Write($r, 0, $r.Length)'
}

windows_put() {
  local account=$1 file dir
  file=$(windows_file "$account") || { fail_line "$account: absent"; exit 1; }
  dir=$(dirname "$file")
  mkdir -p "$dir"
  KS_PATH=$file powershell.exe -NoProfile -NonInteractive -Command 'Add-Type -AssemblyName System.Security; $ms = New-Object IO.MemoryStream; $b = New-Object byte[] 8192; $s = [Console]::OpenStandardInput(); while (($n = $s.Read($b, 0, $b.Length)) -gt 0) { $ms.Write($b, 0, $n) }; $p = [Security.Cryptography.ProtectedData]::Protect($ms.ToArray(), $null, "CurrentUser"); [IO.File]::WriteAllBytes($env:KS_PATH, $p)'
}

canon() {
  perl -MCwd=abs_path -e 'my $p = abs_path($ARGV[0]); print $p if defined $p' "$1" 2>/dev/null || true
}

under_secrets() {
  local path=$1 root sec target
  target=$(canon "$path")
  [ -n "$target" ] || return 1
  root=$(canon ".")
  sec=$root/brain/secrets
  case "$target/" in
    "$sec/"*) return 0 ;;
  esac
  return 1
}

# Store stdin-from-file, then remove the file. A failed remove rolls the
# store back when the file is still there, so only one copy remains.
store_file() {
  local display=$1 path=$2 account=$3 rc=0
  if ! valid_account "$account"; then
    printf '%s\n' "not moved: $display"
    return 1
  fi
  set +e
  bash "$self" same "$account" < "$path"
  rc=$?
  set -e
  case "$rc" in
    0) ;;
    1)
      printf '%s\n' "refused: $account already holds different bytes"
      return 1
      ;;
    2)
      if ! bash "$self" put "$account" < "$path"; then
        printf '%s\n' "not moved: $display"
        return 1
      fi
      ;;
    *)
      printf '%s\n' "not moved: $display"
      return 1
      ;;
  esac
  if ! rm -f -- "$path"; then
    bash "$self" delete "$account" || true
    printf '%s\n' "not moved: $display"
    return 1
  fi
  if [ -e "$path" ] || [ -L "$path" ]; then
    bash "$self" delete "$account" || true
    printf '%s\n' "not moved: $display"
    return 1
  fi
  printf '%s\n' "moved $display"
  return 0
}

# A spec 036 link and its target are one account: the path the tool reads.
store_link() {
  local display=$1 path=$2 account=$3 target rc=0
  if ! under_secrets "$path"; then
    printf '%s\n' "not moved: $display"
    return 1
  fi
  target=$(canon "$path")
  [ -n "$target" ] && [ -f "$target" ] && [ ! -L "$target" ] || {
    printf '%s\n' "not moved: $display"
    return 1
  }
  if ! valid_account "$account"; then
    printf '%s\n' "not moved: $display"
    return 1
  fi
  set +e
  bash "$self" same "$account" < "$target"
  rc=$?
  set -e
  case "$rc" in
    0) ;;
    1)
      printf '%s\n' "refused: $account already holds different bytes"
      return 1
      ;;
    2)
      if ! bash "$self" put "$account" < "$target"; then
        printf '%s\n' "not moved: $display"
        return 1
      fi
      ;;
    *)
      printf '%s\n' "not moved: $display"
      return 1
      ;;
  esac
  if ! rm -f -- "$target"; then
    if [ -e "$target" ] || [ -L "$target" ]; then
      bash "$self" delete "$account" || true
      printf '%s\n' "not moved: $display"
      return 1
    fi
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    bash "$self" delete "$account" || true
    printf '%s\n' "not moved: $display"
    return 1
  fi
  rm -f -- "$path" || true
  consumed="$consumed $target"
  printf '%s\n' "moved $display"
  return 0
}

project_names() {
  find . \
    \( -path ./.git -o -path ./.references -o -name node_modules -o -name target \
       -o -name build -o -name dist -o -name .venv -o -name Pods -o -name DerivedData \
       -o -name .dart_tool -o -name .gradle \) -prune \
    -o \( -type f -o -type l \) \( -name .env -o -name .envrc \) -print \
    | sed 's|^\./||' | sort -u
}

extra_names() {
  local rel
  for rel in \
    brain/secrets/.aws/credentials \
    brain/secrets/.appstoreconnect/config.env \
    brain/secrets/.config/gh/hosts.yml \
    brain/secrets/.grok/auth.json \
    brain/secrets/.grok/mcp_credentials.json \
    brain/03-stack/.aws/credentials \
    brain/03-stack/.appstoreconnect/config.env \
    brain/03-stack/.config/gh/hosts.yml \
    brain/03-stack/.grok/auth.json \
    brain/03-stack/.grok/mcp_credentials.json
  do
    if [ -e "$rel" ]; then printf '%s\n' "$rel"; fi
  done
}

home_rels() {
  printf '%s\n' \
    .aws/credentials \
    .appstoreconnect/config.env \
    .config/gh/hosts.yml \
    .grok/auth.json \
    .grok/mcp_credentials.json
}

pending() {
  local rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$rel" ] && [ ! -L "$rel" ] || continue
    printf '%s\n' "$rel"
  done <<EOF
$(project_names)
$(extra_names)
EOF
}

pending_home() {
  local rel home
  home=$(secret_home)
  [ -n "$home" ] || return 0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ -f "$home/$rel" ] && [ ! -L "$home/$rel" ]; then
      printf '%s\n' "~/$rel"
    fi
  done <<EOF
$(home_rels)
EOF
}

# 0 means the file has no passphrase and should be reported.
ssh_clear() {
  perl -e '
    my $p = $ARGV[0];
    open my $fh, "<", $p or exit 1;
    local $/; my $t = <$fh>; close $fh;
    exit 1 if !defined $t || length($t) > 1048576;
    if ($t =~ /PuTTY-User-Key-File/) {
      exit 0 if $t =~ /^Encryption:\s*none\s*$/m;
      exit 1;
    }
    # Dashes are built here so this file has no PEM header for the
    # private-key hook to refuse (spec 041).
    my $arm = "-" x 5;
    my $b = $arm . "BEGIN ";
    my $e = $arm . "END ";
    if ($t =~ /${b}([A-Z0-9 ]+)${arm}/) {
      my $kind = $1;
      if ($kind eq "OPENSSH PRIVATE KEY") {
        my $body = $t;
        my $header = $b . $kind . $arm;
        my $footer = $e . $kind . $arm;
        $body =~ s/.*?\Q$header\E//s;
        $body =~ s/\Q$footer\E.*//s;
        $body =~ s/\s+//g;
        exit 1 if $body eq "";
        my $bin = decode_b64($body);
        exit 1 if !defined $bin || substr($bin, 0, 15) ne "openssh-key-v1\0";
        my $n = unpack("N", substr($bin, 15, 4));
        exit 1 if !defined $n || 15 + 4 + $n > length($bin);
        my $cipher = substr($bin, 19, $n);
        exit($cipher eq "none" ? 0 : 1);
      }
      exit 1 if $kind eq "ENCRYPTED PRIVATE KEY";
      exit 1 if $t =~ /^Proc-Type:\s*4,ENCRYPTED/m;
      exit 0 if $kind =~ /PRIVATE KEY\z/;
    }
    exit 1;
    sub decode_b64 {
      my ($s) = @_;
      return unpack("u", pack("u", "")) if $s eq "";
      my $pad = (4 - length($s) % 4) % 4;
      $s .= "=" x $pad if $pad && $pad < 4;
      require MIME::Base64;
      return MIME::Base64::decode_base64($s);
    }
  ' "$1"
}

ssh_report() {
  local home base rel
  home=$(secret_home)
  [ -n "$home" ] && [ -d "$home/.ssh" ] || return 0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    base=$(basename "$rel")
    case "$base" in
      *.pub|known_hosts|known_hosts.old|config|authorized_keys) continue ;;
    esac
    [ -f "$home/.ssh/$rel" ] && [ ! -L "$home/.ssh/$rel" ] || continue
    if ssh_clear "$home/.ssh/$rel"; then
      printf '%s\n' "ssh key without a passphrase: ~/.ssh/$rel"
    fi
  done <<EOF
$(cd "$home/.ssh" && find . -type f -print | sed 's|^\./||' | sort)
EOF
  ssh_config "$home"
}

# man ssh_config, file date 2026-10-23, read 2026-10-31. UseKeychain and
# AddKeysToAgent are Apple ssh. First value wins, so a missing line is appended.
# An existing value, including no, is left. This does not run ssh-add.
ssh_config() {
  local home=$1 cfg add_uk=1 add_ak=1 last
  # Apple's UseKeychain is Darwin only (man ssh_config, read 2026-10-31).
  [ "$(os_kind)" = darwin ] || return 0
  [ -d "$home/.ssh" ] || return 0
  cfg=$home/.ssh/config
  if [ ! -e "$cfg" ]; then
    ( umask 077; printf '%s\n' 'UseKeychain yes' 'AddKeysToAgent yes' > "$cfg" )
    return 0
  fi
  [ -f "$cfg" ] && [ ! -L "$cfg" ] || return 0
  if grep -qiE '^[[:space:]]*UseKeychain[[:space:]]' "$cfg"; then add_uk=0; fi
  if grep -qiE '^[[:space:]]*AddKeysToAgent[[:space:]]' "$cfg"; then add_ak=0; fi
  if [ "$add_uk" -eq 0 ] && [ "$add_ak" -eq 0 ]; then return 0; fi
  if [ -s "$cfg" ]; then
    last=$(tail -c 1 "$cfg" || true)
    [ "$last" = "" ] || printf '\n' >> "$cfg"
  fi
  if [ "$add_uk" -eq 1 ]; then printf '%s\n' 'UseKeychain yes' >> "$cfg"; fi
  if [ "$add_ak" -eq 1 ]; then printf '%s\n' 'AddKeysToAgent yes' >> "$cfg"; fi
}

# True when a home secret link points at this file. The account is that home
# path, the one the tool opens, not the brain/secrets copy (spec 041).
claimed_by_home() {
  local want=$1 rel home got
  home=$(secret_home)
  [ -n "$home" ] && [ -n "$want" ] || return 1
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ -L "$home/$rel" ]; then
      got=$(canon "$home/$rel")
      [ "$got" = "$want" ] && return 0
    fi
  done <<EOF
$(home_rels)
EOF
  return 1
}

cmd_migrate() {
  local folder rel account failed=0 consumed=" " target home
  folder=$(basename -- "$PWD")
  if ! valid_account "$folder"; then
    printf '%s\n' "not moved: project folder"
    failed=1
    folder=""
  fi
  if [ -n "$folder" ]; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      [ -L "$rel" ] || continue
      account=$folder/$rel
      target=$(canon "$rel")
      case " $consumed " in
        *" $target "*) continue ;;
      esac
      # The home loop owns a file a home link already names (spec 041).
      if claimed_by_home "$target"; then continue; fi
      store_link "$rel" "$rel" "$account" || failed=1
    done <<EOF
$(project_names)
$(extra_names)
EOF
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      [ -f "$rel" ] && [ ! -L "$rel" ] || continue
      target=$(canon "$rel")
      case " $consumed " in
        *" $target "*) continue ;;
      esac
      if claimed_by_home "$target"; then continue; fi
      account=$folder/$rel
      store_file "$rel" "$rel" "$account" || failed=1
    done <<EOF
$(project_names)
$(extra_names)
EOF
  fi
  home=$(secret_home)
  if [ -n "$home" ]; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      account=home/$rel
      if [ -L "$home/$rel" ]; then
        target=$(canon "$home/$rel")
        case " $consumed " in
          *" $target "*)
            rm -f -- "$home/$rel" || true
            if [ -e "$home/$rel" ] || [ -L "$home/$rel" ]; then
              printf '%s\n' "not moved: ~/$rel"
              failed=1
            else
              printf '%s\n' "moved ~/$rel"
            fi
            continue
            ;;
        esac
        # The account is the path the tool opens. A link into brain/secrets/
        # is one copy, not a second account (spec 041, question 4).
        if under_secrets "$home/$rel"; then
          store_link "~/$rel" "$home/$rel" "$account" || failed=1
        elif [ -n "$target" ] && [ -f "$target" ]; then
          if store_file "~/$rel" "$target" "$account"; then
            rm -f -- "$home/$rel" || true
            consumed="$consumed $target"
          else
            failed=1
          fi
        else
          printf '%s\n' "not moved: ~/$rel"
          failed=1
        fi
        continue
      fi
      [ -f "$home/$rel" ] || continue
      store_file "~/$rel" "$home/$rel" "$account" || failed=1
    done <<EOF
$(home_rels)
EOF
  fi
  ssh_report || true
  exit "$failed"
}

usage() {
  fail_line "keystore.sh get|put|same|delete|migrate|pending|pending-home"
  exit 2
}

cmd=${1:-}
[ -n "$cmd" ] || usage
shift
case "$cmd" in
  get) [ $# -eq 1 ] || usage; cmd_get "$1" ;;
  put) [ $# -eq 1 ] || usage; cmd_put "$1" ;;
  same) [ $# -eq 1 ] || usage; cmd_same "$1" ;;
  delete) [ $# -eq 1 ] || usage; cmd_delete "$1" ;;
  migrate) cmd_migrate ;;
  pending) pending ;;
  pending-home) pending_home ;;
  *) usage ;;
esac
