package swf.exporters.animate.document;

class AnimateDocumentFrame
{
	public var labels:Array<String>;
	/** Null when the frame changes nothing. **/
	public var objects:Array<AnimateDocumentFrameObject>;
	/** The frame script as JavaScript, when the timeline has one (see `FrameScriptParser`). **/
	public var scriptSource:String;

	public function new() {}
}
