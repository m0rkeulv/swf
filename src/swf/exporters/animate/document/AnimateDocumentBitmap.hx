package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentBitmap extends AnimateDocumentSymbol
{
	/** The image in the bundle, and the separate alpha image of a JPEG with transparency. **/
	public var path:String;
	public var alpha:String;
	/** Set once a shape fill has asked for smoothing, or for none. **/
	public var smooth:Null<Bool>;

	public function new()
	{
		super(BITMAP);
	}
}
