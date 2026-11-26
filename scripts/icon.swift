import AppKit
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:output,withIntermediateDirectories:true)
for (name,size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let image = NSImage(size:NSSize(width:size,height:size));image.lockFocus()
    let s = CGFloat(size)/1024;let transform = NSAffineTransform();transform.scale(by:s);transform.concat()
    let rect = NSRect(x:64,y:64,width:896,height:896)
    let shape = NSBezierPath(roundedRect:rect,xRadius:205,yRadius:205)
    NSGradient(starting:NSColor(srgbRed:0.98,green:0.99,blue:1,alpha:1),ending:NSColor(srgbRed:0.89,green:0.93,blue:0.99,alpha:1))!.draw(in:shape,angle:-60)
    NSColor(srgbRed:0.4,green:0.5,blue:0.7,alpha:0.15).setStroke();shape.lineWidth=3;shape.stroke()
    // A continuous L and a detached light point, legible at small sizes.
    let line = NSBezierPath()
    line.move(to:NSPoint(x:372,y:704));line.line(to:NSPoint(x:372,y:391))
    line.curve(to:NSPoint(x:431,y:332),controlPoint1:NSPoint(x:372,y:350),controlPoint2:NSPoint(x:390,y:332))
    line.line(to:NSPoint(x:678,y:332))
    line.lineWidth=92;line.lineCapStyle = .round;line.lineJoinStyle = .round
    NSColor(srgbRed:0.13,green:0.43,blue:0.91,alpha:1).setStroke();line.stroke()
    NSColor(srgbRed:0.30,green:0.66,blue:1,alpha:1).setFill()
    NSBezierPath(ovalIn:NSRect(x:597,y:608,width:118,height:118)).fill()
    image.unlockFocus()
    let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!;try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output+"/"+name+".png"))
}
