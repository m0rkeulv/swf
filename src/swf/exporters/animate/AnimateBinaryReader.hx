package swf.exporters.animate;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import swf.exporters.animate.AnimateBinaryWriter.*;
import swf.exporters.animate.AnimateShapeCommand;
import swf.exporters.core.FilterType;

typedef AnimateBinaryDocument =
{
	frameRate:Float,
	uuid:String,
	rootIndex:Int,
	symbols:Array<AnimateSymbol>
}

/**
	Reads the `data.bin` of an `animate-binary` bundle (the layout is described on
	`AnimateBinaryWriter`) straight into symbols, the same ones `AnimateLibrary` builds from the JSON
	bundle, without a text parse or a `Dynamic` tree in between. A field the writer marked absent is
	left alone, as the JSON path leaves a field `Json.parse` did not provide.
**/
class AnimateBinaryReader
{
	private var input:BytesInput;

	public static function read(bytes:Bytes):AnimateBinaryDocument
	{
		var reader = new AnimateBinaryReader(bytes);
		var input = reader.input;
		var magic = input.readString(4);
		if (magic != MAGIC) throw 'AnimateBinaryReader: not an animate-binary file';
		var version = input.readUInt16();
		if (version != VERSION) throw 'AnimateBinaryReader: data version $version, this reader is version $VERSION';
		var frameRate = input.readDouble();
		var uuid = reader.str();
		var rootIndex = input.readInt32();
		var count = input.readInt32();
		var symbols = [];
		for (i in 0...count)
			symbols.push(reader.symbol());
		return {frameRate: frameRate, uuid: uuid, rootIndex: rootIndex, symbols: symbols};
	}

	private function new(bytes:Bytes)
	{
		input = new BytesInput(bytes);
		input.bigEndian = false;
	}

	// ------------------------------------------------------------------------------------ symbols

	private function symbol():AnimateSymbol
	{
		var type = input.readByte();
		input.readInt32(); // the body length, for a reader that skips symbols
		var id = nint();
		var className = str();
		var symbol:AnimateSymbol = switch (type)
		{
			case 0: // BITMAP
				var bitmap = new AnimateBitmapSymbol();
				bitmap.path = str();
				bitmap.alpha = str();
				var smooth = nbool();
				if (smooth != null) bitmap.smooth = smooth;
				bitmap;
			case 1: // BUTTON
				var button = new AnimateButtonSymbol();
				button.downState = optionalSprite();
				button.hitState = optionalSprite();
				button.overState = optionalSprite();
				button.upState = optionalSprite();
				button;
			case 2: // DYNAMIC_TEXT
				dynamicText();
			case 3: // FONT
				font();
			case 4: // SHAPE
				var shape = new AnimateShapeSymbol();
				shape.commands = commands();
				shape;
			case 5: // SPRITE
				spriteBody(new AnimateSpriteSymbol());
			case 6: // STATIC_TEXT
				staticText();
			default:
				throw 'AnimateBinaryReader: unknown symbol type $type';
		}
		if (id != null) symbol.id = id;
		symbol.className = className;
		return symbol;
	}

	private function optionalSprite():AnimateSpriteSymbol
	{
		if (input.readByte() == 0) return null;
		var sprite = new AnimateSpriteSymbol();
		var id = nint();
		if (id != null) sprite.id = id;
		sprite.className = str();
		return spriteBody(sprite);
	}

	private function spriteBody(symbol:AnimateSpriteSymbol):AnimateSpriteSymbol
	{
		symbol.baseClassName = str();
		var grid = ints();
		symbol.scale9Grid = grid != null ? new Rectangle(pixel(grid[0]), pixel(grid[1]), pixel(grid[2]), pixel(grid[3])) : null;
		var frameCount = input.readInt32();
		for (i in 0...frameCount)
		{
			var frame = new AnimateFrame();
			var labels = strs();
			if (labels != null) frame.labels = labels;
			var scriptSource = str();
			if (scriptSource != null) frame.scriptSource = scriptSource;
			var objectCount = input.readInt32();
			if (objectCount > 0)
			{
				frame.objects = [];
				for (j in 0...objectCount)
					frame.objects.push(frameObject());
			}
			symbol.frames.push(frame);
		}
		return symbol;
	}

	private function frameObject():AnimateFrameObject
	{
		var object = new AnimateFrameObject();
		var symbol = nint();
		if (symbol != null) object.symbol = symbol;
		var id = nint();
		if (id != null) object.id = id;
		object.name = str();
		object.type = input.readByte();
		object.matrix = matrix();
		var ct = ints();
		object.colorTransform = ct != null ? new ColorTransform(pixel(ct[0]), pixel(ct[1]), pixel(ct[2]), pixel(ct[3]), pixel(ct[4]), pixel(ct[5]),
			pixel(ct[6]), pixel(ct[7])) : null;
		object.filters = filters();
		var depth = nint();
		if (depth != null) object.depth = depth;
		var clipDepth = nint();
		if (clipDepth != null) object.clipDepth = clipDepth;
		var visible = nbool();
		if (visible != null) object.visible = visible;
		object.blendMode = str();
		var cacheAsBitmap = nbool();
		if (cacheAsBitmap != null) object.cacheAsBitmap = cacheAsBitmap;
		var metaData = str();
		if (metaData != null) object.metaData = Json.parse(metaData);
		return object;
	}

	private function dynamicText():AnimateDynamicTextSymbol
	{
		var symbol = new AnimateDynamicTextSymbol();
		symbol.align = str();
		var border = nbool();
		if (border != null) symbol.border = border;
		symbol.color = nint();
		var fontHeight = nint();
		if (fontHeight != null) symbol.fontHeight = fontHeight;
		var fontID = nint();
		if (fontID != null) symbol.fontID = fontID;
		symbol.fontName = str();
		var html = nbool();
		if (html != null) symbol.html = html;
		symbol.indent = nint();
		var inputField = nbool();
		if (inputField != null) symbol.input = inputField;
		symbol.leading = nint();
		symbol.leftMargin = nint();
		var multiline = nbool();
		if (multiline != null) symbol.multiline = multiline;
		var password = nbool();
		if (password != null) symbol.password = password;
		symbol.rightMargin = nint();
		var selectable = nbool();
		if (selectable != null) symbol.selectable = selectable;
		symbol.text = str();
		var wordWrap = nbool();
		if (wordWrap != null) symbol.wordWrap = wordWrap;
		var rect = ints();
		symbol.x = pixel(rect[0]);
		symbol.y = pixel(rect[1]);
		symbol.width = pixel(rect[2]);
		symbol.height = pixel(rect[3]);
		return symbol;
	}

	private function font():AnimateFontSymbol
	{
		var symbol = new AnimateFontSymbol();
		symbol.advances = ints();
		var ascent = nint();
		if (ascent != null) symbol.ascent = ascent;
		var bold = nbool();
		if (bold != null) symbol.bold = bold;
		symbol.codes = ints();
		var descent = nint();
		if (descent != null) symbol.descent = descent;
		var italic = nbool();
		if (italic != null) symbol.italic = italic;
		var leading = nint();
		if (leading != null) symbol.leading = leading;
		symbol.name = str();
		var glyphCount = input.readInt32();
		if (glyphCount >= 0)
		{
			symbol.glyphs = [];
			for (i in 0...glyphCount)
			{
				if (input.readByte() != 0) symbol.glyphs[i] = commands();
			}
		}
		return symbol;
	}

	private function staticText():AnimateStaticTextSymbol
	{
		var symbol = new AnimateStaticTextSymbol();
		symbol.matrix = matrix();
		var recordCount = input.readInt32();
		if (recordCount >= 0)
		{
			var records:Array<Dynamic> = [];
			for (i in 0...recordCount)
			{
				// the JSON gives these as anonymous objects holding only the fields the exporter set
				var record:Dynamic = {};
				var advances = ints();
				if (advances != null) Reflect.setField(record, "advances", advances);
				var color = nint();
				if (color != null) Reflect.setField(record, "color", color);
				var fontHeight = nint();
				if (fontHeight != null) Reflect.setField(record, "fontHeight", fontHeight);
				var fontID = nint();
				if (fontID != null) Reflect.setField(record, "fontID", fontID);
				var glyphs = ints();
				if (glyphs != null) Reflect.setField(record, "glyphs", glyphs);
				var offset = ints();
				if (offset != null) Reflect.setField(record, "offset", offset);
				records.push(record);
			}
			symbol.records = cast records;
		}
		return symbol;
	}

	private function commands():Array<AnimateShapeCommand>
	{
		var count = input.readInt32();
		var commands:Array<AnimateShapeCommand> = [];
		for (i in 0...count)
		{
			switch (input.readByte())
			{
				case 0:
					var bitmap = input.readInt32();
					var m = matrix();
					commands.push(BeginBitmapFill(bitmap, m, nbool() == true, nbool() == true));
				case 1:
					var color = input.readInt32();
					commands.push(BeginFill(color, input.readDouble()));
				case 2:
					var fillType = value();
					var colors = ints();
					var alphas = floats();
					var ratios = ints();
					var m = matrix();
					var spreadMethod = value();
					var interpolationMethod = value();
					commands.push(BeginGradientFill(fillType, colors, alphas, ratios, m, spreadMethod, interpolationMethod, value()));
				case 3:
					commands.push(LineStyle(null, null, null, null, null, null, null, null));
				case 4:
					var controlX = pixel(input.readInt32());
					var controlY = pixel(input.readInt32());
					var anchorX = pixel(input.readInt32());
					commands.push(CurveTo(controlX, controlY, anchorX, pixel(input.readInt32())));
				case 5:
					commands.push(EndFill);
				case 6:
					var thickness = value();
					var color = value();
					var alpha = value();
					var pixelHinting = value();
					var scaleMode = value();
					var caps = value();
					var joints = value();
					commands.push(LineStyle(thickness, color, alpha, pixelHinting, scaleMode, caps, joints, value()));
				case 7:
					var x = pixel(input.readInt32());
					commands.push(LineTo(x, pixel(input.readInt32())));
				case 8:
					var x = pixel(input.readInt32());
					commands.push(MoveTo(x, pixel(input.readInt32())));
				case op:
					throw 'AnimateBinaryReader: unknown shape command $op';
			}
		}
		return commands;
	}

	/** The filter list of a frame object, from the tagged arrays the writer stored. **/
	private function filters():Array<FilterType>
	{
		var count = input.readInt32();
		if (count < 0) return null;
		var result = [];
		for (i in 0...count)
		{
			var filter:Array<Dynamic> = value();
			if (filter == null || filter.length == 0) continue;
			switch (filter[0])
			{
				case 0:
					result.push(FilterType.BlurFilter(filter[1], filter[2], filter[3]));
				case 1:
					result.push(FilterType.ColorMatrixFilter(filter[1]));
				case 2:
					result.push(FilterType.DropShadowFilter(filter[1], filter[2], filter[3], filter[4], filter[5], filter[6], filter[7], filter[8], filter[9],
						filter[10], filter[11]));
				case 3:
					result.push(FilterType.GlowFilter(filter[1], filter[2], filter[3], filter[4], filter[5], filter[6], filter[7], filter[8]));
				default:
			}
		}
		return result;
	}

	// ------------------------------------------------------------------------------------ scalars

	private function str():String
	{
		var length = input.readInt32();
		return length < 0 ? null : input.readString(length);
	}

	private function strs():Array<String>
	{
		var count = input.readInt32();
		if (count < 0) return null;
		return [for (i in 0...count) str()];
	}

	private function nint():Null<Int>
	{
		return input.readByte() == 0 ? null : input.readInt32();
	}

	private function nbool():Null<Bool>
	{
		return switch (input.readByte())
		{
			case 1: false;
			case 2: true;
			default: null;
		}
	}

	/** An int array; one written with nulls comes back as the JSON gives it, an array of boxed values with nulls in it. **/
	private function ints():Array<Int>
	{
		var count = input.readInt32();
		if (count < 0) return null;
		if (input.readByte() == 0) return [for (i in 0...count) input.readInt32()];
		var list:Array<Dynamic> = [];
		for (i in 0...count)
			list.push(input.readByte() == 0 ? null : input.readInt32());
		return cast list;
	}

	private function floats():Array<Float>
	{
		var count = input.readInt32();
		if (count < 0) return null;
		if (input.readByte() == 0) return [for (i in 0...count) input.readDouble()];
		var list:Array<Dynamic> = [];
		for (i in 0...count)
			list.push(input.readByte() == 0 ? null : input.readDouble());
		return cast list;
	}

	private function matrix():Matrix
	{
		if (input.readByte() == 0) return null;
		var a = input.readDouble();
		var b = input.readDouble();
		var c = input.readDouble();
		var d = input.readDouble();
		var tx = pixel(input.readInt32());
		return new Matrix(a, b, c, d, tx, pixel(input.readInt32()));
	}

	private function value():Dynamic
	{
		return switch (input.readByte())
		{
			case TAG_NULL: null;
			case TAG_FALSE: false;
			case TAG_TRUE: true;
			case TAG_INT: input.readInt32();
			case TAG_FLOAT: input.readDouble();
			case TAG_STRING: str();
			case TAG_ARRAY:
				var count = input.readInt32();
				var list:Array<Dynamic> = [for (i in 0...count) value()];
				list;
			case TAG_JSON: Json.parse(str());
			case tag: throw 'AnimateBinaryReader: unknown value tag $tag';
		}
	}

	private inline function pixel(twips:Int):Float
	{
		return twips / 20;
	}
}
