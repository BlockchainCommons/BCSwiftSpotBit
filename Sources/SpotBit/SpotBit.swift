import Foundation
import WolfAPI

public class SpotBitAPI: API<NoAuthorization> {
    public static let defaultHost = "h6zwwkcivy2hjys6xpinlnz2f74dsmvltzsd4xb42vinhlcaoe7fdeqd.onion"
    
    public var useMockData: Bool = false
    
    public init(host: String? = nil, session: URLSession) {
        let endpoint = Endpoint(scheme: .http, host: host ?? Self.defaultHost)
        super.init(endpoint: endpoint, session: session)
    }
    
    public var isServerRunning: Bool {
        get async {
            func mock() -> Mock? {
                guard useMockData else {
                    return nil
                }
                return Mock(string: "server is running")
            }

            do {
                let result = try await call(
                    returning: String.self,
                    method: .get,
                    path: ["status"],
                    mock: mock()
                )
                return result == "server is running"
            } catch {
                return false
            }
        }
    }
    
    public var configuration: SpotBitConfiguration {
        get async throws {
            func mock() -> Mock? {
                guard useMockData else {
                    return nil
                }
                let s = #"{"cached exchanges":["gemini","bitstamp","okcoin","coinbasepro","kraken","bitfinex","bitflyer","liquid","coincheck","bitbank","zaif","hitbtc","binance","okex","gateio","bitmax"],"currencies":["USD","GBP","JPY","USDT","EUR"],"interval":10,"keepWeeks":3,"on demand exchanges":["acx","aofex","bequant","bibox","bigone","binance","bitbank","bitbay","bitfinex","bitflyer","bitforex","bithumb","bitkk","bitmax","bitstamp","bittrex","bitz","bl3p","bleutrade","braziliex","btcalpha","btcbox","btcmarkets","btctradeua","bw","bybit","bytetrade","cex","chilebit","coinbase","coinbasepro","coincheck","coinegg","coinex","coinfalcon","coinfloor","coinmate","coinone","crex24","currencycom","digifinex","dsx","eterbase","exmo","exx","foxbit","ftx","gateio","gemini","hbtc","hitbtc","hollaex","huobipro","ice3x","independentreserve","indodax","itbit","kraken","kucoin","lakebtc","latoken","lbank","liquid","livecoin","luno","lykke","mercado","oceanex","okcoin","okex","paymium","poloniex","probit","southxchange","stex","surbitcoin","therock","tidebit","tidex","upbit","vbtc","wavesexchange","whitebit","yobit","zaif","zb"],"updated settings?":"no"}"#
                return Mock(string: s)
            }
            return try await call(
                returning: SpotBitConfiguration.self,
                method: .get,
                path: ["configure"],
                mock: mock()
            )
        }
    }
    
    public func currentPrice(currency: String) async throws -> SpotBitPrice {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"close":10320.4375,"currency_pair":"BTC-USD","datetime":"Sun, 13 Sep 2020 14:39:11 GMT","exchanges":["coinbasepro","hitbtc","bitfinex","kraken","bitstamp"],"failed_exchanges":["hitbtc"],"high":10321.0875,"id":"average_value","low":10319.3175,"oldest_timestamp":1600007460000,"open":10320.0875,"timestamp":1600007951358.4841,"volume":2.3988248000000003}"#
            return Mock(string: s)
        }
        return try await call(
            returning: SpotBitPrice.self,
            method: .get,
            path: ["now", currency],
            mock: mock()
        )
    }
    
    public func currentPrice(currency: String, exchange: String) async throws -> SpotBitPrice {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"close":10314.06,"currency_pair":"BTC-USD","datetime":"2020-09-13 14:31:00","high":10315.65,"id":122983,"low":10314.06,"open":10315.65,"timestamp":1600007460000,"vol":3.53308926}"#
            return Mock(string: s)
        }
        return try await call(
            returning: SpotBitPrice.self,
            method: .get,
            path: ["now", currency, exchange],
            mock: mock()
        )
    }

    public func historicalPrices(currency: String, exchange: String, startDate: Date, endDate: Date) async throws -> SpotBitHistoricalPrices {
        func mock() -> Mock? {
            guard useMockData else {
                return nil
            }
            let s = #"{"columns":["id","timestamp","datetime","currency_pair","open","high","low","close","vol"],"data":[[718,1600804380000,"2020-09-22 12:53:00","BTC-USD",10479.3,10483.3,10479.2,10483.3,17.4109874],[719,1600804440000,"2020-09-22 12:54:00","BTC-USD",10483.3,10483.4,10483.3,10483.4,0.098285],[720,1600804500000,"2020-09-22 12:55:00","BTC-USD",10483.4,10483.4,10483.4,10483.4,0.0]]}"#
            return Mock(string: s)
        }
        return try await call(
            returning: SpotBitHistoricalPrices.self,
            method: .get,
            path: ["hist", currency, exchange, startDate.millisSince1970, endDate.millisSince1970],
            mock: mock()
            )
    }
}

public struct SpotBitPrice: Decodable {
    public let currencyPair: String
    public let close: Double
    public let closeDate: Date

    public let openDate: Date?
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let volume: Double?

    public let exchanges: [String]?
    public let failedExchanges: [String]?

    init(currencyPair: String, close: Double, closeDate: Date, openDate: Date?, open: Double?, high: Double?, low: Double?, volume: Double?, exchanges: [String]?, failedExchanges: [String]?) {
        self.currencyPair = currencyPair
        self.close = close
        self.closeDate = closeDate
        self.openDate = openDate
        self.open = open
        self.high = high
        self.low = low
        self.volume = volume
        self.exchanges = exchanges
        self.failedExchanges = failedExchanges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.currencyPair = try container.decode(String.self, forKey: .currencyPair)
        self.close = try container.decode(Double.self, forKey: .close)
        let closeMillis = try container.decode(Double.self, forKey: .timestamp)
        self.closeDate = Date(millisSince1970: closeMillis)

        if let openMillis = try container.decodeIfPresent(Double.self, forKey: .oldestTimestamp) {
            self.openDate = Date(millisSince1970: openMillis)
        } else {
            self.openDate = nil
        }
        self.open = try container.decodeIfPresent(Double.self, forKey: .open)
        self.high = try container.decodeIfPresent(Double.self, forKey: .high)
        self.low = try container.decodeIfPresent(Double.self, forKey: .low)
        if let vol = try container.decodeIfPresent(Double.self, forKey: .vol) {
            self.volume = vol
        } else if let volume = try container.decodeIfPresent(Double.self, forKey: .volume) {
            self.volume = volume
        } else {
            self.volume = nil
        }
        if let exchanges = try container.decodeIfPresent([String].self, forKey: .exchanges) {
            self.exchanges = exchanges
        } else {
            self.exchanges = nil
        }
        if let failedExchanges = try container.decodeIfPresent([String].self, forKey: .failedExchanges) {
            self.failedExchanges = failedExchanges
        } else {
            self.failedExchanges = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case close = "close"
        case currencyPair = "currency_pair"
        case dateTime = "datetime"
        case exchanges = "exchanges"
        case failedExchanges = "failed_exchanges"
        case high = "high"
        case id = "id"
        case low = "low"
        case oldestTimestamp = "oldest_timestamp"
        case open = "open"
        case timestamp = "timestamp"
        case vol = "vol"
        case volume = "volume"
    }
}

public struct SpotBitHistoricalPrices: Decodable {
    public let prices: [SpotBitPrice]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let columns = try container.decode([String].self, forKey: .columns)
        guard columns == ["id", "timestamp", "datetime", "currency_pair", "open", "high", "low", "close", "vol"] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.columns], debugDescription: "Mismatch of expected columns"))
        }
        self.prices = try container.decode([Price].self, forKey: .data).map({ $0.price })
    }
    
    struct Price: Decodable {
        let price: SpotBitPrice
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let /*id*/ _ = try container.decode(Int.self)
            let timestampMillis = try container.decode(Double.self)
            let closeDate = Date(millisSince1970: timestampMillis)
            let /*dateTime*/ _ = try container.decode(String.self)
            let currencyPair = try container.decode(String.self)
            let open = try container.decode(Double.self)
            let high = try container.decode(Double.self)
            let low = try container.decode(Double.self)
            let close = try container.decode(Double.self)
            let vol = try container.decode(Double.self)
            
            self.price = SpotBitPrice(currencyPair: currencyPair, close: close, closeDate: closeDate, openDate: nil, open: open, high: high, low: low, volume: vol, exchanges: nil, failedExchanges: nil)
        }
    }

    enum CodingKeys: String, CodingKey {
        case columns
        case data
    }
}

public struct SpotBitConfiguration: Decodable {
    public let currencies: [String]
    public let cachedExchanges: [String]
    public let onDemandExchanges: [String]
    public let intervalSeconds: Int
    public let keepWeeks: Int
    public let isUpdatedSettings: Bool
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currencies = try container.decode([String].self, forKey: .currencies)
        cachedExchanges = try container.decode([String].self, forKey: .cachedExchanges)
        onDemandExchanges = try container.decode([String].self, forKey: .onDemandExchanges)
        intervalSeconds = try container.decode(Int.self, forKey: .intervalSeconds)
        keepWeeks = try container.decode(Int.self, forKey: .keepWeeks)
        let v = try container.decodeIfPresent(String.self, forKey: .isUpdatedSettings)
        switch v {
        case "yes":
            isUpdatedSettings = true
        default:
            isUpdatedSettings = false
        }
    }

    enum CodingKeys: String, CodingKey {
        case currencies = "currencies"
        case cachedExchanges = "cached exchanges"
        case onDemandExchanges = "on demand exchanges"
        case intervalSeconds = "interval"
        case keepWeeks = "keepWeeks"
        case isUpdatedSettings = "updated settings?"
    }
}
