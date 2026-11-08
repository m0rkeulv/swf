package swf.exporters.animate;

/** The opcodes of a shape's flat command array in an Animate document. **/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract AnimateShapeCommandType(Int) from Int to Int
{
	public var BEGIN_BITMAP_FILL = 0;
	public var BEGIN_FILL = 1;
	public var BEGIN_GRADIENT_FILL = 2;
	public var CLEAR_LINE_STYLE = 3;
	public var CURVE_TO = 4;
	public var END_FILL = 5;
	public var LINE_STYLE = 6;
	public var LINE_TO = 7;
	public var MOVE_TO = 8;
}
