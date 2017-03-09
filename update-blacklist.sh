#!/bin/vbash

BLACKLISTS=(
    "https://www.spamhaus.org/drop/drop.txt"
    "https://www.spamhaus.org/drop/edrop.txt"
    "https://www.spamhaus.org/drop/dropv6.txt"
    #"http://www.myip.ms/files/blacklist/general/latest_blacklist.txt"
    #"http://lists.blocklist.de/lists/all.txt"
    #"https://www.dshield.org/block.txt"
    #"http://www.openbl.org/lists/base_30days.txt"
    #"http://malc0de.com/bl/IP_Blacklist.txt"
    #"http://blocklist.greensnow.co/greensnow.txt"
)

NETGROUP="BLACKLIST_DROP"
NETGROUPv6="BLACKLIST_DROPv6"

NEWGROUP="$NETGROUP-$$"
NEWGROUPv6="$NETGROUPv6-$$"
TMPFILE="/tmp/block-$$"

[ -L /dev/fd ] || (sudo ln -s /proc/self/fd /dev/fd)

{
	
cat <<EOF
create $NETGROUP -exist hash:net
create $NETGROUPv6 -exist hash:net family inet6
create $NEWGROUP hash:net
create $NEWGROUPv6 hash:net family inet6
EOF

for BLACKLIST in "${BLACKLISTS[@]}"
do
	curl -s --tr-encoding "$BLACKLIST" | tee >(egrep -o '([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}(\/[[:digit:]]{1,2})?([[:space:]-]+([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3})?' | sed -e "s/[[:space:]-]\+/-/g" -e "s/^/-A $NEWGROUP /") >(egrep -o '(([[:xdigit:]]{1,4}:){1,7}:|([[:xdigit:]]{1,4}:){1,5}(:[[:xdigit:]]{1,4}){1,2}|([[:xdigit:]]{1,4}:){1,4}(:[[:xdigit:]]{1,4}){1,3}|([[:xdigit:]]{1,4}:){1,3}(:[[:xdigit:]]{1,4}){1,4}|([[:xdigit:]]{1,4}:){1,2}(:[[:xdigit:]]{1,4}){1,5}|[[:xdigit:]]{1,4}:(:[[:xdigit:]]{1,4}){1,6}|:((:[[:xdigit:]]{1,4}){1,7}|:)|(([[:xdigit:]]{1,4}:){7}|([[:xdigit:]]{1,4}:){1,6}:)[[:xdigit:]]{1,4})(/[[:digit:]]{1,2})?' | sed -e "s/^/-A $NEWGROUPv6 /") >/dev/null | cat
done

cat <<EOF
swap $NEWGROUP $NETGROUP
swap $NEWGROUPv6 $NETGROUPv6
destroy $NEWGROUP
destroy $NEWGROUPv6
EOF

} >"$TMPFILE"

sudo ipset -file "$TMPFILE" restore
rm "$TMPFILE"

