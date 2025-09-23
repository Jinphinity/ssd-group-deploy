// Chaos test for market idempotency - Gate 3 requirement
const { chromium } = require('playwright');

async function chaosTestMarketIdempotency(apiUrl) {
    console.log(`🎯 Starting chaos test for market idempotency: ${apiUrl}`);

    const browser = await chromium.launch();
    const context = await browser.newContext();

    // Register and login to get JWT token
    const setupPage = await context.newPage();

    try {
        // Register a test user
        const registerResponse = await setupPage.request.post(`${apiUrl}/auth/register`, {
            data: {
                email: `chaostest_${Date.now()}@test.com`,
                password: 'testpassword123',
                display_name: 'Chaos Tester'
            }
        });

        const registerData = await registerResponse.json();
        const token = registerData.token;

        if (!token) {
            throw new Error('Failed to get authentication token');
        }

        console.log(`✅ User registered and authenticated`);

        // Create 25 identical buy requests with same request ID (idempotency test)
        const requestId = generateUUID();
        const promises = [];

        console.log(`🚀 Launching 25 parallel requests with same request ID: ${requestId}`);

        for (let i = 0; i < 25; i++) {
            const page = context.newPage();
            const promise = page.then(async (p) => {
                try {
                    const response = await p.request.post(`${apiUrl}/market/buy`, {
                        headers: {
                            'Authorization': `Bearer ${token}`,
                            'X-Request-Id': requestId,
                            'Content-Type': 'application/json'
                        },
                        data: {
                            settlement_id: 1,
                            item_id: 1,
                            quantity: 1
                        }
                    });

                    const data = await response.json();
                    await p.close();

                    return {
                        status: response.status(),
                        data: data,
                        requestNumber: i + 1
                    };
                } catch (error) {
                    await p.close();
                    return {
                        status: 'error',
                        error: error.message,
                        requestNumber: i + 1
                    };
                }
            });
            promises.push(promise);
        }

        // Wait for all requests to complete
        const results = await Promise.all(promises);

        // Analyze results
        let successCount = 0;
        let duplicateCount = 0;
        let errorCount = 0;
        let uniqueResponses = new Set();

        results.forEach((result, index) => {
            if (result.status === 200) {
                successCount++;
                if (result.data.duplicate) {
                    duplicateCount++;
                }
                // Track unique response patterns
                uniqueResponses.add(JSON.stringify(result.data));
            } else {
                errorCount++;
                console.log(`❌ Request ${result.requestNumber} failed:`, result.error || result.status);
            }
        });

        console.log(`\n📊 Chaos Test Results:`);
        console.log(`   Total Requests: 25`);
        console.log(`   Successful: ${successCount}`);
        console.log(`   Marked as Duplicates: ${duplicateCount}`);
        console.log(`   Errors: ${errorCount}`);
        console.log(`   Unique Response Patterns: ${uniqueResponses.size}`);

        // Validate idempotency requirements
        const passesIdempotency = duplicateCount >= 24; // At least 24 should be marked as duplicates
        const noErrors = errorCount === 0;
        const allProcessed = successCount === 25;

        console.log(`\n🔍 Validation:`);
        console.log(`   ${passesIdempotency ? '✅' : '❌'} Idempotency: ${passesIdempotency ? 'PASS' : 'FAIL'} (24+ duplicates detected)`);
        console.log(`   ${noErrors ? '✅' : '❌'} No Errors: ${noErrors ? 'PASS' : 'FAIL'}`);
        console.log(`   ${allProcessed ? '✅' : '❌'} All Processed: ${allProcessed ? 'PASS' : 'FAIL'}`);

        const overallPass = passesIdempotency && noErrors && allProcessed;
        console.log(`   ${overallPass ? '🎉' : '💥'} Overall: ${overallPass ? 'PASS' : 'FAIL'}`);

        if (!overallPass) {
            throw new Error('Chaos test failed - idempotency not working correctly');
        }

        return {
            totalRequests: 25,
            successCount,
            duplicateCount,
            errorCount,
            uniqueResponses: uniqueResponses.size,
            passes: overallPass
        };

    } finally {
        await setupPage.close();
        await browser.close();
    }
}

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

// CLI usage
if (require.main === module) {
    const apiUrl = process.argv[2] || 'http://localhost:8000';
    chaosTestMarketIdempotency(apiUrl)
        .then(result => {
            console.log(`🎉 Chaos test completed successfully`);
            process.exit(0);
        })
        .catch(error => {
            console.error(`❌ Chaos test failed:`, error.message);
            process.exit(1);
        });
}

module.exports = { chaosTestMarketIdempotency };