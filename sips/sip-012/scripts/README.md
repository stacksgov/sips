# SIP 012 Vote Tabulation Script

The main script is `count-votes.sh`.  It will count up the votes for/against SIP 012 for a given reward cycle.  See `count-votes.sh` for detailed usage information.

Sample run:

```
$ cat stackers-19.json delegating.json | ./count-votes.sh /tmp/tally-19 4933b0b002a854a9ca7305166238d17be018ce54e415530540aa7e620e9cd86d 705850
{"yes":"10194020608227","no":"0"}
$ cat stackers-20.json delegating.json | ./count-votes.sh /tmp/tally-20 7ae943351df455aab1aa69ce7ba6606f937ebab5f34322c982227cd9e0322176 707951
{"yes":"77064706545373","no":"0"}
```

To generate the artifacts `stackers-19.json`, `stackers-20.json`, and `delegating.json` from a Stacks node's debug log file, run the following:

```
$ ./generate-artifacts.sh /path/to/node/log.txt
```
