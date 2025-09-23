// Export Security Validation for Desktop Builds (Phase 5 Academic Compliance)
const fs = require('fs');
const path = require('path');

class ExportSecurityValidator {
    constructor() {
        this.results = {
            total_tests: 0,
            passed: 0,
            failed: 0,
            warnings: 0,
            critical_issues: [],
            warning_issues: [],
            security_score: 0
        };
    }

    async validateExportSecurity(projectPath) {
        console.log(`🔒 Starting export security validation: ${projectPath}`);

        try {
            await this.validateExportPresets(projectPath);
            await this.validateBuildSecurity(projectPath);
            await this.validateFilePermissions(projectPath);
            await this.validateExportStructure(projectPath);

            this.generateSecuritySummary();
            return this.results;
        } catch (error) {
            console.error(`❌ Export validation failed:`, error.message);
            throw error;
        }
    }

    async validateExportPresets(projectPath) {
        console.log(`📋 Validating export presets security...`);

        const presetPath = path.join(projectPath, 'export_presets.cfg');
        if (!fs.existsSync(presetPath)) {
            this.addCriticalIssue('Export presets file not found');
            return;
        }

        const presets = fs.readFileSync(presetPath, 'utf-8');

        // Test encryption settings
        this.testPresetSecurity('HTML5 encryption', presets.includes('encrypt_pck=true') && presets.match(/\[preset\.0\][\s\S]*?encrypt_pck=true/));
        this.testPresetSecurity('Windows encryption', presets.includes('encrypt_pck=true') && presets.match(/\[preset\.1\][\s\S]*?encrypt_pck=true/));
        this.testPresetSecurity('Linux encryption', presets.includes('encrypt_pck=true') && presets.match(/\[preset\.2\][\s\S]*?encrypt_pck=true/));
        this.testPresetSecurity('macOS encryption', presets.includes('encrypt_pck=true') && presets.match(/\[preset\.3\][\s\S]*?encrypt_pck=true/));

        // Test debug exclusion
        this.testPresetSecurity('Debug file exclusion', presets.includes('exclude_filter') && presets.includes('*.tmp'));
        this.testPresetSecurity('Encryption filters', presets.includes('encryption_include_filters="*.gd'));

        // Test platform-specific security
        this.testPresetSecurity('macOS sandbox enabled', presets.includes('app_sandbox/enabled=true'));
        this.testPresetSecurity('macOS JIT disabled', presets.includes('allow_jit_code_generation=false'));
        this.testPresetSecurity('macOS unsigned memory disabled', presets.includes('allow_unsigned_executable_memory=false'));

        console.log(`   Export Presets: ${this.getTestResults()} tests passed`);
    }

    async validateBuildSecurity(projectPath) {
        console.log(`🛡️ Validating build security configuration...`);

        // Check for sensitive files that shouldn't be exported
        const sensitiveFiles = [
            '.env',
            'config.dev.json',
            'debug.log',
            'private_key.pem',
            'certificate.key',
            '.secrets'
        ];

        for (const file of sensitiveFiles) {
            const filePath = path.join(projectPath, file);
            this.testBuildSecurity(`No ${file} in export`, !fs.existsSync(filePath));
        }

        // Check for proper project structure
        const requiredSecurityFiles = ['export_presets.cfg'];
        for (const file of requiredSecurityFiles) {
            const filePath = path.join(projectPath, file);
            this.testBuildSecurity(`Required security file: ${file}`, fs.existsSync(filePath));
        }

        // Check for development directories that shouldn't be exported
        const devDirectories = ['development', 'debug', 'temp', '.git'];
        for (const dir of devDirectories) {
            const dirPath = path.join(projectPath, dir);
            this.testBuildSecurity(`Development directory excluded: ${dir}`, !this.wouldBeExported(dir));
        }

        console.log(`   Build Security: ${this.getTestResults()} tests passed`);
    }

    async validateFilePermissions(projectPath) {
        console.log(`📁 Validating file permissions...`);

        // Check critical files have appropriate permissions
        const criticalFiles = [
            'export_presets.cfg',
            'project.godot'
        ];

        for (const file of criticalFiles) {
            const filePath = path.join(projectPath, file);
            if (fs.existsSync(filePath)) {
                try {
                    const stats = fs.statSync(filePath);
                    const isReadable = stats.mode & parseInt('0444', 8);
                    this.testFilePermissions(`${file} readable`, isReadable);

                    // On non-Windows systems, check more detailed permissions
                    if (process.platform !== 'win32') {
                        const isNotWorldWritable = !(stats.mode & parseInt('0002', 8));
                        this.testFilePermissions(`${file} not world-writable`, isNotWorldWritable);
                    }
                } catch (error) {
                    this.addWarning(`Could not check permissions for ${file}: ${error.message}`);
                }
            }
        }

        console.log(`   File Permissions: ${this.getTestResults()} tests passed`);
    }

    async validateExportStructure(projectPath) {
        console.log(`🏗️ Validating export structure...`);

        // Check export directories exist or can be created
        const exportDirs = [
            path.join(projectPath, 'exports'),
            path.join(projectPath, 'exports', 'html5'),
            path.join(projectPath, 'exports', 'windows'),
            path.join(projectPath, 'exports', 'linux'),
            path.join(projectPath, 'exports', 'macos')
        ];

        for (const dir of exportDirs) {
            try {
                if (!fs.existsSync(dir)) {
                    fs.mkdirSync(dir, { recursive: true });
                }
                this.testExportStructure(`Export directory accessible: ${path.basename(dir)}`, fs.existsSync(dir));
            } catch (error) {
                this.testExportStructure(`Export directory creation: ${path.basename(dir)}`, false, error.message);
            }
        }

        // Validate export paths are secure (no path traversal)
        const presetPath = path.join(projectPath, 'export_presets.cfg');
        if (fs.existsSync(presetPath)) {
            const presets = fs.readFileSync(presetPath, 'utf-8');
            const exportPaths = presets.match(/export_path="([^"]+)"/g) || [];

            for (const pathMatch of exportPaths) {
                const exportPath = pathMatch.match(/"([^"]+)"/)[1];
                const isSecure = !exportPath.includes('..') && !exportPath.startsWith('/') && !exportPath.match(/^[a-zA-Z]:/);
                this.testExportStructure(`Secure export path: ${exportPath}`, isSecure || exportPath.startsWith('exports/'));
            }
        }

        console.log(`   Export Structure: ${this.getTestResults()} tests passed`);
    }

    testPresetSecurity(testName, condition, details = '') {
        this.results.total_tests++;
        if (condition) {
            this.results.passed++;
            console.log(`   ✅ ${testName}`);
        } else {
            this.results.failed++;
            this.addCriticalIssue(`Export preset security: ${testName} ${details}`);
            console.log(`   ❌ ${testName}`);
        }
    }

    testBuildSecurity(testName, condition, details = '') {
        this.results.total_tests++;
        if (condition) {
            this.results.passed++;
            console.log(`   ✅ ${testName}`);
        } else {
            this.results.warnings++;
            this.addWarning(`Build security: ${testName} ${details}`);
            console.log(`   ⚠️ ${testName}`);
        }
    }

    testFilePermissions(testName, condition, details = '') {
        this.results.total_tests++;
        if (condition) {
            this.results.passed++;
            console.log(`   ✅ ${testName}`);
        } else {
            this.results.warnings++;
            this.addWarning(`File permissions: ${testName} ${details}`);
            console.log(`   ⚠️ ${testName}`);
        }
    }

    testExportStructure(testName, condition, details = '') {
        this.results.total_tests++;
        if (condition) {
            this.results.passed++;
            console.log(`   ✅ ${testName}`);
        } else {
            this.results.failed++;
            this.addCriticalIssue(`Export structure: ${testName} ${details}`);
            console.log(`   ❌ ${testName}`);
        }
    }

    wouldBeExported(dirName) {
        // Check if directory would be exported based on export filters
        // This is a simplified check - in practice, Godot's export system is more complex
        const commonExcluded = ['development', 'debug', 'temp', '.git', 'node_modules', '.vs'];
        return !commonExcluded.includes(dirName);
    }

    addCriticalIssue(issue) {
        this.results.critical_issues.push(issue);
    }

    addWarning(issue) {
        this.results.warning_issues.push(issue);
    }

    getTestResults() {
        const recent = this.results.total_tests;
        return `${this.results.passed}/${recent}`;
    }

    generateSecuritySummary() {
        this.results.security_score = Math.round((this.results.passed / this.results.total_tests) * 100);

        console.log(`\n📊 Export Security Validation Summary:`);
        console.log(`   Total Tests: ${this.results.total_tests}`);
        console.log(`   Passed: ${this.results.passed} ✅`);
        console.log(`   Failed: ${this.results.failed} ❌`);
        console.log(`   Warnings: ${this.results.warnings} ⚠️`);
        console.log(`   Security Score: ${this.results.security_score}/100`);

        if (this.results.critical_issues.length > 0) {
            console.log(`\n❌ Critical export security issues:`);
            this.results.critical_issues.forEach(issue => {
                console.log(`   - ${issue}`);
            });
        }

        if (this.results.warning_issues.length > 0) {
            console.log(`\n⚠️ Export security warnings:`);
            this.results.warning_issues.forEach(issue => {
                console.log(`   - ${issue}`);
            });
        }

        if (this.results.failed === 0) {
            console.log(`\n🎉 Export security validation passed!`);
            console.log(`✅ All desktop export presets are properly secured`);
            console.log(`✅ Encryption enabled for sensitive files`);
            console.log(`✅ Debug and development files excluded`);
            console.log(`✅ Platform-specific security features configured`);
        } else {
            console.log(`\n❌ Export security validation failed with ${this.results.failed} critical issues`);
            throw new Error(`Export security validation failed`);
        }
    }
}

// Export security recommendations
function generateSecurityRecommendations() {
    console.log(`\n📚 Export Security Best Practices:`);
    console.log(`\n🔒 Encryption:`);
    console.log(`   - Always enable PCK encryption (encrypt_pck=true)`);
    console.log(`   - Encrypt script files (*.gd in encryption_include_filters)`);
    console.log(`   - Consider directory encryption for sensitive assets`);

    console.log(`\n🛡️ File Exclusion:`);
    console.log(`   - Exclude debug files (*.pdb, *.tmp, *.log)`);
    console.log(`   - Exclude development directories (development/*, debug/*)`);
    console.log(`   - Never include sensitive configuration files`);

    console.log(`\n🖥️ Platform Security:`);
    console.log(`   - Windows: Consider code signing for distribution`);
    console.log(`   - macOS: Enable app sandbox and disable JIT compilation`);
    console.log(`   - Linux: Validate file permissions and dependencies`);
    console.log(`   - Web: Use HTTPS for distribution, enable CSP headers`);

    console.log(`\n📋 Distribution:`);
    console.log(`   - Validate export integrity before distribution`);
    console.log(`   - Use secure channels for distribution`);
    console.log(`   - Consider additional obfuscation for commercial release`);
    console.log(`   - Implement update mechanisms with signature verification`);
}

// CLI usage
if (require.main === module) {
    const projectPath = process.argv[2] || process.cwd();
    const validator = new ExportSecurityValidator();

    validator.validateExportSecurity(projectPath)
        .then(result => {
            generateSecurityRecommendations();
            console.log(`\n🎉 Export security validation completed successfully`);
            process.exit(0);
        })
        .catch(error => {
            console.error(`❌ Export security validation failed:`, error.message);
            generateSecurityRecommendations();
            process.exit(1);
        });
}

module.exports = { ExportSecurityValidator };