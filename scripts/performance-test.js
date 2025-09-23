// Playwright TTFF (Time To First Frame) measurement for Gate 1 requirements
const { chromium } = require('playwright');

async function measureTTFF(url) {
    const browser = await chromium.launch();
    const page = await browser.newPage();

    console.log(`🎯 Starting TTFF measurement for: ${url}`);

    // Track navigation timing
    const startTime = Date.now();

    // Navigate and wait for first meaningful paint
    await page.goto(url, { waitUntil: 'networkidle' });

    // Get performance timing
    const performanceMetrics = await page.evaluate(() => {
        const navigation = performance.getEntriesByType('navigation')[0];
        const paintEntries = performance.getEntriesByType('paint');

        let firstPaint = 0;
        let firstContentfulPaint = 0;

        paintEntries.forEach(entry => {
            if (entry.name === 'first-paint') {
                firstPaint = entry.startTime;
            } else if (entry.name === 'first-contentful-paint') {
                firstContentfulPaint = entry.startTime;
            }
        });

        return {
            domLoading: navigation.domLoading,
            domInteractive: navigation.domInteractive,
            domComplete: navigation.domComplete,
            loadEventEnd: navigation.loadEventEnd,
            firstPaint,
            firstContentfulPaint,
            // TTFF is when first frame is rendered (first contentful paint)
            ttff: firstContentfulPaint
        };
    });

    await browser.close();

    const ttffSeconds = performanceMetrics.ttff / 1000;
    const passesRequirement = ttffSeconds <= 5.0; // Gate 1 requirement: ≤5s

    console.log(`📊 Performance Results:`);
    console.log(`   TTFF: ${ttffSeconds.toFixed(2)}s`);
    console.log(`   DOM Interactive: ${(performanceMetrics.domInteractive / 1000).toFixed(2)}s`);
    console.log(`   DOM Complete: ${(performanceMetrics.domComplete / 1000).toFixed(2)}s`);
    console.log(`   Load Event End: ${(performanceMetrics.loadEventEnd / 1000).toFixed(2)}s`);
    console.log(`   ${passesRequirement ? '✅' : '❌'} TTFF Requirement (≤5s): ${passesRequirement ? 'PASS' : 'FAIL'}`);

    if (!passesRequirement) {
        process.exit(1);
    }

    return {
        ttff: ttffSeconds,
        passes: passesRequirement,
        metrics: performanceMetrics
    };
}

// CLI usage
if (require.main === module) {
    const url = process.argv[2] || 'http://localhost:8080';
    measureTTFF(url)
        .then(result => {
            console.log(`🎉 Performance test completed successfully`);
            process.exit(0);
        })
        .catch(error => {
            console.error(`❌ Performance test failed:`, error);
            process.exit(1);
        });
}

module.exports = { measureTTFF };