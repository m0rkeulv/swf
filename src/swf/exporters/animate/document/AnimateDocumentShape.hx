package swf.exporters.animate.document;

import swf.exporters.animate.AnimateSymbolType;

class AnimateDocumentShape extends AnimateDocumentSymbol
{
	/** The flat token array: an `AnimateShapeCommandType` followed by its operands, command after command. **/
	public var commands:Array<Dynamic>;

	public function new()
	{
		super(SHAPE);
	}
}
