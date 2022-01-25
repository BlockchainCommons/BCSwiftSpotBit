import Foundation
import WolfAPI
import WolfBase

public class SpotBitAPI: API {
    public static let defaultHost = "h6zwwkcivy2hjys6xpinlnz2f74dsmvltzsd4xb42vinhlcaoe7fdeqd.onion"
    
    public init(host: String? = nil, session: URLSession) {
        let endpoint = Endpoint(scheme: .http, host: host ?? Self.defaultHost)
        super.init(endpoint: endpoint, session: session)
    }
    
    public func isServerRunning(mock: Mock? = nil) async throws -> Bool {
        let result = try await call(
            returning: String.self,
            method: .get,
            path: ["status"],
            mock: mock
        )
        return result == "server is running"
    }
    
    public func configuration(mock: Mock? = nil) async throws -> SpotBitConfiguration {
        try await call(
            returning: SpotBitConfiguration.self,
            method: .get,
            path: ["configure"],
            mock: mock
        )
    }
    
    public func currentAveragePrice(currency: String, mock: Mock? = nil) async throws -> Candle {
        let data = try await call(
            method: .get,
            path: ["now", currency],
            mock: mock
        )
        return try JSONDecoder().decode(SpotBitPrice.self, from: data).candle
    }
    
    public func currentExchangePrice(currency: String, exchange: String, mock: Mock? = nil) async throws -> Candle {
        let data = try await call(
            method: .get,
            path: ["now", currency, exchange],
            mock: mock
        )
        return try JSONDecoder().decode(SpotBitPrice.self, from: data).candle
    }

    public func historicalPrices(currency: String, exchange: String, timeSpan: Range<Date>, mock: Mock? = nil) async throws -> [Candle] {
        let data = try await call(
            method: .get,
            path: ["hist", currency, exchange, Int(timeSpan.lowerBound.millisSince1970), Int(timeSpan.upperBound.millisSince1970)],
            mock: mock
        )
        return try JSONDecoder().decode(SpotBitHistoricalPrices.self, from: data).candles
    }
}

public struct SpotBitPrice: Decodable, Equatable {
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

    public init(currencyPair: String, close: Double, closeDate: Date, openDate: Date?, open: Double?, high: Double?, low: Double?, volume: Double?, exchanges: [String]?, failedExchanges: [String]?) {
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
        //self.dateTime = try container.decode(String.self, forKey: .dateTime)

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
    
    public var candle: Candle {
        Candle(end: closeDate, close: close)!
    }

    enum CodingKeys: String, CodingKey {
        case close = "close"
        case currencyPair = "currency_pair"
        //case dateTime = "datetime"
        case exchanges = "exchanges"
        case failedExchanges = "failed_exchanges"
        case high = "high"
        case low = "low"
        case oldestTimestamp = "oldest_timestamp"
        case open = "open"
        case timestamp = "timestamp"
        case vol = "vol"
        case volume = "volume"
    }

    public static func mockHistoricalPrice(currency: String, closeDate: Date) -> SpotBitPrice {
        let currencyPair = "BTC-\(currency)"
        let low = Double.random(in: 100...50000)
        let high = low + Double.random(in: 100...50000)
        let open = Double.random(in: low...high)
        let close = Double.random(in: low...high)
        let volume = Double.random(in: 0...10)
        return SpotBitPrice(currencyPair: currencyPair, close: close, closeDate: closeDate, openDate: nil, open: open, high: high, low: low, volume: volume, exchanges: nil, failedExchanges: nil)
    }
    
    public func encodeMockHistoricalPrice(id: Int = 0) -> String {
        let components: [Any] = [id, Int(closeDate.millisSince1970), closeDate.description.quoted(), currencyPair.quoted(), open!, high!, low!, close, volume!]
        return components.map( { "\($0)" } ).joined(separator: ",").flanked("[", "]")
    }

    public static func mockPriceForCurrency(_ currency: String) -> SpotBitPrice {
        let currencyPair = "BTC-\(currency)"
        let low = Double.random(in: 100...50000)
        let high = low + Double.random(in: 100...50000)
        let open = Double.random(in: low...high)
        let close = Double.random(in: low...high)
        let closeDate = Date()
        let openDate = closeDate.addingTimeInterval(-10 * 60)
        let volume = Double.random(in: 0...10)
        let exchanges = ["coinbasepro", "hitbtc", "bitfinex", "kraken", "bitstamp"]
        let failedExchanges = ["hitbtc"]
        return SpotBitPrice(currencyPair: currencyPair, close: close, closeDate: closeDate, openDate: openDate, open: open, high: high, low: low, volume: volume, exchanges: exchanges, failedExchanges: failedExchanges)
    }
    
    public func encodeMockPriceForCurrency() -> String {
        """
            {"close":\(close),"currency_pair":"\(currencyPair)","datetime":"\(closeDate.description)","exchanges":\(exchanges!.description),"failed_exchanges":\(failedExchanges!.description),"high":\(high!),"id":"average_value","low":\(low!),"oldest_timestamp":\(Int(openDate!.millisSince1970)),"open":\(open!),"timestamp":\(Int(closeDate.millisSince1970)),"volume":\(volume!)}
        """
    }
}

public struct SpotBitHistoricalPrices: Decodable, Equatable {
    public let prices: [SpotBitPrice]
    
    public init(prices: [SpotBitPrice]) {
        self.prices = prices
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let columns = try container.decode([String].self, forKey: .columns)
        guard columns == ["id", "timestamp", "datetime", "currency_pair", "open", "high", "low", "close", "vol"] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.columns], debugDescription: "Mismatch of expected columns"))
        }
        self.prices = try container.decode([Price].self, forKey: .data).map({ $0.price })
    }
    
    public var candles: [Candle] {
        prices.compactMap { price in
            Candle(start: price.openDate, end: price.closeDate, low: price.low, high: price.high, open: price.open, close: price.close, volume: price.volume ?? 0)
        }
    }
    
    struct Price: Decodable {
        let price: SpotBitPrice
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            /*let id*/ _ = try container.decode(Int.self)
            let timestampMillis = try container.decode(Double.self)
            let closeDate = Date(millisSince1970: timestampMillis)
            /*let dateTime*/ _ = try container.decode(String.self)
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
    
    public static func mockHistoricalPrices(currency: String, timeSpan: Range<Date>, points: Int = 30) -> SpotBitHistoricalPrices {
        let timeDivision = timeSpan.duration / Double(points - 1)
        let prices: [SpotBitPrice] = (1...points).map { i in
            let closeDate = timeSpan.lowerBound + (timeDivision * Double(i))
            return SpotBitPrice.mockHistoricalPrice(currency: currency, closeDate: closeDate)
        }
        return SpotBitHistoricalPrices(prices: prices)
    }
    
    public func encodeMockHistoricalPrices() -> String {
        let p: [String] = prices.enumerated().map {
            let (i, price) = $0
            return price.encodeMockHistoricalPrice(id: i)
        }
        let pricePoints = p.joined(separator: ",").flanked("[", "]")
        return """
            {"columns":["id","timestamp","datetime","currency_pair","open","high","low","close","vol"],"data":\(pricePoints)}
        """
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
    
    public static func mockConfiguration() -> String {
        #"{"cached exchanges":["gemini","bitstamp","okcoin","coinbasepro","kraken","bitfinex","bitflyer","liquid","coincheck","bitbank","zaif","hitbtc","binance","okex","gateio","bitmax"],"currencies":["USD","GBP","JPY","USDT","EUR"],"interval":10,"keepWeeks":3,"on demand exchanges":["acx","aofex","bequant","bibox","bigone","binance","bitbank","bitbay","bitfinex","bitflyer","bitforex","bithumb","bitkk","bitmax","bitstamp","bittrex","bitz","bl3p","bleutrade","braziliex","btcalpha","btcbox","btcmarkets","btctradeua","bw","bybit","bytetrade","cex","chilebit","coinbase","coinbasepro","coincheck","coinegg","coinex","coinfalcon","coinfloor","coinmate","coinone","crex24","currencycom","digifinex","dsx","eterbase","exmo","exx","foxbit","ftx","gateio","gemini","hbtc","hitbtc","hollaex","huobipro","ice3x","independentreserve","indodax","itbit","kraken","kucoin","lakebtc","latoken","lbank","liquid","livecoin","luno","lykke","mercado","oceanex","okcoin","okex","paymium","poloniex","probit","southxchange","stex","surbitcoin","therock","tidebit","tidex","upbit","vbtc","wavesexchange","whitebit","yobit","zaif","zb"],"updated settings?":"no"}"#
    }
}
