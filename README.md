pluralsight-dl
==============

pluralsight-dl.sh is a Bash script to download courses from [Pluralsight](https://www.pluralsight.com/).

## Dependency

- [jq](https://stedolan.github.io/jq/)
- [commander](https://github.com/tj/commander.js)
- [puppeteer-core](https://github.com/puppeteer/puppeteer)

## npm package installation

```bash
~$ cd bin
~$ npm i puppeteer-core commander
```

## Configuration

- This script is required to login Pluralsight account to get a valid JWT for course downloading. Create `config` file, put Pluralsight username and password in it. First line is `username`, second line is `password`:

```
<username>
<password>
```

## How to use

```
Usage:
  ./pluralsight-dl.sh [-s <slug>]

Options:
  -s <slug>          Optional, course slug
  -h | --help        Display this help message
```

## Limitation

Pluralsight has the request limit. Once the limit is reached, the account will be permanently blocked (403). Therefore, inside the script, there are `_MIN_WAIT_TIME` and `_MAX_WAIT_TIME` in order to generate a random wait time (in second) in-between those 2 values. Hope this wait time will prevent the account being blocked.

Do keep in mind that the request limit can be restricted anytime by Pluralsight. Please take your own risk that your account can be blocked when using this script!

## Disclaimer

The purpose of this script is to download courses in order to watch them later in case when Internet is not available. Please do NOT copy or distribute downloaded courses to any third party. Watch them and delete them afterwards. Please use this script at your own responsibility.
