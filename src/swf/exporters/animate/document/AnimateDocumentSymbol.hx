package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

/** What every symbol of an `AnimateDocument` has; the kind-specific fields are on the subclasses. **/
class AnimateDocumentSymbol
{
	public var type(default, null):AnimateSymbolType;
	/** The character id; null for the root sprite, the main timeline, which is not a character. **/
	public var id:Null<Int>;
	/** The linkage name of a symbol exported for ActionScript, and the ActionScript base class of it. **/
	public var className:String;
	public var baseClassName:String;

	private function new(type:AnimateSymbolType)
	{
		this.type = type;
	}
}
