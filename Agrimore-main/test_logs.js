const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
    console.log("Starting Puppeteer...");
    const browser = await puppeteer.launch({
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors', '--disable-web-security']
    });
    const page = await browser.newPage();
    let logs = [];
    
    page.on('console', msg => {
        const text = msg.text();
        console.log('BROWSER LOG:', text);
        logs.push(`[${msg.type()}] ${text}`);
    });
    
    page.on('pageerror', err => {
        console.log('BROWSER ERROR:', err.message);
        logs.push(`[error] ${err.message}`);
    });

    try {
        console.log("Navigating to http://localhost:5000/ ...");
        await page.goto('http://localhost:5000/', { waitUntil: 'networkidle2', timeout: 15000 });
        await new Promise(resolve => setTimeout(resolve, 5000)); // wait 5 seconds for flutter initialization
    } catch (e) {
        console.error("Navigation error:", e);
        logs.push(`[nav-error] ${e.message}`);
    }

    fs.writeFileSync('browser_logs.txt', logs.join('\n'));
    await browser.close();
    console.log("Logs saved to browser_logs.txt");
})();
