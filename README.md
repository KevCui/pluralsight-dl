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
  ./pluralsight-dl.sh [-s <slug>] [-m <module_num>] [-c <clip_num>] [-r] [-l <file_dir>]

Options:
  -s <slug>          Optional, course slug
  -m <module_num>    Optional, specific module to download
  -c <clip_num>      Optional, specific clip to download
  -r                 Optional, require cf clearance in requests
                     default not required
  -l <file_dir>      Optional, enable local mode, read clip response from local dir
                     file_dir contains viewclip response json, file name must be clipId
                     default disabled
  -h | --help        Display this help message
```

## Limitation

- Pluralsight has a reCAPTCHA challenge to prevent DDoS. If this challenge is activated, current method is to fetch necessary cookie value from browser opened by puppeteer. Using this method, user must solve reCAPTCHA correctly once per day. Executing script with option `-r`, the reCAPTCHA page will be prompted in browser.

- Pluralsight has the request limit. Once the limit is reached, the account will be permanently blocked (403). Therefore, inside the script, there are `_MIN_WAIT_TIME` and `_MAX_WAIT_TIME` in order to generate a random wait time (in second) in-between those 2 values. Hope this wait time will prevent the account being blocked.

Do keep in mind that the request limit can be restricted anytime by Pluralsight. Please take your own risk that your account can be blocked when using this script!

## Disclaimer

The purpose of this script is to download courses in order to watch them later in case when Internet is not available. Please do NOT copy or distribute downloaded courses to any third party. Watch them and delete them afterwards. Please use this script at your own responsibility.
