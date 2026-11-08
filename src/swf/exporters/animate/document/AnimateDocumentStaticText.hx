package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentStaticText extends AnimateDocumentSymbol
{
	/** [a, b, c, d, tx, ty], the offsets in twips. **/
	public var matrix:Array<Float>;
	public var records:Array<AnimateDocumentTextRecord>;

	public function new()
	{
		super(STATIC_TEXT);
	}
}
