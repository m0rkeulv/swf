package swf.exporters.animate.document;

/**
	The document of an `animate` bundle as `AnimateLibraryExporter` builds it from a SWF: the root sprite
	and the symbols, holding the values the bundle stores (lengths in twips as Int, matrices and colour
	transforms as number arrays, shape commands as flat token arrays). `AnimateJsonWriter` writes it as
	`data.json` and `AnimateBinaryWriter` as `data.bin`; `AnimateLibrary` and `AnimateBinaryReader` turn
	either back into the `Animate*Symbol` classes. A field left null is not stored, so every field the
	exporter sets only sometimes is nullable.
**/
class AnimateDocument
{
	public var frameRate:Float;
	public var uuid:String;
	public var root:AnimateDocumentSprite;
	public var symbols:Map<Int, AnimateDocumentSymbol>;

	public function new()
	{
		symbols = new Map();
	}

	/** The root, then the symbols by ascending id: the order both documents store, the same on every target. **/
	public function symbolList():Array<AnimateDocumentSymbol>
	{
		var ids = [for (key in symbols.keys()) key];
		ids.sort(function(a, b) return a - b);
		var list:Array<AnimateDocumentSymbol> = [root];
		for (id in ids)
		{
			list.push(symbols.get(id));
		}
		return list;
	}
}
