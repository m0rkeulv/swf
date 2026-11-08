package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentSprite extends AnimateDocumentSymbol
{
	public var frames:Array<AnimateDocumentFrame>;
	/** [x, y, width, height] in twips. **/
	public var scale9Grid:Array<Int>;

	public function new()
	{
		super(SPRITE);
		frames = [];
	}
}
