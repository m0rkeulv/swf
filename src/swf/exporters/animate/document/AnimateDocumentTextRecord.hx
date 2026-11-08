package swf.exporters.animate.document;

class AnimateDocumentTextRecord
{
	public var advances:Array<Int>;
	public var color:Null<Int>;
	public var fontHeight:Int;
	public var fontID:Null<Int>;
	public var glyphs:Array<Int>;
	/** [x, y] in twips, when the record sets either. **/
	public var offset:Array<Int>;

	public function new() {}
}
