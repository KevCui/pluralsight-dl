#!/usr/bin/env node

const program = require('commander');
const puppeteer = require('puppeteer-core');

program
    .name('./getjwt.js')
    .usage('-a <user-agent> [-u <username>] [-p <password>] [-c <path>]')
    .option('-a, --agent <user_agent>', 'browser user agent')
    .option('-u, --username <username>', 'optional, username for log-in')
    .option('-p, --password <password>', 'optional, password for log-in')
    .option('-c, --chromepath <binary_path>', 'optional, path to chrome/chromium binary\ndefault "/usr/bin/chromium"');

program.parse(process.argv);

if (program.agent === undefined) {
    console.log("[ERROR] -a <user_agent> is undefined!");
    return 1;
}

const cPath = (program.chromepath === undefined) ? '/usr/bin/chromium' : program.chromepath;
const uName = (program.username === undefined) ? '' : program.username;
const pWord = (program.password === undefined) ? '' : program.password;

if (uName === "" && pWord === "") {
    var hMode = false;
} else if ( uName == "" && pWord != ""){
    console.log('[ERROR] password option is not set!');
    return 1;
} else if ( uName != "" && pWord == ""){
    console.log('[ERROR] username option is not set!');
    return 1;
} else {
    var hMode = true;
}

(async() => {
    const url = 'https://app.pluralsight.com/id?';
    const usernameInput = '#Username';
    const passwordInput = '#Password';
    const loginButton = '#login';
    const searchBar = '#prism-search-input';

    const browser = await puppeteer.launch({executablePath: cPath, headless: hMode});
    const page = await browser.newPage();
    await page.setUserAgent(program.agent);

    await page.goto(url, {timeout: 30000, waitUntil: 'domcontentloaded'});

    if (hMode === true) {
        await page.waitForSelector(loginButton);
        await page.type(usernameInput, uName, {delay: 50});
        await page.type(passwordInput, pWord, {delay: 50});
        await page.click(loginButton);
    }

    await page.waitForSelector(searchBar);
    const cookie = await page.cookies();
    console.log(JSON.stringify(cookie));
    await browser.close();
})();
