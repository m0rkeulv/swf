package swf.exporters.animate;

/** The kinds of symbol an Animate document holds, as the `type` field of `data.json` numbers them. **/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract AnimateSymbolType(Int) from Int to Int
{
	public var BITMAP = 0;
	public var BUTTON = 1;
	public var DYNAMIC_TEXT = 2;
	public var FONT = 3;
	public var SHAPE = 4;
	public var SPRITE = 5;
	public var STATIC_TEXT = 6;
}
