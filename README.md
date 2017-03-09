# EdgeOS-Blacklist

Automatically updates IP blacklist for EdgeOS


# Installation

1. Copy the script `update-blacklist.sh` to `/config/scripts/post-config.d/update-blacklist.sh`
2. Make the script executable: `chmod +x /config/scripts/post-config.d/update-blacklist.sh`
3. Edit `/config/config.boot` to use blacklist e.g.

    ```diff
    firewall {
        ...
    +   group {
    +       network-group BLACKLIST_DROP {
    +       }
    +       network-group BLACKLIST_DROPv6 {
    +       }
    +   }
        ...
        ipv6-name WANv6_IN {
            ...
    +       rule 30 {
    +           action drop
    +           description "Networks to drop from blacklist"
    +           source {
    +               group {
    +                   network-group BLACKLIST_DROPv6
    +               }
    +           }
    +       }
        }
        ...
        name WAN_IN {
            ...
    +       rule 30 {
    +           action drop
    +           description "Networks to drop from blacklist"
    +           source {
    +               group {
    +                   network-group BLACKLIST_DROP
    +               }
    +           }
    +       }
    +   }
    }
    ```
    
4. Edit `/config/config.boot` to update blacklist e.g. everyday at 1am

    ```diff
    system {
        ...
    +   task-scheduler {
    +       task BLACKLIST {
    +           crontab-spec "0 1 * * *"
    +           executable {
    +               path /config/scripts/post-config.d/update-blacklist.sh
    +           }
    +       }
    +   }
    }
    ```
5. Reboot device: `reboot`
