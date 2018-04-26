import Foundation


struct prefAPI{
    var AVsuccess:Int = 0
    var IEXsuccess:Int = 0
}
struct asyncResult{
    var value:Double = -1.0
    var yesterdayV:Double = -1.0
}
var prefStat = [String:prefAPI]()

class SwiftFin{
    let AV = AVComm()
    let IEX = IexComm()
    
    func getStockQuote(ticker: String, comp: @escaping (asyncResult,String)->Void){
        let ticker = ticker.components(separatedBy:                   CharacterSet.urlQueryAllowed.inverted).joined()
        if ticker == "$CASH"{
            comp(asyncResult(value: 1.0, yesterdayV: 1.0),"$CASH")
            return
        }
        if ticker.replacingOccurrences(of: ".TO", with: "") == ticker &&
            ticker.replacingOccurrences(of: ".OTC", with: "") == ticker {
            IEX.getStockQuote(ticker: ticker, comp: comp)
        }
        else{
            AV.getStockQuote(ticker: ticker, comp: comp, tryFix: false)
        }

    }
    
    func getStockDaily(ticker: String, comp: @escaping ([Double],String)->Void){
        let ticker = ticker.components(separatedBy:                   CharacterSet.urlQueryAllowed.inverted).joined()
        if ticker == "$CASH"{
            return
        }
        if ticker.replacingOccurrences(of: ".TO", with: "") == ticker
            && ticker.replacingOccurrences(of: ".OTC", with: "") == ticker{
            IEX.getStockDaily(ticker: ticker, comp: comp)
        }
        else{
            AV.getStockDaily(ticker: ticker, comp: comp, tryFix: false)
        }
    }
    
    
}

class IexComm{
    
    func getStockQuote(ticker: String, comp: @escaping (asyncResult, String)->Void){
        
        let urlString = "https://api.iextrading.com/1.0/stock/" + ticker + "/quote"
        let url = URL(string: urlString)
        
        URLSession.shared.dataTask(with:url!) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {comp(asyncResult(),ticker)}
            } else if(data!.count > 200) {
                do {
                    
                    let tSer = try JSONSerialization.jsonObject(with: data!) as! [String:Any]
                    if let yv = tSer["previousClose"] as? Double{
                        if let cv = tSer["latestPrice"]! as? Double{
                        var parR = asyncResult()
                        parR.value = cv
                        parR.yesterdayV = yv
                        DispatchQueue.main.async {comp(parR, ticker)}
                        prefStat[ticker]?.IEXsuccess = 0
                        print("got quote for " + ticker)
                        }
                    }
                } catch let error as NSError {
                    print(error)
                }
                
            }
            else{
                if prefStat[ticker] == nil{
                    prefStat[ticker] = prefAPI()
                }
                prefStat[ticker]?.IEXsuccess -= 1
                DispatchQueue.main.async {comp(asyncResult(),ticker)}
            }
            
            }.resume()
        
        
    }
    func getStockDaily(ticker: String, comp: @escaping ([Double], String)->Void){
        let urlString = "https://api.iextrading.com/1.0/stock/" + ticker + "/time-series/1d?chartInterval=5"
        let url = URL(string: urlString)
        
        URLSession.shared.dataTask(with:url!) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {comp([],ticker)}
            } else if(data!.count > 200) {
                do {
                    
                    let tSer = try JSONSerialization.jsonObject(with: data!) as! [Any]
                    var timeEntries:[Double]=[]
                    for p in tSer{
                        let vSer = p as! [String:Any]
                        if let value1 = vSer["average"] as? Double{
                            if let value2 = vSer["marketAverage"] as? Double{
                                timeEntries.append(nonZero(first: value1,second: value2))
                            }
                        }
                            
                    }
                    timeEntries.reverse()
                    
                    for i in 0..<timeEntries.count{
                        if timeEntries[i] == 0{
                            var leftNonZero = 0.0
                            var rightNonZero = 0.0
                            for k in 0..<timeEntries.count{
                                if i - k > -1{
                                    if timeEntries[i-k] > 0{
                                        leftNonZero = timeEntries[i-k]
                                        break
                                    }
                                }
                            }
                            for k in 0..<timeEntries.count{
                                if i + k < timeEntries.count{
                                    if timeEntries[i+k] > 0{
                                        rightNonZero = timeEntries[i+k]
                                        break
                                    }
                                }
                            }
                            leftNonZero = leftNonZero == 0.0 ? rightNonZero : leftNonZero
                            rightNonZero = rightNonZero == 0.0 ? leftNonZero : rightNonZero
                            timeEntries[i] = (leftNonZero + rightNonZero) / 2.0
                        }
                    }
                   //partLean.values = timeEntries
                    
                    DispatchQueue.main.async {comp(timeEntries, ticker)}
                    prefStat[ticker]?.IEXsuccess = 0
                    print("got daily for " + ticker)
                    
                } catch let error as NSError {
                    print(error)
                }
                
            }
            else{
                if prefStat[ticker] == nil{
                    prefStat[ticker] = prefAPI()
                }
                prefStat[ticker]?.IEXsuccess -= 1
                DispatchQueue.main.async {comp([],ticker)}

            }
            
            }.resume()
        
    }
}

class AVComm{
    let KEY = "YOUR_ALPHAVANTAGE_KEY"
    
    
    func getStockQuote(ticker: String, comp: @escaping (asyncResult, String)->Void, tryFix: Bool){
        var tickerC = ticker
        if tryFix{
            tickerC = ticker.replacingOccurrences(of: ".TO", with: "")
        }else{
            tickerC = ticker.replacingOccurrences(of: ".OTC", with: "")
        }
        let urlString = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=" + tickerC + "&outputsize=compact&apikey="+KEY
        let url = URL(string: urlString)
        
        URLSession.shared.dataTask(with:url!) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {comp(asyncResult(),ticker)}
            } else if(data!.count > 200) {
                
                do {
                    
                    let parsedData = try JSONSerialization.jsonObject(with: data!) as! [String:Any]
                    let tSer = parsedData["Time Series (Daily)"] as! [String:Any]
                    
                    var timeEntries:[Pair]=[]
                    for p in tSer.keys{
                        let vSer = tSer[p] as! [String:Any]
                        let value = vSer["4. close"] as! String
                       // print(ticker + ", " + value);
                        let temp:Pair = Pair(key:p, value:Double(value)!)
                        timeEntries.append(temp)
                    }
                    timeEntries.sort{$0.key>$1.key}
                    
                    var res = asyncResult()
                    if timeEntries.count > 1 {
                        res.value = timeEntries[0].value
                        res.yesterdayV = timeEntries[1].value
                    }
                    DispatchQueue.main.async {comp(res,ticker)}
                    prefStat[ticker]?.AVsuccess = 0
                    print("got quote for " + ticker)

                } catch let error as NSError {
                    print(error)
                }
            } else{
                let res = String(data: data!, encoding: String.Encoding.utf8)
                if res!.range(of:"Invalid API call") != nil &&
                    ticker != ticker.replacingOccurrences(of: ".TO", with: "") && !tryFix{
                    self.getStockQuote(ticker: ticker, comp: comp, tryFix: true)
                }
                else if res!.range(of:"Invalid API call") != nil{
                    if prefStat[ticker] == nil{
                        prefStat[ticker] = prefAPI()
                    }
                    prefStat[ticker]?.AVsuccess -= 1
                    DispatchQueue.main.async {comp(asyncResult(),ticker)}
                }
            }
            
            }.resume()
        
    }
    
    
    func getStockDaily(ticker: String, comp: @escaping ([Double], String)->Void, tryFix: Bool){
        var tickerC = ticker
        if tryFix{
            tickerC = ticker.replacingOccurrences(of: ".TO", with: "")
        }
        else{
            tickerC = ticker.replacingOccurrences(of: ".OTC", with: "")
        }
        let urlString = "https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&symbol=" + tickerC + "&interval=5min&outputsize=full&apikey="+KEY
        let url = URL(string: urlString)
        
        URLSession.shared.dataTask(with:url!) { (data, response, error) in
            if error != nil {
                DispatchQueue.main.async {comp([],ticker)}
            } else if(data!.count > 200) {
                
                do {
                    
                    let parsedData = try JSONSerialization.jsonObject(with: data!) as! [String:Any]
                    let tSer = parsedData["Time Series (5min)"] as! [String:Any]
                   
                    var timeEntries:[Pair]=[]
                    for p in tSer.keys{
                        let vSer = tSer[p] as! [String:Any]
                        let value = vSer["4. close"] as! String
                        let temp:Pair = Pair(key:p, value:Double(value)!)
                        timeEntries.append(temp)
                    }
                    timeEntries.sort{$0.key>$1.key}
                   
                    DispatchQueue.main.async {comp(getAdjustedArray(mixedArray: timeEntries, interval: 5), ticker)}
                    prefStat[ticker]?.AVsuccess = 0
                    print("got daily for " + ticker)

                } catch let error as NSError {
                    print(error)
                }
                
            }
            else{
                let res = String(data: data!, encoding: String.Encoding.utf8)
                if res!.range(of:"Invalid API call") != nil &&
                    ticker != ticker.replacingOccurrences(of: ".TO", with: "") && !tryFix{
                    self.getStockDaily(ticker: ticker, comp: comp, tryFix: true)
                }else if res!.range(of:"Invalid API call") != nil{
                    if prefStat[ticker] == nil{
                        prefStat[ticker] = prefAPI()
                    }
                    prefStat[ticker]?.AVsuccess -= 1
                    DispatchQueue.main.async {comp([],ticker)}
                }
            }
           
            }.resume()
    }
    
    
}

//MISC HELPER FUNCTIONS

extension String {
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
}


func getAdjustedArray(mixedArray: [Pair], interval: Int)->[Double]{
    if mixedArray.count < 2{
        return []
    }
    var ret:[Double] = []
    var inInterval:[Double] = []
    var prTime = 60 * Int(mixedArray[0].key[11..<13])! +  Int(mixedArray[0].key[14..<16])!
    inInterval.append(mixedArray[0].value)
    for i in 1..<mixedArray.count{
        let nwTime = 60 * Int(mixedArray[i].key[11..<13])! +  Int(mixedArray[i].key[14..<16])!
        
        if prTime - nwTime < interval && prTime - nwTime > 0 {
            inInterval.append(mixedArray[i].value)
        }
            
        else {
            if inInterval.count > 0 {
                let sumArray = inInterval.reduce(0, +)
                let avgArrayValue = sumArray / Double(inInterval.count)
                ret.append(avgArrayValue)
                inInterval.removeAll()
            }
            if prTime - nwTime > interval{
                let totalDif = prTime - nwTime
                let addPoints = max(0, totalDif / interval - 1)
                for _ in 0..<addPoints{
                    ret.append(mixedArray[i].value)
                }
            }
            inInterval.removeAll()
            inInterval.append(mixedArray[i].value)
            if prTime - nwTime < 0{
                break
            }
            prTime = nwTime
        }
    }
    return ret;
}

struct Pair{
    var key:String
    var value:Double
}

func nonZero(first: Double, second: Double)->Double{
    if first>0{
        return first
    }
    else if second > 0{
        return second
    }
    else{
        return 0.0
    }
}
