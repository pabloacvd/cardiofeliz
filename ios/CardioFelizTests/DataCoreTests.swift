import XCTest

final class SupabaseDateTests: XCTestCase {
    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int, nanos: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
        return base.addingTimeInterval(Double(nanos) / 1_000_000_000)
    }

    private func assertParses(_ raw: String, _ expected: Date, accuracy: TimeInterval = 0.0005,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard let parsed = SupabaseDate.parse(raw) else { return XCTFail("No se pudo parsear \(raw)", file: file, line: line) }
        XCTAssertEqual(parsed.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: accuracy, raw, file: file, line: line)
    }

    func testZuluWithoutFraction() {
        assertParses("2026-03-04T10:20:30Z", utc(2026, 3, 4, 10, 20, 30))
    }

    func testZuluWithMilliseconds() {
        assertParses("2026-03-04T10:20:30.123Z", utc(2026, 3, 4, 10, 20, 30, nanos: 123_000_000))
    }

    func testPostgrestStyleMicrosecondsAndOffset() {
        assertParses("2026-03-04T10:20:30.123456+00:00", utc(2026, 3, 4, 10, 20, 30, nanos: 123_456_000))
    }

    func testOffsetWithoutFractionPositive() {
        assertParses("2026-03-04T10:20:30+02:00", utc(2026, 3, 4, 8, 20, 30))
    }

    func testNegativeOffsetCompactAndHourOnly() {
        assertParses("2026-03-04T10:20:30-0330", utc(2026, 3, 4, 13, 50, 30))
        assertParses("2026-03-04T10:20:30+00", utc(2026, 3, 4, 10, 20, 30))
        assertParses("2026-03-04T10:20:30-05", utc(2026, 3, 4, 15, 20, 30))
    }

    func testSpaceSeparatorLowercaseAndNoTimezoneAssumesUTC() {
        assertParses("2026-03-04 10:20:30+00", utc(2026, 3, 4, 10, 20, 30))
        assertParses("2026-03-04t10:20:30z", utc(2026, 3, 4, 10, 20, 30))
        assertParses("2026-03-04T10:20:30", utc(2026, 3, 4, 10, 20, 30))
    }

    func testFractionLongerThanNineDigitsIsTruncated() {
        assertParses("2026-03-04T10:20:30.1234567891234Z", utc(2026, 3, 4, 10, 20, 30, nanos: 123_456_789), accuracy: 0.001)
    }

    func testOffsetCrossesDayBoundary() {
        assertParses("2026-03-05T00:30:00+02:00", utc(2026, 3, 4, 22, 30, 0))
    }

    func testLeapDay() {
        XCTAssertNotNil(SupabaseDate.parse("2028-02-29T00:00:00Z"))
        XCTAssertNil(SupabaseDate.parse("2026-02-29T00:00:00Z"))
    }

    func testInvalidInputsReturnNil() {
        for raw in ["", "garbage", "2026-03-04", "2026-02-30T00:00:00Z", "2026-13-01T00:00:00Z",
                    "2026-03-04T25:00:00Z", "2026-03-04T10:61:00Z", "2026-03-04T10:20:30.Z",
                    "2026-03-04T10:20:30+9", "2026-3-4T10:20:30Z", "2026-03-04T1:20:30Z", "2026-03-04T10:20:30+02:99"] {
            XCTAssertNil(SupabaseDate.parse(raw), "Debería rechazar: \(raw)")
        }
    }

    func testFormatIsUTCWithMillisecondsAndRoundTrips() throws {
        let date = utc(2026, 3, 4, 10, 20, 30, nanos: 120_000_000)
        let text = SupabaseDate.format(date)
        XCTAssertEqual(text, "2026-03-04T10:20:30.120Z")
        let back = try XCTUnwrap(SupabaseDate.parse(text))
        XCTAssertEqual(back.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.0005)
    }
}

final class SupabaseConfigTests: XCTestCase {
    private let goodKey = "abcdefghijklmnopqrstuvwxyz0123456789"

    func testValidHTTPS() throws {
        let c = try XCTUnwrap(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: goodKey))
        XCTAssertEqual(c.url.absoluteString, "https://abc.supabase.co")
    }

    func testTrimsWhitespace() {
        XCTAssertNotNil(SupabaseConfig(urlString: " https://abc.supabase.co\n", anonKey: " \(goodKey) "))
    }

    func testHTTPOnlyForLocalhost() {
        XCTAssertNotNil(SupabaseConfig(urlString: "http://localhost:54321", anonKey: goodKey))
        XCTAssertNotNil(SupabaseConfig(urlString: "http://127.0.0.1:54321", anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "http://abc.supabase.co", anonKey: goodKey))
    }

    func testRejectsMissingEmptyAndShortValues() {
        XCTAssertNil(SupabaseConfig(urlString: nil, anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: nil))
        XCTAssertNil(SupabaseConfig(urlString: "", anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: "  "))
        XCTAssertNil(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: "short"))
    }

    func testRejectsBadSchemesHostsAndEmbeddedCredentials() {
        XCTAssertNil(SupabaseConfig(urlString: "ftp://abc.supabase.co", anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "https://", anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "abc.supabase.co", anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "https://user:pass@abc.supabase.co", anonKey: goodKey))
    }

    func testRejectsUnresolvedBuildVariablesAndExamplePlaceholders() {
        XCTAssertNil(SupabaseConfig(urlString: "$(SUPABASE_URL)", anonKey: "$(SUPABASE_ANON_KEY)"))
        XCTAssertNil(SupabaseConfig(urlString: "https://TU-PROYECTO.supabase.co", anonKey: goodKey))
        XCTAssertNil(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: "tu_clave_anon_publica"))
    }

    func testDescriptionNeverRevealsTheKey() throws {
        let c = try XCTUnwrap(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: goodKey))
        XCTAssertFalse(c.description.contains(goodKey))
        XCTAssertFalse("\(c)".contains(goodKey))
    }
}

final class CredentialsTests: XCTestCase {
    func testEmailIsLowercasedTrimmedAndAppLocal() {
        XCTAssertEqual(Credentials.email(username: "  Juli ", password: "x"), "juli@app.local")
        XCTAssertEqual(Credentials.email(username: "ana.m_2-b", password: "x"), "ana.m_2-b@app.local")
    }

    func testRejectsInvalidUsernames() {
        for u in ["", "   ", "ju li", "juli@otro.com", "juli!", "ñandú", "a/b", String(repeating: "a", count: 65)] {
            XCTAssertNil(Credentials.email(username: u, password: "x"), "Debería rechazar: \(u)")
        }
        XCTAssertNotNil(Credentials.email(username: String(repeating: "a", count: 64), password: "x"))
    }

    func testRejectsInvalidPasswords() {
        XCTAssertNil(Credentials.email(username: "juli", password: ""))
        XCTAssertNil(Credentials.email(username: "juli", password: String(repeating: "p", count: 257)))
        XCTAssertNotNil(Credentials.email(username: "juli", password: String(repeating: "p", count: 256)))
    }

    func testUsernameFromEmail() {
        XCTAssertEqual(AuthUser(id: "1", email: "juli@app.local").username, "juli")
        XCTAssertEqual(AuthUser(id: "1", email: nil).username, "usuario")
    }
}

final class ErrorHandlingTests: XCTestCase {
    func testUserMessagesAreGenericAndNeverTechnical() {
        let errors: [DataLayerError] = [.notConfigured, .notAuthenticated, .invalidCredentials, .invalidInput,
                                        .network, .server(code: "23505"), .decoding, .unknown]
        for e in errors {
            XCTAssertFalse(e.userMessage.isEmpty)
            XCTAssertFalse(e.userMessage.contains("23505"))
            XCTAssertFalse(e.userMessage.lowercased().contains("postgres"))
        }
        XCTAssertEqual(DataLayerError.invalidCredentials.userMessage, "Usuario o contraseña incorrectos.")
    }

    func testErrorSummaryDoesNotLeakMessages() {
        let secret = "juli@app.local password=hunter2 token=eyJhbGci"
        let ns = NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: secret])
        let described = ErrorSummary.describe(ns)
        XCTAssertEqual(described, "Test#7")
        XCTAssertFalse(described.contains("hunter2"))
        XCTAssertEqual(ErrorSummary.describe(URLError(.notConnectedToInternet)), "URLError(\(URLError.notConnectedToInternet.rawValue))")
        XCTAssertEqual(ErrorSummary.describe(DataLayerError.server(code: "42501")), "DataLayerError.server(code: 42501)")
        XCTAssertEqual(ErrorSummary.describe(DataLayerError.network), "DataLayerError.network")
    }
}

final class PaginationTests: XCTestCase {
    private func run(total: Int, pageSize: Int) async throws -> (rows: [Int], calls: [[Int]]) {
        var calls: [[Int]] = []
        let rows: [Int] = try await Pagination.fetchAll(pageSize: pageSize) { from, to in
            calls.append([from, to])
            guard from < total else { return [] }
            return Array(from...min(to, total - 1))
        }
        return (rows, calls)
    }

    func testPageSizeMatchesThePWA() {
        XCTAssertEqual(Pagination.pageSize, 1000)
    }

    func testEmptyTableIsOneCall() async throws {
        let r = try await run(total: 0, pageSize: 1000)
        XCTAssertEqual(r.rows.count, 0)
        XCTAssertEqual(r.calls, [[0, 999]])
    }

    func testLessThanOnePageIsOneCall() async throws {
        let r = try await run(total: 999, pageSize: 1000)
        XCTAssertEqual(r.rows.count, 999)
        XCTAssertEqual(r.calls.count, 1)
    }

    func testExactlyOnePageNeedsASecondEmptyCall() async throws {
        let r = try await run(total: 1000, pageSize: 1000)
        XCTAssertEqual(r.rows.count, 1000)
        XCTAssertEqual(r.calls, [[0, 999], [1000, 1999]])
    }

    func testMultiplePagesKeepOrderAndInclusiveRanges() async throws {
        let r = try await run(total: 2500, pageSize: 1000)
        XCTAssertEqual(r.rows, Array(0..<2500))
        XCTAssertEqual(r.calls, [[0, 999], [1000, 1999], [2000, 2999]])
    }

    func testErrorInAPageIsPropagated() async {
        do {
            _ = try await Pagination.fetchAll(pageSize: 10) { from, _ -> [Int] in
                if from > 0 { throw DataLayerError.network }
                return Array(0..<10)
            }
            XCTFail("Debía lanzar")
        } catch {
            XCTAssertEqual(error as? DataLayerError, .network)
        }
    }
}
