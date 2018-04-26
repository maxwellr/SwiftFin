//
//  ViewController.swift
//  swiftFin
//
//  Created by Riza Kazemi on 2018-04-24.
//

import UIKit

class ViewController: UIViewController {
    
    
    @IBOutlet weak var stockRequested: UITextField!
    @IBOutlet weak var stockSharePrice: UILabel!
    @IBOutlet weak var stockPlot: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func getStockInfo(_ sender: Any) {
        let SF = SwiftFin()
        SF.getStockQuote(ticker: stockRequested.text!, comp: recSharePrice(rec:ticker:))
        SF.getStockDaily(ticker: stockRequested.text!, comp: recSharePlot(rec:ticker:))

    }
    func recSharePrice(rec : asyncResult, ticker : String){
        stockSharePrice.text = String(format: "%.2f", rec.value)
    }
    func recSharePlot(rec: [Double], ticker: String){
        stockPlot.image = getPlotImg(toPlot: rec, W: Double(stockPlot.frame.width), H: Double(stockPlot.frame.height))
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

let numberOf5MinPerDay = 78

func getPlotImg(toPlot: [Double], W : Double, H: Double)->UIImage{
    
    UIGraphicsBeginImageContextWithOptions(CGSize(width: W, height: H), false, 0.0)
    if toPlot.count < 2 {
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage()}
    UIColor.lightGray.setStroke()
    var minV = toPlot[0]
    var maxV = toPlot[0]
    let numPoints = toPlot.count
    let numMaxPoints = numberOf5MinPerDay
    for i in 0..<numPoints{
        minV = min(minV,toPlot[i])
        maxV = max(maxV,toPlot[i])
    }
    minV = minV*0.999
    maxV = maxV*1.001

    let containY = H
    let dUnit = (maxV-minV)/containY
    
    
    ctx.beginPath()
    for i in 0..<numPoints{
        let yPoint  = containY - (toPlot[i]-minV)/dUnit
        let xPoint = Double(numPoints-i-1)*W/Double(numMaxPoints)
        if i == 0{
            ctx.move(to: CGPoint(x: xPoint, y: yPoint))
        }
        else{
            ctx.addLine(to: CGPoint(x: xPoint, y: yPoint))
        }
    }
    
    ctx.setLineWidth(1)
    ctx.strokePath()
    return UIGraphicsGetImageFromCurrentImageContext()!
}

