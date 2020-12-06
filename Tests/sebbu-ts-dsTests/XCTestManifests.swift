import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(sebbu_ts_dsTests.allTests),
    ]
}
#endif
