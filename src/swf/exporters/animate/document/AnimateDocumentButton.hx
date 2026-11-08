package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentButton extends AnimateDocumentSymbol
{
	public var downState:AnimateDocumentSprite;
	public var hitState:AnimateDocumentSprite;
	public var overState:AnimateDocumentSprite;
	public var upState:AnimateDocumentSprite;

	public function new()
	{
		super(BUTTON);
	}
}
