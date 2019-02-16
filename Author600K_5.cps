description = "XiLog 3";
vendor = "SCM";
vendorUrl = "http://www.scmgroup.com";
longDescription = "Post processor of XiLog 3";
extension = "xxl";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING;
tolerance = spatial(0.002, MM);
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1400, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined; // allow any circular motion


var xyzFormat = createFormat({decimals:3});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var taperFormat = createFormat({decimals:1, scale:DEG});
var rpmFormat = createFormat({decimals:0});
var DZ = getWorkpiece();
var xOutput = createVariable({prefix:"X="}, xyzFormat);
var yOutput = createVariable({prefix:"Y="}, xyzFormat);
var zOutput = createVariable({prefix:"Z="}, xyzFormat);
var feedOutput = createVariable({prefix:"V="}, feedFormat);
var iOutput = createVariable({prefix:"I=", force:true}, xyzFormat);
var jOutput = createVariable({prefix:"J=", force:true}, xyzFormat);

function writeBlock() {
  writeWords(arguments);
}

function writeComment(text) {
  if (text) {
    writeln("; " + text);
  }
}

function onOpen() {
  var workpiece = getWorkpiece();
  writeBlock("H", "DX=" + xyzFormat.format(workpiece.upper.x), "DY=" + xyzFormat.format(workpiece.upper.y), "DZ=" + xyzFormat.format(workpiece.upper.z), "-A", "*MM", "/DEF");
  writeComment(programName);
  if (programComment != programName) {
    writeComment(programComment);
  }

  // dump tool information
  if (properties.writeTools) {
    var zRanges = {};
    if (is3D()) {
      var numberOfSections = getNumberOfSections();
      for (var i = 0; i < numberOfSections; ++i) {
        var section = getSection(i);
        var zRange = section.getGlobalZRange();
        var tool = section.getTool();
        if (zRanges[tool.number]) {
          zRanges[tool.number].expandToRange(zRange);
        } else {
          zRanges[tool.number] = zRange;
        }
      }
    }

    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment = "T" + toolFormat.format(tool.number) + "  " +
          "D=" + xyzFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
        if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
          comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
        }
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
  }
}

function onComment(message) {
  writeComment(message);
}

function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {
  var abc = currentSection.workPlane.getTurnAndTilt(0, 2);
  writeBlock(
    "XPL",
    "X=" + xyzFormat.format(-1*currentSection.workOrigin.x),
    "Y=" + xyzFormat.format(currentSection.workOrigin.y),
    "Z=" + xyzFormat.format(currentSection.workOrigin.z),
    "Q=" + abcFormat.format(abc.z),
    "R=" + abcFormat.format(abc.x)
  );
 
  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  
  
  feedOutput.reset();
}

function onRadiusCompensation() {
  if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Radius compensation mode not supported."));
  }
}

function onRapid(x, y, z) {
  writeBlock(
    "XG0",
    xOutput.format(-1*x),
    yOutput.format(y),
   
    zOutput.format(-1*z),
    "T=" + toolFormat.format(tool.number),
    "V=" + "1"
  );
  feedOutput.reset();
}

function onLinear(x, y, z, feed) {

  writeBlock("XL2P", xOutput.format(-1*x), yOutput.format(y), zOutput.format(DZ.upper.z - z), feedOutput.format(2));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (isHelical() || (getCircularPlane() != PLANE_XY)) {
    var t = tolerance;
    if ((t == 0) && hasParameter("operation:tolerance")) {
      t = getParameter("operation:tolerance");
    }
    linearize(t);
    return;
  }

  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  writeBlock("XA2P", "G=" + (clockwise ? 2 : 3), xOutput.format(-1*x), yOutput.format(y), zOutput.format(DZ.upper.z - z), iOutput.format(-1*cx), jOutput.format(cy), feedOutput.format(2));
}

function onSectionEnd() {
  writeBlock("XPL", "X=" + xyzFormat.format(0), "Y=" + xyzFormat.format(0), "Z=" + xyzFormat.format(0), "Q=" + abcFormat.format(0), "R=" + abcFormat.format(0)); // reset plane
  writeComment("******************************");
  
  forceAny();
}

function onClose() {
  // home position
  writeBlock("N", "X=" + xyzFormat.format(2000), "; " + localize("home"));
}
