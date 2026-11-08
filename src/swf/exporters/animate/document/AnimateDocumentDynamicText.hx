package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentDynamicText extends AnimateDocumentSymbol
{
	public var align:String;
	public var border:Bool;
	public var color:Null<Int>;
	public var fontHeight:Int;
	public var fontID:Null<Int>;
	public var fontName:String;
	public var html:Null<Bool>;
	public var indent:Null<Int>;
	public var input:Bool;
	public var leading:Null<Int>;
	public var leftMargin:Null<Int>;
	public var multiline:Bool;
	public var password:Bool;
	/** [x, y, width, height] in twips. **/
	public var rect:Array<Int>;
	public var rightMargin:Null<Int>;
	public var selectable:Bool;
	public var text:String;
	public var wordWrap:Bool;

	public function new()
	{
		super(DYNAMIC_TEXT);
	}
}
