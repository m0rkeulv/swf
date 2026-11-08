package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentFont extends AnimateDocumentSymbol
{
	/** By glyph index, filled as static text uses the glyphs, so both keep gaps. **/
	public var advances:Array<Null<Int>>;
	public var glyphs:Array<Array<Dynamic>>;
	public var ascent:Int;
	public var bold:Bool;
	public var codes:Array<Int>;
	public var descent:Int;
	public var italic:Bool;
	public var leading:Int;
	public var name:String;

	public function new()
	{
		super(FONT);
		advances = [];
		glyphs = [];
	}
}
