#!/bin/vbash

BLACKLIST=(
    #Suggestions
    "https://www.spamhaus.org/drop/drop.txt"
    "https://www.spamhaus.org/drop/edrop.txt"
    "https://www.spamhaus.org/drop/dropv6.txt"
    #"http://www.myip.ms/files/blacklist/general/latest_blacklist.txt"
    #"https://www.team-cymru.org/Services/Bogons/fullbogons-ipv4.txt"
    #"https://www.team-cymru.org/Services/Bogons/fullbogons-ipv6.txt"
    #"https://www.dshield.org/block.txt"
    #"http://www.openbl.org/lists/base_30days.txt"
    #"http://malc0de.com/bl/IP_Blacklist.txt"
    #"http://lists.blocklist.de/lists/all.txt"
    #"http://blocklist.greensnow.co/greensnow.txt"
    #Examples
    #"1.1.1.1"
    #"1.1.0.0/16"
    #"a:a:a:a:a:a:a:a"
    #"a:a:a:a:a:a::/48"
)

WHITELIST=(
    #Suggestions
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "fc00::/7"
    #Examples
    #"http://some.site.containing/a_whitelist.txt"
)

NETGROUP="BLACKLIST_DROP"
NETGROUPv6="BLACKLIST_DROPv6"


MAXELEM=131072

NEWGROUP="$NETGROUP-$$"
NEWGROUPv6="$NETGROUPv6-$$"

TMPFILE="/tmp/block-$$"
trap 'rm "$TMPFILE"' EXIT

[ -L /dev/fd ] || (sudo ln -s /proc/self/fd /dev/fd)

{

cat <<EOF
create $NEWGROUP hash:net maxelem $MAXELEM
create $NEWGROUPv6 hash:net family inet6 maxelem $MAXELEM
EOF

function processlist {
  for LIST in "${!1}"
  do
    if [[ $LIST == http* ]]
    then
      { error=$({ curl -fsS --tr-encoding "$LIST" | tee >(grep -Eo '((25[0-5]|(2[0-4]|1?[[:digit:]])?[[:digit:]])\.){3}(25[0-5]|(2[0-4]|1?[[:digit:]])?[[:digit:]])(\/(3[0-2]|[12]?[[:digit:]]))?([[:space:]-]+((25[0-5]|(2[0-4]|1?[[:digit:]])?[[:digit:]])\.){3}(25[0-5]|(2[0-4]|1?[[:digit:]])?[[:digit:]]))?' | sed -e 's/[[:space:]-]\+/-/g' -e "s/.*/-A -! $NEWGROUP \0 $2/") >(grep -Eo '([[:xdigit:]]{1,4}:){1,7}:|([[:xdigit:]]{1,4}:){1,5}(:[[:xdigit:]]{1,4}){1,2}|([[:xdigit:]]{1,4}:){1,4}(:[[:xdigit:]]{1,4}){1,3}|([[:xdigit:]]{1,4}:){1,3}(:[[:xdigit:]]{1,4}){1,4}|([[:xdigit:]]{1,4}:){1,2}(:[[:xdigit:]]{1,4}){1,5}|[[:xdigit:]]{1,4}:(:[[:xdigit:]]{1,4}){1,6}|:((:[[:xdigit:]]{1,4}){1,7}|:)|fe80:(:[[:xdigit:]]{0,4}){0,4}%[[:alnum:]]+|(([[:xdigit:]]{1,4}:){7}|([[:xdigit:]]{1,4}:){1,6}:)[[:xdigit:]]{1,4}|(::(f{4}(:0{1,4})?:)?|([[:xdigit:]]{1,4}:){1,4}:)((25[0-5]|(2[0-4]|1?[[:digit:]])?[[:digit:]])\.){3}(25[0-5]|(2[0-4]|1?[[:digit:]])?[[:digit:]])(/(6[0-4]|[1-5]?[[:digit:]]))?' | sed "s/.*/-A -! $NEWGROUPv6 \0 $2/") >/dev/null | cat; } 2>&1 1>&$out); } {out}>&1
      [[ ! -z "$error" ]] && { logger -s "Blacklist update failed (Unable to access '$LIST')"; exit 1; }
    else
      [[ $LIST == *:* ]] && sed "s/.*/-A -! $NEWGROUPv6 \0 $2/" <<< "$LIST" || sed "s/.*/-A -! $NEWGROUP \0 $2/" <<< "$LIST"
    fi
  done
}
processlist BLACKLIST[@]
processlist WHITELIST[@] "nomatch"

cat <<EOF
swap $NEWGROUP $NETGROUP
swap $NEWGROUPv6 $NETGROUPv6
destroy $NEWGROUP
destroy $NEWGROUPv6
EOF

} >"$TMPFILE"

result=$(sudo ipset -file "$TMPFILE" restore 2>&1)
if [[ ! -z "$result" ]]
then
  lineno=$(sed -n 's/.*line \([[:digit:]]\+\):.*/\1/p' <<<"$result")
  if [[ -z "$lineno" ]]
  then
    logger -s "Blacklist update failed ($result)"
  else 
    line=$(sed "$lineno!d" "$TMPFILE")
    error=$(sed -r 's/([^:]*:){2}[[:space:]]*//' <<<"$result")
    logger -s "Blacklist update failed ('$error' whilst executing 'sudo ipset $line')"
  fi
  exit 1;
fi
logger -s "Blacklist update successful"