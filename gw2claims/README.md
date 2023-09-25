`guilds.jsonl` is a database of all guilds encountered during scans. 
They are not getting updated past the first registration, unless
manually deleting the entry.

`gw2claims.sh` will run only once. Set up a cron or a while loop script
every 5 min.

`clear_eu.sh` and `clear_na.sh` provide nice utility that will save
only the opposite server ID. This could be a function instead. 

`sudo crontab -e`

```crontab
*/5 * * * * cd /var/www/gw2skirmish.github.io/gw2claims/ && gw2claims.sh
```