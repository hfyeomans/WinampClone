//
//  TestRunner.swift
//  WinAmpPlayerTests
//
//  Main test runner for comprehensive test execution
//

import XCTest
import Foundation

/// Main test runner that executes all test suites and generates reports
public class TestRunner {
    
    private var results: TestResults = TestResults()
    private let startTime = Date()
    
    /// Run all test suites in priority order
    public func runAllTests() {
        print("===============================================")
        print("WinAmp Player - Comprehensive Test Execution")
        print("Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Date: \(Date())")
        print("===============================================\n")
        
        // Generate fixtures first
        generateTestFixtures()
        
        // Run test suites in priority order
        runCriticalTests()
        runHighPriorityTests()
        runMediumPriorityTests()
        
        // Generate report
        generateTestReport()
    }
    
    // MARK: - Test Execution
    
    private func generateTestFixtures() {
        print("Generating test fixtures...")
        
        do {
            try TestFixtureGenerator.generateAllFixtures()
            print("✓ Test fixtures generated successfully\n")
        } catch {
            print("✗ Failed to generate test fixtures: \(error)\n")
            results.fixtureGenerationFailed = true
        }
    }
    
    private func runCriticalTests() {
        print("Running CRITICAL priority tests...")
        
        // SUITE-01: Audio Playback & Engine
        runTestSuite(Suite01_AudioPlaybackTests.self, suiteName: "SUITE-01: Audio Playback & Engine")
    }
    
    private func runHighPriorityTests() {
        print("\nRunning HIGH priority tests...")
        
        // SUITE-02: Plugin System
        runTestSuite(Suite02_PluginSystemTests.self, suiteName: "SUITE-02: Plugin System")
        
        // SUITE-03: Skin System
        runTestSuite(Suite03_SkinSystemTests.self, suiteName: "SUITE-03: Skin System")
        
        // SUITE-06: Edge Cases & Error Handling
        runTestSuite(Suite06_EdgeCasesTests.self, suiteName: "SUITE-06: Edge Cases & Error Handling")
    }
    
    private func runMediumPriorityTests() {
        print("\nRunning MEDIUM priority tests...")
        
        // Note: SUITE-04, 05, 07 would be implemented similarly
        print("⚠️  Medium priority test suites not yet implemented")
        results.skippedSuites.append("SUITE-04: UI & Windowing")
        results.skippedSuites.append("SUITE-05: Command Menus & Shortcuts")
        results.skippedSuites.append("SUITE-07: Performance & Resource Usage")
    }
    
    // MARK: - Test Suite Execution
    
    private func runTestSuite<T: XCTestCase>(_ testCaseType: T.Type, suiteName: String) {
        print("\n[\(suiteName)]")
        
        let suite = TestSuite()
        suite.name = suiteName
        suite.startTime = Date()
        
        // Get all test methods
        let testMethods = getTestMethods(for: testCaseType)
        
        for methodName in testMethods {
            let testResult = runTest(testCaseType, methodName: methodName)
            suite.tests.append(testResult)
            
            // Print immediate result
            let status = testResult.passed ? "✓" : "✗"
            let duration = String(format: "%.3fs", testResult.duration)
            print("  \(status) \(methodName) (\(duration))")
            
            if !testResult.passed {
                print("    Error: \(testResult.error ?? "Unknown error")")
            }
        }
        
        suite.endTime = Date()
        results.suites.append(suite)
    }
    
    private func runTest<T: XCTestCase>(_ testCaseType: T.Type, methodName: String) -> TestResult {
        let result = TestResult()
        result.name = methodName
        result.startTime = Date()
        
        do {
            // Create test instance
            let testCase = testCaseType.init()
            
            // Set up
            try testCase.setUpWithError()
            
            // Run test method
            let selector = Selector(methodName)
            if testCase.responds(to: selector) {
                testCase.perform(selector)
                result.passed = true
            } else {
                result.passed = false
                result.error = "Test method not found"
            }
            
            // Tear down
            try testCase.tearDownWithError()
            
        } catch {
            result.passed = false
            result.error = error.localizedDescription
        }
        
        result.endTime = Date()
        result.duration = result.endTime!.timeIntervalSince(result.startTime)
        
        return result
    }
    
    // MARK: - Test Discovery
    
    private func getTestMethods<T: XCTestCase>(for testCaseType: T.Type) -> [String] {
        var methods: [String] = []
        var methodCount: UInt32 = 0
        
        guard let methodList = class_copyMethodList(testCaseType, &methodCount) else {
            return methods
        }
        
        defer {
            free(methodList)
        }
        
        for i in 0..<Int(methodCount) {
            let method = methodList[i]
            let selector = method_getName(method)
            let name = NSStringFromSelector(selector)
            
            // Filter for test methods
            if name.hasPrefix("test") && !name.contains(":") {
                methods.append(name)
            }
        }
        
        return methods.sorted()
    }
    
    // MARK: - Report Generation
    
    private func generateTestReport() {
        let duration = Date().timeIntervalSince(startTime)
        
        print("\n===============================================")
        print("Test Execution Summary")
        print("===============================================")
        
        // Calculate totals
        var totalTests = 0
        var passedTests = 0
        var failedTests = 0
        
        for suite in results.suites {
            for test in suite.tests {
                totalTests += 1
                if test.passed {
                    passedTests += 1
                } else {
                    failedTests += 1
                }
            }
        }
        
        let passRate = totalTests > 0 ? (Double(passedTests) / Double(totalTests)) * 100 : 0
        
        print("Total Duration: \(String(format: "%.2f", duration))s")
        print("Total Tests: \(totalTests)")
        print("Passed: \(passedTests) ✓")
        print("Failed: \(failedTests) ✗")
        print("Pass Rate: \(String(format: "%.1f", passRate))%")
        
        if !results.skippedSuites.isEmpty {
            print("\nSkipped Suites:")
            for suite in results.skippedSuites {
                print("  ⚠️  \(suite)")
            }
        }
        
        // Suite breakdown
        print("\nSuite Results:")
        for suite in results.suites {
            let suitePassed = suite.tests.filter { $0.passed }.count
            let suiteTotal = suite.tests.count
            let suiteDuration = suite.endTime?.timeIntervalSince(suite.startTime) ?? 0
            
            print("\n\(suite.name)")
            print("  Tests: \(suitePassed)/\(suiteTotal) passed")
            print("  Duration: \(String(format: "%.3f", suiteDuration))s")
            
            // Show failed tests
            let failedTests = suite.tests.filter { !$0.passed }
            if !failedTests.isEmpty {
                print("  Failed Tests:")
                for test in failedTests {
                    print("    ✗ \(test.name): \(test.error ?? "Unknown error")")
                }
            }
        }
        
        // Write detailed report to file
        writeDetailedReport()
        
        // Final status
        print("\n===============================================")
        if failedTests == 0 && !results.fixtureGenerationFailed {
            print("✅ ALL TESTS PASSED - Ready for release!")
        } else {
            print("❌ TESTS FAILED - Please review failures above")
        }
        print("===============================================\n")
    }
    
    private func writeDetailedReport() {
        let reportURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TestExecutionReport_\(Date().timeIntervalSince1970).md")
        
        var report = """
        # WinAmp Player - Test Execution Report
        
        **Date:** \(Date())  
        **Platform:** macOS \(ProcessInfo.processInfo.operatingSystemVersionString)  
        **Duration:** \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s
        
        ## Summary
        
        """
        
        // Add statistics
        var totalTests = 0
        var passedTests = 0
        var failedTests = 0
        
        for suite in results.suites {
            totalTests += suite.tests.count
            passedTests += suite.tests.filter { $0.passed }.count
            failedTests += suite.tests.filter { !$0.passed }.count
        }
        
        let passRate = totalTests > 0 ? (Double(passedTests) / Double(totalTests)) * 100 : 0
        
        report += """
        - **Total Tests:** \(totalTests)
        - **Passed:** \(passedTests) ✓
        - **Failed:** \(failedTests) ✗
        - **Pass Rate:** \(String(format: "%.1f", passRate))%
        
        ## Suite Details
        
        """
        
        // Add suite details
        for suite in results.suites {
            report += "### \(suite.name)\n\n"
            
            for test in suite.tests {
                let status = test.passed ? "✓" : "✗"
                report += "- \(status) **\(test.name)** (\(String(format: "%.3f", test.duration))s)\n"
                
                if !test.passed {
                    report += "  - Error: \(test.error ?? "Unknown error")\n"
                }
            }
            
            report += "\n"
        }
        
        // Add recommendations
        report += """
        ## Recommendations
        
        """
        
        if failedTests == 0 {
            report += "✅ All tests passed successfully. The application is ready for release consideration.\n"
        } else {
            report += "❌ There are \(failedTests) failing tests that must be addressed before release.\n\n"
            report += "### Critical Issues:\n"
            
            for suite in results.suites {
                let failedInSuite = suite.tests.filter { !$0.passed }
                if !failedInSuite.isEmpty {
                    report += "\n**\(suite.name):**\n"
                    for test in failedInSuite {
                        report += "- \(test.name): \(test.error ?? "Unknown error")\n"
                    }
                }
            }
        }
        
        // Write report
        do {
            try report.write(to: reportURL, atomically: true, encoding: .utf8)
            print("\nDetailed report written to: \(reportURL.path)")
        } catch {
            print("Failed to write detailed report: \(error)")
        }
    }
}

// MARK: - Test Result Models

class TestResults {
    var suites: [TestSuite] = []
    var skippedSuites: [String] = []
    var fixtureGenerationFailed = false
}

class TestSuite {
    var name: String = ""
    var tests: [TestResult] = []
    var startTime: Date = Date()
    var endTime: Date?
}

class TestResult {
    var name: String = ""
    var passed: Bool = false
    var error: String?
    var startTime: Date = Date()
    var endTime: Date?
    var duration: TimeInterval = 0
}

// MARK: - Main Execution

/// Execute the test runner
public func executeTests() {
    let runner = TestRunner()
    runner.runAllTests()
}