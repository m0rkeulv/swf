package swf;

import haxe.Resource;
import openfl._internal.backend.lime.Image;
import openfl.display.Loader;
import openfl.display.MovieClip;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.ProgressEvent;
import openfl.net.URLRequest;
import openfl.system.ApplicationDomain;
import openfl.system.LoaderContext;
import openfl.utils.AssetLibrary;
import openfl.utils.AssetType;
import openfl.utils.ByteArray;
import openfl.utils.Future;
import openfl.utils.Promise;
#if flash
import flash.display.AVM1Movie;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@SuppressWarnings("checkstyle:FieldDocComment")
@:keep class SWFLibrary extends AssetLibrary
{
	private var applicationDomain:ApplicationDomain;
	private var context:LoaderContext;
	private var id:String;
	private var loader:Loader;

	public function new(id:String)
	{
		super();

		this.id = id;
	}

	public override function exists(id:String, type:String):Bool
	{
		if (id == "" && type == cast AssetType.MOVIE_CLIP)
		{
			return true;
		}

		if (type == (cast AssetType.IMAGE) || type == (cast AssetType.MOVIE_CLIP))
		{
			return applicationDomain.hasDefinition(id);
		}

		return false;
	}

	public override function getImage(id:String):Image
	{
		return Image.fromBitmapData(Type.createEmptyInstance(cast applicationDomain.getDefinition(id)));
	}

	public override function getMovieClip(id:String):MovieClip
	{
		if (id == "")
		{
			#if flash
			if (Std.is(loader.content, AVM1Movie))
			{
				var clip = new MovieClip();
				clip.addChild(loader);
				return clip;
			}
			#end

			return cast loader.content;
		}
		else
		{
			return cast Type.createInstance(applicationDomain.getDefinition(id), []);
		}
	}

	public override function isLocal(id:String, type:String):Bool
	{
		return true;
	}

	public override function load():Future<lime.utils.AssetLibrary>
	{
		var promise = new Promise<lime.utils.AssetLibrary>();

		var bytes:ByteArray = Resource.getBytes("swf:" + id);

		if (bytes == null && classTypes.exists(id))
		{
			bytes = cast(Type.createInstance(classTypes.get(id), []), ByteArray);
		}

		if (bytes != null || paths.exists(id))
		{
			context = new LoaderContext(false, ApplicationDomain.currentDomain, null);
			context.allowCodeImport = true;

			loader = new Loader();
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(event)
			{
				promise.error(event.text);
			});
			loader.contentLoaderInfo.addEventListener(ProgressEvent.PROGRESS, function(event)
			{
				promise.progress(Std.int(event.bytesLoaded), Std.int(event.bytesTotal));
			});
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(_)
			{
				applicationDomain = loader.contentLoaderInfo.applicationDomain;
				promise.complete(this);
			});

			if (bytes != null)
			{
				loader.loadBytes(bytes, context);
			}
			else
			{
				loader.load(new URLRequest(paths.get(id)), context);
			}
		}
		else
		{
			// Assume it's been included using -swf-lib, binary embeds don't appear to work

			applicationDomain = ApplicationDomain.currentDomain;
			promise.complete(this);
		}

		return promise.future;
	}
}
