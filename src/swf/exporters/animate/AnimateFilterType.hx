package swf.exporters.animate;

/** The first entry of a filter's array in an Animate document (see `AnimateLibraryExporter.serializeFilters`). **/
#if (haxe_ver >= 4.0) enum #else @:enum #end abstract AnimateFilterType(Int) from Int to Int
{
	public var BLUR = 0;
	public var COLOR_MATRIX = 1;
	public var DROP_SHADOW = 2;
	public var GLOW = 3;
	public var GRADIENT_GLOW = 4;
	public var GRADIENT_BEVEL = 5;
}
