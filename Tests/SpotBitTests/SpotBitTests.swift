import XCTest
import SpotBit
import Tor
import WolfBase

let useMockData = true

final class SpotBitTests: XCTestCase {
    var controller: TorController!
    var session: URLSession!
    var api: SpotBitAPI!

    func testIsServerRunning() async {
        let result = await api.isServerRunning
        XCTAssertTrue(result)
    }
    
    func testGetConfiguration() async throws {
        let result = try await api.configuration
        XCTAssertTrue(result.currencies.contains("USD"))
        XCTAssertTrue(result.currencies.contains("EUR"))
        XCTAssertTrue(result.onDemandExchanges.contains("kraken"))
        XCTAssertTrue(result.cachedExchanges.contains("kraken"))
    }
    
    func testCurrentExchangePrice() async throws {
        let result = try await api.currentPrice(currency: "USD", exchange: "kraken")
        XCTAssertEqual(result.currencyPair, "BTC-USD")
    }
    
    func testCurrentAveragePrice() async throws {
        let result = try await api.currentPrice(currency: "USD")
        XCTAssertEqual(result.currencyPair, "BTC-USD")
        XCTAssertTrue(result.exchanges?.contains("kraken") ?? false)
    }
    
    func testHistoricalPrices() async throws {
        let result = try await api.historicalPrices(currency: "USD", exchange: "kraken", startDate: Date(timeIntervalSince1970: 160080438), endDate: Date(timeIntervalSince1970: 160080450))
        XCTAssertTrue(!result.prices.isEmpty)
        XCTAssertEqual(result.prices[0].currencyPair, "BTC-USD")
    }

    static let configuration: TorConfiguration = {
        var homeDirectory: URL!
        #if targetEnvironment(simulator)
        for variable in ["IPHONE_SIMULATOR_HOST_HOME", "SIMULATOR_HOST_HOME"] {
            if let p = getenv(variable) {
                homeDirectory = URL(fileURLWithPath: String(cString: p))
                break
            }
        }
        #else
        homeDirectory = URL(fileURLWithPath: NSHomeDirectory())
        #endif
        precondition(homeDirectory != nil)
        
        let fileManager = FileManager.default
        
        let dataDirectory = fileManager.temporaryDirectory
        let socketDirectory = homeDirectory.appendingPathComponent(".tor")
        try! fileManager.createDirectory(at: socketDirectory, withIntermediateDirectories: true)
        let socketFile = socketDirectory.appendingPathComponent("control_port")

        return TorConfiguration(
            dataDirectory: dataDirectory,
            controlSocket: socketFile,
            options: [.ignoreMissingTorrc, .cookieAuthentication]
        )
    }()
    
    func authenticate() async throws {
        guard let cookie = Self.configuration.cookie else {
            XCTFail("No cookie file found.")
            return
        }
        try await controller.authenticate(with: cookie)
    }

    static override func setUp() {
        super.setUp()
        guard !useMockData else {
            return
        }
        TorRunner(configuration: Self.configuration).run()
    }
    
    override func setUp() async throws {
        try await super.setUp()

        guard !useMockData else {
            api = SpotBitAPI(session: URLSession(configuration: .default))
            api.useMockData = true
            return
        }

        controller = try await TorController(socket: Self.configuration.controlSocket)
        guard let cookie = Self.configuration.cookie else {
            XCTFail("No cookie file found.")
            return
        }
        try await controller.authenticate(with: cookie)
        try await controller.untilCircuitEstablished()
        let sessionConfiguration = try await controller.getSessionConfiguration()
        session = URLSession(configuration: sessionConfiguration)
        // Blockchain Commons SpotBit instance.
        // https://github.com/blockchaincommons/spotbit#test-server
        api = SpotBitAPI(session: session)
    }
}
