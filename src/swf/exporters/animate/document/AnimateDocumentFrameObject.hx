package swf.exporters.animate.document;

import swf.exporters.animate.AnimateFrameObjectType;

class AnimateDocumentFrameObject
{
	public var type:AnimateFrameObjectType;
	/** Identifies the object across the frames of its timeline (the index of the tag that placed it). **/
	public var id:Int;
	/** The character placed; null when the object is removed. **/
	public var symbol:Null<Int>;
	public var name:String;
	/** [a, b, c, d, tx, ty], the offsets in twips. **/
	public var matrix:Array<Float>;
	/** The eight components of the transform, each multiplied by 20 and rounded. **/
	public var colorTransform:Array<Int>;
	/** Per filter an `AnimateFilterType` and its parameters (see `AnimateLibraryExporter.serializeFilters`). **/
	public var filters:Array<Array<Dynamic>>;
	public var depth:Null<Int>;
	public var clipDepth:Null<Int>;
	public var visible:Null<Bool>;
	public var blendMode:String;
	public var cacheAsBitmap:Null<Bool>;
	/** The AMF object of a PlaceObject4 tag. **/
	public var metaData:Dynamic;

	public function new() {}
}
