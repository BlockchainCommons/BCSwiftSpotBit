import XCTest
import SpotBit
import Tor
import WolfBase
import WolfAPI

let useMockData = true

final class SpotBitTests: XCTestCase {
    var controller: TorController!
    var session: URLSession!
    var api: SpotBitAPI!

    func testIsServerRunning() async throws {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            return Mock(string: "server is running")
        }
        let result = try await api.isServerRunning(mock: mock())
        XCTAssertTrue(result)
    }
    
    func testGetConfiguration() async throws {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"cached exchanges":["gemini","bitstamp","okcoin","coinbasepro","kraken","bitfinex","bitflyer","liquid","coincheck","bitbank","zaif","hitbtc","binance","okex","gateio","bitmax"],"currencies":["USD","GBP","JPY","USDT","EUR"],"interval":10,"keepWeeks":3,"on demand exchanges":["acx","aofex","bequant","bibox","bigone","binance","bitbank","bitbay","bitfinex","bitflyer","bitforex","bithumb","bitkk","bitmax","bitstamp","bittrex","bitz","bl3p","bleutrade","braziliex","btcalpha","btcbox","btcmarkets","btctradeua","bw","bybit","bytetrade","cex","chilebit","coinbase","coinbasepro","coincheck","coinegg","coinex","coinfalcon","coinfloor","coinmate","coinone","crex24","currencycom","digifinex","dsx","eterbase","exmo","exx","foxbit","ftx","gateio","gemini","hbtc","hitbtc","hollaex","huobipro","ice3x","independentreserve","indodax","itbit","kraken","kucoin","lakebtc","latoken","lbank","liquid","livecoin","luno","lykke","mercado","oceanex","okcoin","okex","paymium","poloniex","probit","southxchange","stex","surbitcoin","therock","tidebit","tidex","upbit","vbtc","wavesexchange","whitebit","yobit","zaif","zb"],"updated settings?":"no"}"#
            return Mock(string: s)
        }
        let result = try await api.configuration(mock: mock())
        XCTAssertTrue(result.currencies.contains("USD"))
        XCTAssertTrue(result.currencies.contains("EUR"))
        XCTAssertTrue(result.onDemandExchanges.contains("kraken"))
        XCTAssertTrue(result.cachedExchanges.contains("kraken"))
    }
    
    func testCurrentAveragePrice() async throws {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"close":10320.4375,"currency_pair":"BTC-USD","datetime":"Sun, 13 Sep 2020 14:39:11 GMT","exchanges":["coinbasepro","hitbtc","bitfinex","kraken","bitstamp"],"failed_exchanges":["hitbtc"],"high":10321.0875,"id":"average_value","low":10319.3175,"oldest_timestamp":1600007460000,"open":10320.0875,"timestamp":1600007951358.4841,"volume":2.3988248000000003}"#
            return Mock(string: s)
        }
        let result = try await api.currentAveragePrice(currency: "USD", mock: mock())
        XCTAssertEqual(result.currencyPair, "BTC-USD")
        XCTAssertTrue(result.exchanges?.contains("kraken") ?? false)
    }

    func testCurrentExchangePrice() async throws {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"close":10314.06,"currency_pair":"BTC-USD","datetime":"2020-09-13 14:31:00","high":10315.65,"id":122983,"low":10314.06,"open":10315.65,"timestamp":1600007460000,"vol":3.53308926}"#
            return Mock(string: s)
        }
        let result = try await api.currentExchangePrice(currency: "USD", exchange: "kraken", mock: mock())
        XCTAssertEqual(result.currencyPair, "BTC-USD")
    }
    
    func testHistoricalPrices() async throws {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"columns":["id","timestamp","datetime","currency_pair","open","high","low","close","vol"],"data":[[718,1600804380000,"2020-09-22 12:53:00","BTC-USD",10479.3,10483.3,10479.2,10483.3,17.4109874],[719,1600804440000,"2020-09-22 12:54:00","BTC-USD",10483.3,10483.4,10483.3,10483.4,0.098285],[720,1600804500000,"2020-09-22 12:55:00","BTC-USD",10483.4,10483.4,10483.4,10483.4,0.0]]}"#
            return Mock(string: s)
        }
        let result = try await api.historicalPrices(currency: "USD", exchange: "kraken", startDate: Date(timeIntervalSince1970: 160080438), endDate: Date(timeIntervalSince1970: 160080450), mock: mock())
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
