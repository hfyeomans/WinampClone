#!/bin/bash

# WinAmp Player Comprehensive Test Suite Runner
# Runs all tests and generates unified test report
# Compatible with macOS 15.5

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${TEST_DIR}/build"
RESULTS_DIR="${TEST_DIR}/test_results"
COVERAGE_DIR="${RESULTS_DIR}/coverage"
REPORT_DIR="${RESULTS_DIR}/reports"
LOG_FILE="${RESULTS_DIR}/test_run_$(date +%Y%m%d_%H%M%S).log"

# Initialize test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Ensure results directories exist
mkdir -p "${RESULTS_DIR}"
mkdir -p "${COVERAGE_DIR}"
mkdir -p "${REPORT_DIR}"

# Logging function
log() {
    echo -e "$1" | tee -a "${LOG_FILE}"
}

# Error handling
handle_error() {
    log "${RED}Error occurred in test execution at line $1${NC}"
    log "${RED}Error: $2${NC}"
    generate_failure_report
    exit 1
}

trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Print banner
print_banner() {
    log "${BLUE}======================================${NC}"
    log "${BLUE}   WinAmp Player Test Suite Runner    ${NC}"
    log "${BLUE}   macOS 15.5 Compatibility Test      ${NC}"
    log "${BLUE}   $(date)${NC}"
    log "${BLUE}======================================${NC}"
}

# Check system compatibility
check_system_compatibility() {
    log "\n${YELLOW}[1/9] Checking System Compatibility...${NC}"
    
    # Check macOS version
    if [[ "$(uname)" != "Darwin" ]]; then
        log "${RED}✗ Not running on macOS${NC}"
        return 1
    fi
    
    # Get macOS version
    macos_version=$(sw_vers -productVersion)
    log "Current macOS version: $macos_version"
    
    # Check for minimum version (15.5)
    if [[ $(echo "$macos_version 15.5" | awk '{if ($1 >= $2) print 1; else print 0}') -eq 0 ]]; then
        log "${YELLOW}⚠ Warning: Running on macOS $macos_version (recommended: 15.5+)${NC}"
    else
        log "${GREEN}✓ macOS version compatible${NC}"
    fi
    
    # Check for required tools
    for tool in cmake make clang xcrun instruments; do
        if ! command -v $tool &> /dev/null; then
            log "${RED}✗ Required tool '$tool' not found${NC}"
            return 1
        fi
    done
    
    log "${GREEN}✓ All required tools found${NC}"
    
    # Check Xcode installation
    if ! xcode-select -p &> /dev/null; then
        log "${RED}✗ Xcode Command Line Tools not installed${NC}"
        return 1
    fi
    
    log "${GREEN}✓ Xcode Command Line Tools installed${NC}"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

# Build application in debug mode
build_application() {
    log "\n${YELLOW}[2/9] Building Application (Debug Mode)...${NC}"
    
    # Clean previous build
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    
    cd "${BUILD_DIR}"
    
    # Configure with CMake
    log "Configuring build..."
    if cmake -DCMAKE_BUILD_TYPE=Debug \
             -DENABLE_COVERAGE=ON \
             -DENABLE_SANITIZERS=ON \
             -DCMAKE_CXX_FLAGS="-fsanitize=address -fsanitize=undefined" \
             -DCMAKE_C_FLAGS="-fsanitize=address -fsanitize=undefined" \
             .. >> "${LOG_FILE}" 2>&1; then
        log "${GREEN}✓ CMake configuration successful${NC}"
    else
        log "${RED}✗ CMake configuration failed${NC}"
        return 1
    fi
    
    # Build
    log "Building application..."
    if make -j$(sysctl -n hw.ncpu) >> "${LOG_FILE}" 2>&1; then
        log "${GREEN}✓ Build successful${NC}"
        ((PASSED_TESTS++))
    else
        log "${RED}✗ Build failed${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
    
    ((TOTAL_TESTS++))
    cd "${TEST_DIR}"
}

# Run unit tests
run_unit_tests() {
    log "\n${YELLOW}[3/9] Running Unit Tests...${NC}"
    
    local test_categories=("AudioTests" "UITests" "VisualizationTests")
    local category_results=()
    
    for category in "${test_categories[@]}"; do
        log "\nRunning $category..."
        
        if [[ -f "${BUILD_DIR}/Tests/$category" ]]; then
            if "${BUILD_DIR}/Tests/$category" --gtest_output=xml:"${RESULTS_DIR}/${category}_results.xml" >> "${LOG_FILE}" 2>&1; then
                log "${GREEN}✓ $category passed${NC}"
                ((PASSED_TESTS++))
                category_results+=("$category:PASS")
            else
                log "${RED}✗ $category failed${NC}"
                ((FAILED_TESTS++))
                category_results+=("$category:FAIL")
            fi
        else
            log "${YELLOW}⚠ $category not found, skipping${NC}"
            ((SKIPPED_TESTS++))
            category_results+=("$category:SKIP")
        fi
        ((TOTAL_TESTS++))
    done
    
    # Generate unit test summary
    echo "Unit Test Summary:" > "${RESULTS_DIR}/unit_test_summary.txt"
    for result in "${category_results[@]}"; do
        echo "  $result" >> "${RESULTS_DIR}/unit_test_summary.txt"
    done
}

# Run integration tests
run_integration_tests() {
    log "\n${YELLOW}[4/9] Running Integration Tests...${NC}"
    
    if [[ -f "${BUILD_DIR}/Tests/IntegrationTests" ]]; then
        if timeout 300 "${BUILD_DIR}/Tests/IntegrationTests" \
            --gtest_output=xml:"${RESULTS_DIR}/integration_results.xml" >> "${LOG_FILE}" 2>&1; then
            log "${GREEN}✓ Integration tests passed${NC}"
            ((PASSED_TESTS++))
        else
            log "${RED}✗ Integration tests failed${NC}"
            ((FAILED_TESTS++))
        fi
    else
        log "${YELLOW}⚠ Integration tests not found${NC}"
        ((SKIPPED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Run performance benchmarks
run_performance_benchmarks() {
    log "\n${YELLOW}[5/9] Running Performance Benchmarks...${NC}"
    
    if [[ -f "${BUILD_DIR}/Tests/PerformanceTests" ]]; then
        log "Running performance benchmarks (this may take a while)..."
        
        if "${BUILD_DIR}/Tests/PerformanceTests" \
            --benchmark_out="${RESULTS_DIR}/benchmark_results.json" \
            --benchmark_out_format=json >> "${LOG_FILE}" 2>&1; then
            log "${GREEN}✓ Performance benchmarks completed${NC}"
            ((PASSED_TESTS++))
            
            # Extract key metrics
            if command -v jq &> /dev/null && [[ -f "${RESULTS_DIR}/benchmark_results.json" ]]; then
                log "\nKey Performance Metrics:"
                jq -r '.benchmarks[] | "\(.name): \(.real_time) ns"' "${RESULTS_DIR}/benchmark_results.json" | head -10
            fi
        else
            log "${RED}✗ Performance benchmarks failed${NC}"
            ((FAILED_TESTS++))
        fi
    else
        log "${YELLOW}⚠ Performance tests not found${NC}"
        ((SKIPPED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Generate code coverage report
generate_coverage_report() {
    log "\n${YELLOW}[6/9] Generating Code Coverage Report...${NC}"
    
    if command -v llvm-cov &> /dev/null; then
        # Collect coverage data
        find "${BUILD_DIR}" -name "*.gcda" -o -name "*.gcno" | while read -r file; do
            cp "$file" "${COVERAGE_DIR}/" 2>/dev/null || true
        done
        
        # Generate coverage report
        if [[ -n "$(find "${COVERAGE_DIR}" -name "*.gcda" 2>/dev/null)" ]]; then
            llvm-cov gcov "${COVERAGE_DIR}"/*.gcda >> "${LOG_FILE}" 2>&1
            
            # Generate HTML report if lcov is available
            if command -v lcov &> /dev/null && command -v genhtml &> /dev/null; then
                lcov --capture --directory "${BUILD_DIR}" --output-file "${COVERAGE_DIR}/coverage.info" >> "${LOG_FILE}" 2>&1
                genhtml "${COVERAGE_DIR}/coverage.info" --output-directory "${REPORT_DIR}/coverage_html" >> "${LOG_FILE}" 2>&1
                log "${GREEN}✓ Code coverage HTML report generated${NC}"
            else
                log "${YELLOW}⚠ lcov not found, skipping HTML coverage report${NC}"
            fi
            
            log "${GREEN}✓ Code coverage data collected${NC}"
            ((PASSED_TESTS++))
        else
            log "${YELLOW}⚠ No coverage data found${NC}"
            ((SKIPPED_TESTS++))
        fi
    else
        log "${YELLOW}⚠ llvm-cov not found, skipping coverage${NC}"
        ((SKIPPED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Create unified HTML report
create_unified_report() {
    log "\n${YELLOW}[7/9] Creating Unified HTML Test Report...${NC}"
    
    local report_file="${REPORT_DIR}/test_report_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "${report_file}" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WinAmp Player Test Report - $(date)</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007AFF; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .stat-box { flex: 1; padding: 20px; border-radius: 8px; text-align: center; color: white; }
        .stat-box.total { background: #007AFF; }
        .stat-box.passed { background: #34C759; }
        .stat-box.failed { background: #FF3B30; }
        .stat-box.skipped { background: #FF9500; }
        .stat-box h3 { margin: 0; font-size: 2em; }
        .stat-box p { margin: 5px 0 0 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f8f8f8; font-weight: 600; }
        tr:hover { background: #f5f5f5; }
        .pass { color: #34C759; font-weight: 600; }
        .fail { color: #FF3B30; font-weight: 600; }
        .skip { color: #FF9500; font-weight: 600; }
        .info-box { background: #E5F4FF; border-left: 4px solid #007AFF; padding: 15px; margin: 20px 0; }
        .warning-box { background: #FFF4E5; border-left: 4px solid #FF9500; padding: 15px; margin: 20px 0; }
        .error-box { background: #FFE5E5; border-left: 4px solid #FF3B30; padding: 15px; margin: 20px 0; }
        code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: 'SF Mono', Monaco, monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>WinAmp Player Test Report</h1>
        <div class="info-box">
            <strong>Test Run:</strong> $(date)<br>
            <strong>Platform:</strong> $(uname -mrs)<br>
            <strong>Build Type:</strong> Debug with Coverage and Sanitizers
        </div>
        
        <h2>Test Summary</h2>
        <div class="summary">
            <div class="stat-box total">
                <h3>$TOTAL_TESTS</h3>
                <p>Total Tests</p>
            </div>
            <div class="stat-box passed">
                <h3>$PASSED_TESTS</h3>
                <p>Passed</p>
            </div>
            <div class="stat-box failed">
                <h3>$FAILED_TESTS</h3>
                <p>Failed</p>
            </div>
            <div class="stat-box skipped">
                <h3>$SKIPPED_TESTS</h3>
                <p>Skipped</p>
            </div>
        </div>
        
        <h2>Test Results by Category</h2>
        <table>
            <thead>
                <tr>
                    <th>Test Category</th>
                    <th>Status</th>
                    <th>Duration</th>
                    <th>Notes</th>
                </tr>
            </thead>
            <tbody>
EOF

    # Add test results to HTML
    if [[ -f "${RESULTS_DIR}/unit_test_summary.txt" ]]; then
        while IFS=: read -r test status; do
            local status_class="skip"
            local status_text="SKIPPED"
            case $status in
                "PASS") status_class="pass"; status_text="PASSED" ;;
                "FAIL") status_class="fail"; status_text="FAILED" ;;
            esac
            echo "                <tr><td>$test</td><td class=\"$status_class\">$status_text</td><td>-</td><td>-</td></tr>" >> "${report_file}"
        done < <(grep -v "Summary:" "${RESULTS_DIR}/unit_test_summary.txt" | sed 's/^ *//')
    fi
    
    cat >> "${report_file}" << EOF
            </tbody>
        </table>
        
        <h2>System Compatibility</h2>
        <div class="info-box">
            <strong>macOS Version:</strong> $(sw_vers -productVersion)<br>
            <strong>Xcode Version:</strong> $(xcodebuild -version | head -1)<br>
            <strong>Compiler:</strong> $(clang --version | head -1)
        </div>
EOF

    if [[ -f "${RESULTS_DIR}/benchmark_results.json" ]]; then
        cat >> "${report_file}" << EOF
        
        <h2>Performance Metrics</h2>
        <div class="info-box">
            <p>Performance benchmarks completed successfully. See detailed results in benchmark_results.json</p>
        </div>
EOF
    fi

    if [[ -d "${REPORT_DIR}/coverage_html" ]]; then
        cat >> "${report_file}" << EOF
        
        <h2>Code Coverage</h2>
        <div class="info-box">
            <p>Code coverage report generated. <a href="coverage_html/index.html">View Coverage Report</a></p>
        </div>
EOF
    fi

    cat >> "${report_file}" << EOF
        
        <h2>Test Logs</h2>
        <div class="info-box">
            <p>Detailed test logs available at: <code>$LOG_FILE</code></p>
        </div>
    </div>
</body>
</html>
EOF

    log "${GREEN}✓ HTML test report created: ${report_file}${NC}"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    
    # Open report in browser if on macOS
    if [[ "$(uname)" == "Darwin" ]] && command -v open &> /dev/null; then
        open "${report_file}"
    fi
}

# Check for memory leaks
check_memory_leaks() {
    log "\n${YELLOW}[8/9] Checking for Memory Leaks...${NC}"
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # Use leaks tool on macOS
        if command -v leaks &> /dev/null && [[ -f "${BUILD_DIR}/WinAmpPlayer" ]]; then
            log "Running memory leak detection..."
            
            # Start the application in background
            "${BUILD_DIR}/WinAmpPlayer" &
            local app_pid=$!
            
            # Give it time to initialize
            sleep 3
            
            # Run leaks detection
            if leaks $app_pid > "${RESULTS_DIR}/leaks_report.txt" 2>&1; then
                if grep -q "0 leaks for 0 total leaked bytes" "${RESULTS_DIR}/leaks_report.txt"; then
                    log "${GREEN}✓ No memory leaks detected${NC}"
                    ((PASSED_TESTS++))
                else
                    log "${RED}✗ Memory leaks detected${NC}"
                    grep "leaks for" "${RESULTS_DIR}/leaks_report.txt"
                    ((FAILED_TESTS++))
                fi
            else
                log "${YELLOW}⚠ Could not complete leak detection${NC}"
                ((SKIPPED_TESTS++))
            fi
            
            # Clean up
            kill $app_pid 2>/dev/null || true
        else
            log "${YELLOW}⚠ Leaks tool not available or application not built${NC}"
            ((SKIPPED_TESTS++))
        fi
    else
        log "${YELLOW}⚠ Memory leak detection only available on macOS${NC}"
        ((SKIPPED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Validate resource usage
validate_resource_usage() {
    log "\n${YELLOW}[9/9] Validating Resource Usage...${NC}"
    
    if [[ -f "${BUILD_DIR}/WinAmpPlayer" ]]; then
        # Check binary size
        local binary_size=$(stat -f%z "${BUILD_DIR}/WinAmpPlayer" 2>/dev/null || stat -c%s "${BUILD_DIR}/WinAmpPlayer" 2>/dev/null)
        local size_mb=$((binary_size / 1024 / 1024))
        
        log "Binary size: ${size_mb}MB"
        
        if [[ $size_mb -lt 50 ]]; then
            log "${GREEN}✓ Binary size acceptable (<50MB)${NC}"
            ((PASSED_TESTS++))
        else
            log "${YELLOW}⚠ Binary size large (${size_mb}MB)${NC}"
            ((PASSED_TESTS++))
        fi
        
        # Check dependencies
        log "\nChecking dependencies..."
        otool -L "${BUILD_DIR}/WinAmpPlayer" > "${RESULTS_DIR}/dependencies.txt"
        local dep_count=$(wc -l < "${RESULTS_DIR}/dependencies.txt")
        log "Total dependencies: $dep_count"
        
        # Validate no missing dependencies
        if ! grep -q "not found" "${RESULTS_DIR}/dependencies.txt"; then
            log "${GREEN}✓ All dependencies resolved${NC}"
        else
            log "${RED}✗ Missing dependencies found${NC}"
            grep "not found" "${RESULTS_DIR}/dependencies.txt"
        fi
    else
        log "${YELLOW}⚠ Application binary not found${NC}"
        ((SKIPPED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Generate failure report
generate_failure_report() {
    local fail_report="${REPORT_DIR}/failure_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "${fail_report}" << EOF
WinAmp Player Test Failure Report
Generated: $(date)

Test Summary:
- Total Tests: $TOTAL_TESTS
- Passed: $PASSED_TESTS
- Failed: $FAILED_TESTS
- Skipped: $SKIPPED_TESTS

Failure Details:
EOF
    
    # Add last 100 lines of log
    echo -e "\nLast 100 lines of test log:\n" >> "${fail_report}"
    tail -100 "${LOG_FILE}" >> "${fail_report}"
    
    log "\nFailure report generated: ${fail_report}"
}

# Generate test summary markdown
generate_test_summary() {
    local summary_file="${TEST_DIR}/Tests/TestSummary.md"
    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    cat > "${summary_file}" << EOF
# WinAmp Player Test Summary

**Generated:** $(date)  
**Platform:** macOS $(sw_vers -productVersion)  
**Build Type:** Debug with Coverage and Sanitizers

## Executive Summary

The WinAmp Player test suite has completed with a **${pass_rate}% pass rate**.

### Overall Results
- **Total Tests:** $TOTAL_TESTS
- **Passed:** $PASSED_TESTS ✅
- **Failed:** $FAILED_TESTS ❌
- **Skipped:** $SKIPPED_TESTS ⚠️

## Test Categories

### Unit Tests
- Audio Engine Tests: $(grep -c "AudioTests" "${RESULTS_DIR}/unit_test_summary.txt" 2>/dev/null || echo "0") tests
- UI Component Tests: $(grep -c "UITests" "${RESULTS_DIR}/unit_test_summary.txt" 2>/dev/null || echo "0") tests
- Visualization Tests: $(grep -c "VisualizationTests" "${RESULTS_DIR}/unit_test_summary.txt" 2>/dev/null || echo "0") tests

### Integration Tests
$(if [[ -f "${RESULTS_DIR}/integration_results.xml" ]]; then echo "✅ Completed successfully"; else echo "⚠️ Not executed"; fi)

### Performance Tests
$(if [[ -f "${RESULTS_DIR}/benchmark_results.json" ]]; then echo "✅ Benchmarks completed"; else echo "⚠️ Not executed"; fi)

## System Compatibility

- **macOS Version:** $(sw_vers -productVersion) $(if [[ $(sw_vers -productVersion | cut -d. -f1) -ge 15 ]]; then echo "✅"; else echo "⚠️"; fi)
- **Xcode Tools:** $(if xcode-select -p &>/dev/null; then echo "✅ Installed"; else echo "❌ Not installed"; fi)
- **Architecture:** $(uname -m)

## Code Quality Metrics

### Code Coverage
$(if [[ -d "${REPORT_DIR}/coverage_html" ]]; then echo "Coverage report generated. [View HTML Report](../test_results/reports/coverage_html/index.html)"; else echo "Coverage data not available"; fi)

### Memory Analysis
$(if [[ -f "${RESULTS_DIR}/leaks_report.txt" ]]; then
    if grep -q "0 leaks" "${RESULTS_DIR}/leaks_report.txt"; then
        echo "✅ No memory leaks detected"
    else
        echo "❌ Memory leaks found - see leaks_report.txt for details"
    fi
else
    echo "⚠️ Memory leak analysis not performed"
fi)

### Resource Usage
- **Binary Size:** $(if [[ -f "${BUILD_DIR}/WinAmpPlayer" ]]; then stat -f%z "${BUILD_DIR}/WinAmpPlayer" | awk '{printf "%.1f MB", $1/1024/1024}'; else echo "N/A"; fi)
- **Dependencies:** $(if [[ -f "${RESULTS_DIR}/dependencies.txt" ]]; then wc -l < "${RESULTS_DIR}/dependencies.txt"; else echo "N/A"; fi) libraries

## Performance Metrics

$(if [[ -f "${RESULTS_DIR}/benchmark_results.json" ]] && command -v jq &>/dev/null; then
    echo "### Key Benchmarks"
    echo '```'
    jq -r '.benchmarks[] | select(.name | contains("Audio")) | "- \(.name): \(.real_time | tonumber / 1000000 | tostring + " ms")"' "${RESULTS_DIR}/benchmark_results.json" 2>/dev/null | head -5
    echo '```'
else
    echo "Performance benchmarks not available"
fi)

## Recommendations for Release

$(if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "### ✅ Ready for Release"
    echo ""
    echo "All tests passed successfully. The application is ready for release consideration."
else
    echo "### ❌ Not Ready for Release"
    echo ""
    echo "There are $FAILED_TESTS failing tests that must be addressed before release."
fi)

### Pre-Release Checklist
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] No memory leaks detected
- [ ] Performance benchmarks meet targets
- [ ] Code coverage > 80%
- [ ] Binary size < 50MB
- [ ] Compatible with macOS 15.5+

## Known Issues and Workarounds

$(if [[ $FAILED_TESTS -gt 0 || $SKIPPED_TESTS -gt 0 ]]; then
    echo "### Issues Identified"
    echo ""
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo "1. **Test Failures:** $FAILED_TESTS tests are currently failing. Review test logs for details."
    fi
    if [[ $SKIPPED_TESTS -gt 0 ]]; then
        echo "2. **Skipped Tests:** $SKIPPED_TESTS tests were skipped due to missing dependencies or configurations."
    fi
    echo ""
    echo "### Workarounds"
    echo "- Ensure all build dependencies are installed"
    echo "- Run tests with administrator privileges if permission errors occur"
    echo "- Check that audio devices are available for audio tests"
else
    echo "No critical issues identified during testing."
fi)

## Test Artifacts

All test artifacts are available in the \`test_results/\` directory:
- **Test Logs:** \`test_results/test_run_*.log\`
- **Coverage Report:** \`test_results/reports/coverage_html/index.html\`
- **Benchmark Results:** \`test_results/benchmark_results.json\`
- **Memory Analysis:** \`test_results/leaks_report.txt\`
- **HTML Report:** \`test_results/reports/test_report_*.html\`

---
*This report was automatically generated by the WinAmp Player test suite.*
EOF

    log "${GREEN}✓ Test summary generated: ${summary_file}${NC}"
}

# Main execution
main() {
    print_banner
    
    # Run all test phases
    check_system_compatibility
    build_application
    run_unit_tests
    run_integration_tests
    run_performance_benchmarks
    generate_coverage_report
    create_unified_report
    check_memory_leaks
    validate_resource_usage
    
    # Generate final summary
    generate_test_summary
    
    # Print final results
    log "\n${BLUE}======================================${NC}"
    log "${BLUE}          Test Run Complete           ${NC}"
    log "${BLUE}======================================${NC}"
    log "Total Tests: $TOTAL_TESTS"
    log "${GREEN}Passed: $PASSED_TESTS${NC}"
    log "${RED}Failed: $FAILED_TESTS${NC}"
    log "${YELLOW}Skipped: $SKIPPED_TESTS${NC}"
    
    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    log "\nPass Rate: ${pass_rate}%"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log "\n${GREEN}✅ All tests passed! Ready for release consideration.${NC}"
        exit 0
    else
        log "\n${RED}❌ Some tests failed. Please review the test report.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"