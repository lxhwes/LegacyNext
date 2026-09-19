ObjC.import('AppKit');
function run(argv) {
  var inPath = argv[0], outPath = argv[1], size = parseInt(argv[2], 10);
  var img = $.NSImage.alloc.initWithContentsOfFile(inPath);
  if (img.isNil()) return 'load failed';
  var sz = img.size;
  var rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(null, size, size, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0);
  if (rep.isNil()) return 'rep nil';
  var ctx = $.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep);
  if (ctx.isNil()) return 'ctx nil';
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext(ctx);
  ctx.setImageInterpolation($.NSImageInterpolationHigh);
  img.drawInRectFromRectOperationFraction($.NSMakeRect(0, 0, size, size), $.NSZeroRect, $.NSCompositingOperationSourceOver, 1.0);
  ctx.flushGraphics;
  $.NSGraphicsContext.restoreGraphicsState;
  var data = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $());
  if (data.isNil()) return 'data nil';
  var ok = data.writeToFileAtomically(outPath, false);
  return 'img ' + sz.width + 'x' + sz.height + ' bytes ' + data.length + ' write ' + ok + ' -> ' + outPath;
}
